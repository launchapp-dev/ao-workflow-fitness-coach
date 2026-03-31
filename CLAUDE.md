# Fitness Coach — Agent Context

## What This Project Is

An automated fitness coaching pipeline for a single client (Alex Chen, intermediate lifter, powerlifting goal in 6 months). The system runs 4 workflows at different cadences: one-time onboarding, daily workout generation, weekly progress review, and monthly program evaluation.

## Data Model — What's in Each File

| File | What It Contains | Who Reads It | Who Writes It |
|---|---|---|---|
| `config/client-profile.yaml` | Demographics, goals, equipment, training history, injury history | assessment-specialist, program-designer | Never modified after onboarding |
| `config/exercise-library.yaml` | ~40 exercises: movement pattern, muscles, equipment, difficulty | workout-generator, program-designer | Never modified (static reference) |
| `config/periodization-templates.yaml` | Linear, DUP, block periodization models with weekly structures | program-designer | Never modified (static reference) |
| `config/recovery-thresholds.yaml` | Composite readiness scoring formula and verdict thresholds | recovery-analyst | Never modified (static reference) |
| `data/assessment.json` | Baseline assessment + calculated 1RM benchmarks and training zones | All agents | assess-baseline (create), calculate-benchmarks (augment) |
| `data/current-program.json` | Active mesocycle: split, weekly loads, exercise prescriptions | workout-generator, recovery-analyst, progress-tracker | program-designer |
| `data/recovery-log.json` | Daily check-ins: sleep hours/quality, soreness, energy, mood, composite score | recovery-analyst, progress-tracker | log-recovery.sh (append daily) |
| `data/workout-log.json` | Completed session records: exercises, sets, weights, reps, RPE | progress-tracker, report-compiler | workout-generator (append after each session) |
| `data/progress-metrics.json` | Calculated metrics: adherence, volume trend, estimated 1RMs, recovery trend | analyze-week, program-designer, report-compiler | calculate-progress.sh, calculate-monthly.sh |
| `data/history/` | Weekly and monthly snapshots for trend analysis | progress-tracker, program-designer | calculate-progress.sh, calculate-monthly.sh |
| `workouts/` | Daily workout files (YYYY-MM-DD.md or YYYY-MM-DD-rest.md) | Client reference, agents checking recent sessions | workout-generator, force-rest-day phase |
| `reports/` | Weekly and monthly report markdown files | Client reference | report-compiler |

## Domain Terminology

**Training Age** — Years of consistent, structured lifting. Intermediate = 2-4 years. This affects how fast an athlete can recover and progress. Alex is intermediate (3 years).

**Mesocycle** — A training block of 4-8 weeks. This pipeline runs 4-week mesocycles with a deload week 4.

**DUP (Daily Undulating Periodization)** — Rep ranges and intensities vary across the week (e.g., Monday = strength day 4×5, Tuesday = hypertrophy day 4×10). Produces more training variety than linear periodization. Appropriate for intermediate lifters.

**Upper-Lower Split** — 4 days alternating upper (push/pull) and lower (squat/hinge) body sessions. Trains each movement pattern 2x/week.

**Progressive Overload** — Systematic increase of training stress (load, sets, or reps) over time. Without it, adaptation stalls.

**Estimated 1RM** — Calculated maximum for one rep using the Epley formula: `1RM = weight × (1 + reps/30)`. Used to track strength progress without true max testing.

**RPE (Rate of Perceived Exertion)** — 6-10 scale where 10 = absolute max. RPE 8 = 2 reps in reserve. Used to auto-regulate intensity day to day.

**Deload** — Planned reduction in volume (50-60%) and slight intensity reduction. Essential for long-term progress; prevents cumulative fatigue from compounding.

**MRV / MEV** — Maximum Recoverable Volume / Minimum Effective Volume. Volume must be in this range to stimulate growth without causing breakdown. This mesocycle starts at MEV and builds toward MRV over 3 weeks before deload.

## Key Invariants Agents Must Respect

1. **Injury caution**: Alex has a lower back history — never prescribe hyperlordotic positions or high-rep spinal loading under fatigue. Always monitor lumbar position cues in deadlift variants.

2. **Shoulder protection**: Avoid very wide grip bench press and behind-the-neck pressing. Resolved impingement — keep with shoulder-safe variants (moderate grip, natural arc DBs).

3. **Equipment constraints**: Alex has a home gym. No machines, no cable station, no trap bar. Check exercise-library.yaml `equipment` field before prescribing.

4. **Load continuity**: When generating workouts, always check workout-log.json for the most recent session of that type to ensure loads are continuous with the program progression (not random).

5. **Recovery-gated intensity**: The workout-generator MUST apply the readiness modifier from recovery-analyst before finalizing loads. Never generate a full-intensity workout when readiness verdict is `fatigued` or `overtrained`.

6. **Deload is non-negotiable**: Week 4 always runs at deload parameters regardless of how good recovery looks. Skipping deloads leads to overtraining downstream.

## Workflow Entry Points

| Workflow | When to Run | Starting Point |
|---|---|---|
| `onboard-client` | Once, at project start | `ao workflow run onboard-client` |
| `daily-workout` | Every Mon-Sat morning | Auto via cron (`ao daemon start`) |
| `weekly-review` | Every Monday | Auto via cron (runs after daily-workout) |
| `monthly-review` | 1st of each month | Auto via cron |

## Script Assumptions

The bash scripts use Python3 for calculation logic (embedded via heredoc). They expect:
- Python 3.8+ with standard library (no external packages required)
- Existing JSON data files in `data/` (scripts check and handle missing files gracefully)
- Working directory is `workflows/fitness-coach/` (all paths are relative)
