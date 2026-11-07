extends Control
## Post-launch HUD: T+/countdown, range, stage, arrival countdowns (light / heat / blast /
## sound), overpressure at the bunker, time-scale and PAUSED indicators. Compact, top-left,
## monospace; never takes mouse input. Hidden in cinematographer mode and in phase "idle".

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const CAP_COLOR := Color(0.42, 0.84, 0.54)

var _panel: PanelContainer
var _bomb_l: Label
var _t_cap: Label
var _t_val: Label
var _t_sub: Label
var _vals: Dictionary = {}          # row key -> value Label
var _tr: Array = []                 # [Label, key]
var _badge: PanelContainer
var _badge_l: Label
var _info: Dictionary = {}
var _last_ms := 0
var _anim_t := 0.0


func _init() -> void:
	name = "Hud"
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_ignore_mouse(self)
	Game.language_changed.connect(_retranslate)


func _lbl(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if bold:
		l.add_theme_font_override("font", UiTheme.font(true))
	return l


func _key_lbl(key: String, size: int, color: Color, bold: bool = false) -> Label:
	var l := _lbl(Game.tr_key(key), size, color, bold)
	_tr.append([l, key])
	return l


func _grid(rows: Array) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 1)
	for r in rows:
		var cap := _key_lbl(String(r[1]), UiTheme.FONT_SMALL + 1, CAP_COLOR)
		cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(cap)
		var v := _lbl("—", UiTheme.FONT_SIZE, UiTheme.GREEN, true)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.custom_minimum_size.x = 200
		g.add_child(v)
		_vals[String(r[0])] = v
	return g


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiTheme.box(Color(0.004, 0.02, 0.01, 0.82), UiTheme.BORDER, 1, 14, 9))
	_panel.position = Vector2(24.0, 24.0)
	_panel.custom_minimum_size = Vector2(470.0, 0.0)
	_panel.visible = false
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	_panel.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(_lbl("■", UiTheme.FONT_SMALL, UiTheme.AMBER))
	head.add_child(_key_lbl("hud.title", UiTheme.FONT_SMALL, UiTheme.AMBER, true))
	_bomb_l = _lbl("", UiTheme.FONT_SMALL, UiTheme.GREEN)
	_bomb_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bomb_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bomb_l.clip_text = true
	_bomb_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(_bomb_l)
	v.add_child(head)

	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 10)
	_t_cap = _lbl("T+", UiTheme.FONT_TITLE + 4, UiTheme.AMBER, true)
	trow.add_child(_t_cap)
	_t_val = _lbl("0,0 с", UiTheme.FONT_TITLE + 4, UiTheme.AMBER, true)
	_t_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_t_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	trow.add_child(_t_val)
	v.add_child(trow)
	_t_sub = _lbl("", UiTheme.FONT_TINY, CAP_COLOR)
	_t_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_t_sub)

	v.add_child(_grid([["dist", "hud.distance"], ["stage", "hud.stage"]]))
	v.add_child(HSeparator.new())
	v.add_child(_grid([["light", "hud.light"], ["heat", "hud.heat"], ["blast", "hud.blast"], ["sound", "hud.sound"]]))
	v.add_child(HSeparator.new())
	v.add_child(_grid([["p", "hud.pressure"], ["ts", "hud.timescale"]]))
	v.add_child(_key_lbl("hud.hint", UiTheme.FONT_TINY, UiTheme.GREEN_DIM))

	# top-centre badge: PAUSED or slow-motion / fast-forward factor
	_badge = PanelContainer.new()
	_badge.add_theme_stylebox_override("panel", UiTheme.box(Color(0.03, 0.02, 0.0, 0.84), Color(UiTheme.AMBER, 0.85), 2, 22, 6))
	_badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_badge.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_badge.offset_top = 24.0
	_badge.visible = false
	_badge_l = _lbl("", UiTheme.FONT_LARGE + 4, UiTheme.AMBER, true)
	_badge_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.add_child(_badge_l)
	add_child(_badge)
	_retranslate()


func _ignore_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse(c)


func _retranslate() -> void:
	for e in _tr:
		var l: Label = e[0]
		if is_instance_valid(l):
			l.text = Game.tr_key(String(e[1]))
	if not _info.is_empty():
		update_info(_info)


static func _num(v: Variant) -> float:
	if v is float or v is int:
		var f := float(v)
		if is_nan(f) or is_inf(f):
			return NAN
		return f
	return NAN


func _put(key: String, text: String, color: Color) -> void:
	var l: Label = _vals[key]
	if l.text != text:
		l.text = text
	l.add_theme_color_override("font_color", color)


