# 03. Godot 4.7.2: технические факты для агента

Проверено 2026-11-06 по официальной документации и GitHub. **[проверено]** — читалось в доках/репозитории; **[память]** — не проверено, проверь быстрым тестом.

## Установка и запуск
- Godot 4.7.2-stable (релиз 2026-08-18) **уже установлен** у пользователя:
  - редактор: `W:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`
  - консоль (используй её, чтобы видеть stdout/stderr): `W:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`
  (папка называется как exe — это нормально.) Скачивать ничего не нужно. Шаблоны экспорта не нужны для запуска `--path`.
- Рендерер проекта: Forward+. В `project.godot` сейчас `rendering_device/driver.windows="d3d12"` (редактор создал по умолчанию). Проверь оба драйвера (`vulkan` и `d3d12`) на этой машине, выбери стабильный и быстрый и зафиксируй в `project.godot`. HDR-вывод в 4.7 работает только на d3d12; для записи видео лучше SDR.
- Железо: RTX 5070, 64 ГБ ОЗУ, Ryzen 7 5700X3D.

## Командная строка [проверено, docs: command_line_tutorial]
`--path <dir>`; `--rendering-method forward_plus`; `--rendering-driver vulkan|d3d12`; `--resolution WxH`; `-w` оконный; `--fixed-fps N`; `--max-fps N`; `--disable-vsync`; `--quit`; `--quit-after N` (кадры); `--write-movie file`; `--headless`; `-s/--script x.gd`; `--check-only`; `--import`; `--log-file f`; `-v`; всё после `--` Godot игнорирует (читай через `OS.get_cmdline_user_args()`).
- Неизвестные флаги **молча игнорируются**: опечатка не даёт ошибки.
- `--headless` = dummy-дисплей и аудио: **пикселей нет**. Используй только для `--import`, проверки парсинга и логики. Скриншоты и видео — только в оконном режиме на реальном GPU при разблокированном рабочем столе.
- **Коды выхода ненадёжны** [проверено на 4.7.2, форум]: синтаксическая ошибка может дать exit 0, пустой лог ничего не доказывает. Правило: прогон считается успешным, только если в stdout есть ожидаемый маркер (например, `READY`) И в логе нет `SCRIPT ERROR`, `ERROR:`, `Parse Error`. Пиши лог через `--log-file`.
- `--check-only` даёт ложные срабатывания на скриптах с autoload/ещё не импортированным `class_name`. Для проверки парсинга напиши `--script`, который `load()`-ит все `.gd` и проверяет `can_instantiate()`.
- Первый запуск и после добавления новых `class_name`/ассетов: `godot --headless --path P --import` (строит `.godot/` и кэш классов). Без этого бывают ложные «Could not find type».
- Файлы `.uid` и `.import` — текстовые, сохраняй. `.godot/` — кэш, перегенерируемый.
- `user://` на Windows: `%APPDATA%\Godot\app_userdata\<имя проекта>\`.

## Скриншоты и видео [проверено]
- Скриншот изнутри запущенной сцены:
  ```gdscript
  await RenderingServer.frame_post_draw
  var img := get_viewport().get_texture().get_image()
  var err := img.save_png("C:/abs/path/shot.png")
  ```
  Нельзя вызывать в `_ready()` (чёрный кадр). Проверяй `err`. Путь — абсолютный или `user://`. Не нужен `flip_y()`. Для HDR — `Image.save_exr(path, false, false, -1.0)` (в 4.7 у `save_exr` новые параметры).
- Детерминированный кадр-за-кадром: `godot --path P --write-movie out.png --fixed-fps 30 --quit-after 900 --resolution 1920x1080`. Относительные пути идут от папки проекта. Формат `.png` даёт последовательность PNG + WAV (`out00000000.png`), `.avi` — MJPEG (лимит 4 ГБ). Звук пишется в файл, не воспроизводится. Mix rate должен делиться на FPS. Выходить через `get_tree().quit()` или `--quit-after`, не убивать процесс (AVI/WAV повредятся). `OS.has_feature("movie")` истинно при записи — используй, чтобы включить максимальное качество.
- ffmpeg пример: `ffmpeg -r 30 -i out%08d.png -i out.wav -crf 15 out.mp4`.
- Время эффекта привязывай к `frame/fps`, а не к `delta` или `TIME` (`TIME` в шейдере сбрасывается каждые 3600 с и зависит от `time_scale`). Передавай «возраст взрыва» через uniform/global shader parameter.
- Seed для шума и частиц фиксируй явно.
- `await get_tree().create_timer(delay).timeout` в режиме movie работает по игровому времени (детерминирован).

