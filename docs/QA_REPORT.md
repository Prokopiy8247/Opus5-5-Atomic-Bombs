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

<!--CYCLES-->

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
