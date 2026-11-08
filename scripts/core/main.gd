extends Node3D
## Main scene: builds the world, bunker, camera, launcher, explosion system, range objects,
## UI and audio; runs the game loop (menu -> flight -> explosion), input, auto-quality,
## movie/cinematic mode and the deterministic test rig.

const BlastParams = preload("res://scripts/audio/blast_params.gd")
const BlastSamples = preload("res://scripts/audio/blast_samples.gd")

enum State { MENU, FLIGHT, EXPLOSION, DESTROYED }

const UI_PATH := "res://scripts/ui/ui_root.gd"
const SOUND_PATH := "res://scripts/audio/sound_manager.gd"
const RANGE_PATH := "res://scripts/world/range_objects.gd"
const QA_DRIVER := preload("res://scripts/tools/qa_driver.gd")

var env_ctl: EnvironmentCtl
var terrain: Terrain
var bunker: Bunker
var cam: PlayerCamera
var launcher: Launcher
var explosion: Explosion
var water: Node3D
var ui: Node
var sound: Node
var range_objs: Node3D

var state: int = State.MENU
var target_gz := Vector3.ZERO
var burst_point := Vector3.ZERO
var _world_ready := false
var _fps_acc := 0.0
var _fps_frames := 0
var _quality_cooldown := 0.0
var _q_live := 1.0               # current raymarch quality scale (g_quality)
var _destroyed_shown := false
var _shot_counter := 0
var _flight_bomb := -1
var _whiteout: ColorRect
var _whistling := false


func _ready() -> void:
	print("BOOT main")
	env_ctl = EnvironmentCtl.new()
	env_ctl.name = "Environment"
	add_child(env_ctl)
	terrain = Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	bunker = Bunker.new()
	bunker.name = "Bunker"
	add_child(bunker)
	cam = PlayerCamera.new()
	cam.name = "Camera"
	add_child(cam)
	launcher = Launcher.new()
	launcher.name = "Launcher"
	add_child(launcher)
	launcher.detonated.connect(_on_detonated)
	env_ctl.set_humidity(Game.humidity)
	_load_optional_modules()
	# eye white-out / glare from the flash (also present in movie and test-rig renders)
	var wl := CanvasLayer.new()
	wl.layer = 50
	add_child(wl)
	_whiteout = ColorRect.new()
	_whiteout.set_anchors_preset(Control.PRESET_FULL_RECT)
	_whiteout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_whiteout.color = Color(1.0, 0.98, 0.95, 0.0)
	wl.add_child(_whiteout)
	if Args.has("qa_matrix"):
		Game.is_test_rig = false
		var qa: Node = QA_DRIVER.new()
		qa.set("main", self)
		add_child(qa)
		qa.call_deferred("run")
		return
	if Args.has("shots"):
		Game.is_test_rig = true
		var rig := ShotRig.new()
		rig.main = self
		add_child(rig)
		rig.run.call_deferred()
		return
	if Args.has("world_test"):
		_run_world_test()
		return
	_start_game.call_deferred()


func _load_optional_modules() -> void:
	if ResourceLoader.exists(RANGE_PATH):
		var rs: Script = load(RANGE_PATH)
		if rs:
			range_objs = rs.new()
			range_objs.name = "RangeObjects"
			add_child(range_objs)
	if ResourceLoader.exists(SOUND_PATH):
		var ss: Script = load(SOUND_PATH)
		if ss:
			sound = ss.new()
			sound.name = "Sound"
			add_child(sound)
			sound.setup()
			# --audio_log: print every scheduled sound layer (and whether the synthesized event was used)
			sound.log_events = Args.has("audio_log")
	if ResourceLoader.exists(UI_PATH) and not Args.has("shots"):
		var us: Script = load(UI_PATH)
		if us:
			ui = us.new()
			ui.name = "UI"
			# main owns the mouse mode and the Tab key (camera look must follow the menu state)
			ui.manage_mouse = false
			ui.handle_tab_key = false
			add_child(ui)
			ui.setup(Game.bombs)
			ui.launch_requested.connect(_on_launch_requested)
			ui.reset_requested.connect(reset_scene)
			ui.quit_requested.connect(func() -> void: get_tree().quit())
			ui.setting_changed.connect(_on_setting_changed)