## Рендер [проверено, docs]
- **Объёмный туман Forward+**: froxel-сетка с ограниченной дальностью (`volumetric_fog_length`, по умолчанию ≈ 64 м) — «не покрывает очень большие миры». Для километровых взрывов НЕ подходит как основной инструмент; годится для локальной дымки в бункере и мелких эффектов. FogVolume-шейдер (`shader_type fog`) работает по froxel-ячейкам.
- **Рэймарчинг в spatial-шейдере**: ставь прокси-меш (сфера, полусфера, billboard-quad, камера-ориентированный бокс) с `render_mode unshaded, blend_mix|blend_add, cull_front|cull_disabled, depth_draw_never, fog_disabled;` и марширь шум внутри. Для ограничения шагов используй пересечение луча со сферой/боксом. Canvas-шейдеры не дают 3D-окклюзии.
- **Fullscreen post-process quad** (рабочий шаблон 4.3+):
  ```glsl
  shader_type spatial;
  render_mode unshaded, fog_disabled;
  uniform sampler2D depth_texture : hint_depth_texture;
  void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }
  void fragment() {
      float depth = texture(depth_texture, SCREEN_UV).x;
      vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
      vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
      view.xyz /= view.w;
      float linear_depth = -view.z;
      vec4 world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
      vec3 world_position = world.xyz / world.w;
  }
  ```
  Квад: QuadMesh 2×2 с flip_faces, либо один треугольник; крепи к камере или задавай `extra_cull_margin`, иначе обрежется.
- **Reversed-Z** (4.3+): ближняя = 1.0, дальняя = 0.0. Всегда восстанавливай позицию через `INV_PROJECTION_MATRIX`. NDC z в [0,1] на Forward+/Mobile.
- `hint_screen_texture` и `hint_depth_texture`: прозрачные объекты в них не попадают. Чтение `hint_depth_texture` из прозрачного меша — путь к «мягким» объёмам и частицам [память].
- Прозрачные объекты сортируются по позиции узла (без OIT): используй `sorting_offset` и `render_priority`.
- **Environment**: тонмаппер Linear/Reinhard/Filmic/ACES/AgX (`white` 6–8 для фотореализма); glow: HDR Threshold ≈ 1.0, режим Additive/Screen для взрывов; значения emission/albedo выше 1.0 (5–50) питают bloom. Авто-экспозиция — только Forward+ через `CameraAttributesPractical` (ISO, min/max sensitivity, speed, scale) или `CameraAttributesPhysical` (EV100). `Camera3D.attributes` перекрывает WorldEnvironment.
- **GI**: SDFGI следует за камерой и масштабируется на любой мир, но не поддерживает динамические излучатели. Свет взрыва делай анимированными OmniLight3D/DirectionalLight3D с огромным range и энергией. VoxelGI — только для маленьких областей.
- **Камера**: по умолчанию near 0.05, far 4000. Для километровых сцен подними far до 200–300 км и near до ≈ 1–5 м снаружи бункера (в бункере отдельная камера/слой с малым near). Глубина 32 бита на десктопе.
- **Дальний горизонт**: терраформ без аддонов — clipmap (кольца сетки, смещаемые в vertex-шейдере по heightmap, привязка к сетке под камерой) или chunk-quadtree с LOD (`visibility_range_*`). На любом смещаемом шейдером меше ставь большой `extra_cull_margin`. Нормали считай в fragment по соседним сэмплам heightmap. Деревья/камни/дома — `MultiMeshInstance3D` (сначала `transform_format`, потом `instance_count`), разбивай на области — per-instance culling нет.
- **Небо**: `shader_type sky` (встроенные `EYEDIR`, `LIGHT0_DIRECTION`, `LIGHT0_ENERGY`, `LIGHT0_COLOR`, `AT_CUBEMAP_PASS`, `TIME`) для процедурного рэлеевского рассеяния. Дымку расстояния можно считать в шейдере террейна (воздушная перспектива).
- **Точность**: стандартный float32 даёт ≈ 1 см на 10 км и ≈ 6 см на 50 км от начала координат [память]. Double precision — только сборка движка из исходников (недоступна). Приём: камера и бункер в (0,0,0), эффект строить в локальных координатах прокси (шейдер марширит в локальном пространстве меша, масштаб — через scale узла), позицию эффекта задавать в мировых метрах.
- **HDR-вывод** (новое в 4.7, только d3d12/Windows): не нужен для записи; оставайся в SDR, если не просили иного.

