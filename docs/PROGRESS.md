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
| 1 | Mk 82 (0.0001 kt, CONVENTIONAL_SURFACE) | tools/bomb_profiles.py `mk82` | 2 (cycle 1 reviewed, cycle 2 rendered) | in progress |
| 2 | Mk 84 (0.0005 kt, CONVENTIONAL_SURFACE) | tools/bomb_profiles.py `mk84` | 2 (cycle 1 reviewed, cycle 2 rendered) | in progress |
| 3 | Tallboy (0.003 kt, CONVENTIONAL_BURIED) | tools/bomb_profiles.py `tallboy` | 2 (cycle 1 reviewed, cycle 2 rendered) | in progress |
| 4 | Grand Slam (0.0066 kt, CONVENTIONAL_BURIED) | tools/bomb_profiles.py `grand_slam` | 2 (cycle 1 reviewed, cycle 2 rendered) | in progress |
| 5 | GBU-43/B MOAB (0.011 kt, CONVENTIONAL_SURFACE) | tools/bomb_profiles.py `moab` | 2 (cycle 1 reviewed, cycle 2 rendered) | in progress |
| 6 | W54 Davy Crockett (0.018 kt, NUCLEAR_SURFACE) | tools/bomb_profiles.py `davy_crockett` | 2 (cycle 1 reviewed, cycle 2 rendered) | in progress |
| 7 | ATBIP "Father of All Bombs" (0.044 kt, THERMOBARIC) | tools/bomb_profiles.py `foab` | 2 (cycle 1 reviewed, cycle 2 rendered) | in progress |
| 8 | B61 Mod 12 (0.3 kt, NUCLEAR_AIR) | tools/bomb_profiles.py `b61_12` | 2 (cycle 1 reviewed, cycle 2 rendered) | in progress |
| 9 | Grable (15.0 kt, NUCLEAR_LOW_AIR) | tools/bomb_profiles.py `grable` | 2 (cycle 1 reviewed, cycle 2 rendered) | in progress |
| 10 | Little Boy (Hiroshima) (16.0 kt, NUCLEAR_AIR) | tools/bomb_profiles.py `little_boy` | 2 (cycle 1 reviewed, cycle 2 rendered) | in progress |
| 11 | Trinity ("Gadget") (21.0 kt, NUCLEAR_TOWER) | tools/bomb_profiles.py `trinity` | 2 (cycle 1 reviewed, cycle 2 rendered) | in progress |
| 12 | Baker (Crossroads) (23.0 kt, NUCLEAR_UNDERWATER) | tools/bomb_profiles.py `baker` | 2 (cycle 1 reviewed, cycle 2 rendered) | in progress |
| 13 | Sedan (Plowshare) (104.0 kt, NUCLEAR_BURIED) | tools/bomb_profiles.py `sedan` | 2 (cycle 1 reviewed, cycle 2 rendered) | in progress |
| 14 | Ivy King (500.0 kt, NUCLEAR_AIR) | tools/bomb_profiles.py `ivy_king` | 2 (cycle 1 reviewed, cycle 2 rendered) | in progress |
| 15 | B83 (1200.0 kt, NUCLEAR_SURFACE) | tools/bomb_profiles.py `b83` | 2 (cycle 1 reviewed, cycle 2 rendered) | in progress |
| 16 | RDS-37 (1600.0 kt, NUCLEAR_AIR) | tools/bomb_profiles.py `rds37` | 2 (cycle 1 reviewed, cycle 2 rendered) | in progress |
| 17 | Ivy Mike (10400.0 kt, NUCLEAR_SURFACE) | tools/bomb_profiles.py `ivy_mike` | 2 (cycle 1 reviewed, cycle 2 rendered) | in progress |
| 18 | Castle Bravo (15000.0 kt, NUCLEAR_SURFACE) | tools/bomb_profiles.py `castle_bravo` | 2 (cycle 1 reviewed, cycle 2 rendered) | in progress |
| 19 | Test No. 219 (24200.0 kt, NUCLEAR_HIGH_AIR) | tools/bomb_profiles.py `test219` | 2 (cycle 1 reviewed, cycle 2 rendered) | in progress |
| 20 | Tsar Bomba (AN602) (50000.0 kt, NUCLEAR_HIGH_AIR) | tools/bomb_profiles.py `tsar` | 2 (cycle 1 reviewed, cycle 2 rendered) | in progress |

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
