class_name ShotRig
extends Node
## Deterministic screenshot rig.
## Args (after --): --bomb N (1..20) --dist KM --tod dawn|noon|dusk|night --humidity 0..1
##   --quality low|medium|high|cine --shots t1,t2,... --out DIR [--view bunker|cine|side|low|orbit|zoom]
##   [--fov DEG] [--sheet name] [--quit]
## Saves <out>/<prefix>_t<age>.png and an optional contact sheet.

var main: Node


func run() -> void:
	var out := Args.get_str("out", OS.get_user_data_dir().path_join("shots"))
	DirAccess.make_dir_recursive_absolute(out)
	var bomb_n := Args.get_int("bomb", 11)
	var dist := Args.get_float("dist", -1.0)
	var bd: Dictionary = Game.bomb(bomb_n - 1)
	if dist <= 0.0:
		dist = float(bd.get("rec_km", 20.0))
	var tod_s := Args.get_str("tod", "noon")
	var tod_i := Game.TOD_NAMES.find(tod_s)
	if tod_i < 0:
		tod_i = 1
	var q := Game.QUALITY_NAMES.find(Args.get_str("quality", "high"))
	Game.quality = q if q >= 0 else Game.Quality.HIGH
	Game.auto_quality = false
	Game.humidity = Args.get_float("humidity", Game.site_humidity(bd))
	var view := Args.get_str("view", "bunker")
	var prefix := Args.get_str("prefix", "b%02d_%s_%skm_%s_%s" % [bomb_n, bd.get("id", "x"), _fmt(dist), tod_s, view])
	var shots := Args.get_float_list("shots")
	if shots.is_empty():
		shots = PackedFloat64Array([0.002, 0.02, 0.1, 0.5, 1, 2, 5, 10, 20, 40, 90, 180, 360])
	print("RIG bomb=%d dist=%.2f tod=%s view=%s shots=%s" % [bomb_n, dist, tod_s, view, str(shots)])
	await main.prepare_world(tod_i, bomb_n - 1)
	var ex: Explosion = main.detonate_now(bomb_n - 1, dist, Args.get_float("az", 0.0))
	_setup_view(view, ex)
	# warm-up frames
	for i in 8:
		await get_tree().process_frame
	var files: Array[String] = []
	var prev := 0.0
	for t in shots:
		ex.step_exposure(t, t - prev)
		ex.set_age(t, t - prev)
		main.after_age_set(ex, t - prev)
		prev = t
		_setup_view_dynamic(view, ex)
		if main._whiteout:
			main._whiteout.color.a = clampf(main.env_ctl.white_out * 0.9, 0.0, 0.95)
		for i in 3:
			await get_tree().process_frame
		if Args.has("fps_hold"):
			# real-time cost at this age: render N frames and time them (vsync is off)
			var n := Args.get_int("fps_hold", 120)
			var t0 := Time.get_ticks_usec()
			var worst := 0.0
			var last := t0
			for i in n:
				await RenderingServer.frame_post_draw
				var now := Time.get_ticks_usec()
				worst = maxf(worst, (now - last) / 1000.0)
				last = now
			var avg_ms := (Time.get_ticks_usec() - t0) / 1000.0 / n
			print("FPS bomb=%d age=%s avg_fps=%.1f avg_ms=%.2f worst_ms=%.2f" % [bomb_n, _fmt(t), 1000.0 / avg_ms, avg_ms, worst])
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := out.path_join("%s_t%s.png" % [prefix, _fmt(t)])
		var err := img.save_png(path)
		files.append(path)
		if Args.has("dbgstate"):
			print("MAT fb=", ex.vol_mat.get_shader_parameter("fb"), " fb_look=", ex.vol_mat.get_shader_parameter("fb_look"), " head=", ex.vol_mat.get_shader_parameter("head"), " head_heat=", ex.vol_mat.get_shader_parameter("head_heat"), " stem=", ex.vol_mat.get_shader_parameter("stem"), " skirt=", ex.vol_mat.get_shader_parameter("skirt"))
			print("STATE t=", t, " fb=", ex.prof.fireball_state(t), " head=", ex.prof.head_state(t))
		print("SHOT ", path, " err=", err, " exp=%.5f adapt=%.2f maxc=%.1f flash=%.1f" % [main.env_ctl.current_exposure(), main.env_ctl.adapt_log, main.env_ctl.max_comp, main.env_ctl.flash_lum])
	if Args.has("sheet"):
		_contact_sheet(files, shots, out.path_join("%s_sheet.png" % prefix))
	print("READY")
	if Args.has("quit") or true:
		get_tree().quit()


