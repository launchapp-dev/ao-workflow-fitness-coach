# Fitness Coach Pipeline

An AI-powered fitness coaching system that assesses client baseline, designs periodized training programs, generates daily workouts, tracks progress, and adapts intensity based on recovery signals — running fully automated across daily, weekly, and monthly cadences.

---

## How It Works

Four workflows cover the complete coaching lifecycle:

```
ONBOARD (once)
  assess-baseline ──► calculate-benchmarks ──► design-program ──► generate-first-week

DAILY (Mon-Sat 6am)
  log-recovery ──► check-readiness ──► generate-workout
                         │
                  [overtrained] ──► force-rest-day

WEEKLY (Monday 7am)
  calculate-progress ──► analyze-week ──► adjust-intensity ──► verify-adjustment ──► compile-weekly-report
                                               ▲                      │
                                               └──── [rework] ────────┘ (max 2x)

MONTHLY (1st of month 8am)
  calculate-monthly-metrics ──► evaluate-program ──┬── [advance]   ──► progress-program ──►─┐
                                                    ├── [maintain]  ─────────────────────────┤
                                                    ├── [deload]    ─────────────────────────┤
                                                    └── [redesign]  ──► redesign-program ──►─┘
                                                                                              │
                                                                              compile-monthly-report
```

---

## Agents

| Agent | Model | Role |
|---|---|---|
| **assessment-specialist** | claude-sonnet-4-6 | Evaluates baseline fitness, training history, mobility, and goals |
| **program-designer** | claude-opus-4-6 | Designs periodized mesocycles and makes macro-level progression decisions |
| **workout-generator** | claude-sonnet-4-6 | Translates program templates into specific daily sessions with loads and rest |
| **recovery-analyst** | claude-haiku-4-5 | Rates daily readiness from sleep/soreness/energy signals; verifies weekly adjustments |
| **progress-tracker** | claude-haiku-4-5 | Aggregates weekly training metrics; identifies adherence, volume, and strength trends |
| **report-compiler** | claude-haiku-4-5 | Generates weekly and monthly progress reports in readable markdown |

---

## AO Features Demonstrated

| Feature | Where |
|---|---|
| **Scheduled workflows** | 3 schedules: daily workout (Mon-Sat 6am), weekly review (Mon 7am), monthly review (1st 8am) |
| **Command phases** | 4 bash scripts with embedded Python for metric calculation |
| **Multi-agent pipeline** | 6 agents across 3 model tiers (Opus, Sonnet, Haiku) |
| **Decision contracts** | 3 decision points: readiness (fresh/moderate/fatigued/overtrained), safety (approve/rework), progression (advance/maintain/deload/redesign) |
| **Output contracts** | Structured outputs on assessment, weekly analysis, and reports |
| **Phase routing** | Readiness verdict routes to workout or rest-day; monthly verdict branches across 4 paths |
| **Rework loops** | `verify-adjustment` loops back to `adjust-intensity` up to 2 times if plan is unsafe |
| **Model variety** | Opus for complex periodization reasoning, Sonnet for structured generation, Haiku for fast analysis |
| **Multiple workflows** | 4 distinct workflows at different cadences |

---

## Quick Start

```bash
cd workflows/fitness-coach

# One-time: onboard the client and generate the first week of workouts
ao workflow run onboard-client

# Start the daemon for scheduled daily/weekly/monthly automation
ao daemon start --autonomous

# Watch live logs
ao daemon stream --pretty
```

---

## Requirements

### API Keys
None required — this pipeline is fully file-based using Claude models via the AO daemon.

### MCP Servers (auto-installed via npx)
- `@modelcontextprotocol/server-filesystem` — read/write all data and workout files
- `@modelcontextprotocol/server-sequential-thinking` — structured reasoning for program design

### Runtime
- Node.js 18+ (for MCP servers via npx)
- Python 3.8+ (for metric calculation scripts)

---

## Project Layout

