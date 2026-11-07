# Atomic Bombs

A Godot 4.7.2 game about the scale of explosions. You stand in a concrete observation bunker at the
edge of a desert test range and launch one of **20 historical bombs**, in strictly ascending yield
from a 500-lb Mk 82 (≈0.1 t TNT) to the 50-megaton Tsar Bomba, and watch the explosion through a
panoramic window: flash, fireball, shock wave, dust, cloud, the blast wave reaching the bunker and
the sound arriving seconds or minutes later.

Every size and time comes from published physics (Glasstone & Dolan, Fletcher, the DNA 1-kt
standard, Miller's cloud model, Kingery-Bulmash for conventional explosives) plus per-bomb measured
values from the research notes. Everything is procedural: no downloaded models, textures or sounds.

## Running

- **Play:** double-click `run.bat`. It finds Godot 4.7.2 (`%GODOT%`, then
  `W:\Godot_v4.7.2-stable_win64.exe\…`, then `PATH`), runs the one-time import if needed and starts
  the game in a window.
- **Offline cinematic render (PNG sequence + WAV, 60 fps, 4K by default):**
  `run_cinematic.bat [bomb 1-20] [seconds] [WxH] [tod] [view]`, for example
  `run_cinematic.bat 20 90 3840x2160 dawn bunker`. Frames go to `movie\`. Assemble with
  `ffmpeg -framerate 60 -i movie\b20_frame%08d.png -i movie\b20_frame.wav -c:v libx264 -crf 14 -pix_fmt yuv420p tsar.mp4`.
  In movie mode the game uses maximum quality (`OS.has_feature("movie")`).
  The output size comes from a temporary `override.cfg` that the script writes and deletes (Godot's
  Movie Maker records at the project's base viewport size and ignores `--resolution`). Rendering
  takes ~1.5 ms per frame; Godot's PNG encoding dominates (~0.3 s per 1080p frame, ~1 s at 4K), so a
  90 s 4K clip takes over an hour to write.

Requirements: Windows 10/11, a Vulkan/D3D12 GPU (developed on an RTX 5070), Godot 4.7.2-stable
(no export templates needed). The project uses the D3D12 driver (measured slightly faster than
Vulkan on the development machine; both work).

## Controls

| Key | Action |
|---|---|
| Mouse | look around (right mouse button toggles the cursor) |
| Mouse wheel | binocular zoom (FOV 80° → 3°, smoothed; with high zoom you lean into the embrasure) |
| Tab | terminal menu |
| R | reset |
| Space | pause |
| `[` / `]` | slow down / speed up time (0.05× … 4×) |
| C | cinematographer mode (free camera outside: WASD, Q/E up/down, Shift fast, Ctrl slow) |
| 1–4 | director angles: bunker, side view of the shock wave, low angle at the cloud, orbit |
| T | time of day (dawn, noon, dusk, night; the review renders also use a historical pre-dawn twilight for Trinity) |
| H | humidity (dry → humid; affects haze and Wilson condensation clouds). Until you change it, each bomb uses its historical site humidity (Pacific atolls and Hiroshima humid, Nevada dry). |
| F1 | hide/show HUD |
| F12 | screenshot (saved to `%APPDATA%\Godot\app_userdata\Atomic Bombs Opus 5.5\screenshots`) |
| Esc | quit |

The terminal menu (Russian by default, RU/EN toggle) lists the 20 bombs with name (Russian +
original), year and country, yield (kt/Mt and TNT tonnes), burst type and height, a fact-checked
blurb, a confidence tag, a rotating 3D model at true scale and a logarithmic yield bar. The range
slider is logarithmic (0.5–200 km) with a "recommended distance" button and a ±30° azimuth; under it
the flight time, the estimated damage zones (glass 1 psi, houses 5 psi, third-degree burns,
concrete 20 psi) and the expected overpressure and thermal fluence at the bunker are shown. A
dangerous distance asks for confirmation.

## What happens on launch

A generic booster on the pad front-left of the window carries the bomb along a compressed
ballistic arc (6–25 s; heavy bombs finish under a parachute; contact/buried/underwater bombs
impact). At detonation:

- **Flash and eye adaptation:** double thermal pulse (first UV spike, dip at t_min, second maximum
  at t₂ = 0.0417 W^0.44 s), white-out, then an eye/camera adaptation model (up to ~10 stops when the
  fireball fills the binocular view) that recovers over seconds.
- **Fireball:** raymarched volume with Sedov–Taylor growth limited by the measured maximum,
  blackbody colour from the Stefan–Boltzmann temperature, convective cells, smoke skin, cooling.
- **Shock wave:** refractive expanding front, ground dust sweep with Mach-stem/precursor variants,
  real DNA time of arrival; the bunker shakes with the computed overpressure, dust falls, lights
  flicker, the 10-psi window cracks and at ≥ 25 psi the bunker is destroyed.
- **Cloud:** fireball → vortex-torus head with cauliflower billows, NOx red-brown that whitens,
  dust stem with afterwinds, wind drift and shear, condensation rings, ice caps, two-tier caps for
  the largest yields, cloud shadow on the ground, internal glow at night.
- **Ground:** crater and ejecta (high-resolution terrain patch around ground zero), scorch and
  trinitite, ballistic debris, ground heave for buried shots (Sedan dome, Tallboy/Grand Slam
  camouflets), base surges (Baker, Sedan), a lagoon with waves for Baker, snow for the Arctic tests.
- **Test range objects** in distance rings scaled to each bomb's pressure radii (houses, trees,
  vehicles, towers, a bridge, bunkers, a hangar, aircraft) are destroyed in the physically correct
  order and ignite above their thermal thresholds.
- **Sound:** procedural crack, sub-bass thump, terrain-echo rumble, fireball roar, distant thunder,
  seismic tremor ahead of the air wave, infrasonic thump for megatons, ear-ringing after close
  blasts; delays from the speed of sound / blast arrival; distance low-pass; master limiter.

## Architecture

```
scenes/main.tscn            root (scripts/core/main.gd builds everything procedurally)
scenes/selftest.tscn        quantitative tests (tools/selftest.gd)
scripts/core/               game.gd (autoload: state, data, localisation), main.gd (game loop, input,
                            auto-quality, movie autopilot), player_camera.gd, args.gd
scripts/physics/            blast_physics.gd — every formula (fireball, pulse, overpressure,
                            arrival time, thermal, cloud, crater, Wilson, HE scaling)
scripts/fx/                 explosion_profile.gd (physics + art → state of each layer as a pure
                            function of age), explosion.gd (uniforms, lights, globals, events),
                            fx_layers.gd (shock, dust wall, Wilson shell, debris), launcher.gd,
                            fx_resources.gd (3D noise volumes)
scripts/world/              terrain.gd + terrain_math.gd (clipmap + ground-zero patch; identical
                            CPU/GPU height function with Earth curvature), environment_ctl.gd
                            (sky, sun/moon, aerial perspective, time of day, eye adaptation),
                            bunker.gd, water_pond.gd, range_objects.gd
scripts/audio/              audio_synth.gd (procedural synthesis), sound_manager.gd (buses, scheduling)
scripts/ui/                 ui_root.gd, terminal_menu.gd, hud.gd, ui_theme.gd
scripts/bombs/              bomb_models.gd (20 procedural bomb models, booster, parachute)
scripts/tools/              shot_rig.gd (deterministic screenshots), qa_driver.gd (QA matrix)
shaders/                    explosion_volume (raymarched fireball/cloud), terrain, sky, atmos
                            (shared aerial perspective), shockwave, dust_wall, wilson, debris,
                            water, glass, destructible
data/                       bombs.json (generated by tools/gen_bombs.py from tools/bomb_profiles.py,
                            the cycle-3 per-bomb overrides in tools/profiles_c3/group_[A-E].py
                            and data/research_values.json), locale.json (all UI strings RU/EN),
                            noise_fbm.bin / noise_billow.bin (seam-free 3D noise, tools/gen_noise.py)
tools/                      gen_bombs.py, gen_noise.py, render_all.py, make_screens.py, selftest.gd,
                            fps_report.py, qa_tables.py, usage_report.py (+ prices.json), module
                            tests test_audio.gd / test_ui.gd / test_models.gd / test_range.gd
docs/                       task, references, RESEARCH_NOTES, DECISIONS, PROGRESS, TIMELOG,
                            QA_REPORT, PROJECT_STATS, reviews/, screens/, refs/ (not shipped)
```

Key design points (details in `docs/DECISIONS.md`):

- **Everything is a function of the explosion's age.** Shaders receive the age as a uniform, never
  `TIME`; debris is an analytic particle system; terrain deformation and scorch are global shader
  parameters. Slow motion, pause, scrubbing and offline rendering are therefore deterministic.
- **True 1:1 scale on float32**: the observer is at the origin, effects are raymarched in local
  coordinates relative to ground zero, the camera uses reversed-Z with a 420 km far plane.
- **Earth curvature** (standard refraction, R_eff = 8500 km) is applied to the terrain, so at 100+ km
  the bases of explosions sink below the horizon as they should.
- **Godot exposure quirk:** unshaded effects and custom fog colours are multiplied by a global
  exposure parameter because Godot only applies the camera exposure to lit shading.

## Verification

- `scenes/selftest.tscn` (run: `Godot_v4.7.2-stable_win64_console.exe --path . res://scenes/selftest.tscn`)
  checks the physics against reference data (Trinity fireball radii, Glasstone maxima, DNA arrival
  times, Sublette pressure radii, burn radii, Miller cloud tops, crater sizes, Kingery-Bulmash),
  ascending yields, NaN/∞ in all profiles at all ages, safe recommended distances, and node/memory
  leaks over 20 consecutive explosions. Prints `READY` when everything passes.
- `scripts/tools/shot_rig.gd`: `-- --bomb N --dist KM --tod T --view bunker|zoom|near|side|low|orbit --shots t1,t2 --out DIR --sheet 1 [--fps_hold N]`
  renders deterministic frames at any explosion age, contact sheets and per-age FPS.
- `scripts/tools/qa_driver.gd`: `-- --qa_matrix` launches all 20 bombs at the recommended / 3×
  closer / 3× farther distances at noon and night in one session through the real launch path, then
  exercises slow motion, pause, cinematographer, director angles, HUD, RU/EN and time of day.
- `tools/fps_report.py`: real-time FPS per scenario (every bomb, bunker and binocular views, the
  Tsar Bomba night worst case at all four quality presets) → `docs/fps_report.json`.
- `tools/render_all.py` and three cycles of independent art-director reviews (`docs/reviews/cycle1..3_art_review.json`),
  each followed by fixes and a re-render; in cycle 3 five technical-artist agents tuned four bombs each in parallel.

See `docs/QA_REPORT.md` for results and FPS.

## Known limitations

See `docs/QA_REPORT.md` → "Known limitations".
