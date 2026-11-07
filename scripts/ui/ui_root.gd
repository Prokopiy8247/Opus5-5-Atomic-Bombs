extends CanvasLayer
## Root of the 2D interface over the 3D view: white-out/glare overlay, HUD, toasts, the
## bunker terminal menu and the "BUNKER DESTROYED" screen. Handles Tab (menu toggle) itself
## in _input, before GUI focus navigation could swallow it, and keeps the mouse visible
## while the menu or the destroyed screen is open (captured otherwise).
##
## Integration (main.gd):
##   const UiRoot = preload("res://scripts/ui/ui_root.gd")
##   ui = UiRoot.new(); add_child(ui); ui.setup(Game.bombs)
##   ui.launch_requested.connect(...); ui.reset_requested.connect(...); ...

signal launch_requested(bomb_index: int, dist_km: float, az_deg: float)
signal reset_requested
signal quit_requested
signal setting_changed(key: String, value)   # "tod","humidity","quality","lang","grain","hud","clouds"
signal menu_visibility_changed(v: bool)

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const TerminalMenu = preload("res://scripts/ui/terminal_menu.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const MAX_TOASTS := 4
const TOAST_HOLD := 2.4
const TOAST_FADE := 0.6

## Set false if the owner wants to manage Input.mouse_mode itself.
var manage_mouse := true
## Set false if the owner handles Tab and calls toggle_menu() itself.
var handle_tab_key := true
## Hide the menu automatically when LAUNCH is pressed.
var hide_menu_on_launch := true

var menu: TerminalMenu
var hud: Hud
var _flash: ColorRect
var _toasts: VBoxContainer
var _destroyed: Control
var _dest_title: Label
var _dest_peak: Label
var _tr: Array = []
var _hud_visible := true
var _peak_p := 0.0
var _last_ms := 0
var _anim_t := 0.0


func _init() -> void:
	name = "UI"
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hud_visible = Game.hud_visible

	_flash = ColorRect.new()
	_flash.name = "WhiteOut"
	_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.visible = false
	add_child(_flash)

	hud = Hud.new()
	hud.visible = _hud_visible
	add_child(hud)

	menu = TerminalMenu.new()
	add_child(menu)

	_toasts = VBoxContainer.new()
	_toasts.name = "Toasts"
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.add_theme_constant_override("separation", 6)
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toasts.offset_bottom = -120.0
	_toasts.theme = UiTheme.get_theme()
	add_child(_toasts)

	_destroyed = _build_destroyed()
	add_child(_destroyed)

	menu.launch_pressed.connect(_on_launch)
	menu.setting_changed.connect(_on_setting)
	menu.reset_pressed.connect(func() -> void: reset_requested.emit())
	menu.quit_pressed.connect(func() -> void: quit_requested.emit())
	menu.close_pressed.connect(func() -> void: show_menu(false))
	Game.language_changed.connect(_retranslate)


func _ready() -> void:
	_apply_mouse()


# ================================================================ public API

func setup(bombs: Array) -> void:
	menu.setup(bombs)


func show_menu(v: bool) -> void:
	var changed := menu.visible != v
	menu.visible = v
	if v:
		menu.sync_from_game()
	_apply_mouse()
	if changed:
		menu_visibility_changed.emit(v)


func is_menu_visible() -> bool:
	return menu.visible


func toggle_menu() -> void:
	show_menu(not menu.visible)


## Called every frame after launch. See hud.gd update_info() for the keys.
func update_hud(info: Dictionary) -> void:
	var phase := String(info.get("phase", "idle"))
	if phase != "explosion":
		_peak_p = 0.0
	else:
		var p: Variant = info.get("p_psi", 0.0)
		if p is float or p is int:
			_peak_p = maxf(_peak_p, float(p))
	hud.update_info(info)


func set_hud_visible(v: bool) -> void:
	_hud_visible = v
	hud.visible = v
	Game.hud_visible = v


func is_hud_visible() -> bool:
	return _hud_visible


## "BUNKER DESTROYED" screen with a retry button (emits reset_requested).
func show_destroyed(v: bool) -> void:
	if v:
		_dest_peak.text = Game.tr_key("dest.peak").format({"p": UiTheme.fmt_psi(_peak_p)}) if _peak_p > 0.0 else ""
		_dest_peak.visible = _peak_p > 0.0
	_destroyed.visible = v
	_apply_mouse()


func is_destroyed_visible() -> bool:
	return _destroyed.visible


## Full-screen white-out / glare, 0..1.
func flash_white(amount: float) -> void:
	var a := clampf(amount, 0.0, 1.0)
	_flash.color = Color(1.0, 1.0, 1.0, a)
	_flash.visible = a > 0.002


func show_toast(text: String) -> void:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.add_theme_stylebox_override("panel", UiTheme.box(Color(0.01, 0.04, 0.02, 0.86), Color(UiTheme.AMBER, 0.7), 1, 18, 7))
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", UiTheme.AMBER)
	l.add_theme_font_size_override("font_size", UiTheme.FONT_SIZE + 1)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.set_meta("t0", Time.get_ticks_msec())
	_toasts.add_child(p)
	while _toasts.get_child_count() > MAX_TOASTS:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()


## Menu estimates for the current selection (p psi, q cal/cm2, zones, flight time).
func get_estimate() -> Dictionary:
	return menu.est


# ================================================================ internals

func _apply_mouse() -> void:
	if not manage_mouse or not is_inside_tree():
		return
	var need := menu.visible or _destroyed.visible
	var mode := Input.MOUSE_MODE_VISIBLE if need else Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode != mode:
		Input.mouse_mode = mode


func _on_launch(bomb_index: int, dist_km: float, az_deg: float) -> void:
	if hide_menu_on_launch:
		show_menu(false)
	launch_requested.emit(bomb_index, dist_km, az_deg)


func _on_setting(key: String, value: Variant) -> void:
	if key == "hud":
		set_hud_visible(bool(value))
	setting_changed.emit(key, value)


func _reg(node: Object, key: String) -> void:
	_tr.append([node, key])
	node.set("text", Game.tr_key(key))


func _retranslate() -> void:
	for e in _tr:
		var o: Object = e[0]
		if is_instance_valid(o):
			o.set("text", Game.tr_key(String(e[1])))
	if _destroyed.visible:
		show_destroyed(true)


func _build_destroyed() -> Control:
	var root := Control.new()
	root.name = "Destroyed"
	root.theme = UiTheme.get_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.0, 0.0, 0.88)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	root.add_child(UiTheme.make_scanlines(0.12, 0.55))
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(cc)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.box(Color(0.09, 0.0, 0.0, 0.92), UiTheme.RED, 2, 56, 34))
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	p.add_child(v)
	_dest_title = Label.new()
	_reg(_dest_title, "dest.title")
	_dest_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dest_title.add_theme_font_override("font", UiTheme.font(true))
	_dest_title.add_theme_font_size_override("font_size", 76)
	_dest_title.add_theme_color_override("font_color", UiTheme.RED)
	v.add_child(_dest_title)
	var line := ColorRect.new()
	line.color = Color(UiTheme.RED, 0.6)
	line.custom_minimum_size = Vector2(0, 2)
	v.add_child(line)
	var txt := Label.new()
	_reg(txt, "dest.text")
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	txt.custom_minimum_size = Vector2(900, 0)
	txt.add_theme_font_size_override("font_size", UiTheme.FONT_LARGE)
	txt.add_theme_color_override("font_color", Color(1.0, 0.8, 0.75))
	v.add_child(txt)
	_dest_peak = Label.new()
	_dest_peak.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dest_peak.add_theme_font_override("font", UiTheme.font(true))
	_dest_peak.add_theme_font_size_override("font_size", UiTheme.FONT_LARGE)
	_dest_peak.add_theme_color_override("font_color", UiTheme.AMBER)
	v.add_child(_dest_peak)
	var adv := Label.new()
	_reg(adv, "dest.advice")
	adv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	adv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	adv.add_theme_color_override("font_color", UiTheme.GREEN_DIM)
	v.add_child(adv)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 28)
	v.add_child(hb)
	var retry := Button.new()
	_reg(retry, "dest.retry")
	retry.theme_type_variation = &"AmberButton"
	retry.focus_mode = Control.FOCUS_NONE
	retry.custom_minimum_size = Vector2(320, 64)
	retry.add_theme_font_override("font", UiTheme.font(true))
	retry.add_theme_font_size_override("font_size", 28)
	retry.pressed.connect(_on_retry)
	hb.add_child(retry)
	var quit_b := Button.new()
	_reg(quit_b, "dest.quit")
	quit_b.focus_mode = Control.FOCUS_NONE
	quit_b.custom_minimum_size = Vector2(240, 64)
	quit_b.add_theme_font_size_override("font_size", 24)
	quit_b.pressed.connect(func() -> void: quit_requested.emit())
	hb.add_child(quit_b)
	return root


