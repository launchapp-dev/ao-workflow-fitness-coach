#!/usr/bin/env bash
# calculate-monthly.sh
# Aggregates 4 weeks of training data for monthly program evaluation.
# Reads all data/history/week-*.json snapshots from the past 4 weeks.
# Calculates:
#   - Strength progression curves (start vs end estimated 1RMs)
#   - Total volume trend over 4 weeks
#   - Recovery capacity trend
#   - Adherence consistency
#   - PR highlights
# Writes monthly summary to data/progress-metrics.json (overwrites weekly)
# Archives to data/history/month-<YYYY-MM>.json

set -euo pipefail

mkdir -p data/history

MONTH=$(date +%Y-%m)
TODAY=$(date +%Y-%m-%d)

echo "Calculating monthly metrics for $MONTH..."

python3 << 'PYEOF'
import json
import os
import glob
from datetime import datetime, timedelta

TODAY = os.popen("date +%Y-%m-%d").read().strip()
MONTH = os.popen("date +%Y-%m").read().strip()

def epley_1rm(weight_kg, reps):
    if reps == 1:
        return weight_kg
    return round(weight_kg * (1 + reps / 30.0), 1)

# Load all weekly snapshots from history
history_files = sorted(glob.glob("data/history/week-*.json"))
# Only use the last 4 weekly snapshots
last_4_weeks = history_files[-4:] if len(history_files) >= 4 else history_files

if not last_4_weeks:
    print("No weekly snapshots found. Run calculate-progress.sh first for each week.")
    # Create stub metrics for demo
    metrics = {
        "month": MONTH,
        "weeks_analyzed": 0,
        "sessions_completed_total": 0,
        "sessions_planned_total": 16,
        "adherence_pct_avg": 0,
        "volume_by_week": [],
        "strength_start": {},
        "strength_end": {},
        "strength_progression": {},
        "recovery_by_week": [],
        "recovery_trend_monthly": "insufficient_data",
        "avg_rpe_trend": [],
        "prs_this_month": [],
        "calculated_at": TODAY,
    }
    with open("data/progress-metrics.json", "w") as f:
        json.dump(metrics, f, indent=2)
    print("Stub monthly metrics written.")
    exit(0)

weekly_data = []
for f in last_4_weeks:
    with open(f, "r") as fh:
        weekly_data.append(json.load(fh))

# Aggregate metrics
total_sessions_completed = sum(w.get("sessions_completed", 0) for w in weekly_data)
total_sessions_planned = sum(w.get("sessions_planned", 4) for w in weekly_data)
adherence_avg = round(total_sessions_completed / total_sessions_planned * 100, 1) if total_sessions_planned else 0

volume_by_week = [w.get("total_volume_kg_reps", 0) for w in weekly_data]

recovery_by_week = [w.get("avg_recovery_score") for w in weekly_data]
recovery_by_week_clean = [r for r in recovery_by_week if r is not None]

# Recovery trend: compare first half vs second half
if len(recovery_by_week_clean) >= 4:
    first_half_avg = sum(recovery_by_week_clean[:2]) / 2
    second_half_avg = sum(recovery_by_week_clean[2:]) / 2
    diff = second_half_avg - first_half_avg
    recovery_trend_monthly = "improving" if diff > 0.2 else ("declining" if diff < -0.2 else "stable")
elif len(recovery_by_week_clean) >= 2:
    diff = recovery_by_week_clean[-1] - recovery_by_week_clean[0]
    recovery_trend_monthly = "improving" if diff > 0.2 else ("declining" if diff < -0.2 else "stable")
else:
    recovery_trend_monthly = "insufficient_data"

# Strength progression: compare first week to last week
strength_keys = ["squat", "deadlift", "bench", "ohp"]
strength_start = {}
strength_end = {}
strength_progression = {}

first_week = weekly_data[0] if weekly_data else {}
last_week = weekly_data[-1] if weekly_data else {}

for lift in strength_keys:
    start = first_week.get("strength_trend", {}).get(lift, {}).get("estimated_1rm_kg")
    end = last_week.get("strength_trend", {}).get(lift, {}).get("estimated_1rm_kg")
    strength_start[lift] = start
    strength_end[lift] = end
    if start and end:
        delta_kg = round(end - start, 1)
        delta_pct = round(delta_kg / start * 100, 1) if start > 0 else 0
        strength_progression[lift] = {
            "delta_kg": delta_kg,
            "delta_pct": delta_pct,
            "trending": "up" if delta_kg > 0 else ("down" if delta_kg < 0 else "stable"),
        }

# RPE trend across weeks
rpe_trend = [w.get("avg_rpe") for w in weekly_data]

# Identify PRs (simplified: any positive estimated 1RM delta vs start)
prs_this_month = []
for lift, prog in strength_progression.items():
    if prog["delta_kg"] > 2.5:
        prs_this_month.append(f"{lift.upper()} estimated 1RM +{prog['delta_kg']}kg ({prog['delta_pct']}%)")

metrics = {
    "month": MONTH,
    "weeks_analyzed": len(weekly_data),
    "sessions_completed_total": total_sessions_completed,
    "sessions_planned_total": total_sessions_planned,
    "adherence_pct_avg": adherence_avg,
    "volume_by_week": volume_by_week,
    "strength_start": strength_start,
    "strength_end": strength_end,
    "strength_progression": strength_progression,
    "recovery_by_week": recovery_by_week,
    "recovery_trend_monthly": recovery_trend_monthly,
    "avg_rpe_trend": rpe_trend,
    "prs_this_month": prs_this_month,
    "calculated_at": TODAY,
}

with open("data/progress-metrics.json", "w") as f:
    json.dump(metrics, f, indent=2)

# Archive monthly snapshot
archive_path = f"data/history/month-{MONTH}.json"
with open(archive_path, "w") as f:
    json.dump(metrics, f, indent=2)

print(f"Monthly metrics written to data/progress-metrics.json")
print(f"  Weeks analyzed: {len(weekly_data)}")
print(f"  Adherence: {adherence_avg}% ({total_sessions_completed}/{total_sessions_planned} sessions)")
print(f"  Recovery trend: {recovery_trend_monthly}")
print(f"  PRs: {', '.join(prs_this_month) if prs_this_month else 'None recorded'}")

print("\nStrength progression:")
for lift, prog in strength_progression.items():
    if prog:
        sign = "+" if prog['delta_kg'] >= 0 else ""
        print(f"  {lift.upper()}: {strength_start[lift]}kg → {strength_end[lift]}kg ({sign}{prog['delta_kg']}kg, {sign}{prog['delta_pct']}%)")

print("\nVolume by week (kg·reps):")
for i, v in enumerate(volume_by_week, 1):
    bar = "█" * max(1, int(v / 5000))
    print(f"  Week {i}: {bar} {v:,}")

PYEOF

echo "Monthly calculation complete."
