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
| 5 | Reference explosion at full quality | done | raymarched volume (fireball/head/stem/skirt/rings/caps/dome), shock/dust/wilson/debris layers, periodic noise |
| 6 | Remaining 19 bombs, special types, destruction | done | all 20 profiles; column/surge/dome/rings/ice caps; range objects destroyed by pressure/thermal thresholds |
| 7 | Menu, slider, previews, HUD, cine mode, keys, l10n | done | modules built + independently verified (UI 86/86, models, range); menu-drive QA in the real game |
| 8 | Sound | done | procedural synth, 23 sounds, scheduling by DNA arrival, limiter; verifier 126/126 |
| 9 | Polish, optimization, auto-quality | in progress | auto-quality fixed (D014); worst case ~107 fps at 1440p |
| 10 | QA matrix, independent review, fixes, final frames | in progress | review cycle 2 done (avg 3.1/10, 162 issues) and fixed; cycle 3 next; QA matrix runs clean after fixes |
| 11 | Docs (README, CREDITS, QA_REPORT), cleanup | not started | |
| 12 | Final statistics (section 14) | not started | |

## Bombs (20)

| # | Bomb | Profile | Render cycles | Status |
|---|---|---|---|---|
| 1 | Mk 82 (0.0001 kt, CONVENTIONAL_SURFACE) | tools/bomb_profiles.py `mk82` | 2 reviewed (c1, c2), c2 fixes applied | in progress |
| 2 | Mk 84 (0.0005 kt, CONVENTIONAL_SURFACE) | tools/bomb_profiles.py `mk84` | 2 reviewed (c1, c2), c2 fixes applied | in progress |
| 3 | Tallboy (0.003 kt, CONVENTIONAL_BURIED) | tools/bomb_profiles.py `tallboy` | 2 reviewed (c1, c2), c2 fixes applied | in progress |
| 4 | Grand Slam (0.0066 kt, CONVENTIONAL_BURIED) | tools/bomb_profiles.py `grand_slam` | 2 reviewed (c1, c2), c2 fixes applied | in progress |
| 5 | GBU-43/B MOAB (0.011 kt, CONVENTIONAL_SURFACE) | tools/bomb_profiles.py `moab` | 2 reviewed (c1, c2), c2 fixes applied | in progress |
| 6 | W54 Davy Crockett (0.018 kt, NUCLEAR_SURFACE) | tools/bomb_profiles.py `davy_crockett` | 2 reviewed (c1, c2), c2 fixes applied | in progress |
| 7 | ATBIP "Father of All Bombs" (0.044 kt, THERMOBARIC) | tools/bomb_profiles.py `foab` | 2 reviewed (c1, c2), c2 fixes applied | in progress |
| 8 | B61 Mod 12 (0.3 kt, NUCLEAR_AIR) | tools/bomb_profiles.py `b61_12` | 2 reviewed (c1, c2), c2 fixes applied | in progress |
| 9 | Grable (15.0 kt, NUCLEAR_LOW_AIR) | tools/bomb_profiles.py `grable` | 2 reviewed (c1, c2), c2 fixes applied | in progress |
| 10 | Little Boy (Hiroshima) (16.0 kt, NUCLEAR_AIR) | tools/bomb_profiles.py `little_boy` | 2 reviewed (c1, c2), c2 fixes applied | in progress |
| 11 | Trinity ("Gadget") (21.0 kt, NUCLEAR_TOWER) | tools/bomb_profiles.py `trinity` | 2 reviewed (c1, c2), c2 fixes applied | in progress |
| 12 | Baker (Crossroads) (23.0 kt, NUCLEAR_UNDERWATER) | tools/bomb_profiles.py `baker` | 2 reviewed (c1, c2), c2 fixes applied | in progress |
| 13 | Sedan (Plowshare) (104.0 kt, NUCLEAR_BURIED) | tools/bomb_profiles.py `sedan` | 2 reviewed (c1, c2), c2 fixes applied | in progress |
| 14 | Ivy King (500.0 kt, NUCLEAR_AIR) | tools/bomb_profiles.py `ivy_king` | 2 reviewed (c1, c2), c2 fixes applied | in progress |
| 15 | B83 (1200.0 kt, NUCLEAR_SURFACE) | tools/bomb_profiles.py `b83` | 2 reviewed (c1, c2), c2 fixes applied | in progress |
| 16 | RDS-37 (1600.0 kt, NUCLEAR_AIR) | tools/bomb_profiles.py `rds37` | 2 reviewed (c1, c2), c2 fixes applied | in progress |
| 17 | Ivy Mike (10400.0 kt, NUCLEAR_SURFACE) | tools/bomb_profiles.py `ivy_mike` | 2 reviewed (c1, c2), c2 fixes applied | in progress |
| 18 | Castle Bravo (15000.0 kt, NUCLEAR_SURFACE) | tools/bomb_profiles.py `castle_bravo` | 2 reviewed (c1, c2), c2 fixes applied | in progress |
| 19 | Test No. 219 (24200.0 kt, NUCLEAR_HIGH_AIR) | tools/bomb_profiles.py `test219` | 2 reviewed (c1, c2), c2 fixes applied | in progress |
| 20 | Tsar Bomba (AN602) (50000.0 kt, NUCLEAR_HIGH_AIR) | tools/bomb_profiles.py `tsar` | 2 reviewed (c1, c2), c2 fixes applied | in progress |

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