## Частицы GPUParticles3D / ParticleProcessMaterial [проверено]
- `sub_emitter` + `sub_emitter_mode` и `sub_emitter_amount_*` на материале; трейлы (`trail_enabled`, нужен `RibbonTrailMesh`/`TubeTrailMesh` и `use_particle_trails`); турбулентность (`turbulence_*`); аттракторы (`GPUParticlesAttractor*`); коллизии (`GPUParticlesCollisionHeightField3D` — `size`, `resolution` 256–8192, `follow_camera_enabled` — дешёвый способ заставить пыль и обломки сталкиваться с террейном).
- `visibility_aabb` по умолчанию мал (≈ 8 м): **увеличивай для больших эффектов**, иначе частицы исчезают, и коллизии/аттракторы работают только внутри.
- `amount` перезапускает систему — используй `amount_ratio`. Для повторного запуска one_shot вызывай `restart()`. `fixed_fps` по умолчанию 30, `interpolate`, `local_coords`, `explosiveness`, `preprocess`, `speed_scale`, `emit_particle()`.
- Собственный `shader_type particles` возможен, но детали не проверены.

## Звук [проверено]
- `AudioStreamWAV`: `format = FORMAT_16_BITS`, `mix_rate = 44100`, `stereo`, `data = PackedByteArray`. Запись сэмплов: `PackedByteArray.resize(n*2)`, `encode_s16(i*2, int(clampf(v,-1,1)*32767))`. 8-бит — знаковый PCM. Геттер `data` возвращает копию. Для отладки есть `save_to_wav(path)`. Расположение байтов 16-бит (little-endian signed, стерео интерливинг L,R) — [память].
- `AudioStreamGenerator` + `AudioStreamGeneratorPlayback.push_buffer(PackedVector2Array)` — реальное время, подпитка каждый кадр. Для коротких ударов и режима movie проще заранее собранный `AudioStreamWAV`.
- Шины: `AudioServer.add_bus`, `set_bus_name`, `add_bus_effect(idx, AudioEffectLowPassFilter.new(), ...)`, `set_bus_send`, `set_bus_volume_db`. Эффекты [память]: `AudioEffectLowPassFilter.cutoff_hz`, `AudioEffectReverb`, `AudioEffectCompressor`, `AudioEffectLimiter`, `AudioEffectDistortion`. Мастер держи ≤ 0 дБ (Limiter). Неиспользуемые шины засыпают через несколько секунд.
- `AudioStreamPlayer3D`: `attenuation_model`, `unit_size` (10), `max_distance` (0 = безлимит), `max_db`, `pitch_scale`, `attenuation_filter_cutoff_hz` (5000; 20500 отключает), `doppler_tracking` (ставь и на проигрывателе, и на камере). `play()` ставится в очередь до следующего физического кадра.
- Задержка прихода звука: `await get_tree().create_timer(distance / 343.0).timeout` перед `play()`.
- Басовые удары питчуй вниз, слои: сабсонический шум, «треск» фронта, рокот-хвост, фильтр низких частот растёт с дистанцией. Всё синтезируй процедурно в GDScript.

