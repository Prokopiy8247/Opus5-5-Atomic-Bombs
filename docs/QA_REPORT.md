# QA REPORT

All results below were produced by the project's own tooling on the development machine
(Windows 11, RTX 5070, Godot 4.7.2-stable, D3D12). Raw outputs: `docs/qa_results.json`,
`docs/fps_report.json`, `docs/reviews/*.json`.

## 1. Automated physics and integrity tests (`scenes/selftest.tscn`)

Run: `Godot_v4.7.2-stable_win64_console.exe --headless --path . res://scenes/selftest.tscn`

Result of the final run (2026-11-07, after all cycle-3 and audio changes): **`SELFTEST checks=126 failures=0` → `READY`**.

| Group | Checks | What is compared |
|---|---|---|
| Recommended distances | 34 | per bomb: bunker overpressure < 2 psi and distance beyond the 2nd-degree burn radius |
| NaN / inf | 20 | every explosion profile sampled at all ages, no NaN/inf in any value |
| Fireball | 25 | maximum radii vs scaled law (12 bombs), Trinity radii at 25/53/90 ms and ~2 s, R_max for 1 kt / 15 kt / 1 Mt air, Bravo contact, Tsar; t2, t_min, temperature at t2 and 5 t2 |
| Blast | 17 | DNA arrival times (1 kt @ 1 km ... 1 Mt @ 100 km, bomb table), Glasstone overpressures, Sublette R(1/5/20 psi), contact factor, Kingery-Bulmash HE radius, shock radius at 1 s, peak winds |
| Thermal | 7 | thermal pulse F(2 t2), F(5 t2), double pulse, 3rd-degree burn radii (20 kt, 1 Mt), flash brightness at 10 and 50 km |
| Cloud / ground | 19 | Miller / Glasstone cloud tops at stabilisation (16 bombs), cap radius, cloud rise, crater radius |
| Data | 2 | 20 bombs loaded, strictly ascending yields |
| Leaks | 2 | node count 4 -> 4 and static memory 59.6 -> 59.6 MB over 20 consecutive explosions |

Audio module (`tools/test_audio.gd`, headless, run after the audio rework): **133 checks, `RESULT fails=0` → `READY`** -
generation timing, peak/RMS of every procedural sound, loop seams, bus layout and limiter, scheduled timelines for
15 kt @ 20 km and 50 Mt @ 150 km, ear ringing, pause / backward scrubbing / slow motion, NaN/inf robustness, rocket,
whistle (incl. 30 km attenuation), ambience, no node growth over 20 launches, and the per-event synthesis path
(worker-thread synthesis, synthesized front + tail replacing the generic layers at the SPL-mapped level, fallback to
the generic layers when the event was not prepared, the synthesized layers on their own bus with the Blast-bus
distance filter untouched, and a relaunch while an older synthesis is still running).

Independent audio code review (workflow: 3 reviewer agents + 1 adversarial verifier per finding, 13 agents): 10
findings, 9 confirmed and fixed (D037): the ridge-echo level was normalised over a fixed 20-90 s window that was empty
for short tails (gain up to 1e5: a +88 dB echo for Tallboy at 12.25 km), a ridge next to ground zero could make an echo
19 dB louder than the blast, the zero-phase 16 Hz loudspeaker high-pass put a DC step at the start of the front, an
older synthesis finishing late could overwrite a newer launch's result, the megaton infrasound cut and the Blast-bus
filter changes also hit the generic fallback, movie renders could pick synth or generic depending on thread timing,
small HE overpressure fell to the bisection floor beyond 167 km, and the FOAB main report lagged the visuals by
150 ms. Re-check after the fixes: the reviewers' failing cases and a sweep of all 20 bombs x 7 distances (0.7-199 km,
140 events): the tail is always below the front (max -4.6 dB), every front stream starts from silence, 0 errors.

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

### QA matrix summary

- launches: 121 (20 bombs x 3 distances x 2 times of day + feature test), failures: 0
- engine/script/shader errors counted in-process: 0, warnings: 0
- nodes after the 2nd launch / at the end (range objects excluded): 567 / 567
- static memory: 172.0 MB -> 187.7 MB; wall time 10.8 min

