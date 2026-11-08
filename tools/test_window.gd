extends Node
## Window keys in the real game (scenes/main.tscn): F11 and Alt+Enter toggle full screen and back,
## Esc opens the quit dialog (pausing the game, cursor visible) and closes it again; the game does
## not quit. Run windowed (full screen needs a real window):
##   Godot_console --path . res://tools/test_window.tscn [-- --out DIR]   (screenshot of the dialog)
## Prints READY when every check passed.

var _fails := 0
var _main: Node


func _check(ok: bool, what: String) -> void:
	print("CHECK ", "ok   " if ok else "FAIL ", what)
	if not ok:
		_fails += 1


func _key(code: Key, alt := false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.alt_pressed = alt
	ev.pressed = true
	get_viewport().push_input(ev)
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	get_viewport().push_input(up)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_main)
	var t0 := Time.get_ticks_msec()
	while (_main.get("ui") == null or not _main.get("ui").is_menu_visible()) and Time.get_ticks_msec() - t0 < 60000:
		await get_tree().process_frame
	await _frames(10)
	var ui: Node = _main.get("ui")
	var m0 := DisplayServer.window_get_mode()
	_key(KEY_F11)
	await _frames(10)
	_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "F11: full screen (mode %d)" % DisplayServer.window_get_mode())
	_key(KEY_F11)
	await _frames(10)
	_check(DisplayServer.window_get_mode() == m0, "F11 again: back to the window (mode %d)" % DisplayServer.window_get_mode())
	_key(KEY_ENTER, true)
	await _frames(10)
	_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN and ui.is_menu_visible(), "Alt+Enter: full screen, no launch")
	_key(KEY_ENTER, true)
	await _frames(10)
	_check(DisplayServer.window_get_mode() == m0, "Alt+Enter again: window")
	# Esc with the terminal menu closed (in the 3D view): quit dialog, pause, cursor
	ui.show_menu(false)
	_main.call("_update_mouse")
	await _frames(3)
	Game.paused = false
	_key(KEY_ESCAPE)
	await _frames(3)
	_check(ui.is_quit_dialog_open() and Game.paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
			"Esc in the 3D view: quit dialog, game paused, cursor visible")
	_key(KEY_F11)
	await _frames(10)
	_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN and ui.is_quit_dialog_open(),
			"F11 works while the quit dialog is open")
	await RenderingServer.frame_post_draw
	var a := OS.get_cmdline_user_args()
	var oi := a.find("--out")
	var out := (a[oi + 1] if oi >= 0 and oi + 1 < a.size() else OS.get_user_data_dir()).path_join("test_window_quit_fullscreen.png")
	print("SHOT ", out, " err=", get_viewport().get_texture().get_image().save_png(out))
	_key(KEY_F11)
	await _frames(10)
	_key(KEY_ESCAPE)
	await _frames(3)
	_check(not ui.is_quit_dialog_open() and not Game.paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
			"Esc again: back to the game, unpaused, mouse captured for looking around")
	_check(is_inside_tree(), "the game did not quit")
	print("READY" if _fails == 0 else "FAIL (%d)" % _fails)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().quit()
