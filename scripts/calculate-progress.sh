#!/usr/bin/env bash
# calculate-progress.sh
# Aggregates weekly training metrics from workout-log.json and recovery-log.json.
# Calculates:
#   - Session adherence (completed vs planned)
#   - Total weekly volume (sets × reps × load for working sets)
#   - Estimated 1RM changes per main lift (Epley formula)
#   - Average RPE for the week
#   - Recovery composite score trend
# Writes to data/progress-metrics.json
# Also archives a weekly snapshot to data/history/week-<YYYY-MM-DD>.json

set -euo pipefail

mkdir -p data/history

WORKOUT_LOG="data/workout-log.json"
RECOVERY_LOG="data/recovery-log.json"
PROGRESS_FILE="data/progress-metrics.json"
PROGRAM_FILE="data/current-program.json"
WEEK_DATE=$(date +%Y-%m-%d)

echo "Calculating weekly progress metrics for week of $WEEK_DATE..."

python3 << 'PYEOF'
import json
import os
from datetime import datetime, timedelta

WORKOUT_LOG = "data/workout-log.json"
RECOVERY_LOG = "data/recovery-log.json"
PROGRESS_FILE = "data/progress-metrics.json"
WEEK_DATE = os.popen("date +%Y-%m-%d").read().strip()

def epley_1rm(weight_kg, reps):
    if reps == 1:
        return weight_kg
    return round(weight_kg * (1 + reps / 30.0), 1)

def get_last_7_days_dates():
    today = datetime.strptime(WEEK_DATE, "%Y-%m-%d")
    return [(today - timedelta(days=i)).strftime("%Y-%m-%d") for i in range(7)]

# Load logs
with open(WORKOUT_LOG, "r") as f:
    workout_log = json.load(f)
with open(RECOVERY_LOG, "r") as f:
    recovery_log = json.load(f)

last_7 = get_last_7_days_dates()

# Filter this week's workout sessions
this_week_sessions = [s for s in workout_log.get("sessions", []) if s["date"] in last_7]
this_week_recovery = [e for e in recovery_log.get("entries", []) if e["date"] in last_7]

# Sessions completed
sessions_completed = len([s for s in this_week_sessions if s.get("completed", True)])
sessions_planned = workout_log.get("weekly_plan_sessions", 4)  # Default 4 from client profile

adherence_pct = round((sessions_completed / sessions_planned * 100) if sessions_planned > 0 else 0, 1)

# Total volume per session
total_volume = 0
main_lift_reps = {"squat": [], "deadlift": [], "bench": [], "ohp": []}
all_rpes = []

for session in this_week_sessions:
    for exercise in session.get("exercises", []):
        for s in exercise.get("sets", []):
            weight = s.get("weight_kg", 0)
            reps = s.get("reps", 0)
            total_volume += weight * reps
            # Track main lift sets for 1RM estimation
            lift_name = exercise.get("lift_category", "")
            if lift_name in main_lift_reps and s.get("working_set", True):
                main_lift_reps[lift_name].append({"weight": weight, "reps": reps})
    if session.get("rpe"):
        all_rpes.append(session["rpe"])

avg_rpe = round(sum(all_rpes) / len(all_rpes), 1) if all_rpes else 7.5

# Estimated 1RM per main lift (best set of the week)
strength_trend = {}
for lift, sets in main_lift_reps.items():
    if sets:
        best_e1rm = max(epley_1rm(s["weight"], s["reps"]) for s in sets)
        strength_trend[lift] = {"estimated_1rm_kg": best_e1rm}
    else:
        strength_trend[lift] = {"estimated_1rm_kg": None}

# Load previous metrics for comparison
prev_metrics = {}
prev_file = "data/progress-metrics.json"
if os.path.exists(prev_file):
    with open(prev_file, "r") as f:
        prev = json.load(f)
    prev_strength = prev.get("strength_trend", {})
    for lift in strength_trend:
        if strength_trend[lift]["estimated_1rm_kg"] and lift in prev_strength:
            prev_e1rm = prev_strength[lift].get("estimated_1rm_kg")
            if prev_e1rm:
                delta = round(strength_trend[lift]["estimated_1rm_kg"] - prev_e1rm, 1)
                strength_trend[lift]["delta_vs_last_week_kg"] = delta

# Recovery trend
recovery_scores = [e["composite_score"] for e in this_week_recovery if "composite_score" in e]
avg_recovery = round(sum(recovery_scores) / len(recovery_scores), 2) if recovery_scores else None

# Load previous week recovery for trend
prev_recovery_avg = None
if os.path.exists(prev_file):
    with open(prev_file, "r") as f:
        prev = json.load(f)
    prev_recovery_avg = prev.get("avg_recovery_score")

recovery_trend = "stable"
if avg_recovery and prev_recovery_avg:
    delta = avg_recovery - prev_recovery_avg
    if delta > 0.3:
        recovery_trend = "improving"
    elif delta < -0.3:
        recovery_trend = "declining"

# Volume trend (compare to previous week)
prev_total_volume = None
if os.path.exists(prev_file):
    with open(prev_file, "r") as f:
        prev = json.load(f)
    prev_total_volume = prev.get("total_volume_kg_reps")

volume_trend = "stable"
if prev_total_volume and total_volume:
    pct_change = (total_volume - prev_total_volume) / prev_total_volume * 100
    if pct_change > 5:
        volume_trend = "increasing"
    elif pct_change < -5:
        volume_trend = "decreasing"

metrics = {
    "week_ending": WEEK_DATE,
    "sessions_completed": sessions_completed,
    "sessions_planned": sessions_planned,
    "adherence_pct": adherence_pct,
    "total_volume_kg_reps": total_volume,
    "volume_trend": volume_trend,
    "avg_rpe": avg_rpe,
    "strength_trend": strength_trend,
    "avg_recovery_score": avg_recovery,
    "recovery_trend": recovery_trend,
    "calculated_at": WEEK_DATE,
}

with open(PROGRESS_FILE, "w") as f:
    json.dump(metrics, f, indent=2)

# Archive weekly snapshot
snapshot_path = f"data/history/week-{WEEK_DATE}.json"
with open(snapshot_path, "w") as f:
    json.dump(metrics, f, indent=2)

print(f"Progress metrics written to {PROGRESS_FILE}")
print(f"  Adherence: {adherence_pct}% ({sessions_completed}/{sessions_planned} sessions)")
print(f"  Total volume: {total_volume} kg·reps")
print(f"  Average RPE: {avg_rpe}")
print(f"  Recovery trend: {recovery_trend}")
for lift, data in strength_trend.items():
    e1rm = data.get("estimated_1rm_kg", "N/A")
    delta = data.get("delta_vs_last_week_kg", "")
    delta_str = f" ({'+' if delta and delta > 0 else ''}{delta}kg)" if delta else ""
    print(f"  {lift.upper()} est. 1RM: {e1rm}kg{delta_str}")

PYEOF

echo "Progress calculation complete."