func _start_game() -> void:
	await prepare_world(Game.tod, Game.selected_bomb)
	launcher.load_bomb(Game.bomb())
	_place_range(Game.selected_bomb, Game.distance_km, Game.azimuth_deg)
	if sound:
		sound.set_ambience(true)
	if Game.is_movie or Args.has("autolaunch"):
		_movie_autopilot()
		return
	if ui:
		ui.show_menu(true)
	_update_mouse()
	print("READY")
	if Args.has("menu_drive"):
		_menu_drive()
	if Args.has("ui_shot"):
		# QA: screenshot of the terminal menu (optionally in English / another bomb)
		if Args.has("lang"):
			Game.set_language(Args.get_str("lang", "ru"))
		for i in 90:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var out := Args.get_str("out", OS.get_user_data_dir())
		DirAccess.make_dir_recursive_absolute(out)
		var p := out.path_join("ui_menu_%s.png" % Game.lang)
		print("SHOT ", p, " err=", get_viewport().get_texture().get_image().save_png(p))
		get_tree().quit()


## QA (clean-launch test via run.bat): drives the REAL terminal menu like a player would: selects a
## bomb, moves the logarithmic range slider, presses the Launch button, waits for the detonation and
## takes screenshots of every step. Run: run.bat -- --menu_drive [--bomb N] [--out DIR]
func _menu_drive() -> void:
	var out := Args.get_str("out", OS.get_user_data_dir().path_join("menu_drive"))
	DirAccess.make_dir_recursive_absolute(out)
	for i in 60:
		await get_tree().process_frame
	var ok := ui != null and ui.get("menu") != null
	print("MENU_DRIVE ui=", ok)
	if not ok:
		print("FAIL")
		get_tree().quit()
		return
	var menu: Node = ui.get("menu")
	await _menu_shot(out, "1_menu")
	menu.call("select_bomb", Args.get_int("bomb", 10) - 1)
	await get_tree().process_frame
	var slider: HSlider = menu.get("_dist_slider")
	slider.value = 0.57
	for i in 10:
		await get_tree().process_frame
	print("MENU_DRIVE bomb=", Game.selected_bomb + 1, " dist_km=", snappedf(Game.distance_km, 0.01))
	await _menu_shot(out, "2_slider")
	var btn: Button = menu.get("_launch_btn")
	btn.pressed.emit()
	var t0 := Time.get_ticks_msec()
	while state == State.FLIGHT and Time.get_ticks_msec() - t0 < 60000:
		await get_tree().process_frame
	await _menu_shot(out, "3_detonation")
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 8000:
		await get_tree().process_frame
	await _menu_shot(out, "4_explosion")
	var good := explosion != null and explosion.age > 5.0
	print("MENU_DRIVE launched=", explosion != null, " age=", snappedf(explosion.age if explosion else -1.0, 0.1))
	if sound:
		# the blast usually arrives later than 8 s: report whether its recording (or, for a bomb
		# without one, its synthesized event) is ready
		var syn: Dictionary = sound.call("_synth_ready", sound.get("_syn_key"))
		var smp: Dictionary = sound.get("_smp_plan")
		print("MENU_DRIVE audio sample=", not smp.is_empty(), " synth_ready=", not syn.is_empty(), " mode=", sound.get("_mode"))
		if Args.has("audio_log"):
			# wait for the blast to reach the bunker: the recording (front + tail) must be what plays
			var t2 := Time.get_ticks_msec()
			while not _blast_heard() and Time.get_ticks_msec() - t2 < 120000:
				await get_tree().process_frame
			await _menu_shot(out, "5_blast")
			print("MENU_DRIVE audio at blast arrival: mode=", sound.get("_mode"), " age=", snappedf(explosion.age if explosion else -1.0, 0.1))
			good = good and _blast_heard() and String(sound.get("_mode")) == ("sample" if not smp.is_empty() else "synth")
	print("READY" if good else "FAIL")
	get_tree().quit()