| # | bomb | tod | rec km | psi rec | near km | psi near | far km | psi far | destroyed | min fps | worst frame ms | errors |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | mk82 | noon | 2.0 | 0.021 | 0.67 | 0.075 | 6.0 | 0.006 | - | 104 | 15 | 0 |
| 2 | mk84 | noon | 3.0 | 0.025 | 1.0 | 0.088 | 9.0 | 0.007 | - | 112 | 14 | 0 |
| 3 | tallboy | noon | 4.0 | 0.014 | 1.33 | 0.047 | 12.0 | 0.004 | - | 187 | 9 | 0 |
| 4 | grand_slam | noon | 5.0 | 0.014 | 1.67 | 0.049 | 15.0 | 0.004 | - | 182 | 9 | 0 |
| 5 | moab | noon | 8.0 | 0.026 | 2.67 | 0.093 | 24.0 | 0.008 | - | 122 | 19 | 0 |
| 6 | davy_crockett | noon | 8.0 | 0.02 | 2.67 | 0.071 | 24.0 | 0.006 | - | 110 | 14 | 0 |
| 7 | foab | noon | 10.0 | 0.034 | 3.33 | 0.124 | 30.0 | 0.01 | - | 123 | 13 | 0 |
| 8 | b61_12 | noon | 12.0 | 0.073 | 4.0 | 0.277 | 36.0 | 0.021 | - | 212 | 6 | 0 |
| 9 | grable | noon | 20.0 | 0.19 | 6.67 | 0.762 | 60.0 | 0.051 | - | 151 | 12 | 0 |
| 10 | little_boy | noon | 20.0 | 0.195 | 6.67 | 0.78 | 60.0 | 0.053 | - | 157 | 12 | 0 |
| 11 | trinity | noon | 25.0 | 0.081 | 8.33 | 0.308 | 75.0 | 0.023 | - | 135 | 16 | 0 |
| 12 | baker | noon | 8.0 | 0.204 | 2.67 | 0.824 | 24.0 | 0.055 | - | 133 | 12 | 0 |
| 13 | sedan | noon | 12.0 | 0.135 | 4.0 | 0.528 | 36.0 | 0.037 | - | 214 | 24 | 0 |
| 14 | ivy_king | noon | 50.0 | 0.259 | 16.67 | 1.072 | 150.0 | 0.069 | - | 153 | 12 | 0 |
| 15 | b83 | noon | 55.0 | 0.158 | 18.33 | 0.628 | 165.0 | 0.043 | - | 181 | 14 | 0 |
| 16 | rds37 | noon | 60.0 | 0.335 | 20.0 | 1.453 | 180.0 | 0.088 | - | 173 | 13 | 0 |
| 17 | ivy_mike | noon | 90.0 | 0.209 | 30.0 | 0.845 | 200.0 | 0.08 | - | 224 | 6 | 0 |
| 18 | castle_bravo | noon | 100.0 | 0.214 | 33.33 | 0.864 | 200.0 | 0.092 | - | 207 | 10 | 0 |
| 19 | test219 | noon | 120.0 | 0.439 | 40.0 | 1.994 | 200.0 | 0.231 | - | 199 | 13 | 0 |
| 20 | tsar | noon | 150.0 | 0.449 | 50.0 | 2.055 | 200.0 | 0.312 | - | 230 | 8 | 0 |
| 1 | mk82 | night | 2.0 | 0.021 | 0.67 | 0.075 | 6.0 | 0.006 | - | 112 | 14 | 0 |
| 2 | mk84 | night | 3.0 | 0.025 | 1.0 | 0.088 | 9.0 | 0.007 | - | 119 | 14 | 0 |
| 3 | tallboy | night | 4.0 | 0.014 | 1.33 | 0.047 | 12.0 | 0.004 | - | 193 | 11 | 0 |
| 4 | grand_slam | night | 5.0 | 0.014 | 1.67 | 0.049 | 15.0 | 0.004 | - | 196 | 8 | 0 |
| 5 | moab | night | 8.0 | 0.026 | 2.67 | 0.093 | 24.0 | 0.008 | - | 133 | 13 | 0 |
| 6 | davy_crockett | night | 8.0 | 0.02 | 2.67 | 0.071 | 24.0 | 0.006 | - | 117 | 14 | 0 |
| 7 | foab | night | 10.0 | 0.034 | 3.33 | 0.124 | 30.0 | 0.01 | - | 131 | 14 | 0 |
| 8 | b61_12 | night | 12.0 | 0.073 | 4.0 | 0.277 | 36.0 | 0.021 | - | 234 | 6 | 0 |
| 9 | grable | night | 20.0 | 0.19 | 6.67 | 0.762 | 60.0 | 0.051 | - | 165 | 11 | 0 |
| 10 | little_boy | night | 20.0 | 0.195 | 6.67 | 0.78 | 60.0 | 0.053 | - | 174 | 11 | 0 |
| 11 | trinity | night | 25.0 | 0.081 | 8.33 | 0.308 | 75.0 | 0.023 | - | 148 | 15 | 0 |
| 12 | baker | night | 8.0 | 0.204 | 2.67 | 0.824 | 24.0 | 0.055 | - | 139 | 12 | 0 |
| 13 | sedan | night | 12.0 | 0.135 | 4.0 | 0.528 | 36.0 | 0.037 | - | 223 | 24 | 0 |
| 14 | ivy_king | night | 50.0 | 0.259 | 16.67 | 1.072 | 150.0 | 0.069 | - | 162 | 12 | 0 |
| 15 | b83 | night | 55.0 | 0.158 | 18.33 | 0.628 | 165.0 | 0.043 | - | 195 | 14 | 0 |
| 16 | rds37 | night | 60.0 | 0.335 | 20.0 | 1.453 | 180.0 | 0.088 | - | 185 | 13 | 0 |
| 17 | ivy_mike | night | 90.0 | 0.209 | 30.0 | 0.845 | 200.0 | 0.08 | - | 241 | 6 | 0 |
| 18 | castle_bravo | night | 100.0 | 0.214 | 33.33 | 0.864 | 200.0 | 0.092 | - | 224 | 10 | 0 |
| 19 | test219 | night | 120.0 | 0.439 | 40.0 | 1.994 | 200.0 | 0.231 | - | 216 | 12 | 0 |
| 20 | tsar | night | 150.0 | 0.449 | 50.0 | 2.055 | 200.0 | 0.312 | - | 251 | 8 | 0 |

