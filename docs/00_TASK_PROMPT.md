# TASK: "Atomic Bombs", a game in Godot 4.7.2. A finished project in one pass, with no human involvement

You are an autonomous developer, technical artist and QA engineer in one. Project root (already contains an empty Godot project): `G:\YouTube\Atomic Bombs\atomic-bombs-opus-5.5`.
The result will be used for a YouTube video about what Claude Opus 5.5 can do from a single prompt, so the top priority is the **spectacle and realism of the explosions**. Everything else serves that.

Note: the reference documents in `docs/` (01, 02, 03) are written in Russian. Read them as they are. All code, comments, file names and documentation you write should be in English, except the player-facing UI text (see section 4).

## 0. Rules for autonomous work (read first)

**THE MAIN RULE: DO NOT STOP UNTIL THE PROJECT IS FULLY FINISHED.** This applies to you and to every subagent you launch.
- Finish only when ALL criteria in section 15 are met. Do not end your turn with a question, an interim report, a "next steps" plan, or a phrase like "I can continue if you want". If you catch yourself about to write something like that, just keep working.
- None of these are reasons to stop: large scope, context fatigue, long compilations, errors, bad first versions. Context compaction is a normal event: re-read `docs/00_TASK_PROMPT.md` and `docs/PROGRESS.md`, then carry on. Fix errors. Work around dead ends another way and log it in `docs/DECISIONS.md`.
- Give every subagent this same rule in its brief. Never accept "done" from a subagent without verifying the result yourself (run it, look at the frames, read the log).
- Before you finish, open `docs/PROGRESS.md` and go through the section 15 checklist. Any item not marked `verified` means you keep working.
- There are only two valid reasons to stop: (a) section 15 is fully satisfied; (b) continuing is physically impossible (disk full, window/GPU unavailable after repeated attempts). In case (b), write the reason and the remaining work to `docs/BLOCKERS.md` and say so honestly in your final message.