func _on_retry() -> void:
	show_destroyed(false)
	reset_requested.emit()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	if menu.visible and menu.is_confirm_open():
		if ke.keycode == KEY_ESCAPE:
			menu.close_confirm()
			get_viewport().set_input_as_handled()
			return
		if ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER:
			menu.confirm_launch()
			get_viewport().set_input_as_handled()
			return
	if handle_tab_key and ke.keycode == KEY_TAB:
		toggle_menu()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var dt := 0.0
	if _last_ms > 0:
		dt = clampf(float(now - _last_ms) / 1000.0, 0.0, 0.1)
	_last_ms = now
	_anim_t += dt
	for c in _toasts.get_children():
		var t0 := int(c.get_meta("t0", now))
		var age := float(now - t0) / 1000.0
		if age > TOAST_HOLD + TOAST_FADE:
			_toasts.remove_child(c)
			c.queue_free()
		elif age > TOAST_HOLD:
			(c as Control).modulate.a = 1.0 - (age - TOAST_HOLD) / TOAST_FADE
	if _destroyed.visible:
		# unstable, failing-display flicker
		var f := 0.82 + 0.18 * sin(_anim_t * 31.0) * sin(_anim_t * 7.3)
		if fmod(_anim_t, 2.7) < 0.08:
			f = 0.35
		_dest_title.modulate.a = f