Feature test (slow motion 0.05x, pause, cinematographer, 4 director angles, HUD off/on, RU/EN, 4 times of day, humidity): ok=True

Final run: 2026-11-07 23:49 - 2026-11-08 00:00, after every audio fix (an earlier run at 22:52, before the review
fixes, gave the same result); every launch also synthesized its blast on a worker thread while the booster flew. **121/121 launches passed, 0 errors, 0 warnings, node count unchanged (567 -> 567)**.
Static memory grew by 15.7 MB over 121 launches (0.13 MB per launch; Godot's shader-pipeline and resource caches
fill as new bomb/time-of-day variants are drawn) and the node count did not grow; the selftest leak check (20 launches
of the same bomb) shows no growth at all. The only engine output at exit is the known shutdown warning
`7 RIDs of type "Texture" were leaked` (section 6). The "destroyed" column is empty because no recommended / near /
far distance reaches the bunker's 5 psi destruction threshold (the near distances peak at 2.1 psi for Tsar Bomba).

## 3. Performance (task section 9)

Run: `python tools/fps_report.py` (windowed real-time runs, vsync off, 2560x1440, the explosion frozen
at the given age and 240 frames timed; `--write-movie` is never used for FPS).

### FPS (windowed, real time, explosion frozen at the given age)

