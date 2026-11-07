extends SceneTree
## UI module test: builds the terminal menu / HUD / overlays over a plain 3D backdrop,
## exercises the API and, when windowed, saves screenshots.
## Headless logic run:
##   godot --headless --path P -s res://tools/test_ui.gd
## Windowed screenshots:
##   godot --path P --resolution 1600x900 -s res://tools/test_ui.gd -- --out C:/abs/dir

const MODELS_PATH := "res://scripts/bombs/bomb_models.gd"
const DEFAULT_OUT := "user://test_ui"

var ui      # ui_root.gd instance (scripts are load()-ed at runtime so autoload names resolve)
var UiRoot: GDScript
var TerminalMenu: GDScript
var G      # the "Game" autoload node
var out_dir := DEFAULT_OUT
var fails := 0
var shots := true
var launches: Array = []
var settings: Array = []
var resets := 0
var quits := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		print("CHECK ok   ", what)
	else:
		fails += 1
		printerr("CHECK FAIL ", what)


func wait_sec(t: float) -> void:
	await create_timer(t, true).timeout


func wait_frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(file: String) -> void:
	if not shots:
		return
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var p := out_dir.path_join(file)
	var err := img.save_png(p)
	print("SHOT ", p, " ", img.get_width(), "x", img.get_height(), " err=", err)


func _backdrop() -> void:
	var w := Node3D.new()
	w.name = "Backdrop"
	root.add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.25, 0.42, 0.7)
	sm.sky_horizon_color = Color(0.78, 0.72, 0.62)
	sm.ground_bottom_color = Color(0.4, 0.33, 0.24)
	sm.ground_horizon_color = Color(0.75, 0.66, 0.52)
	sky.sky_material = sm
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, -40, 0)
	w.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40000, 40000)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.72, 0.6, 0.45)
	ground.material_override = gm
	ground.position = Vector3(0, -22, 0)
	w.add_child(ground)
	var cam := Camera3D.new()
	cam.fov = 80
	cam.far = 50000
	cam.current = true
	w.add_child(cam)


func _fake_info(phase: String, t: float, stage: String, paused: bool, ts: float, bomb: int, dist: float, p: float) -> Dictionary:
	var c := 299792.458
	return {
		"phase": phase, "t_plus": t, "dist_km": dist, "stage": stage,
		"eta_light": dist / c - t if phase == "explosion" else -t,
		"eta_heat": 0.4 - t if phase == "explosion" else 0.4 - t,
		"eta_blast": 61.3 - t, "eta_sound": 61.3 - t,
		"p_psi": p, "time_scale": ts, "paused": paused, "bomb_index": bomb, "cine": false,
	}


func _preview_sheet() -> void:
	# grab the preview SubViewport for every bomb and compose a contact sheet
	var menu = ui.menu
	var cw := 480
	var ch := 300
	var cols := 4
	var n: int = menu.bombs.size()
	var rows := int(ceil(float(n) / cols))
	var sheet := Image.create_empty(cw * cols, ch * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.02, 0.06, 0.035, 1.0))
	for i in n:
		menu.select_bomb(i)
		await wait_sec(0.12)
		await RenderingServer.frame_post_draw
		var img: Image = menu._sv.get_texture().get_image()
		if img == null or img.is_empty():
			continue
		img.convert(Image.FORMAT_RGBA8)
		img.resize(cw, int(float(cw) * img.get_height() / img.get_width()), Image.INTERPOLATE_BILINEAR)
		var cell := Image.create_empty(cw, ch, false, Image.FORMAT_RGBA8)
		cell.fill(Color(0.02, 0.06, 0.035, 1.0))
		var src_y := maxi(0, (img.get_height() - ch) / 2)
		cell.blend_rect(img, Rect2i(0, src_y, cw, mini(ch, img.get_height())), Vector2i(0, maxi(0, (ch - img.get_height()) / 2)))
		sheet.blit_rect(cell, Rect2i(0, 0, cw, ch), Vector2i((i % cols) * cw, (i / cols) * ch))
	var p := out_dir.path_join("preview_sheet.png")
	print("SHOT ", p, " err=", sheet.save_png(p))


