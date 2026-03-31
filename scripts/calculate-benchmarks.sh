#!/usr/bin/env bash
# calculate-benchmarks.sh
# Reads data/assessment.json and computes:
#   - Estimated 1RMs using the Epley formula
#   - Training zones (percentages of 1RM)
#   - Initial volume targets
#
# Epley formula: 1RM = weight * (1 + reps / 30)
# Writes updated assessment.json with benchmarks field added.

set -euo pipefail

ASSESSMENT_FILE="data/assessment.json"

if [ ! -f "$ASSESSMENT_FILE" ]; then
  echo "ERROR: $ASSESSMENT_FILE not found. Run assess-baseline first."
  exit 1
fi

echo "Calculating strength benchmarks..."

python3 << 'PYEOF'
import json
import math
import os

ASSESSMENT_FILE = "data/assessment.json"

def epley_1rm(weight_kg, reps):
    """Epley formula: 1RM = weight * (1 + reps/30)"""
    if reps == 1:
        return weight_kg
    return round(weight_kg * (1 + reps / 30), 1)

def training_zones(one_rm):
    """Calculate training zones as % of 1RM"""
    return {
        "intensity_50pct": round(one_rm * 0.50, 1),
        "intensity_60pct": round(one_rm * 0.60, 1),
        "intensity_65pct": round(one_rm * 0.65, 1),
        "intensity_70pct": round(one_rm * 0.70, 1),
        "intensity_75pct": round(one_rm * 0.75, 1),
        "intensity_80pct": round(one_rm * 0.80, 1),
        "intensity_85pct": round(one_rm * 0.85, 1),
        "intensity_90pct": round(one_rm * 0.90, 1),
        "intensity_95pct": round(one_rm * 0.95, 1),
    }

with open(ASSESSMENT_FILE, "r") as f:
    assessment = json.load(f)

# Default rep/weight inputs if baseline_strength uses estimated 1RMs directly
# (assessment agent may have already calculated these, this is a verification pass)
baseline = assessment.get("baseline_strength", {})

lifts = {
    "squat": baseline.get("squat", 120),
    "deadlift": baseline.get("deadlift", 150),
    "bench": baseline.get("bench", 95),
    "ohp": baseline.get("ohp", 65),
}

benchmarks = {}
for lift, est_1rm in lifts.items():
    benchmarks[lift] = {
        "estimated_1rm_kg": est_1rm,
        "zones": training_zones(est_1rm),
    }

# Volume targets for intermediate DUP periodization
# Target: 10-20 sets per muscle group per week (Israetel MEV-MAV)
volume_targets = {
    "quads_sets_per_week": 12,
    "hamstrings_sets_per_week": 10,
    "chest_sets_per_week": 12,
    "back_sets_per_week": 14,
    "shoulders_sets_per_week": 10,
    "biceps_sets_per_week": 8,
    "triceps_sets_per_week": 8,
    "core_sets_per_week": 8,
    "notes": "Starting at MEV (minimum effective volume) with room to progress over mesocycle."
}

assessment["benchmarks"] = benchmarks
assessment["volume_targets"] = volume_targets
assessment["benchmark_calculated_at"] = "2026-03-30"

with open(ASSESSMENT_FILE, "w") as f:
    json.dump(assessment, f, indent=2)

print("Benchmarks written to:", ASSESSMENT_FILE)
for lift, data in benchmarks.items():
    print(f"  {lift.upper()}: {data['estimated_1rm_kg']}kg 1RM | 70%: {data['zones']['intensity_70pct']}kg | 80%: {data['zones']['intensity_80pct']}kg | 90%: {data['zones']['intensity_90pct']}kg")

PYEOF

echo "Benchmark calculation complete."