## The blast has reached the bunker: a recording's front fired, or the synthesized/generic mode
## was decided at the arrival.
func _blast_heard() -> bool:
	var m := String(sound.get("_mode"))
	if m == "sample":
		for ev: Array in sound.get("event_log"):
			if String(ev[1]) == "smp_front":
				return true
		return false
	return m != ""


func _menu_shot(out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var p := out.path_join("menu_drive_%s.png" % name)
	print("SHOT ", p, " err=", get_viewport().get_texture().get_image().save_png(p))


# ------------------------------------------------------------------ world / targets

func prepare_world(tod_i: int, bomb_idx: int) -> void:
	Game.tod = tod_i
	env_ctl.apply_tod(tod_i)
	env_ctl.set_humidity(Game.humidity)
	bunker.set_night(tod_i == Game.TimeOfDay.NIGHT)
	var b := Game.bomb(bomb_idx)
	var snow := 1.0 if (bool(b.get("snow", false)) and Game.snow_override != 0) or Game.snow_override == 1 else 0.0
	RenderingServer.global_shader_parameter_set("g_snow", snow)
	_set_quality_scale(Game.quality_steps_scale())
	if not _world_ready:
		await FxResources.wait_ready(get_tree())
		_warm_up_shaders()
		_world_ready = true
	for i in 3:
		await get_tree().process_frame


func _warm_up_shaders() -> void:
	# compile every explosion shader once (invisible, tiny) so the first detonation never hitches
	var b := Game.bomb(9)
	var ex := Explosion.new()
	ex.observer = Vector3.ZERO
	add_child(ex)
	ex.setup(b, Vector3(0, -5000, -400000), null, null, null)
	ex.set_age(1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	ex.cleanup_globals()
	ex.queue_free()


func target_position(dist_km: float, az_deg: float) -> Vector3:
	var d := dist_km * 1000.0
	var az := deg_to_rad(az_deg)
	var x := sin(az) * d
	var z := -cos(az) * d
	return Vector3(x, TerrainMath.height(x, z), z)


func _burst_point(b: Dictionary, gz: Vector3) -> Vector3:
	var hob := float(b.get("burst_height_m", 0.0))
	return gz + Vector3(0, maxf(hob, 0.0), 0)


func _patch_extent(b: Dictionary) -> float:
	var prof := ExplosionProfile.new(b)
	var r := maxf(prof.crater_r * 4.0, float(b.get("profile", {}).get("dome_r", 0.0)) * 4.0)
	r = maxf(r, BlastPhysics.radius_for_pressure(prof.w_kt, 5.0, prof.surface) * 1.2)
	return clampf(r, 250.0, 6000.0)


func _place_range(bomb_idx: int, dist_km: float, az: float) -> void:
	var b := Game.bomb(bomb_idx)
	target_gz = target_position(dist_km, az)
	_setup_water(b, target_gz)
	terrain.set_patch(target_gz, _patch_extent(b))
	_setup_range_objects(b, target_gz)


func _setup_range_objects(b: Dictionary, gz: Vector3) -> void:
	if range_objs == null or not range_objs.has_method("setup") or Args.has("norange"):
		return
	var prof := ExplosionProfile.new(b)
	var exclude := 0.0
	if water:
		exclude = float(b.get("profile", {}).get("pond_radius_m", 4000.0))
		exclude = maxf(exclude, Vector2(gz.x, gz.z).length() - 1000.0)
	range_objs.setup(gz, prof.w_kt, prof.hob, prof.surface, Game.humidity, {
		"nuclear": prof.nuclear, "conventional": prof.conventional,
		"fireball_r": prof.r_fb_max, "crater_r": prof.crater_r,
		"blast_scale": prof.blast_yield() / maxf(prof.w_kt, 1e-9),
		"exclude_r": exclude})


func _setup_water(b: Dictionary, gz: Vector3) -> void:
	if water:
		water.queue_free()
		water = null
	RenderingServer.global_shader_parameter_set("g_water", Vector4(0, 0, 0, -10000))
	if String(b.get("medium", "")) != "water":
		return
	water = WaterPond.new()
	add_child(water)
	var pr := float(b.get("profile", {}).get("pond_radius_m", 4000.0))
	# lagoon reaching to a beach ~1 km in front of the bunker so the water is actually in view
	var d := Vector2(gz.x, gz.z).length()
	pr = maxf(pr, d - 1000.0)
	(water as WaterPond).setup(gz, pr)


func detonate_now(bomb_idx: int, dist_km: float, az_deg: float) -> Explosion:
	clear_explosion()
	var b := Game.bomb(bomb_idx)
	var gz := target_position(dist_km, az_deg)
	target_gz = gz
	_setup_water(b, gz)
	terrain.set_patch(gz, _patch_extent(b))
	_setup_range_objects(b, gz)
	explosion = Explosion.new()
	explosion.name = "Explosion"
	explosion.observer = Vector3.ZERO
	add_child(explosion)
	explosion.setup(b, gz, env_ctl, bunker, cam)
	launcher.visible = false
	return explosion


func clear_explosion() -> void:
	if explosion:
		explosion.cleanup_globals()
		explosion.queue_free()
		explosion = null
	env_ctl.reset_adaptation()
	bunker.reset_state()
	if sound:
		sound.stop_all()


func after_age_set(_ex: Explosion, _dt: float) -> void:
	if range_objs and range_objs.has_method("set_age") and explosion:
		range_objs.set_age(explosion.age)


# ------------------------------------------------------------------ game flow

func _on_launch_requested(bomb_index: int, dist_km: float, az_deg: float) -> void:
	launch(bomb_index, dist_km, az_deg)


func launch(bomb_index: int, dist_km: float, az_deg: float) -> void:
	Game.selected_bomb = bomb_index
	Game.distance_km = dist_km
	Game.azimuth_deg = az_deg
	clear_explosion()
	_destroyed_shown = false
	var b := Game.bomb(bomb_index)
	if not Game.humidity_manual:
		# historical site conditions by default (Wilson clouds over the Pacific shots, dry Nevada)
		env_ctl.set_humidity(Game.site_humidity(b))
	var snow := 1.0 if (bool(b.get("snow", false)) and Game.snow_override != 0) or Game.snow_override == 1 else 0.0
	RenderingServer.global_shader_parameter_set("g_snow", snow)
	launcher.visible = true
	launcher.load_bomb(b)
	_place_range(bomb_index, dist_km, az_deg)
	burst_point = _burst_point(b, target_gz)
	var contact := float(b.get("burst_height_m", 0.0)) <= 3.0
	launcher.launch(target_gz, burst_point, dist_km, contact)
	_flight_bomb = bomb_index
	_whistling = false
	state = State.FLIGHT
	if sound:
		sound.rocket_start(launcher.current_position())
		sound.play_ui("launch")
		_prepare_blast_sound(bomb_index)
	if ui:
		ui.show_menu(false)
		if ui.has_method("show_destroyed"):
			ui.show_destroyed(false)
	_update_mouse()


func _on_detonated(_burst: Vector3) -> void:
	var b := Game.bomb(_flight_bomb)
	explosion = Explosion.new()
	explosion.name = "Explosion"
	explosion.observer = Vector3.ZERO
	add_child(explosion)
	explosion.setup(b, target_gz, env_ctl, bunker, cam)
	state = State.EXPLOSION
	if sound:
		sound.rocket_stop()
		sound.whistle_stop()
		if String(sound.get("_syn_key")) != _synth_key(_flight_bomb, Vector2(target_gz.x, target_gz.z).length()):
			# time of day or humidity changed during the flight: adapt the recording to the new
			# atmosphere now (cheap; a bomb without a recording starts its synthesis late)
			_prepare_blast_sound(_flight_bomb)
		sound.on_detonation({
			"yield_kt": explosion.prof.w_kt, "distance_m": explosion.obs_dist,
			"t_seismic": explosion.t_seismic_obs, "t_shock": explosion.t_shock_obs,
			"p_psi": explosion.p_obs, "nuclear": explosion.prof.nuclear,
			"kind": String(b.get("burst_type", "")), "megaton": explosion.prof.w_kt >= 1000.0,
			"synth_key": _synth_key(_flight_bomb, Vector2(target_gz.x, target_gz.z).length()),
		})


## The blast this bomb makes at this distance: its recording adapted to the distance, time of day,
## humidity and bearing (BlastSamples); a bomb without a recording is synthesized while the booster
## flies (BlastSynth).
func _prepare_blast_sound(bomb_index: int) -> void:
	var b := Game.bomb(bomb_index)
	var gd := Vector2(target_gz.x, target_gz.z).length()
	var tod_s := String(Game.TOD_NAMES[Game.tod])
	var sp := BlastParams.params_for(b, gd, Game.humidity, tod_s)
	sp["key"] = _synth_key(bomb_index, gd)
	sp["sample"] = BlastSamples.plan(b, gd, Game.humidity, tod_s, Game.azimuth_deg)
	sound.prepare_blast(sp)


func _synth_key(bomb_index: int, ground_m: float) -> String:
	# the atmosphere (time of day, humidity) changes the event too
	return "%d_%d_%d_%d" % [bomb_index, int(ground_m), Game.tod, int(Game.humidity * 100.0)]


func reset_scene() -> void:
	clear_explosion()
	state = State.MENU
	_destroyed_shown = false
	launcher.visible = true
	launcher.reset()
	launcher.load_bomb(Game.bomb())
	if sound:
		sound.rocket_stop()
		sound.whistle_stop()
	if ui:
		if ui.has_method("show_destroyed"):
			ui.show_destroyed(false)
		ui.show_menu(true)
	if cam.cine:
		cam.set_cine(false)
	_update_mouse()


func _on_setting_changed(key: String, value: Variant) -> void:
	match key:
		"tod":
			Game.tod = int(value)
			env_ctl.apply_tod(Game.tod)
			bunker.set_night(Game.tod == Game.TimeOfDay.NIGHT)
		"humidity":
			Game.humidity_manual = true
			env_ctl.set_humidity(float(value))
		"quality":
			Game.quality = int(value)
			Game.auto_quality = false
			_set_quality_scale(Game.quality_steps_scale())
		"lang":
			Game.set_language(String(value))
		"hud":
			Game.hud_visible = bool(value)
		"grain":
			Game.film_grain = bool(value)
		"clouds":
			Game.high_clouds = bool(value)


func _update_mouse() -> void:
	var menu_open: bool = ui != null and ui.is_menu_visible()
	if menu_open or state == State.DESTROYED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		cam.look_enabled = false
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		cam.look_enabled = true


func _unhandled_input(event: InputEvent) -> void:
	if Game.is_test_rig:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if ui and not ui.is_menu_visible():
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ESCAPE:
			get_tree().quit()
		KEY_TAB:
			if ui:
				ui.toggle_menu()
				_update_mouse()
		KEY_R:
			reset_scene()
		KEY_SPACE:
			Game.paused = not Game.paused
		KEY_BRACKETLEFT:
			Game.time_scale = maxf(0.05, Game.time_scale / 2.0)
		KEY_BRACKETRIGHT:
			Game.time_scale = minf(4.0, Game.time_scale * 2.0)
		KEY_C:
			cam.set_cine(not cam.cine)
			bunker.get_node("OuterShell").visible = cam.cine
		KEY_T:
			Game.tod = (Game.tod + 1) % 4
			env_ctl.apply_tod(Game.tod)
			bunker.set_night(Game.tod == Game.TimeOfDay.NIGHT)
			if ui and ui.has_method("show_toast"):
				ui.show_toast(Game.tr_key("tod." + Game.TOD_NAMES[Game.tod]))
		KEY_H:
			var h := fposmod(Game.humidity + 0.25, 1.25)
			Game.humidity_manual = true
			env_ctl.set_humidity(h)
			if ui and ui.has_method("show_toast"):
				ui.show_toast("%s %d%%" % [Game.tr_key("set.humidity"), int(h * 100.0)])
		KEY_F1:
			Game.hud_visible = not Game.hud_visible
			if ui:
				ui.set_hud_visible(Game.hud_visible)
		KEY_F12:
			_screenshot()
		KEY_1, KEY_2, KEY_3, KEY_4:
			if explosion:
				var idx: int = event.keycode - KEY_0
				cam.director_angle(idx, explosion.gz, explosion.prof.cloud_top, explosion.prof.cap_r)
				bunker.get_node("OuterShell").visible = true


func _screenshot() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var dir := OS.get_user_data_dir().path_join("screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
	_shot_counter += 1
	var p := dir.path_join("shot_%s_%03d.png" % [Time.get_datetime_string_from_system().replace(":", "-"), _shot_counter])
	img.save_png(p)
	if ui and ui.has_method("show_toast"):
		ui.show_toast(p)


# ------------------------------------------------------------------ per-frame

func _exit_tree() -> void:
	FxResources.release()
	for path in ["res://scripts/ui/ui_theme.gd", "res://scripts/bombs/bomb_models.gd"]:
		if ResourceLoader.exists(path):
			var sc: Script = load(path)
			if sc and sc.has_method("release"):
				sc.call("release")


func _process(delta: float) -> void:
	if Game.is_test_rig:
		return
	# (in Movie Maker mode --fixed-fps already makes delta exactly 1 / fps; assuming 60 fps here made
	# game time run at half speed against the recorded audio in a 30 fps render)
	var dt := 0.0 if Game.paused else delta * Game.time_scale
	launcher.advance(dt)
	if state == State.FLIGHT and sound:
		sound.rocket_update(launcher.current_position())
		# falling-bomb whistle over the last seconds (air-dropped / parachute phase)
		if not _whistling and launcher.time_to_detonation() < 4.0 and not launcher.chute_on:
			_whistling = true
			sound.whistle_start()
	if explosion:
		explosion.advance(dt)
		explosion.step_exposure(explosion.age, dt)
		after_age_set(explosion, dt)
		if sound:
			sound.update_age(explosion.age, 0.0 if Game.paused else Game.time_scale)
		if explosion.shock_done and explosion.p_obs >= 25.0 and not _destroyed_shown:
			_destroyed_shown = true
			state = State.DESTROYED
			if ui and ui.has_method("show_destroyed"):
				ui.show_destroyed(true)
			_update_mouse()
	_update_hud()
	_auto_quality(delta)
	if _whiteout:
		_whiteout.color.a = clampf(env_ctl.white_out * 0.9, 0.0, 0.95)


func _update_hud() -> void:
	if ui == null:
		return
	var info := {"phase": "idle", "time_scale": Game.time_scale, "paused": Game.paused, "cine": cam.cine,
		"bomb_index": Game.selected_bomb, "dist_km": Game.distance_km}
	if state == State.FLIGHT:
		info["phase"] = "flight"
		info["t_plus"] = -launcher.time_to_detonation()
		info["stage"] = ""
	elif explosion:
		info["phase"] = "explosion"
		var a := explosion.age
		info["t_plus"] = a
		info["stage"] = explosion.stage
		info["eta_light"] = explosion.obs_dist / 299792458.0 - a
		info["eta_heat"] = explosion.prof.t2 - a if explosion.prof.nuclear else -1.0
		info["eta_blast"] = explosion.t_shock_obs - a
		info["eta_sound"] = explosion.t_sound_obs - a
		info["p_psi"] = explosion.p_obs
	ui.update_hud(info)


func _auto_quality(delta: float) -> void:
	if not Game.auto_quality or Game.is_movie:
		return
	_fps_acc += delta
	_fps_frames += 1
	_quality_cooldown -= delta
	if _fps_acc < 1.0:
		return
	var fps := _fps_frames / _fps_acc
	_fps_acc = 0.0
	_fps_frames = 0
	if _quality_cooldown > 0.0:
		return
	var q := _q_live
	if fps < 50.0 and q > 0.4:
		q = maxf(0.4, q * 0.8)
		_quality_cooldown = 2.0
	elif fps > 85.0 and q < Game.quality_steps_scale():
		q = minf(Game.quality_steps_scale(), q * 1.15)
		_quality_cooldown = 3.0
	_set_quality_scale(q)


func _set_quality_scale(q: float) -> void:
	_q_live = q
	RenderingServer.global_shader_parameter_set("g_quality", q)


# ------------------------------------------------------------------ movie / cinematic

func _movie_autopilot() -> void:
	# run_cinematic.bat: --write-movie ... -- --bomb N [--dist KM] [--tod T] [--view V]
	Game.quality = Game.Quality.CINEMATIC
	Game.auto_quality = false
	_set_quality_scale(Game.quality_steps_scale())
	var n := Args.get_int("bomb", 20) - 1
	var b := Game.bomb(n)
	var d := Args.get_float("dist", float(b.get("rec_km", 20.0)))
	var tod_i := Game.TOD_NAMES.find(Args.get_str("tod", Game.TOD_NAMES[Game.tod]))
	if tod_i >= 0:
		Game.tod = tod_i
		env_ctl.apply_tod(tod_i)
		bunker.set_night(tod_i == Game.TimeOfDay.NIGHT)
	if ui:
		ui.show_menu(false)
		ui.set_hud_visible(Args.has("hud"))
	var to := target_position(d, 0.0)
	cam.set_look(atan2(-to.x, -to.z), deg_to_rad(Args.get_float("pitch", 5.0)))
	print("READY")
	await get_tree().create_timer(1.0).timeout
	launch(n, d, Args.get_float("az", 0.0))
	if Args.has("live_shots"):
		_live_capture()


## Real-time capture during an actual launch (QA): --autolaunch --live_shots 2,10,20 --out DIR
func _live_capture() -> void:
	var out := Args.get_str("out", OS.get_user_data_dir().path_join("live"))
	DirAccess.make_dir_recursive_absolute(out)
	var t0 := Time.get_ticks_msec()
	var fps_log: Array = []
	for ts in Args.get_float_list("live_shots"):
		while (Time.get_ticks_msec() - t0) / 1000.0 < ts:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var p := out.path_join("live_b%02d_t%05.1f.png" % [Game.selected_bomb + 1, ts])
		print("SHOT ", p, " err=", img.save_png(p), " fps=", Engine.get_frames_per_second(), " state=", state, " age=", explosion.age if explosion else -1.0)
	print("LIVE_DONE")
	get_tree().quit()


func _run_world_test() -> void:
	var out := Args.get_str("out", OS.get_user_data_dir().path_join("shots"))
	DirAccess.make_dir_recursive_absolute(out)
	var tods := ["dawn", "noon", "dusk", "night"]
	for i in tods.size():
		Game.tod = i
		env_ctl.apply_tod(i)
		bunker.set_night(i == 3)
		for f in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var p := out.path_join("world_%s.png" % tods[i])
		print("SHOT ", p, " err=", img.save_png(p))
	print("READY")
	get_tree().quit()