1. **There is no human around.** Do not ask questions or wait for confirmation. If a decision is unclear, choose a reasonable option, log it in `docs/DECISIONS.md` (what you chose and why), and move on. Do not leave stubs or placeholders.
2. **The FIRST action, before anything else:** run `Get-Date -Format o` in PowerShell and write a line `START <time>` to `docs/TIMELOG.md`. Then append a timestamped line at the start and end of every stage. This is needed for the final report (section 14).
3. **Task memory.** Your context will be compacted. So: immediately save a copy of this prompt to `docs/00_TASK_PROMPT.md` (if it does not exist yet), keep `docs/PROGRESS.md` (a checklist of stages and of all 20 bombs with statuses: not started / in progress / done / verified), and after any context compaction always re-read `docs/00_TASK_PROMPT.md` and `docs/PROGRESS.md` first.
4. **Allowed without further questions:** searching and reading web pages; downloading public reference images and free CC0 materials (Poly Haven, ambientCG, Wikimedia Commons, US government photos) **into the project folder only**; running Godot and any safe PowerShell commands; `git init` and local commits inside the project (no push). Any downloaded asset must be CC0/public domain and listed in `CREDITS.md`. Prefer generating everything procedurally (code, shaders, procedural audio).
5. **Forbidden:** writing outside the project folder (except temp files in the session's system temp folder); changing system settings; touching other processes (if a Godot editor is open on this project, do not kill it: work through the CLI, and if files are locked wait 10 s and retry); installing anything on the system; using third-party addons or GDExtensions.
6. **Do not use Blender** (it is not installed). No external 3D editors. Build every model in code from primitives (`ArrayMesh`, `CSGShape`, `MeshInstance3D`, etc.).
7. You may and should use subagents and workflows: parallel research, independent screenshot review with fresh eyes (an "art director" whose job is to find what looks fake), bug hunting. Integrate code sequentially and avoid conflicting edits to the same files.
8. This is a visualization of known public historical and scientific data. No technical details of weapon design are needed; do not add any.

## 1. Environment

- Windows 11; PowerShell. Hardware: RTX 5070, 64 GB RAM, Ryzen 7 5700X3D.
- Godot **4.7.2-stable is already installed**: editor `W:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`, console build (use this one for runs so you can see output) `W:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`. Do not download the engine.
- The project already has a `project.godot` (Forward+, Jolt Physics, d3d12 driver). Test both `--rendering-driver vulkan` and `d3d12`, pick the stable/faster one and pin it in the project.
- **Screenshots and video are only possible in windowed mode** (not `--headless`: it renders nothing). The machine's desktop must stay unlocked. This is a hard prerequisite.
- Godot exit codes are unreliable: treat a run as successful only if the log contains your own `READY` marker and contains no `SCRIPT ERROR` / `ERROR:` / `Parse Error`. Run `--headless --import` first, and again after adding new `class_name`s or assets.
- Detailed facts about the CLI, rendering, particles, audio and GDScript pitfalls are in `docs/03_GODOT_REFERENCE.md`. **Read it fully before writing code.**

## 2. Reference material already in the project

- `docs/01_BOMBS_REFERENCE.md`: dossiers on the 20 bombs (dimensions, yield, burst height, what the explosion looked like, confidence flags [V]/[1]/[E]/[D]).
- `docs/02_PHYSICS_REFERENCE.md`: formulas and scaling tables (fireball, thermal pulse, blast wave, cloud, light, sound, damage thresholds, the 12 cues of "real" footage).
- `docs/03_GODOT_REFERENCE.md`: technical facts about Godot 4.7.2.
This is starting data collected from open sources. It does not replace your own research (section 3); it speeds it up.

## 3. MANDATORY internet research

Use the internet **at the start and throughout development**; do not rely on memory. Record results in `docs/RESEARCH_NOTES.md` (fact → source/URL → how it was used).

A. **About the bombs.** For each of the 20 bombs find and cross-check against at least two sources: yield, burst height/type, dimensions and mass, what the explosion looked like (photos, film, eyewitness accounts), fireball and cloud sizes, timings. Separate clearly: measured / estimated / disputed. Download 2–4 reference photos or film stills per bomb (declassified LLNL films, DOE/NNSA, Wikimedia Commons, US National Archives) into `docs/refs/NN_name/` and **compare your screenshots against them by eye** (open the images with the file-reading tool). The references must not ship with the game (add a `.gdignore` to `docs/refs`).
Resolve the disputed points in the dossiers (Little Feller I burst height, Trinity yield, Ivy Mike cloud ceiling, Test 219 date, etc.) and correct `docs/01_BOMBS_REFERENCE.md`. If a bomb turns out to be poorly documented or visually duplicates another, **replace** it with a better-documented one of the same yield class (options: BLU-82, Castle Yankee, Operation Snowball, Hardtack II "Eddy"/"Quay"), keeping the rule "20 bombs in strictly ascending yield". Log any replacement in `DECISIONS.md`.

B. **About development.** Study current techniques: real-time volumetric explosions and mushroom clouds (raymarching in a spatial shader, fBM/curl noise, density → blackbody colour mapping, SDF torus and stem), shock waves with refraction, dust and base surges, cinematic post-processing in Godot 4.7, addon-free clipmap terrain in Godot, large (hundreds of km) scenes on float32, procedural synthesis of low-frequency sound. Reference links are at the end of `docs/03_GODOT_REFERENCE.md`. Always verify that an API actually exists in 4.7.2 (`docs.godotengine.org/en/stable`).

## 4. Game concept

- The player is in a **concrete bunker** at the edge of a huge **test range**. In front is a giant panoramic window (a viewing pane in a frame: slightly dirty, with reflections of the interior; wide field of view, default FOV 75–90°). Outside: desert and a horizon tens of kilometres away, with mountain ranges hazed in the distance.
- The bunker has a console/terminal (style it as a military terminal; it can be a 2D interface over the 3D scene) with a **menu to choose from 20 bombs**. For each bomb show: name (Russian + original), year and country, yield (kt/Mt and TNT equivalent), burst type and height, a short fact-checked blurb (2–3 sentences, in Russian), a rotating 3D preview model, a logarithmic yield bar, and a confidence tag ("claimed", "estimate", "conceptual model" where applicable).
- **Launch range is adjustable** with a slider (logarithmic scale, 0.5–200 km) plus a "Recommended distance" button (values are in `01_BOMBS_REFERENCE.md`, the "Рек. дистанция" column). The player can also adjust the target azimuth slightly (±30°). On the slider show flight time and the estimated zones (glass 1 psi, house 5 psi, third-degree burns, concrete 20 psi), computed from the formulas in `02_PHYSICS_REFERENCE.md`.
- The **LAUNCH** button: a launch position is visible outside the window, front-left. The bomb rides a generic booster missile (one shared model scaled to the bomb's size), lifts off with flame and a smoke trail, follows a ballistic arc and detonates on target at the specified height. Flight time is 6–25 s (compressed, depends on range). Heavy bombs (Tsar Bomba, B83, Little Boy, etc.) may have a parachute phase. The camera looks around freely with the mouse; the mouse wheel is a binocular zoom (FOV 75° → 3°, smooth, stabilized), an important tool for small explosions far away.
- Other controls: `R` reset, `Tab` menu, `Space` pause, `[` / `]` slow down / speed up time (0.05×–4×), `C` **cinematographer mode** (free camera outside the bunker, HUD hidden, `WASD` + mouse + `Shift`), `T` time of day (dawn, noon, dusk, night), `H` humidity (affects condensation domes), `F12` screenshot, `Esc` quit. Key hints are shown in the menu.
- Post-launch HUD (can be hidden): T+ seconds, distance, countdown to arrival of light / heat / blast wave / sound, current stage (flash, fireball, breakaway, rise, stabilization).
- The bunker must feel alive: when the blast wave arrives, camera shake (amplitude from the computed pressure at the observer), dust falling from the ceiling, flickering/dying lights, cracks on the glass above a threshold, darkening or white-out. The window glass is rated for 10 psi; above that it cracks, and at ≥ 25 psi it blows out and a "BUNKER DESTROYED" screen with a retry button appears. Before launching at a dangerous distance show a warning (but do not forbid it).
- UI language: Russian by default; bomb names show Russian + original. Provide an RU/EN toggle (all strings in a localization table).

## 5. The 20 bombs (strictly ascending yield)

Full dossiers are in `docs/01_BOMBS_REFERENCE.md`. Summary:

| # | Bomb | Yield | Burst |
|---|---|---|---|
| 1 | Mk 82 | ≈0.1 t | contact / low air |
| 2 | Mk 84 | ≈0.5 t | contact / low air |
| 3 | Tallboy | ≈3 t | buried (camouflet) |
| 4 | Grand Slam | ≈6.6 t | buried (camouflet) |
| 5 | GBU-43/B MOAB | 11 t | air, just above ground |
| 6 | W54 "Davy Crockett" (Little Feller I) | 18–20 t | near-contact |
| 7 | "Father of All Bombs" (ATBIP) | 44 t (claimed) | volumetric / thermobaric |
| 8 | B61 Mod 12 (minimum yield) | ≈0.3 kt | air, ≈100 m |
| 9 | "Little Boy" | 15 kt | air, 580–600 m |
| 10 | "Grable" | 15 kt | air, 160 m |
| 11 | "Trinity" | ≈21 kt | tower, 30 m |
| 12 | "Baker" | 21–23 kt | underwater |
| 13 | "Sedan" | 104 kt | buried, 194 m |
| 14 | Ivy "King" | 500 kt | air, 450 m |
| 15 | B83 | 1.2 Mt | surface |
| 16 | RDS-37 | 1.6 Mt | air, 1,550 m |
| 17 | Ivy "Mike" | 10.4 Mt | surface |
| 18 | Castle "Bravo" | 15 Mt | surface |
| 19 | Test No. 219 | 24.2 Mt | air, 3,750 m |
| 20 | "Tsar Bomba" | 50 Mt | air, 4,000 m |

**Bomb models:** do not spend time on them. Each one must differ in shape, size (real proportions), and colour/markings (olive drab with a yellow band, dark grey cylinder, white "Tsar", caisson, etc.), but it can look simple: primitives, procedural geometry, plain materials. They will barely be visible. The only requirement is a recognizable silhouette in the menu preview and that they are distinguishable from each other. For Ivy "Mike" (a 74 t stationary device) use a conceptual model and label it in the UI "device, not a bomb; conceptual delivery".

Keep data in `data/bombs.json` (or `.tres`): id, names, year, country, yield, TNT equivalent, confidence notes, burst type, height, medium (air / ground / water / underground), dimensions and mass, colours, recommended distance, blurb text, and the explosion-profile parameters (section 6). Do not hardcode numbers in scripts.

## 6. Explosions: the top priority

### 6.1. Architecture
- One physics module `blast_physics` (formulas from `02_PHYSICS_REFERENCE.md`: fireball radius and time, thermal pulse, pressure vs distance, arrival time, cloud height and width, rise rate, crater, burn ranges) plus an **explosion profile** (`ExplosionProfile`) per bomb. All stages are driven by the explosion's "age" in seconds, which shaders receive as a uniform or global parameter rather than `TIME`. This gives slow motion, pause, scrubbing and a deterministic offline render.
- Burst types: `CONVENTIONAL_SURFACE`, `CONVENTIONAL_BURIED` (camouflet), `THERMOBARIC`, `NUCLEAR_AIR`, `NUCLEAR_LOW_AIR` (precursor), `NUCLEAR_TOWER`, `NUCLEAR_SURFACE`, `NUCLEAR_BURIED` (Sedan), `NUCLEAR_UNDERWATER` (Baker), `NUCLEAR_HIGH_AIR` (Tsar class). For Baker, locally create water (a pond of about 3–5 km radius around the target); for Sedan, a ground dome and crater.
- All effect sizes are computed from formulas (yield and burst type), not eyeballed. Art parameters (colour ramps, noise scale, cap shape) sit on top of the physics, in each bomb's profile.

### 6.2. Effect layers (build all of them, not only the fireball)
1. **Flash:** an HDR white sphere, a powerful directional/point light, a global exposure flash (auto-exposure drops 3–8 stops and recovers over 5–20 s), bloom, a lens halo; a time-correct brightness curve (double thermal pulse, dip at t_min, peak at t₂).
2. **Fireball:** volumetric raymarching (fBM + curl noise, density → temperature → blackbody colour, cooling 8,000 K → 2,000 K), a "rapatronic" bumpy early shell, shock-front breakaway, a toroidal vortex inside during the rise. Sizes and times come from the formulas.
3. **Blast wave:** a visible expanding spherical shell with refraction (background distortion), a ring along the ground sweeping dust; **Mach stem** and thermal precursor (a ragged, low front) for low bursts; a dust "skirt"; the wave crosses the terrain and actually destroys range objects by the psi thresholds in `02_PHYSICS_REFERENCE.md` (section 6): glass / trees / houses / vehicles / towers / bridges in the correct order.
4. **Wilson condensation dome:** a white shell for 1–2 s in humid air (depends on the humidity setting).
5. **Dust, debris, base surge:** GPU particles that collide with the terrain (heightfield), large debris on ballistic arcs, a low-lying base surge for underwater / underground / low bursts.
6. **Cloud:** a toroidal vortex + cap + stem (SDF + raymarching + noise) and/or layered GPU particles; rise on the real speed curve; "cauliflower" structure; red-brown from nitrogen oxides at the start → white/grey as it cools; afterwinds along the stem; ice caps and ring-shaped "skirts" for megatons; overshoot and settling; sunlit with self-shadowing, lit from within by the glowing core, lit from clouds above the bunker; cloud shadow on the ground.
7. **Light on the landscape:** the flash lights the terrain; hard shadows sweep across the range while the fireball grows and rises; at dusk / night, dramatic scene lighting from the explosion itself.
8. **Heat and fires:** by the burn and ignition thresholds (section 4 of the physics reference), trees / grass / buildings ignite, the ground chars (a scorched-zone decal), heat haze over the ground.
9. **Crater and traces:** a crater of the correct size, ejected soil, fragment marks.
10. **Sound** (section 8) and the **bunker** (shake, dust, lights, cracks).
11. **Atmosphere:** aerial perspective, distance haze, a horizon; for megatons, a visible sky glow, and optionally ring clouds punched out by the shock wave.

### 6.3. Every bomb MUST have its own recognizable signature (not scaled copies of one cloud)
1 Mk 82: sharp flash, a small black-grey dirt cloud, a fan of fragments, a 5–8 m crater.
2 Mk 84: bigger: an orange ball and a black-brown column, a dust ring, a visible shock ring on dry ground.
3 Tallboy: no fireball: ground heave, a geyser of soil and smoke, a camouflet crater, ground tremor.
4 Grand Slam: the same but deeper and wider, volcano-like gas venting from the crater, a moderate orange flash.
5 MOAB: bright orange flame plus a lot of black smoke, a mini-mushroom, a visible wave ring, condensation.
6 Davy Crockett: a tiny nuclear explosion: white flash, a ≈15 m ball, a dirty small 3 km cap.
7 "Father of All Bombs": thermobaric: a huge rolling orange ball of ≈110 m lasting 8–9 s, little dust, the start of a mushroom.
8 B61 (0.3 kt): a bright white ≈40 m ball, a small clean 1.5–2 km cloud, a Wilson dome.
9 Little Boy: airburst at 580 m: flash, a ≈200 m ball, a shock wave with condensation, a dark boiling 9–12 km cloud, "black rain".
10 Grable: low burst at 160 m: Mach stem, precursor, a ragged dusty front.
11 Trinity: tower, dawn: a purple-green-white colour progression, an early-phase "bubble", a dust skirt, a three-layer red-brown cloud, trinitite.
12 Baker: no ball: a spray dome, a Wilson hemisphere ≈1.6 km across, a hollow 1.8 km water column, a base surge out to 5 km, waves.
13 Sedan: a ground dome, flash venting through it, a base surge, a dust column without a true cap, a ≈380 × 100 m crater.
14 Ivy "King": a blinding white ball of ≈0.7 km radius, a 20+ km cloud piercing the tropopause.
15 B83: a surface megaton burst: a dark dirty stem, a huge crater, a brown cloud.
16 RDS-37: high airburst: a giant white ball, a 14+ km cloud, a condensation ring on the stem, a transparent "skirt", a double "thunder".
17 Ivy "Mike": a gigantic surface burst: a ≈5 km ball, a wide 100+ km cap, a water curtain at the base, a crater in the reef.
18 Castle "Bravo": surface burst: condensation rings and ice caps, a crimson sky, a dark 7 km stem.
19 Test No. 219: Tsar class: an airburst at 3.75 km, a ball near the ground, a winter scene (optional snow on the range).
20 "Tsar Bomba": the limit: an ≈8 km ball touching the ground, a flash to the horizon, a two-tier 95/70 km cap, the shock wave visible in the sky.

### 6.4. Realism checklist: check every explosion against it
Double thermal pulse and correct fireball colour; the brightness dip at t_min; the ball is not "plasticine": a ragged, bumpy surface with fine turbulence; fine detail (prominences, vortices) on the cap; the cloud has a torus and "cauliflower" structure; correct stem-to-cap proportions; **correct sizes and times** (check the numbers against the physics reference tables: ball radius, cloud height, arrival time); sound delay and ground tremor; cloud shadow; scene illumination; eye exposure; dust and the wave along the ground; destruction of objects in the correct order; no artifacts (raymarching banding, flicker, pixel squares, hard LOD seams), no time "stair-stepping".

### 6.5. Extra amplifiers (do them where performance allows)
- Times of day: dawn (Trinity!), noon, dusk, night; at night the explosion lights the whole range, producing the most spectacular frames. Humidity and haze presets.
- Cinematographer mode: slow motion (0.05×), free camera, manual focus/zoom, fixed "director" angles (bunker, side view of the shock wave, low angle up at the cloud, orbit).
- Offline render for the video: `--write-movie` mode with a PNG sequence (60 fps, 4K) and maximum quality (more raymarch steps, higher particle resolution), enabled via `OS.has_feature("movie")`.
- Careful post-processing: HDR glow, tonemapper (AgX/ACES), light chromatic aberration and film grain (toggle), vignette, a delicate lens flare from the flash, heat haze.
- Near the target, instrumented structures and test objects in distance rings (wooden and brick houses, tanks, trucks, towers, a bridge, concrete bunkers, a hangar, aircraft on the apron, rows of trees) so the blast wave is "readable" and destruction is visible. Use `MultiMeshInstance3D` and procedural models. There should be enough objects to look alive, but not at the cost of FPS.
- The sound design (section 8) and the bunker's tactile reaction give the sense of scale; do not skip them.

## 7. World and scale

- Real 1:1 scale: a range up to 200 km, a target on the slider at 0.5–200 km, a cloud up to 67 km high. The camera and bunker sit at the origin (0,0,0); vertices and effects use local coordinates (see `03_GODOT_REFERENCE.md`: float32, reversed-Z, far plane 200–300 km, near plane 1–5 m outside the bunker; a separate layer/camera with a small near plane for the bunker interior).
- Addon-free terrain: a clipmap or chunks with LOD from a heightmap (procedural low-frequency ridges at the horizon, a dry lake / playa around the target, washes, roads), normals in the shader, aerial perspective, texturing by height/slope with macro variation. For CPU height queries (destruction, object placement) use the same noise function.
- Sky: a procedural sky shader (Rayleigh/Mie scattering, sun, stars at night); clouds at altitude must not hide the explosion (on/off option).
- Environment for special bombs: water for Baker, snow optional for Test 219 / Tsar. Verify that switching does not break the others.

## 8. Sound (procedural)

Synthesize everything in GDScript (WAV / AudioStream); no external recordings are needed. Layers: the sharp "crack" of the front, a low-frequency thump (subsonic), a rumble with terrain echo lasting 5–30 s, the hiss/roar of the fireball, the sound of airflow as the cloud rises, distant "thunder". **Delay = distance / 343 m/s** (or the blast-wave arrival time for strong explosions); **ground tremor** arrives before the air wave. A stronger low-pass filter with distance; for megatons, an infrasonic "thump" and temporary "ringing in the ears" (the master bus is muffled for a few seconds after a close explosion). Keep the master ≤ 0 dB (Limiter). Bunker ambience: ventilation, a light electrical hum. In-flight bomb sound: the rocket launch, the whistle of the fall.

## 9. Performance

Target: ≥ 60 fps at 1440p in a typical scene, ≥ 30 fps in the worst case (Tsar Bomba, night, cloud peak) on an RTX 5070 in real time, with automatic quality adaptation (raymarch steps, volume resolution, particle count) and manual presets (Low / Medium / High / Cinematic). Measure FPS in a separate windowed run (`--write-movie` does not measure real FPS). The first launch must warm up shaders with no noticeable hitches at the moment of an explosion (pre-compilation / warm-up at load).

## 10. Project structure (recommended)

```
res://scenes/    main.tscn, bunker.tscn, range.tscn, ui/...
res://scripts/   core/, physics/blast_physics.gd, bombs/, fx/, world/, ui/, audio/, tools/
res://shaders/   fireball.gdshader, cloud.gdshader, shockwave.gdshader, terrain.gdshader, sky.gdshader, post.gdshader ...
res://data/      bombs.json, locale.json
res://tools/     shoot.gd (screenshots), selftest.gd, usage_report.ps1
docs/            00_TASK_PROMPT.md, 01..03_*_REFERENCE.md, RESEARCH_NOTES.md, DECISIONS.md, PROGRESS.md, TIMELOG.md, QA_REPORT.md, PROJECT_STATS.md, refs/
run.bat          launch the game windowed (relative path or variable for godot.exe, with a fallback search)
run_cinematic.bat  launch recording mode
README.md, CREDITS.md
```

## 11. Verification: without it the work is not done

You cannot "see" or "hear" without tooling, so build it.

1. **Deterministic test rig.** Arguments after `--`: `--bomb N --dist KM --tod dawn|noon|dusk|night --humidity 0..1 --quality low..cine --shots t1,t2,... --out DIR --quit`. The scene runs windowed, waits for warm-up, fires, sets the time to the given `age` values and saves PNGs via `await RenderingServer.frame_post_draw` + `get_viewport().get_texture().get_image().save_png(...)`. For video use `--write-movie`.
2. **Frame schedule** for every bomb (explosion "age" in seconds; scale to the real explosion timings): 0.002; 0.02; 0.1; 0.5; 1; 2; 5; 10; 20; 40; 90; 180; 360 (nuclear); shorter for small bombs but covering the same stages. At least 3 viewpoints: the recommended distance, 3× closer, 3× farther; plus an outside cinematic camera; plus day and night.
3. **Contact sheets:** stitch a series of frames into one PNG (via `Image.blit_rect` in Godot) so you can review an explosion's development at a glance.
4. **Look at the frames yourself** (open the PNGs with the image-reading tool) and compare them with the references in `docs/refs/`. Then give an independent art-director subagent the task "find everything that looks unrealistic / ugly / physically wrong" and fix it. For **each** bomb do **at least 3 full cycles of "fix → render → look"**; a first version is never accepted.
5. **Quantitative checks** (automated tests in `selftest.gd`, output `READY`/`FAIL`): ball radius vs formula (±15%), cloud height vs table (±20%), blast arrival time vs calculation (±5%), peak pressures at the bunker, monotonic yield ordering across bombs, no NaN/∞, no errors in the log, no leaks (nodes/memory do not grow over 20 consecutive launches).
6. **QA matrix:** 20 bombs × 3 distances × 2 times of day, with no crashes and no errors in the log; repeat launches without restarting the game; switching time of day, slow motion, pause, cinematographer camera, HUD on/off, RU/EN.
7. **Performance:** an FPS report per scenario (summary in `docs/QA_REPORT.md`).
8. **Godot traps** (see `03_GODOT_REFERENCE.md`): the first `--import`, `visibility_aabb` on particles, `extra_cull_margin` on mesh proxies, `await frame_post_draw`, absolute paths, `set_shader_parameter`, reversed-Z, return values on overridden methods in 4.7, unreliable exit codes.

Acceptance criteria: the game launches via `run.bat` with no manual steps; the menu works; all 20 bombs launch at any distance; each bomb's explosion is visibly different; the numbers agree with the physics; no errors in the log; FPS is in the target range; the documentation is up to date.

## 12. Order of work (stages)

0. Start time in `TIMELOG.md`, a copy of the prompt in `docs/00_TASK_PROMPT.md`, `PROGRESS.md`; read `docs/01..03`.
1. Research (section 3), refine the dossiers, download references; write to `RESEARCH_NOTES.md`.
2. Skeleton: `--import`, choose the driver, an empty scene, the screenshot rig (verify PNGs really save and are not black), `git init` and a first commit.
3. World: terrain, sky, lighting, the bunker with its window, camera, scale/precision; render test frames.
4. The `blast_physics` module + `bombs.json` + automated tests.
5. **Bring ONE reference explosion up to full quality** (I recommend Trinity at dawn or "Little Boy"), then replicate the system for the other 19: fireball/cloud shaders, blast wave, dust, light, sound, bunker.
6. The remaining bombs in ascending order: profiles, special types (camouflet, thermobaric, water, underground, low air, megatons), object destruction.
7. Menu, range slider, model previews, HUD, cinematographer mode, keys, localization.
8. Sound.
9. Polish (section 6.5), optimization, auto-quality.
10. The full QA matrix, independent review, fixes, final frames.
11. Documentation (`README.md`, `CREDITS.md`, `QA_REPORT.md`), project cleanup.
12. Final statistics (section 14).

Before and after every stage update `PROGRESS.md` and `TIMELOG.md`; after every significant step make a local `git commit`.

## 13. Practices that save time

- Do many small runs with a log instead of one big one. Run long commands in the background and poll the log.
- Do not break what already works: commit before editing shared shaders/scripts, and re-test on 2–3 reference bombs afterwards.
- Do not spend time on bomb models or UI decoration before the explosions look good.
- If a feature depends on an API that does not exist in 4.7.2, check the docs, find a workaround, and log it in `DECISIONS.md`.
- Introduce anything risky (long shader compilation, unstable effects) step by step and check FPS.

## 14. What to deliver, and the FINAL REPORT (mandatory)

Deliver: a working project, `run.bat`, `run_cinematic.bat`, `README.md` (how to run, controls, architecture, known limitations), `CREDITS.md`, `docs/*`, a set of the best screenshots in `docs/screens/` (2–3 per bomb), and `docs/QA_REPORT.md`.

**At the very end of the work, calculate and show:**
1. **Time spent:** the start time from `docs/TIMELOG.md`, the end time (`Get-Date -Format o`), total duration, and a per-stage breakdown. State how much time went to waiting on background processes if that is measurable.
2. **Token count:** find the session logs (JSONL) under `%USERPROFILE%\.claude\projects\` (this project's folder is `G--YouTube-Atomic-Bombs-atomic-bombs-opus-5-5` or similar; find it exactly) and sum the `usage` fields **across the main log and the logs of all subagents/workflows**: `input_tokens`, `output_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens`. Write a script for this, `tools/usage_report.ps1` (or Python if available), and give a table by category and by model (if subagents ran on other models, list them separately). If some logs are unavailable, say so plainly and give an estimate labelled "estimate".
3. **Cost in dollars at API-equivalent prices:** look up the **current Anthropic API prices** for the models used (Claude Opus 5.5 and any other subagent models) on the official pricing page (input, output, cache write, cache read per 1M tokens; account for the 5-minute / 1-hour cache tiers and long-context pricing if applicable). Compute the cost per category and the total. Show the formula, the prices and the assumptions. If you cannot find the prices, say so and do not invent numbers.
Write all of this to `docs/PROJECT_STATS.md` and repeat it in the final message. The numbers must be measured, not invented; where something is an estimate, say so.

In the final message, briefly state: what was done, what was verified (and how), known limitations, where the best frames are, and how to run it.

## 15. Completion condition (the "done" checklist)

You may finish only when ALL of the following are met. Check them one by one and mark them in `docs/PROGRESS.md`.

1. All 20 bombs launch from the menu at the recommended, near and far distances, and each has the status `verified` (at least 3 full cycles of "fix → render → look", frames in `docs/screens/`).
2. The explosions are visibly different in character (section 6.3), and the numbers agree with the physics (the `selftest.gd` automated tests print `READY` and do not print `FAIL`).
3. The QA matrix from section 11 passes with no crashes and no errors in the log; `docs/QA_REPORT.md` is filled in.
4. FPS has been measured and the section 9 targets are met, or the deviations are honestly described.
5. The game has been cleanly launched from scratch via `run.bat`: it starts, the menu works, the range slider works, and launch and explosion run with no manual steps. `run_cinematic.bat` is also tested.
6. `README.md`, `CREDITS.md`, `docs/RESEARCH_NOTES.md`, `docs/DECISIONS.md`, `docs/PROGRESS.md`, `docs/TIMELOG.md` and `docs/PROJECT_STATS.md` are ready.
7. A final local `git commit` has been made.
8. As the last step, the time / token / cost calculation (section 14) has been done and its result shown in the final message.

While even one item is unmet, keep working and do not end your turn.