## Timing of the menu's physics estimates (headless is fine).
func _bench() -> void:
	var TM: GDScript = load("res://scripts/ui/terminal_menu.gd")
	var worst_e := 0.0
	var worst_d := 0.0
	for i in G.bombs.size():
		var b: Dictionary = G.bombs[i]
		var t0 := Time.get_ticks_usec()
		for d in [0.5, 2.0, 10.0, 50.0, 200.0]:
			TM.estimate(b, d, 0.0, 0.5)
		var te := float(Time.get_ticks_usec() - t0) / 5000.0
		t0 = Time.get_ticks_usec()
		TM.danger_range(b, 0.0, 0.5, 10.0, true)
		TM.danger_range(b, 0.0, 0.5, 25.0, false)
		var td := float(Time.get_ticks_usec() - t0) / 1000.0
		worst_e = maxf(worst_e, te)
		worst_d = maxf(worst_d, td)
		print("BENCH #%d %s estimate %.2f ms/call, danger ranges %.1f ms" % [i + 1, String(b.get("burst_type", "")), te, td])
	print("BENCH worst estimate %.2f ms, worst danger %.1f ms" % [worst_e, worst_d])


## Only the RU + EN menu screenshots (used for checking other resolutions / aspect ratios).
func _menu_only() -> void:
	UiRoot = load("res://scripts/ui/ui_root.gd")
	_backdrop()
	ui = UiRoot.new()
	ui.manage_mouse = false
	root.add_child(ui)
	ui.setup(G.bombs)
	var tag := "%dx%d" % [root.get_visible_rect().size.x, root.get_visible_rect().size.y]
	print("MENU ONLY window=", DisplayServer.window_get_size(), " canvas=", tag)
	ui.menu.select_bomb(13)
	ui.menu.set_distance(8.0)
	await wait_sec(1.0)
	await shot("res_%s_ru.png" % tag)
	G.set_language("en")
	ui.menu.select_bomb(6)
	await wait_sec(1.0)
	await shot("res_%s_en.png" % tag)
	G.set_language("ru")
	print("READY")
	quit()