| # | bomb | view | tod | quality | age s | avg fps | avg ms | worst ms |
|---|---|---|---|---|---|---|---|---|
| 1 | mk82 | bunker | noon | high | 0.1 | 314 | 3.18 | 7.9 |
| 1 | mk82 | bunker | noon | high | 2 | 334 | 3.00 | 5.7 |
| 1 | mk82 | bunker | noon | high | 20 | 352 | 2.84 | 3.2 |
| 1 | mk82 | zoom | noon | high | 20 | 157 | 6.37 | 6.8 |
| 2 | mk84 | bunker | noon | high | 0.1 | 312 | 3.21 | 5.6 |
| 2 | mk84 | bunker | noon | high | 2 | 297 | 3.37 | 5.7 |
| 2 | mk84 | bunker | noon | high | 20 | 330 | 3.03 | 3.5 |
| 2 | mk84 | zoom | noon | high | 20 | 151 | 6.61 | 7.7 |
| 3 | tallboy | bunker | noon | high | 0.1 | 376 | 2.66 | 7.2 |
| 3 | tallboy | bunker | noon | high | 2 | 311 | 3.21 | 6.5 |
| 3 | tallboy | bunker | noon | high | 20 | 320 | 3.13 | 3.6 |
| 3 | tallboy | zoom | noon | high | 20 | 75 | 13.29 | 14.7 |
| 4 | grand_slam | bunker | noon | high | 0.1 | 368 | 2.72 | 9.6 |
| 4 | grand_slam | bunker | noon | high | 2 | 325 | 3.08 | 7.0 |
| 4 | grand_slam | bunker | noon | high | 20 | 314 | 3.19 | 3.6 |
| 4 | grand_slam | zoom | noon | high | 20 | 111 | 8.99 | 9.4 |
| 5 | moab | bunker | noon | high | 0.1 | 310 | 3.23 | 5.1 |
| 5 | moab | bunker | noon | high | 2 | 266 | 3.76 | 5.6 |
| 5 | moab | bunker | noon | high | 20 | 304 | 3.29 | 3.7 |
| 5 | moab | zoom | noon | high | 20 | 92 | 10.87 | 11.3 |
| 6 | davy_crockett | bunker | noon | high | 1 | 234 | 4.27 | 7.7 |
| 6 | davy_crockett | bunker | noon | high | 20 | 244 | 4.10 | 4.6 |
| 6 | davy_crockett | bunker | noon | high | 90 | 201 | 4.99 | 5.8 |
| 6 | davy_crockett | zoom | noon | high | 90 | 72 | 13.86 | 15.0 |
| 7 | foab | bunker | noon | high | 0.1 | 307 | 3.26 | 6.5 |
| 7 | foab | bunker | noon | high | 2 | 286 | 3.50 | 5.6 |
| 7 | foab | bunker | noon | high | 20 | 291 | 3.44 | 3.8 |
| 7 | foab | zoom | noon | high | 20 | 109 | 9.18 | 9.7 |
| 8 | b61_12 | bunker | noon | high | 1 | 224 | 4.46 | 6.3 |
| 8 | b61_12 | bunker | noon | high | 20 | 244 | 4.10 | 4.7 |
| 8 | b61_12 | bunker | noon | high | 90 | 240 | 4.17 | 4.9 |
| 8 | b61_12 | zoom | noon | high | 90 | 105 | 9.49 | 10.3 |
| 9 | grable | bunker | noon | high | 1 | 242 | 4.13 | 8.9 |
| 9 | grable | bunker | noon | high | 20 | 232 | 4.32 | 8.0 |
| 9 | grable | bunker | noon | high | 90 | 224 | 4.45 | 5.7 |
| 9 | grable | zoom | noon | high | 90 | 122 | 8.22 | 20.6 |
| 10 | little_boy | bunker | noon | high | 1 | 282 | 3.55 | 7.9 |
| 10 | little_boy | bunker | noon | high | 20 | 238 | 4.19 | 4.7 |
| 10 | little_boy | bunker | noon | high | 90 | 258 | 3.88 | 4.6 |
| 10 | little_boy | zoom | noon | high | 90 | 148 | 6.75 | 8.8 |
| 11 | trinity | bunker | noon | high | 1 | 239 | 4.19 | 6.0 |
| 11 | trinity | bunker | noon | high | 20 | 252 | 3.97 | 4.5 |
| 11 | trinity | bunker | noon | high | 90 | 240 | 4.17 | 4.9 |
| 11 | trinity | zoom | noon | high | 90 | 91 | 11.02 | 11.6 |
| 12 | baker | bunker | noon | high | 1 | 239 | 4.19 | 6.0 |
| 12 | baker | bunker | noon | high | 20 | 148 | 6.74 | 9.9 |
| 12 | baker | bunker | noon | high | 90 | 158 | 6.33 | 8.6 |
| 12 | baker | zoom | noon | high | 90 | 70 | 14.25 | 14.8 |
| 13 | sedan | bunker | noon | high | 1 | 344 | 2.90 | 6.9 |
| 13 | sedan | bunker | noon | high | 20 | 265 | 3.77 | 5.7 |
| 13 | sedan | bunker | noon | high | 90 | 197 | 5.07 | 5.9 |
| 13 | sedan | zoom | noon | high | 90 | 71 | 14.02 | 16.8 |
| 14 | ivy_king | bunker | noon | high | 1 | 283 | 3.53 | 6.2 |
| 14 | ivy_king | bunker | noon | high | 20 | 175 | 5.71 | 7.2 |
| 14 | ivy_king | bunker | noon | high | 90 | 173 | 5.80 | 7.5 |
| 14 | ivy_king | zoom | noon | high | 90 | 80 | 12.49 | 13.2 |
| 15 | b83 | bunker | noon | high | 2 | 288 | 3.47 | 5.8 |
| 15 | b83 | bunker | noon | high | 40 | 228 | 4.38 | 5.4 |
| 15 | b83 | bunker | noon | high | 180 | 151 | 6.63 | 7.0 |
| 15 | b83 | bunker | noon | high | 360 | 240 | 4.16 | 4.5 |
| 15 | b83 | zoom | noon | high | 360 | 121 | 8.29 | 9.8 |
| 16 | rds37 | bunker | noon | high | 2 | 261 | 3.83 | 5.9 |
| 16 | rds37 | bunker | noon | high | 40 | 237 | 4.22 | 4.8 |
| 16 | rds37 | bunker | noon | high | 180 | 196 | 5.11 | 5.5 |
| 16 | rds37 | bunker | noon | high | 360 | 177 | 5.64 | 7.9 |
| 16 | rds37 | zoom | noon | high | 360 | 78 | 12.84 | 14.4 |
| 17 | ivy_mike | bunker | noon | high | 2 | 293 | 3.41 | 6.0 |
| 17 | ivy_mike | bunker | noon | high | 40 | 249 | 4.01 | 4.7 |
| 17 | ivy_mike | bunker | noon | high | 180 | 255 | 3.92 | 4.4 |
| 17 | ivy_mike | bunker | noon | high | 360 | 253 | 3.96 | 4.4 |
| 17 | ivy_mike | zoom | noon | high | 360 | 118 | 8.44 | 9.4 |
| 18 | castle_bravo | bunker | noon | high | 2 | 301 | 3.33 | 8.3 |
| 18 | castle_bravo | bunker | noon | high | 40 | 188 | 5.32 | 6.0 |
| 18 | castle_bravo | bunker | noon | high | 180 | 233 | 4.30 | 5.1 |
| 18 | castle_bravo | bunker | noon | high | 360 | 213 | 4.70 | 5.7 |
| 18 | castle_bravo | zoom | noon | high | 360 | 81 | 12.31 | 13.0 |
| 19 | test219 | bunker | noon | high | 2 | 295 | 3.39 | 6.4 |
| 19 | test219 | bunker | noon | high | 40 | 187 | 5.34 | 7.1 |
| 19 | test219 | bunker | noon | high | 180 | 129 | 7.73 | 8.5 |
| 19 | test219 | bunker | noon | high | 360 | 112 | 8.90 | 9.6 |
| 19 | test219 | zoom | noon | high | 360 | 35 | 28.42 | 32.2 |
| 20 | tsar | bunker | noon | high | 2 | 324 | 3.08 | 5.4 |
| 20 | tsar | bunker | noon | high | 40 | 238 | 4.21 | 5.0 |
| 20 | tsar | bunker | noon | high | 180 | 149 | 6.73 | 7.3 |
| 20 | tsar | bunker | noon | high | 360 | 135 | 7.43 | 7.9 |
| 20 | tsar | zoom | noon | high | 360 | 30 | 33.13 | 34.2 |
| 20 | tsar | bunker | night | low | 90 | 172 | 5.80 | 8.3 |
| 20 | tsar | bunker | night | low | 180 | 157 | 6.38 | 6.8 |
| 20 | tsar | bunker | night | low | 360 | 139 | 7.18 | 7.7 |
| 20 | tsar | bunker | night | medium | 90 | 171 | 5.85 | 9.8 |
| 20 | tsar | bunker | night | medium | 180 | 155 | 6.44 | 9.5 |
| 20 | tsar | bunker | night | medium | 360 | 138 | 7.23 | 7.8 |
| 20 | tsar | bunker | night | high | 90 | 169 | 5.90 | 6.5 |
| 20 | tsar | bunker | night | high | 180 | 154 | 6.49 | 7.1 |
| 20 | tsar | bunker | night | high | 360 | 137 | 7.31 | 7.8 |
| 20 | tsar | bunker | night | cine | 90 | 167 | 6.00 | 6.5 |
| 20 | tsar | bunker | night | cine | 180 | 152 | 6.58 | 7.2 |
| 20 | tsar | bunker | night | cine | 360 | 136 | 7.38 | 7.8 |
| 20 | tsar | zoom | night | high | 20 | 120 | 8.31 | 10.6 |
| 20 | tsar | zoom | night | high | 90 | 64 | 15.54 | 16.6 |
| 20 | tsar | zoom | night | high | 180 | 50 | 20.11 | 21.3 |