func _fmt(v: float) -> String:
	var s := "%.3f" % v
	while s.ends_with("0"):
		s = s.substr(0, s.length() - 1)
	if s.ends_with("."):
		s = s.substr(0, s.length() - 1)
	return s


func _setup_view(view: String, ex: Explosion) -> void:
	var cam: PlayerCamera = main.cam
	var to := ex.gz
	var hs := ex.prof
	cam.set_cine(view != "bunker" and view != "zoom")
	cam.force_embrasure = view == "zoom"
	match view:
		"bunker", "zoom":
			var d := Vector2(to.x, to.z)
			var yaw := atan2(-to.x, -to.z)
			cam.set_look(yaw, deg_to_rad(Args.get_float("pitch", 6.0)))
		"side":
			cam.director_angle(2, ex.gz, hs.cloud_top, hs.cap_r)
		"low":
			cam.director_angle(3, ex.gz, hs.cloud_top, hs.cap_r)
		"orbit":
			cam.director_angle(4, ex.gz, hs.cloud_top, hs.cap_r)
		"cine":
			cam.director_angle(1, ex.gz, hs.cloud_top, hs.cap_r)
		"near":
			# camera between the bunker and ground zero at --near metres from it, --cam_h above ground
			var fwd := Vector3(ex.gz.x, 0, ex.gz.z).normalized()
			var nd := Args.get_float("near", 1000.0)
			var p := ex.gz - fwd * nd
			p.y = TerrainMath.height(p.x, p.z) + Args.get_float("cam_h", 20.0)
			cam.position = p
			var aim := ex.gz + Vector3(0, Args.get_float("look_h", 50.0), 0)
			var d := (aim - p).normalized()
			cam.set_look(atan2(-d.x, -d.z), asin(clampf(d.y, -1.0, 1.0)))
	var fov := Args.get_float("fov", -1.0)
	if fov > 0.0:
		cam.fov = fov
		cam.target_fov = fov
	else:
		cam.fov = cam.target_fov


func _setup_view_dynamic(view: String, ex: Explosion) -> void:
	if view == "zoom":
		# frame the current cloud: fov so that cloud height fills ~70% of the view
		var cam: PlayerCamera = main.cam
		var hs := ex.prof.head_state(ex.age)
		var fs := ex.prof.fireball_state(ex.age)
		var top := maxf(float(hs["center_y"]) + float(hs["half"]), float(fs["center_y"]) + float(fs["radius"]))
		var w := maxf(float(hs["radius"]), float(fs["radius"])) * 2.0
		var d := ex.obs_ground_dist
		var size := maxf(top, w * 0.6) * 1.35
		var vfov := 2.0 * atan(size * 0.5 / maxf(d, 1.0))
		var ang := rad_to_deg(2.0 * atan(tan(vfov * 0.5) * 16.0 / 9.0))
		cam.fov = clampf(ang, 3.0, 58.0)
		cam.target_fov = cam.fov
		var aim := ex.gz + Vector3(0, top * 0.45, 0)
		if ang > 58.0:
			aim = ex.gz + Vector3(0, top * 0.55, 0)
		var dir := aim.normalized()
		cam.set_look(atan2(-dir.x, -dir.z), asin(clampf(dir.y, -1.0, 1.0)))


func _contact_sheet(files: Array[String], shots: PackedFloat64Array, path: String) -> void:
	var cols := 4
	var rows := int(ceil(files.size() / float(cols)))
	var tw := 480
	var th := 270
	var sheet := Image.create_empty(tw * cols, th * rows, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.05, 0.05, 0.05))
	for i in files.size():
		var img := Image.load_from_file(files[i])
		if img == null:
			continue
		img.convert(Image.FORMAT_RGB8)
		img.resize(tw, th, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(img, Rect2i(0, 0, tw, th), Vector2i((i % cols) * tw, (i / cols) * th))
	var err := sheet.save_png(path)
	print("SHEET ", path, " err=", err)
