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

<!--LAUNCH-->

## 6. Known limitations

<!--LIMITS-->