errors during FPS runs: 0

**Section 9 targets (RTX 5070, 2560x1440, windowed, vsync off):**
- Typical scene ≥ 60 fps: **met** - every bunker view of every bomb at every age runs at 112-352 fps (average
  frame 2.8-8.9 ms); the binocular views run at 70-157 fps for 18 of 20 bombs.
- Worst case ≥ 30 fps (Tsar Bomba, night, cloud peak): **met** - bunker view 136-172 fps at all four quality
  presets; binocular view 50-120 fps at night.
- The heaviest scenario found is not the specified worst case but the binocular view filled edge to edge by a
  fully grown 24-50 Mt cloud at noon (Test 219 / Tsar at 360 s): 35 / 30 fps (worst frame 32-34 ms), right at the
  30 fps floor. The auto-quality controller lowers raymarch steps when the frame time stays above budget, and
  the Low preset is available.
- Shader warm-up: `main.gd` `_warm_up_shaders()` draws the explosion materials once at load, so the first
  detonation does not compile pipelines. The worst single frame of each QA launch (launch, flight, detonation,
  0.8 s real time, then 16x) is 6-61 ms; only Test 219 at noon reached 61 ms, all other runs stayed under 45 ms.

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

Final clean-launch test (2026-11-07, after all changes):
1. `.godot/` deleted (no import cache), no Godot process running.
2. `run.bat --log-file <tmp>\game.log -- --menu_drive --bomb 10 --out <tmp> --audio_log`: `run.bat` found no
   `global_script_class_cache.cfg`, ran the headless import (12 s, cache rebuilt), then started the game windowed.
   The menu-drive mode drove the real UI: terminal menu → Little Boy selected → logarithmic distance slider moved to
   15.2 km (HUD: 0.27 psi at the bunker, shock wave in 43.2 s) → LAUNCH pressed → booster flight → detonation →
   explosion age 8.2 s, then it waited for the blast: `AUDIO synth event used: tail -12.0 dB`, `blast_front` at
   t = 43.13 s (-4.2 dB), `blast_tail` at 43.27 s, tremor earlier at 8.45 s; `mode=synth` → `READY`. Screenshots of
   every step were checked (menu in Russian, slider, flash, mushroom cloud from the bunker).