```
workflows/fitness-coach/
├── .ao/workflows/
│   ├── agents.yaml               # 6 agent profiles
│   ├── phases.yaml               # 15 phase definitions
│   ├── workflows.yaml            # 4 workflow pipelines
│   ├── mcp-servers.yaml          # filesystem + sequential-thinking
│   └── schedules.yaml            # 3 cron schedules
├── config/
│   ├── client-profile.yaml       # Alex Chen: goals, equipment, history
│   ├── exercise-library.yaml     # ~40 exercises by movement pattern
│   ├── periodization-templates.yaml  # Linear, DUP, Block models
│   └── recovery-thresholds.yaml  # Composite readiness scoring
├── scripts/
│   ├── log-recovery.sh           # Simulate/log daily recovery check-in
│   ├── calculate-benchmarks.sh   # Epley 1RM estimation + training zones
│   ├── calculate-progress.sh     # Weekly metrics aggregation
│   └── calculate-monthly.sh      # Monthly trend analysis
├── data/
│   ├── assessment.json           # Baseline assessment results
│   ├── current-program.json      # Active mesocycle program
│   ├── recovery-log.json         # Daily recovery check-in history
│   ├── workout-log.json          # Completed session records
│   ├── progress-metrics.json     # Latest metrics snapshot
│   └── history/                  # Weekly and monthly snapshots
├── workouts/                     # Generated daily workout files
└── reports/                      # Weekly and monthly report files
```

---

## Domain Context

**Periodization** — Systematic planning of training variables (volume, intensity) over time. This pipeline uses Daily Undulating Periodization (DUP), which varies rep ranges and intensities within each week.

**RPE (Rate of Perceived Exertion)** — 6-10 scale. RPE 8 = 2 reps left in the tank. RPE 10 = absolute maximum. The pipeline targets RPE 7-8 in early mesocycle, building to 8-9 by week 3.

**Progressive Overload** — The fundamental driver of strength gains: systematically increasing training stress week over week (load, volume, or both).

**Mesocycle** — A training block of 4-8 weeks with a defined goal. This pipeline runs 4-week mesocycles with a built-in deload (week 4).

**Deload** — A planned reduction in training volume (50-60%) and slightly reduced intensity to allow full systemic recovery before the next mesocycle.

---

## Sample Output

### Daily Workout (workouts/2026-03-30.md excerpt)
```
# Lower B — Deadlift Focus | Week 3 | Readiness: fresh (4.10/5.0)

## Warm-Up (8 min)
- Hip 90/90 mobility: 60s each side
- Banded hip circle: 15 reps each direction
- Romanian deadlift with empty bar: 2×8

## Main Work
| Exercise               | Sets × Reps | Load (kg) | Rest (sec) | RPE Target |
|------------------------|-------------|-----------|------------|------------|
| Conventional Deadlift  | 4 × 3-5     | 120.0     | 360        | 8.5        |
| Good Morning           | 3 × 8       | 65.0      | 150        | 7.5        |

## Accessories
| Exercise     | Sets × Reps   | Load    | Rest |
|--------------|---------------|---------|------|
| Farmer Carry | 3 × 40m walk  | 40kg DB | 120s |
| Pallof Press | 3 × 10/side   | Band    | 90s  |
```

### Weekly Report (reports/weekly-review-2026-03-24.md excerpt)
```
## Week in Review
Strong week 2. Adherence 100% (4/4 sessions). Bench and squat loads increased
as planned. Recovery was solid Monday-Thursday, dipped Friday after heavy deadlifts.

## Performance Metrics
| Lift    | Planned | Actual | Est. 1RM | Δ vs Week 1 |
|---------|---------|--------|----------|-------------|
| Squat   | 90kg×5  | 90kg×5 | 122.5kg  | +2.5kg      |
| Deadlift| 115kg×5 | 115kg×5| 153.3kg  | +3.3kg      |
| Bench   | 77.5kg×5| 77.5kg×5| 97.1kg  | +2.1kg      |
| OHP     | 52.5kg×6| 52.5kg×6| 68.2kg  | +3.2kg      |
```
