# QA REPORT

All results below were produced by the project's own tooling on the development machine
(Windows 11, RTX 5070, Godot 4.7.2-stable, D3D12). Raw outputs: `docs/qa_results.json`,
`docs/fps_report.json`, `docs/reviews/*.json`.

## 1. Automated physics and integrity tests (`scenes/selftest.tscn`)

Run: `Godot_v4.7.2-stable_win64_console.exe --headless --path . res://scenes/selftest.tscn`

<!--SELFTEST-->

## 2. QA matrix (task section 11.6)

Run: `Godot_v4.7.2-stable_win64_console.exe --path . --resolution 2560x1440 -- --qa_matrix --secs 3`

In ONE game session, through the real launch path (menu state → booster flight at 8x → detonation),
every bomb is launched at the recommended distance, 3x closer and 3x farther, at noon and at night
(120 launches without restarting), each explosion is run for 0.8 s in real time and then at 16x.
After that the feature test runs slow motion (0.05x), pause, the cinematographer camera with all
four director angles, HUD off/on, RU/EN, all four times of day and a humidity change. A Godot
`Logger` installed by the driver counts every engine, script and shader error during each launch;
a launch passes only with 0 errors. Leak check: node count after the 2nd launch vs after the last
reset (range objects excluded, their number depends on the bomb) and static memory.

<!--QAMATRIX-->

## 3. Performance (task section 9)

Run: `python tools/fps_report.py` (windowed real-time runs, vsync off, 2560x1440, the explosion frozen
at the given age and 240 frames timed; `--write-movie` is never used for FPS).

<!--FPS-->

## 4. Visual verification: fix → render → look cycles

Each cycle: deterministic renders of every bomb (`tools/render_all.py`: binocular "zoom" view from the bunker at the
recommended distance and the historical time of day, plus an outside camera between the bunker and ground zero),
then an independent review by five art-director agents comparing contact sheets with the reference photos in
`docs/refs/` (`docs/reviews/cycleN_art_review.json`: per bomb a 1-10 realism score and severity-ranked issues with
concrete fixes), then fixes, then a re-render that the lead developer looked at frame by frame. Cycle 3 added five
parallel technical-artist agents that each tuned four bombs over 6-13 render iterations (`docs/reviews/cycle3_tuning.json`).

| # | bomb | cycle 1 | cycle 2 | cycle 3 review | after cycle-3 tuning (tuner estimate) |
|---|---|---|---|---|---|
| 1 | mk82 | 2 | 3 | 4 | 6 |
| 2 | mk84 | 2 | 3 | 3 | 6 |
| 3 | tallboy | 3 | 3 | 4 | 5 |
| 4 | grand_slam | 2 | 3 | 3 | 5 |
| 5 | moab | 3 | 2 | 3 | 6 |
| 6 | davy_crockett | 3 | 3 | 3 | 6 |
| 7 | foab | 2 | 4 | 4 | 6 |
| 8 | b61_12 | 3 | 4 | 4 | 6 |
| 9 | grable | 3 | 3 | 4 | 6 |
| 10 | little_boy | 2 | 3 | 3 | 5 |
| 11 | trinity | 3 | 3 | 4 | 7 |
| 12 | baker | 3 | 2 | 3 | 6 |
| 13 | sedan | 2 | 3 | 3 | 5 |
| 14 | ivy_king | 3 | 3 | 4 | 5 |
| 15 | b83 | 2 | 4 | 5 | 6 |
| 16 | rds37 | 3 | 3 | 4 | 5 |
| 17 | ivy_mike | 3 | 4 | 4 | 6 |
| 18 | castle_bravo | 2 | 3 | 3 | 5 |
| 19 | test219 | 3 | 3 | 4 | 6 |
| 20 | tsar | 3 | 3 | 4 | 5 |
| | **average** | 2.60 | 3.10 | 3.65 | 5.65 |

The reviewers were instructed to be harsh ("find everything that looks fake"); a 5-6 means "clearly recognisable
and plausible, with visible CG shortcuts". The tuner estimates are self-assessments by the agents that made the
changes, verified by the lead on the final render set (r8) - they are not independent scores.

Main systemic fixes of cycle 3 (details in `docs/DECISIONS.md` D022-D030): cloud-head noise rescaled from a fine
"pom-pom" felt to large cauliflower lobes; condensation rings as thin laminar sheets; HE flames on the ground with a hot
core dying into soot; fireball metering that keeps the white -> yellow -> orange progression; phallic silhouettes
(Sedan, Mk 84 at 2 s, Grand Slam, B61 dust column, Bravo stem tip) removed; the Baker lagoon made visible (it was
back-face culled); a pre-dawn preset for Trinity; review framing that keeps ground zero and the whole cloud in frame.

## 5. Launch scripts

Bugs found and fixed while testing the scripts themselves:
- `run.bat` and `run_cinematic.bat` passed `--path "%~dp0"`; the trailing backslash of `%~dp0`
  escapes the closing quote on the Windows command line, so Godot received a garbled project path
  ("Invalid project path specified ... aborting"). Both now `cd` to the script folder and pass
  `--path "%CD%"`.
- Godot's Movie Maker records at the project's base viewport size and ignores `--resolution`, so
  `run_cinematic.bat ... 3840x2160` produced 1920x1080 frames. The script now writes a temporary
  `override.cfg` (viewport size = requested resolution, stretch mode `viewport`) and deletes it
  afterwards. Verified: `run_cinematic.bat 1 1 1280x720 noon bunker` → 60 PNG frames of 1280x720 +
  WAV, `override.cfg` removed; a 30 s 1080p run (B61-12, launch → flight → detonation) wrote 1800
  frames + WAV with no errors (render 1.5 ms/frame, PNG encoding 280 ms/frame).

<!--CLEANLAUNCH-->

## 6. Known limitations

- **Art quality is not photographic.** Three independent art-director review cycles scored the
  explosions harshly (see section 4); the remaining issues are listed per bomb in
  `docs/reviews/cycle3_art_review.json`. The main systemic ones: cauliflower detail of very large caps
  is still coarser than in the films; condensation rings/ice caps are simple soft discs and lenses;
  HE debris is a modest particle set, not individual clods with dust trails.
- **Ground events at long range** (Sedan's dome, craters, ejecta aprons) are partly drawn in the
  explosion volume because the camera-centred terrain LOD cannot resolve 100 m features 10+ km away.
- **Scale objects on the range** (houses, trees, vehicles, towers…) are only a few pixels from the
  bunker at the recommended distance; they need the binocular zoom, and are invisible for megatons.
- **Wilson clouds and Baker's lagoon** depend on the site humidity defaults (D020); a dry setting
  (H key) removes the condensation features by design.
- **Shutdown warning:** Godot prints `7 RIDs of type "Texture" were leaked` when the game quits. It
  persists after all static caches are released and comes from engine-internal RenderingDevice
  resources at exit; it is a warning at shutdown, not an error during play.
- **Cinematic render speed:** Godot's PNG encoder needs ~0.3 s per 1080p frame (~1 s at 4K); a 90 s
  4K clip takes over an hour to write (rendering itself is ~1.5 ms/frame).
- **Physics simplifications** (documented in `docs/RESEARCH_NOTES.md` and `docs/DECISIONS.md`):
  scaled-law fireball growth, a parametric cloud-rise model rather than a plume simulation,
  measured per-bomb keyframes where the films give them; no fallout, EMP or ionisation modelling.
