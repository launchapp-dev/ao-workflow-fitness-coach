#!/usr/bin/env bash
# log-recovery.sh
# Simulates daily recovery check-in data for today and appends to data/recovery-log.json
# In a real deployment, this would pull from a mobile app check-in form or wearable data.
# For demo purposes, generates realistic values with some variation.

set -euo pipefail

RECOVERY_LOG="data/recovery-log.json"
TODAY=$(date +%Y-%m-%d)
DOW=$(date +%u)  # 1=Mon ... 7=Sun

echo "Logging recovery check-in for $TODAY..."

mkdir -p data

python3 << PYEOF
import json
import os
import random
from datetime import datetime, timedelta

RECOVERY_LOG = "data/recovery-log.json"
TODAY = "$TODAY"
DOW = int("$DOW")  # Day of week 1-7

# Load existing log or start fresh
if os.path.exists(RECOVERY_LOG):
    with open(RECOVERY_LOG, "r") as f:
        log = json.load(f)
else:
    log = {"entries": []}

# Check if today's entry already exists
existing = [e for e in log["entries"] if e["date"] == TODAY]
if existing:
    print(f"Recovery entry for {TODAY} already exists. Skipping.")
    exit(0)

# Look at last 3 days to simulate realistic variation
recent = sorted(log["entries"], key=lambda x: x["date"])[-3:]

# Simulate realistic recovery values
# Base values for a moderately recovered intermediate athlete
base_sleep_hours = 7.0
base_sleep_quality = 3.8
base_soreness = 2.5
base_energy = 3.5
base_mood = 3.7

# Add day-of-week effects (Mondays often better after Sunday rest)
if DOW == 1:  # Monday
    sleep_bonus = 0.5
    soreness_penalty = -0.5  # Less sore after rest day
elif DOW == 5:  # Friday (high training week fatigue)
    sleep_bonus = 0.0
    soreness_penalty = 0.5
elif DOW == 7:  # Sunday (rest day, good recovery)
    sleep_bonus = 0.7
    soreness_penalty = -0.8
else:
    sleep_bonus = 0.0
    soreness_penalty = 0.0

# Generate values with small random variation
sleep_hours = round(max(5.0, min(9.5, base_sleep_hours + sleep_bonus + random.gauss(0, 0.4))), 1)
sleep_quality = round(max(1.0, min(5.0, base_sleep_quality + random.gauss(0, 0.3))), 1)
soreness_avg = round(max(1.0, min(5.0, base_soreness + soreness_penalty + random.gauss(0, 0.4))), 1)
energy = round(max(1.0, min(5.0, base_energy + random.gauss(0, 0.3))), 1)
mood = round(max(1.0, min(5.0, base_mood + random.gauss(0, 0.3))), 1)

# Look up last session RPE
last_rpe = None
if recent:
    last_entry = recent[-1]
    last_rpe = last_entry.get("session_rpe_yesterday")

# Simulate session RPE for yesterday (if it was a training day)
if DOW not in [1, 7]:  # Not Monday or Sunday (rest days)
    session_rpe_yesterday = round(max(6.0, min(10.0, 7.5 + random.gauss(0, 0.5))), 1)
else:
    session_rpe_yesterday = None

# Calculate composite score (matches recovery-thresholds.yaml formula)
adjusted_sleep_score = (sleep_hours / 8.0 * 5.0) * (sleep_quality / 5.0)
adjusted_sleep_score = max(1.0, min(5.0, adjusted_sleep_score))

# Map soreness to score (inverted — higher soreness = lower score)
soreness_score = 6.0 - soreness_avg  # 1 soreness = 5 score, 5 soreness = 1 score
soreness_score = max(1.0, min(5.0, soreness_score))

composite = (
    adjusted_sleep_score * 0.40 +
    soreness_score * 0.25 +
    energy * 0.20 +
    mood * 0.15
)
composite = round(composite, 2)

entry = {
    "date": TODAY,
    "day_of_week": ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"][DOW-1],
    "sleep_hours": sleep_hours,
    "sleep_quality": sleep_quality,
    "soreness_avg": soreness_avg,
    "soreness_breakdown": {
        "lower_body": round(soreness_avg + random.gauss(0, 0.2), 1),
        "upper_body": round(max(1, soreness_avg - 0.5 + random.gauss(0, 0.2)), 1),
        "back": round(max(1, soreness_avg - 0.3 + random.gauss(0, 0.2)), 1),
    },
    "energy": energy,
    "mood": mood,
    "session_rpe_yesterday": session_rpe_yesterday,
    "composite_score": composite,
    "notes": ""
}

log["entries"].append(entry)
log["last_updated"] = TODAY

with open(RECOVERY_LOG, "w") as f:
    json.dump(log, f, indent=2)

print(f"Recovery logged: sleep={sleep_hours}h (quality {sleep_quality}/5), soreness={soreness_avg}/5, energy={energy}/5, mood={mood}/5")
print(f"Composite readiness score: {composite}/5.0")

PYEOF

echo "Recovery log updated."