## Подводные камни GDScript 4.x [проверено, docs]
- Типизированные массивы `Array[int]`; `Array[Node2D]` не присваивается в `Array[Node]` (используй `.assign()`). Типизированные словари `Dictionary[String, int]` с 4.4.
- Сигналы: `signal hit(amount: int)`, `hit.emit(5)`, `node.hit.connect(callable)`. Старый `connect("sig", obj, "method")` не используй.
- `await signal`/`await coroutine()`; `yield` нет.
- `@export var` и `@onready` на одной переменной — ошибка (`ONREADY_WITH_EXPORT`). Setter/getter: `var x: int: set(v): ...`.
- `var x := some_variant_call()` — ошибка (вывод типа из Variant): указывай тип явно.
- Целочисленное деление `5/2 == 2`; `%` только для int, для float — `fmod`/`fposmod`; сравнивай float через `is_equal_approx`.
- Лямбды захватывают локальные переменные по значению.
- `match`: `1` не совпадает с `1.0`.
- Переопределение невиртуальных методов — ошибка. Если у родителя `_init` с аргументами — `super(...)`.
- 4.7: у переопределений методов с типом возврата теперь нужен явный `return` (добавь `return null`); `Image.save_exr` получил `color_image` и `max_linear_value`; `LinearToSRGB` больше не клампит на Forward+.
- Шейдеры: `mat.set_shader_parameter("name", v)` (3.x `set_shader_param` нет); глобальные: `RenderingServer.global_shader_parameter_add(name, type, default)` и `global_shader_parameter_set`; в шейдере `global uniform float x;`. Float-литералы пиши с `.0`. Подсказки uniform: `: source_color`, `: hint_range(a,b)`, `: hint_screen_texture`, `: hint_depth_texture`, `: hint_normal_roughness_texture`, сэмплеры `: repeat_enable, filter_linear`.
- `ArrayMesh`: массив `arrays` должен быть размера `Mesh.ARRAY_MAX`.
- Типичные ошибки LLM: `get_image()` в `_ready()`; API Godot 3 (`OS.get_ticks_msec` → `Time.get_ticks_msec`, `Spatial` → `Node3D`, `KinematicBody` → `CharacterBody3D`); забыть `get_tree().quit()` в скриптованных прогонах; не задать `visibility_aabb`/`extra_cull_margin`; смешивать `res://` и абсолютные пути в `Image.save_*`; забыть `set_surface_override_material`.

## Эталоны техник (портировать в spatial-шейдер)
1. GPU Pro 6, A. Dunn «Realistic Volumetric Explosions in Games» — рэймарчинг шума внутри сжимающейся полусферы-прокси.
2. GPU Gems 3, гл. 30 — сетка 3D-жидкости (огонь/дым) в 3D-текстурах. Полезна как модель освещения; в Godot — тяжело.
3. Wallis «Volumetric Rendering Part 1» (wallisc.github.io) — SDF-объёмы + fBM + Beer–Lambert. Шляпка = SDF-тор, ножка = цилиндр, fBM добавляет турбулентность.
4. godotshaders.com «Spatial Fire Raymarched» — рабочий Godot 4 пример: billboard + NoiseTexture3D, 4–6 шагов.
5. godotshaders.com «Volumetric Plasma Flame» (порт iq, CC BY-NC-SA — проверь лицензию) — только функция плотности.
6. Shadertoy XT95 flame (`MdX3zr`) — переход плотность → цвет чёрного тела, излучение → bloom.
7. Unity VFX Graph «6-way lighting» — предрендеренные спрайты дыма с освещением по 6 направлениям, смешиваются по направлению света.
8. Unreal Niagara Fluids — для сценария фаз (начальная вспышка, подъём шара, захват дыма); не портируется напрямую.
9. Hillaire «Scalable and Production Ready Sky and Atmosphere» — LUT для рассеяния; в Godot — упрощённая аналитика в sky-шейдере и дымка в шейдере террейна.
10. Статья Люблянского университета 2025 (WebGPU volumetric explosion, lgm.fri.uni-lj.si) — raymarch + transfer function + noise + bloom; ложится на spatial-шейдер + glow.

Практическая схема ядерного взрыва по слоям: эмиссионный рэймарчинг-шар (рамп чёрного тела по температуре, остывает со временем) + дым-ножка и шляпка (рэймарчинг тора/SDF и/или GPU-частицы) + ударная волна (расширяющаяся оболочка с рефракцией через `hint_screen_texture` и кольцо по земле) + пылевая юбка + свет и тряска камеры.