func _run() -> void:
	await process_frame
	G = root.get_node_or_null("Game")
	if G == null:
		printerr("CHECK FAIL Game autoload missing")
		quit(1)
		return
	shots = DisplayServer.get_name() != "headless"
	var a := OS.get_cmdline_user_args()
	for i in a.size():
		if a[i] == "--out" and i + 1 < a.size():
			out_dir = a[i + 1]
	if shots:
		DirAccess.make_dir_recursive_absolute(out_dir)
	if a.has("--menu-only"):
		await _menu_only()
		return
	if a.has("--bench"):
		_bench()
		print("READY")
		quit()
		return
	print("UI TEST display=", DisplayServer.get_name(), " bombs=", G.bombs.size(), " out=", out_dir)
	G.set_language("ru")

	UiRoot = load("res://scripts/ui/ui_root.gd")
	TerminalMenu = load("res://scripts/ui/terminal_menu.gd")
	_backdrop()
	ui = UiRoot.new()
	ui.manage_mouse = false
	root.add_child(ui)
	ui.launch_requested.connect(func(i: int, d: float, az: float) -> void: launches.append([i, d, az]))
	ui.setting_changed.connect(func(k: String, v: Variant) -> void: settings.append([k, v]))
	ui.reset_requested.connect(func() -> void: resets += 1)
	ui.quit_requested.connect(func() -> void: quits += 1)
	ui.setup(G.bombs)
	await wait_frames(3)
	var menu = ui.menu

	# ---- pure helpers
	check(is_equal_approx(TerminalMenu.slider_to_km(0.0), 0.5), "slider 0 -> 0.5 km")
	check(is_equal_approx(TerminalMenu.slider_to_km(1.0), 200.0), "slider 1 -> 200 km")
	check(absf(TerminalMenu.km_to_slider(TerminalMenu.slider_to_km(0.37)) - 0.37) < 1e-6, "slider roundtrip")
	check(is_equal_approx(TerminalMenu.flight_time(0.5), 6.0) and is_equal_approx(TerminalMenu.flight_time(200.0), 25.0), "flight time 6..25 s")
	check(ui.is_menu_visible(), "menu visible at start")
	check(menu._rows.size() == G.bombs.size(), "list has %d rows" % menu._rows.size())

	# ---- every bomb: estimates finite, select works
	for i in G.bombs.size():
		var b: Dictionary = G.bombs[i]
		var e: Dictionary = TerminalMenu.estimate(b, float(b.get("rec_km", 25.0)), 0.0, 0.55)
		var ok := true
		for k in ["p", "q", "r_glass", "r_house", "r_concrete", "r_burn", "t_shock", "flight"]:
			var v := float(e[k])
			if is_nan(v) or is_inf(v):
				ok = false
		check(ok, "estimate finite #%d %s: rec %.1f km p=%.3f psi q=%.3f glass=%.0f m house=%.0f m burn=%.0f m concrete=%.0f m t=%.1f s" % [
			i + 1, G.bomb_text(b, "name"), float(b.get("rec_km", 0.0)), e["p"], e["q"], e["r_glass"], e["r_house"], e["r_burn"], e["r_concrete"], e["t_shock"]])
		var dz: float = TerminalMenu.danger_range(b, 0.0, 0.55, 10.0, true)
		print("  danger range (10 psi / 10 cal): %.2f km, rec %.1f km%s" % [dz, float(b.get("rec_km", 0.0)), "  <-- REC INSIDE DANGER" if dz > float(b.get("rec_km", 0.0)) else ""])
	for i in [0, 8, 16, 19]:
		menu.select_bomb(i)
		check(menu.sel == i and G.selected_bomb == i, "select bomb %d" % i)
	menu.select_bomb(16)
	check(menu._device_l.visible == bool(G.bombs[16].get("device", false)), "device note follows b.device (#17)")
	menu.select_bomb(0)
	check(not menu._device_l.visible, "no device note on #1")

	# ---- sliders
	menu.select_bomb(10)
	menu._dist_slider.value = 0.25
	check(absf(menu.dist_km - 0.5 * pow(400.0, 0.25)) < 1e-3 and absf(G.distance_km - menu.dist_km) < 1e-6, "distance slider log mapping -> %.3f km" % menu.dist_km)
	check(menu._dist_val.text.contains("2,24"), "distance label '%s'" % menu._dist_val.text)
	menu._rec_btn.pressed.emit()
	check(is_equal_approx(menu.dist_km, float(G.bombs[10]["rec_km"])), "recommended distance button -> %.1f km" % menu.dist_km)
	menu._az_slider.value = 12.0
	check(is_equal_approx(menu.az_deg, 12.0) and is_equal_approx(G.azimuth_deg, 12.0), "azimuth slider")
	menu._az_slider.value = 0.0

	# ---- safe launch
	launches.clear()
	check(not menu.is_dangerous(), "Trinity at rec range not dangerous")
	menu._launch_btn.pressed.emit()
	check(launches.size() == 1 and int(launches[0][0]) == 10, "launch_requested emitted %s" % str(launches))
	check(not ui.is_menu_visible(), "menu hidden after launch")
	ui.show_menu(true)
	check(ui.is_menu_visible(), "show_menu(true)")

	# ---- dangerous launch -> confirmation
	launches.clear()
	menu.select_bomb(19)
	menu.set_distance(5.0)
	check(menu.is_dangerous(), "Tsar at 5 km dangerous (p=%.1f psi)" % float(menu.est["p"]))
	check(menu._warn_l.visible, "red warning visible")
	menu._launch_btn.pressed.emit()
	check(menu.is_confirm_open() and launches.is_empty(), "confirmation shown, no launch yet")
	await wait_sec(0.6)
	await shot("confirm_ru.png")
	menu.close_confirm()
	check(not menu.is_confirm_open(), "cancel closes confirmation")
	await wait_sec(0.4)
	await shot("menu_ru_tsar_danger.png")
	menu._launch_btn.pressed.emit()
	menu.confirm_launch()
	check(launches.size() == 1 and int(launches[0][0]) == 19, "launch anyway emits")
	ui.show_menu(true)

	# ---- settings
	settings.clear()
	menu._tod_btns[3].pressed.emit()
	check(G.tod == 3 and settings.size() == 1 and settings[0][0] == "tod" and int(settings[0][1]) == 3, "tod setting %s" % str(settings))
	menu._hum_slider.value = 0.8
	check(is_equal_approx(G.humidity, 0.8), "humidity setting")
	menu._quality_opt.item_selected.emit(3)
	check(G.quality == 3, "quality setting")
	menu._grain_cb.button_pressed = not G.film_grain
	menu._clouds_cb.button_pressed = not G.high_clouds
	var keys: Array = []
	for s in settings:
		keys.append(s[0])
	check(keys.has("humidity") and keys.has("quality") and keys.has("grain") and keys.has("clouds"), "setting keys %s" % str(keys))
	menu._hud_cb.button_pressed = false
	check(not ui.hud.visible and not G.hud_visible, "HUD checkbox hides HUD")
	menu._hud_cb.button_pressed = true
	check(ui.hud.visible, "HUD checkbox shows HUD")
	# external change (T/H key) is pulled into the controls
	G.tod = 0
	G.humidity = 0.3
	menu.sync_from_game()
	check(menu._tod_btns[0].button_pressed and not menu._tod_btns[3].button_pressed and is_equal_approx(menu._hum_slider.value, 0.3), "sync_from_game")
	G.tod = 1
	G.humidity = 0.55
	G.quality = 2
	menu.sync_from_game()

	# ---- language
	menu.select_bomb(10)
	menu._rec_btn.pressed.emit()
	await wait_sec(0.9)
	await shot("menu_ru.png")
	menu.select_bomb(5)    # longest blurb
	await wait_sec(0.9)
	await shot("menu_ru_longest_blurb.png")
	menu.select_bomb(10)
	menu._lang_btns[1].pressed.emit()
	check(G.lang == "en" and menu._launch_btn.text == "LAUNCH", "RU->EN: launch '%s'" % menu._launch_btn.text)
	check(menu._name_l.text == G.bomb_text(G.bombs[10], "name"), "dossier name re-localized")
	menu.select_bomb(16)
	await wait_sec(0.9)
	await shot("menu_en_mike.png")
	menu.select_bomb(0)
	await wait_sec(0.9)
	await shot("menu_en_mk82.png")
	menu._lang_btns[0].pressed.emit()
	check(G.lang == "ru" and menu._launch_btn.text == "ПУСК", "EN->RU: launch '%s'" % menu._launch_btn.text)

	# ---- Tab key toggles the menu (handled in _input)
	var ev := InputEventKey.new()
	ev.keycode = KEY_TAB
	ev.physical_keycode = KEY_TAB
	ev.pressed = true
	root.push_input(ev)
	check(not ui.is_menu_visible(), "Tab hides menu")
	var ev2 := ev.duplicate() as InputEventKey
	root.push_input(ev2)
	check(ui.is_menu_visible(), "Tab shows menu")
	ui.show_menu(false)

	# ---- HUD
	ui.update_hud(_fake_info("flight", -9.4, "", false, 1.0, 10, 25.0, 0.0))
	check(ui.hud._panel.visible and ui.hud._t_cap.text == "T−", "HUD flight countdown")
	await wait_sec(0.4)
	await shot("hud_flight_ru.png")
	ui.update_hud(_fake_info("explosion", 12.4, "breakaway", false, 0.25, 10, 25.0, 0.42))
	ui.show_toast(G.tr_key("toast.time_scale").format({"v": "0,25"}))
	check(ui.hud._vals["light"].text.contains(G.tr_key("hud.arr_light")), "HUD light arrived '%s'" % ui.hud._vals["light"].text)
	check(ui.hud._vals["blast"].text.contains("48,9"), "HUD blast countdown '%s'" % ui.hud._vals["blast"].text)
	await wait_sec(0.4)
	await shot("hud_explosion_ru.png")
	G.set_language("en")
	ui.update_hud(_fake_info("explosion", 75.0, "rise", true, 1.0, 19, 150.0, 12.5))
	ui.flash_white(0.35)
	await wait_sec(0.4)
	await shot("hud_paused_en_glare.png")
	ui.flash_white(0.0)
	ui.update_hud(_fake_info("explosion", 75.0, "rise", false, 1.0, 19, 150.0, 12.5))
	var cine := _fake_info("explosion", 75.0, "rise", false, 1.0, 19, 150.0, 12.5)
	cine["cine"] = true
	ui.update_hud(cine)
	check(not ui.hud._panel.visible, "HUD hidden in cinematographer mode")
	ui.set_hud_visible(false)
	check(not ui.hud.visible, "set_hud_visible(false)")
	ui.set_hud_visible(true)
	G.set_language("ru")

	# ---- destroyed screen
	ui.update_hud(_fake_info("explosion", 30.0, "fireball", false, 1.0, 19, 5.0, 31.2))
	ui.show_destroyed(true)
	check(ui.is_destroyed_visible(), "destroyed visible")
	await wait_sec(0.5)
	await shot("destroyed_ru.png")
	resets = 0
	ui._destroyed.find_children("*", "Button", true, false)[0].pressed.emit()
	check(resets == 1 and not ui.is_destroyed_visible(), "retry emits reset_requested and hides")

	# ---- 20 previews (exercises bomb_models.gd if present)
	check(ResourceLoader.exists(MODELS_PATH) == (menu._models_script != null), "bomb_models.gd used if present (%s)" % str(menu._models_script != null))
	ui.show_menu(true)
	if shots:
		await _preview_sheet()
	menu.select_bomb(10)

	# ---- repeated setup / no leaks of rows
	var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for i in 5:
		ui.setup(G.bombs)
		await process_frame
	await wait_frames(3)
	var after := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	check(absf(after - before) < 5.0, "node count stable across setup() (%d -> %d)" % [before, after])

	print("UI TEST fails=", fails)
	if fails == 0:
		print("READY")
	else:
		print("FAIL")
	quit()
