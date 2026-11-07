# PROGRESS

Statuses: `not started` / `in progress` / `done` / `verified`.
After any context compaction: re-read `docs/00_TASK_PROMPT.md` and this file first.

## Stages (section 12)

| # | Stage | Status | Notes |
|---|---|---|---|
| 0 | Timelog, prompt copy, progress, read refs | done | |
| 1 | Research (section 3), refs download, RESEARCH_NOTES | done | 10-agent workflow; refs for all 20 in docs/refs; RESEARCH_NOTES.md; 01 reference corrected |
| 2 | Skeleton: import, driver, screenshot rig, git | done | d3d12 chosen (808 vs 743 fps); shot rig + contact sheets; git |
| 3 | World: terrain, sky, bunker, window, camera | done | clipmap + GZ patch, Nishita sky, aerial perspective, bunker, TOD |
| 4 | blast_physics + bombs.json + selftest | done | research-corrected formulas; selftest 112/112 READY |
| 5 | Reference explosion at full quality | in progress | volume shader v2, shock/dust/wilson/debris layers |
| 6 | Remaining 19 bombs, special types, destruction | in progress | all 20 profiles render; column/surge/dome/rings/ice caps |
| 7 | Menu, slider, previews, HUD, cine mode, keys, l10n | in progress | modules workflow (UI/audio/models/range) |
| 8 | Sound | in progress | modules workflow |
| 9 | Polish, optimization, auto-quality | not started | |
| 10 | QA matrix, independent review, fixes, final frames | not started | |
| 11 | Docs (README, CREDITS, QA_REPORT), cleanup | not started | |
| 12 | Final statistics (section 14) | not started | |

## Bombs (20)

| # | Bomb | Profile | Render cycles | Status |
|---|---|---|---|---|
| 1 | Mk 82 | - | 0 | not started |
| 2 | Mk 84 | - | 0 | not started |
| 3 | Tallboy | - | 0 | not started |
| 4 | Grand Slam | - | 0 | not started |
| 5 | GBU-43/B MOAB | - | 0 | not started |
| 6 | W54 Davy Crockett (Little Feller I) | - | 0 | not started |
| 7 | Father of All Bombs (ATBIP) | - | 0 | not started |
| 8 | B61 Mod 12 (0.3 kt) | - | 0 | not started |
| 9 | Little Boy | - | 0 | not started |
| 10 | Grable | - | 0 | not started |
| 11 | Trinity | - | 0 | not started |
| 12 | Baker | - | 0 | not started |
| 13 | Sedan | - | 0 | not started |
| 14 | Ivy King | - | 0 | not started |
| 15 | B83 | - | 0 | not started |
| 16 | RDS-37 | - | 0 | not started |
| 17 | Ivy Mike | - | 0 | not started |
| 18 | Castle Bravo | - | 0 | not started |
| 19 | Test No. 219 | - | 0 | not started |
| 20 | Tsar Bomba | - | 0 | not started |

## Section 15 completion checklist

| # | Criterion | Status |
|---|---|---|
| 1 | All 20 bombs launch at rec/near/far, each `verified` (>=3 fix-render-look cycles, frames in docs/screens) | not started |
| 2 | Explosions visibly different; selftest prints READY, no FAIL | not started |
| 3 | QA matrix passes, no crashes/errors; QA_REPORT filled | not started |
| 4 | FPS measured, section 9 targets met or deviations described | not started |
| 5 | Clean launch via run.bat (menu, slider, launch, explosion); run_cinematic.bat tested | not started |
| 6 | README, CREDITS, RESEARCH_NOTES, DECISIONS, PROGRESS, TIMELOG, PROJECT_STATS ready | not started |
| 7 | Final local git commit | not started |
| 8 | Time/token/cost calculation done and shown | not started |