func _eta(key: String, v: Variant, arrived_key: String) -> void:
	var f := _num(v)
	if is_nan(f):
		_put(key, "—", UiTheme.GREEN_FAINT)
	elif f <= 0.0:
		_put(key, "● " + Game.tr_key(arrived_key), UiTheme.GREEN)
	else:
		var dec := 1 if f < 1000.0 else 0
		_put(key, "○ " + Game.tr_key("hud.in").format({"t": UiTheme.fmt_fixed(f, dec)}), UiTheme.AMBER)


func _set_badge(text: String) -> void:
	_badge.visible = text != ""
	if _badge_l.text != text:
		_badge_l.text = text
		_badge.reset_size()


## info keys: phase ("flight","explosion","idle"), t_plus, dist_km, stage, eta_light, eta_heat,
## eta_blast, eta_sound, p_psi, time_scale, paused, bomb_index, cine.
func update_info(info: Dictionary) -> void:
	_info = info
	var phase := String(info.get("phase", "idle"))
	var cine := bool(info.get("cine", false))
	var paused := bool(info.get("paused", false))
	var ts := _num(info.get("time_scale", 1.0))
	if is_nan(ts):
		ts = 1.0
	var slow := absf(ts - 1.0) > 0.001
	_panel.visible = phase != "idle" and not cine
	if cine or phase == "idle":
		_set_badge("▌▌ " + Game.tr_key("hud.paused") if (paused and not cine) else "")
	elif paused:
		_set_badge("▌▌ " + Game.tr_key("hud.paused"))
	elif slow:
		_set_badge(Game.tr_key("hud.slow" if ts < 1.0 else "hud.fast").format({"v": UiTheme.fmt_sig(ts, 3)}))
	else:
		_set_badge("")
	if not _panel.visible:
		return

	var bi_f := _num(info.get("bomb_index", -1))
	var bi := -1 if is_nan(bi_f) else int(bi_f)
	var b: Dictionary = Game.bomb(bi) if bi >= 0 else {}
	var bname := ""
	if not b.is_empty():
		var bt := String(b.get("burst_type", ""))
		bname = Game.bomb_text(b, "name") + " · " + UiTheme.fmt_yield_short(float(b.get("yield_kt", 0.0)), bt.begins_with("NUCLEAR"))
	if _bomb_l.text != bname:
		_bomb_l.text = bname

	var t := _num(info.get("t_plus", 0.0))
	if is_nan(t):
		t = 0.0
	var flight := phase == "flight" or t < 0.0
	_t_cap.text = Game.tr_key("hud.tminus") if flight else Game.tr_key("hud.tplus")
	var tv := UiTheme.fmt_fixed(absf(t), 1 if absf(t) < 10000.0 else 0) + " " + Game.tr_key("unit.s")
	if _t_val.text != tv:
		_t_val.text = tv
	var tcol := UiTheme.AMBER if flight else UiTheme.GREEN_BRIGHT
	_t_cap.add_theme_color_override("font_color", tcol)
	_t_val.add_theme_color_override("font_color", tcol)
	_t_sub.text = Game.tr_key("hud.countdown") if flight else Game.tr_key("hud.after")

	var d := _num(info.get("dist_km", NAN))
	_put("dist", "—" if is_nan(d) else UiTheme.fmt_km(d), UiTheme.GREEN)
	var stage := String(info.get("stage", ""))
	if flight:
		_put("stage", Game.tr_key("stage.flight"), UiTheme.AMBER)
	elif stage == "":
		_put("stage", Game.tr_key("stage.none"), UiTheme.GREEN_DIM)
	else:
		_put("stage", Game.tr_key("stage." + stage), UiTheme.GREEN_BRIGHT)

	_eta("light", info.get("eta_light", null), "hud.arr_light")
	_eta("heat", info.get("eta_heat", null), "hud.arr_heat")
	_eta("blast", info.get("eta_blast", null), "hud.arr_blast")
	_eta("sound", info.get("eta_sound", null), "hud.arr_sound")

	var p := _num(info.get("p_psi", NAN))
	if is_nan(p):
		_put("p", "—", UiTheme.GREEN_FAINT)
	else:
		var pc := UiTheme.GREEN
		if p >= 10.0:
			pc = UiTheme.RED
		elif p >= 1.0:
			pc = UiTheme.AMBER
		_put("p", UiTheme.fmt_psi(p), pc)
	var tstxt := "×" + UiTheme.fmt_sig(ts, 3)
	if paused:
		tstxt = Game.tr_key("hud.paused")
	_put("ts", tstxt, UiTheme.AMBER if (slow or paused) else UiTheme.GREEN)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var dt := 0.0
	if _last_ms > 0:
		dt = clampf(float(now - _last_ms) / 1000.0, 0.0, 0.1)
	_last_ms = now
	_anim_t += dt
	if _badge.visible:
		_badge_l.modulate.a = 0.72 + 0.28 * cos(_anim_t * 4.0)