## PAUSED by the user at 2026-11-07T09:41:24.2858342+01:00

State when paused (resume from here):
- Last commit: `ee6ea99 Fix run.bat/run_cinematic.bat project path quoting, movie resolution via override.cfg, menu-drive QA mode, per-bomb batch 2, QA tables tool, QA report skeleton` (work after it is uncommitted: QA_REPORT draft, PROGRESS/TIMELOG, near-view pitch fix in shot_rig.gd, static-cache release, Little Boy skirt).
- Review cycle 2: done (docs/reviews/cycle2_art_review.json, avg 3.1/10); systemic + per-bomb fixes applied (D013-D021).
- Two background agents were told to stop and leave their files compiling:
  1. environment agent (sky.gdshader, atmos.gdshaderinc, terrain.gdshader, terrain_common.gdshaderinc, environment_ctl.gd, terrain.gd): dawn/noon sky, fireball halo, dawn ground, LOD seam/stripes.
  2. layers agent (fx_layers.gd, shockwave/dust_wall/wilson/debris shaders): dust wall, shock rim, debris rocks, Wilson look.
  On resume: read their final reports, run selftest + a few renders (the terrain shader had a transient road_mask() compile error mid-edit), check Baker's lagoon is visible, commit.
- Next steps, in order:
  1. Cycle-3 render: `python tools/render_all.py --out <scratch>/r7 --views zoom,near --tods hist --extra="--norange"`.
  2. Cycle-3 review: Workflow scriptPath <scratchpad>/review_wf3.js, args {renders: <scratch>/r7, cycle: 3}; save docs/reviews/cycle3_art_review.json; apply fixes; final look; mark bombs `verified`.
  3. Final QA matrix at 2560x1440 (`-- --qa_matrix --secs 3`, copy qa_results.json to docs/), `python tools/fps_report.py`, fill docs/QA_REPORT.md via tools/qa_tables.py.
  4. Screens: `python tools/make_screens.py` → docs/screens (2-3 per bomb).
  5. Clean launch: delete .godot, run run.bat (import) then `run.bat -- --menu_drive`; record in QA_REPORT.
  6. Section 15 checklist above, README/CREDITS final, final git commit.
  7. Section 14: end time, per-stage times, `python tools/usage_report.py --project-dir %USERPROFILE%/.claude/projects/G--YouTube-Atomic-Bombs --session <session-1-id> --prices tools/prices.json` (official prices already saved in tools/prices.json), write docs/PROJECT_STATS.md.
- Environment agent FINISHED (stopped cleanly, files final, 26 shot-rig runs READY with no errors): ozone absorption fixes the olive dawn zenith; the noon sky now brightens toward the horizon; the fireball halo is normalised to the ball's brightness (atm_fireball_glow in atmos.gdshaderinc); fog colour is derived from the sky; terrain detail fades with the pixel footprint (seam and stripes gone); warm dawn sand; brighter night ambient. Not done: Rayleigh tint for faint glows, per-bomb "morning/predawn/overcast" presets (need Game.TimeOfDay), a direct fireball light on the terrain. Evidence: scratchpad/env_agent/before|after.
- Layers agent: still finishing its current edit (shockwave/dust_wall/wilson/debris + fx_layers.gd uncommitted); read its report on resume.