3. The import also showed that Godot imported the 60 PNGs of `docs/screens/` as game textures; `docs/.gdignore`
   now excludes the whole documentation folder from the project.
4. `run_cinematic.bat 1 20 1280x720 noon bunker`: 1200 PNG frames of 1280x720 + `b1_frame.wav` (48 kHz, 32-bit
   stereo), `override.cfg` removed afterwards; GPU 1.55 ms/frame, PNG encoding 139 ms/frame (185 s in total). The
   soundtrack: rocket ignition peaking at -4 dBFS at ~2 s, roar fading with distance, the Mk 82 report at ~17 s at
   -11 dBFS (= the synthesized front level for 137 dB SPL), no clipping. A `--verbose` run showed 3 playbacks and
   3 streams leaked at exit (the movie writer mixes on the main thread, so voices playing when `--quit-after`
   ends the render are never released); `run_cinematic.bat` now passes the frame count (`--movie_frames`) and the
   sound manager stops every voice 4 frames before the end: 0 leaked instances, last 50 ms silent.

Standalone build (2026-11-08, `build.bat`, Godot 4.7.2 release template `windows_release_x86_64`):
1. Export of the "Windows Desktop" preset in 6 s, no warnings or errors in the log; the pack holds the 4 runtime data
   files (`bombs.json`, `locale.json`, `noise_fbm.bin`, `noise_billow.bin`), all scenes, scripts (binary tokens) and
   shaders; `tools/`, the self-test scene and `research_values.json` are excluded. Output: `AtomicBombs.exe`
   (111.6 MB, PCK embedded, version info "Atomic Bombs 1.0.0.0") + `AtomicBombs.console.exe` (91 KB).
2. The two files were copied to a folder outside the project and run from there (so nothing could be read from the
   project files): `-- --menu_drive --audio_log` gave the same result as the editor run above (Little Boy at
   15.2 km, `blast_front` at t = 43.13 s at -4.2 dB, `mode=synth`, `READY`); the screenshots of the menu, the
   detonation and the cloud match the editor ones.
3. `--autolaunch` of Tsar Bomba at night (shots at 3/20/40 s, fps 540/540/299) and Baker at noon (fps 638/649/242,
   water column and Wilson cloud rendered) in a 1920x1080 window: no errors; the only message at exit is the known
   "7 RIDs of type Texture were leaked" warning (section 6).
4. `AtomicBombs.exe res://scenes/selftest.tscn` is refused by the release template ("compiled without support for
   path overrides"), so the self-test stays an editor-binary tool and was removed from the build.

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
