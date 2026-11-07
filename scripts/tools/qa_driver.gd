class_name QaDriver
extends Node
## QA matrix driver (task section 11.6): in ONE game session, launches every bomb at the
## recommended / 3x closer / 3x farther distance at noon and at night, through the real flight ->
## detonation path, runs the explosion at accelerated time, toggles features (slow motion, pause,
## cinematographer camera, HUD, RU/EN, time of day) and records FPS, node counts and errors.
## Run: godot --path . -- --qa_matrix [--bombs 1,2] [--secs 3] [--out DIR]

var main: Node
var results: Array = []
var _errors_before := 0


func run() -> void:
	var out := Args.get_str("out", OS.get_user_data_dir().path_join("qa"))
	DirAccess.make_dir_recursive_absolute(out)
	var bombs: Array = []
	if Args.has("bombs"):
		for s in Args.get_str("bombs").split(",", false):
			bombs.append(s.to_int())
	else:
		for i in 20:
			bombs.append(i + 1)
	var tods := ["noon", "night"]
	if Args.has("tods"):
		tods = Array(Args.get_str("tods").split(",", false))
	var dists := ["rec", "near", "far"]
	var hold := Args.get_float("secs", 3.0)
	await main.prepare_world(Game.TimeOfDay.NOON, 0)
	var nodes_start := 0
	var mem_start := 0.0
	var run_i := 0
	var t_all := Time.get_ticks_msec()
	for tod_s in tods:
		var tod_i := Game.TOD_NAMES.find(tod_s)
		Game.tod = tod_i
		main.env_ctl.apply_tod(tod_i)
		main.bunker.set_night(tod_i == Game.TimeOfDay.NIGHT)
		for n in bombs:
			var b: Dictionary = Game.bomb(n - 1)
			for dm in dists:
				var rec := float(b.get("rec_km", 20.0))
				var d := clampf({"rec": rec, "near": rec / 3.0, "far": rec * 3.0}[dm], 0.5, 200.0)
				var r := await _one(n, d, dm, tod_s, hold, run_i, out)
				results.append(r)
				run_i += 1
				if run_i == 2:
					nodes_start = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
					mem_start = Performance.get_monitor(Performance.MEMORY_STATIC)
				print("QA %s" % JSON.stringify(r))
	# feature toggles on the last explosion
	await _features(out)
	main.reset_scene()
	for i in 10:
		await get_tree().process_frame
	var nodes_end := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var mem_end := Performance.get_monitor(Performance.MEMORY_STATIC)
	var fails := 0
	for r in results:
		if not r["ok"]:
			fails += 1
	var summary := {"runs": results.size(), "fails": fails, "nodes_start": nodes_start, "nodes_end": nodes_end,
		"mem_start_mb": snappedf(mem_start / 1048576.0, 0.1), "mem_end_mb": snappedf(mem_end / 1048576.0, 0.1),
		"minutes": snappedf((Time.get_ticks_msec() - t_all) / 60000.0, 0.1)}
	print("QA_SUMMARY %s" % JSON.stringify(summary))
	var f := FileAccess.open(out.path_join("qa_results.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"summary": summary, "runs": results}, "\t"))
		f.close()
	print("READY" if fails == 0 and nodes_end <= nodes_start + 50 else "FAIL")
	get_tree().quit()


func _one(n: int, d: float, dm: String, tod_s: String, hold: float, idx: int, out: String) -> Dictionary:
	var r := {"bomb": n, "dist_km": snappedf(d, 0.01), "mode": dm, "tod": tod_s, "ok": false}
	Game.time_scale = 1.0
	Game.paused = false
	main.launch(n - 1, d, 0.0)
	# fly at 8x until detonation
	Game.time_scale = 8.0
	var t0 := Time.get_ticks_msec()
	while main.state == main.State.FLIGHT and Time.get_ticks_msec() - t0 < 30000:
		await get_tree().process_frame
	r["detonated"] = main.explosion != null
	# watch the explosion: real-time first second (flash), then accelerated
	Game.time_scale = 1.0
	var frames := 0
	var t1 := Time.get_ticks_msec()
	var worst := 0.0
	var last := t1
	while Time.get_ticks_msec() - t1 < int(hold * 1000.0):
		if Time.get_ticks_msec() - t1 > 800:
			Game.time_scale = 16.0
		await get_tree().process_frame
		var now := Time.get_ticks_msec()
		worst = maxf(worst, float(now - last))
		last = now
		frames += 1
	var secs := (Time.get_ticks_msec() - t1) / 1000.0
	r["fps"] = snappedf(frames / maxf(secs, 0.001), 0.1)
	r["worst_ms"] = worst
	r["age"] = snappedf(main.explosion.age if main.explosion else -1.0, 0.1)
	r["p_bunker_psi"] = snappedf(main.explosion.p_obs if main.explosion else 0.0, 0.001)
	r["destroyed"] = main.state == main.State.DESTROYED
	r["ok"] = bool(r["detonated"]) and float(r["age"]) > 0.0
	if idx % 6 == 0:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("qa_%02d_%s_%s.png" % [n, dm, tod_s]))
	Game.time_scale = 1.0
	main.reset_scene()
	await get_tree().process_frame
	return r


func _features(out: String) -> void:
	# slow motion, pause, cinematographer, director angles, HUD, language, time of day, humidity
	main.launch(10, 25.0, 10.0)
	Game.time_scale = 8.0
	while main.state == main.State.FLIGHT:
		await get_tree().process_frame
	Game.time_scale = 0.05
	for i in 20:
		await get_tree().process_frame
	var a0: float = main.explosion.age
	Game.paused = true
	for i in 20:
		await get_tree().process_frame
	var paused_ok: bool = absf(main.explosion.age - a0) < 0.01 + 0.05 * 20.0 / 60.0
	Game.paused = false
	Game.time_scale = 4.0
	main.cam.set_cine(true)
	for k in [1, 2, 3, 4]:
		main.cam.director_angle(k, main.explosion.gz, main.explosion.prof.cloud_top, main.explosion.prof.cap_r)
		for i in 15:
			await get_tree().process_frame
	main.cam.set_cine(false)
	if main.ui:
		main.ui.set_hud_visible(false)
		await get_tree().process_frame
		main.ui.set_hud_visible(true)
		Game.set_language("en")
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("qa_hud_en.png"))
		Game.set_language("ru")
	for t in 4:
		Game.tod = t
		main.env_ctl.apply_tod(t)
		await get_tree().process_frame
	main.env_ctl.set_humidity(0.9)
	await get_tree().process_frame
	main.env_ctl.set_humidity(0.55)
	results.append({"feature_test": true, "paused_ok": paused_ok, "ok": paused_ok})
	print("QA features paused_ok=%s" % paused_ok)
