extends Control
## Bunker terminal menu: bomb list (ascending yield), dossier with a rotating true-scale 3D
## preview, launch control (log range slider, azimuth, zones from BlastPhysics, danger
## warning + confirmation), environment/display settings and key hints.
## Built entirely in code; every player-facing string comes from data/locale.json.

signal launch_pressed(bomb_index: int, dist_km: float, az_deg: float)
signal setting_changed(key: String, value: Variant)
signal reset_pressed
signal quit_pressed
signal close_pressed

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const MODELS_PATH := "res://scripts/bombs/bomb_models.gd"
const D_MIN := 0.5
const D_MAX := 200.0
const AZ_LIMIT := 30.0
const Y_MIN := 0.0001
const Y_MAX := 100000.0
const P_WARN := 10.0
const Q_WARN := 10.0
const P_DESTROY := 25.0
const LIST_W := 540.0
const FIRE_W := 560.0
const CAP_W := 214.0
const ZONES := ["glass", "house", "burn", "concrete"]
const ZONE_COLORS := {
	"glass": Color(0.5, 0.86, 1.0),
	"house": Color(1.0, 0.76, 0.3),
	"burn": Color(1.0, 0.47, 0.16),
	"concrete": Color(1.0, 0.22, 0.2),
}
const HUMAN_MIN_SIZE := 1.2      # show the 1.8 m scale figure only next to objects at least this big
# burst-type groups, identical to ExplosionProfile._init()
const CONVENTIONAL_KINDS := ["CONVENTIONAL_SURFACE", "CONVENTIONAL_BURIED", "THERMOBARIC"]
const BURIED_KINDS := ["NUCLEAR_BURIED", "CONVENTIONAL_BURIED"]
const SURFACE_KINDS := ["NUCLEAR_SURFACE", "NUCLEAR_TOWER", "CONVENTIONAL_SURFACE", "CONVENTIONAL_BURIED", "NUCLEAR_BURIED", "NUCLEAR_UNDERWATER"]
const CONF_COLORS := {
	"measured": Color(0.45, 1.0, 0.58),
	"estimate": Color(1.0, 0.76, 0.3),
	"claimed": Color(1.0, 0.52, 0.3),
	"conceptual": Color(0.55, 0.82, 1.0),
}

const GRID_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 line_color : source_color = vec4(0.35, 1.0, 0.5, 0.55);
uniform float fade_r = 10.0;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 g = wp.xz;
	vec2 d = abs(fract(g - 0.5) - 0.5) / max(fwidth(g), vec2(1e-4));
	float line = 1.0 - clamp(min(d.x, d.y), 0.0, 1.0);
	float fade = 1.0 - smoothstep(fade_r * 0.45, fade_r, length(wp.xz));
	ALBEDO = line_color.rgb;
	ALPHA = (line * line_color.a + 0.05) * fade;
}
"""

var bombs: Array = []
var sel := -1
var dist_km := 25.0
var az_deg := 0.0
var est: Dictionary = {}

var _tr: Array = []                  # [Object, key, property]
var _rows: Array = []                # Array of Dictionary {btn, num, name, orig, yield}
var _row_group := ButtonGroup.new()
var _list_box: VBoxContainer
var _list_scroll: ScrollContainer

# dossier
var _name_l: Label
var _orig_l: Label
var _origin_v: Label
var _yield_l: Label
var _yield_bar: YieldBar
var _burst_v: Label
var _height_v: Label
var _conf_tag: PanelContainer
var _conf_l: Label
var _device_l: Label
var _blurb_l: Label
var _dims_l: Label
var _ref_l: Label

# preview
var _sv: SubViewport
var _pv_rect: TextureRect
var _pv_cam: Camera3D
var _pv_pivot: Node3D
var _pv_model: Node3D
var _pv_human: Node3D
var _pv_grid: MeshInstance3D
var _pv_grid_mat: ShaderMaterial
var _pv_fit: Dictionary = {}
var _models_script: Script = null
var _models_checked := false

# launch control
var _dist_slider: HSlider
var _dist_val: Label
var _scale: RangeScale
var _rec_btn: Button
var _az_slider: HSlider
var _az_val: Label
var _flight_val: Label
var _zone_rows: Dictionary = {}      # key -> [name Label, value Label, mark Label]
var _p_val: Label
var _q_val: Label
var _t_val: Label
var _warn_l: Label
var _launch_btn: Button
var _map: RangeMap

# settings
var _tod_btns: Array = []
var _tod_group := ButtonGroup.new()
var _hum_slider: HSlider
var _hum_val: Label
var _quality_opt: OptionButton
var _lang_btns: Array = []
var _lang_group := ButtonGroup.new()
var _grain_cb: CheckBox
var _clouds_cb: CheckBox
var _hud_cb: CheckBox

# header / misc
var _clock_l: Label
var _cursor_l: Label
var _confirm: Control
var _confirm_text: Label
var _syncing := false
var _last_ms := 0
var _anim_t := 0.0
var _reveal := 1.0
var _sync_t := 0.0
var _game_snap: Array = []
var _danger_key := ""
var _danger_cache := Vector2.ZERO    # x = 10 psi / 10 cal range, y = 25 psi range (km)


func _init() -> void:
	name = "TerminalMenu"
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	dist_km = clampf(Game.distance_km, D_MIN, D_MAX)
	az_deg = clampf(Game.azimuth_deg, -AZ_LIMIT, AZ_LIMIT)
	_build()
	Game.language_changed.connect(_on_language_changed)
	Game.settings_changed.connect(sync_from_game)


func _ready() -> void:
	_pv_rect.texture = _sv.get_texture()
	_on_visibility()
	_on_preview_resized()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and _sv != null:
		_on_visibility()


func _on_visibility() -> void:
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	if not visible and _confirm != null:
		_confirm.visible = false


# ================================================================ public

## Populate the list. bombs = Game.bombs (sorted by ascending yield).
func setup(p_bombs: Array) -> void:
	bombs = p_bombs
	for r in _rows:
		var old: Button = r["btn"]
		_list_box.remove_child(old)
		old.queue_free()
	_rows.clear()
	for i in bombs.size():
		_rows.append(_make_row(i))
	_refresh_rows()
	dist_km = clampf(Game.distance_km, D_MIN, D_MAX)
	az_deg = clampf(Game.azimuth_deg, -AZ_LIMIT, AZ_LIMIT)
	_dist_slider.set_value_no_signal(km_to_slider(dist_km))
	_az_slider.set_value_no_signal(az_deg)
	select_bomb(clampi(Game.selected_bomb, 0, maxi(bombs.size() - 1, 0)))
	sync_from_game()


func select_bomb(i: int) -> void:
	if bombs.is_empty():
		return
	i = clampi(i, 0, bombs.size() - 1)
	var changed := i != sel
	sel = i
	_refresh_rows()
	_refresh_details()
	if changed:
		_show_model(bombs[i])
		_reveal = 0.0
	_update_estimates()
	if Game.selected_bomb != i and i < Game.bombs.size():
		Game.select_bomb(i)
	_scroll_to_sel.call_deferred()


func _scroll_to_sel() -> void:
	if sel < 0 or sel >= _rows.size() or not is_inside_tree():
		return
	var b: Button = _rows[sel]["btn"]
	if is_instance_valid(b) and b.is_inside_tree() and _list_scroll.is_ancestor_of(b):
		_list_scroll.ensure_control_visible(b)


func set_distance(km: float) -> void:
	dist_km = clampf(km, D_MIN, D_MAX)
	_dist_slider.set_value_no_signal(km_to_slider(dist_km))
	Game.distance_km = dist_km
	_update_estimates()


func set_azimuth(deg: float) -> void:
	az_deg = clampf(deg, -AZ_LIMIT, AZ_LIMIT)
	_az_slider.set_value_no_signal(az_deg)
	Game.azimuth_deg = az_deg
	_update_estimates()


func is_dangerous() -> bool:
	return float(est.get("p", 0.0)) >= P_WARN or float(est.get("q", 0.0)) >= Q_WARN


func is_confirm_open() -> bool:
	return _confirm.visible


func close_confirm() -> void:
	_confirm.visible = false


func confirm_launch() -> void:
	_do_launch()


## Press the LAUNCH button (shows the danger confirmation if needed).
func request_launch() -> void:
	if sel < 0:
		return
	if is_dangerous():
		_open_confirm()
	else:
		_do_launch()


## Pull settings changed elsewhere (T/H keys, command line) into the controls, without emitting.
func sync_from_game() -> void:
	_syncing = true
	for k in _tod_btns.size():
		(_tod_btns[k] as Button).set_pressed_no_signal(k == Game.tod)
	_hum_slider.set_value_no_signal(Game.humidity)
	_hum_val.text = str(roundi(Game.humidity * 100.0)) + " %"
	if _quality_opt.selected != Game.quality:
		_quality_opt.select(clampi(Game.quality, 0, 3))
	_lang_btns[0].set_pressed_no_signal(Game.lang == "ru")
	_lang_btns[1].set_pressed_no_signal(Game.lang == "en")
	_grain_cb.set_pressed_no_signal(Game.film_grain)
	_clouds_cb.set_pressed_no_signal(Game.high_clouds)
	_hud_cb.set_pressed_no_signal(Game.hud_visible)
	if absf(Game.distance_km - dist_km) > 1e-4:
		dist_km = clampf(Game.distance_km, D_MIN, D_MAX)
		_dist_slider.set_value_no_signal(km_to_slider(dist_km))
	if absf(Game.azimuth_deg - az_deg) > 1e-4:
		az_deg = clampf(Game.azimuth_deg, -AZ_LIMIT, AZ_LIMIT)
		_az_slider.set_value_no_signal(az_deg)
	_syncing = false
	_game_snap = _game_snapshot()
	_update_estimates()


# ================================================================ static helpers

static func slider_to_km(v: float) -> float:
	return D_MIN * pow(D_MAX / D_MIN, clampf(v, 0.0, 1.0))


static func km_to_slider(km: float) -> float:
	return clampf(log(maxf(km, 1e-6) / D_MIN) / log(D_MAX / D_MIN), 0.0, 1.0)


## Missile flight time (s) for a range; same curve as Launcher.flight_time_for().
static func flight_time(km: float) -> float:
	return lerpf(6.0, 25.0, clampf(log(maxf(km, 1e-6) / 0.5) / log(400.0), 0.0, 1.0))


## Parachute phase (s) the launcher appends for retarded, non-contact bursts
## (mirrors Launcher.launch(): contact = burst height <= 3 m).
static func chute_time(b: Dictionary) -> float:
	var hob := float(b.get("burst_height_m", 0.0))
	if not bool(b.get("parachute", false)) or hob <= 3.0:
		return 0.0
	var drop := clampf(hob, 150.0, 1500.0) * 0.6 + 150.0
	return clampf(drop / 60.0, 3.0, 6.0)


static func _ground_r(slant: float, h: float) -> float:
	if h <= 0.0:
		return slant
	if slant <= h:
		return 0.0
	return sqrt(slant * slant - h * h)


## Air-blast coupling exactly as ExplosionProfile derives it (and Explosion.setup() uses it):
## conventional = HE/thermobaric (Kingery-Bulmash scaling), surface = fireball touches the ground,
## buried bursts couple profile.air_coupling (default 8 %) and underwater 30 % into the air blast.
## Returns w, w_air (kt), surface, conventional, nuclear, thermal (bool), hob (m, >= 0).
static func coupling(b: Dictionary) -> Dictionary:
	var bt := String(b.get("burst_type", "NUCLEAR_AIR"))
	var w := maxf(float(b.get("yield_kt", 1.0)), 1e-7)
	var art: Variant = b.get("profile", {})
	var air_c := -1.0
	if art is Dictionary and (art as Dictionary).has("air_coupling"):
		air_c = float((art as Dictionary)["air_coupling"])
	var conventional := bt in CONVENTIONAL_KINDS
	var buried := bt in BURIED_KINDS
	var underwater := bt == "NUCLEAR_UNDERWATER"
	var w_air := w
	if buried:
		w_air = w * (air_c if air_c >= 0.0 else 0.08)
	elif underwater:
		w_air = w * (air_c if air_c >= 0.0 else 0.3)
	return {
		"w": w,
		"w_air": maxf(w_air, 1e-9),
		"surface": bt in SURFACE_KINDS,
		"conventional": conventional,
		"nuclear": not conventional,
		"thermal": not conventional and not buried and not underwater,
		"hob": maxf(float(b.get("burst_height_m", 0.0)), 0.0),
	}


## Slant distance (m) from the bunker eye to the burst point for a target at d_km / az.
static func _slant_at(d_km: float, az: float, hob: float) -> float:
	var d := d_km * 1000.0
	var a := deg_to_rad(az)
	var x := sin(a) * d
	var z := -cos(a) * d
	return Vector3(x, TerrainMath.height(x, z) + hob, z).length()


## Menu estimates for bomb b at range d_km / azimuth az, computed the same way as
## Explosion.setup() (p_obs, t_shock_obs) so the warning agrees with what happens in game.
## Returns r_glass/r_house/r_concrete/r_burn (ground range m; 0 = does not reach the ground,
## -1 = not applicable), p (psi at the bunker), q (cal/cm2), thermal (bool), slant (m),
## t_shock (s), flight (s, missile + parachute), chute (s).
static func estimate(b: Dictionary, d_km: float, az: float, humidity: float) -> Dictionary:
	var c := coupling(b)
	var w: float = c["w"]
	var w_air: float = c["w_air"]
	var surf: bool = c["surface"]
	var conv: bool = c["conventional"]
	var thermal: bool = c["thermal"]
	var h: float = c["hob"]
	var slant := _slant_at(d_km, az, h)
	var res := {}
	res["p"] = BlastPhysics.overpressure(w_air, slant, surf, conv)
	res["q"] = BlastPhysics.thermal_fluence(w, slant, humidity) if thermal else 0.0
	res["thermal"] = thermal
	res["slant"] = slant
	res["r_glass"] = _ground_r(BlastPhysics.radius_for_pressure(w_air, 1.0, surf, conv), h)
	res["r_house"] = _ground_r(BlastPhysics.radius_for_pressure(w_air, 5.0, surf, conv), h)
	res["r_concrete"] = _ground_r(BlastPhysics.radius_for_pressure(w_air, 20.0, surf, conv), h)
	res["r_burn"] = _ground_r(BlastPhysics.burn_radius(w, 3), h) if thermal else -1.0
	res["t_shock"] = BlastPhysics.arrival_time(w, slant, surf, conv)
	var chute := chute_time(b)
	res["chute"] = chute
	res["flight"] = flight_time(d_km) + chute
	return res


## Pressure/fluence only (no zones / arrival time).
static func estimate_fast(b: Dictionary, d_km: float, az: float, humidity: float) -> Dictionary:
	var c := coupling(b)
	var slant := _slant_at(d_km, az, float(c["hob"]))
	return {
		"p": BlastPhysics.overpressure(float(c["w_air"]), slant, bool(c["surface"]), bool(c["conventional"])),
		"q": BlastPhysics.thermal_fluence(float(c["w"]), slant, humidity) if bool(c["thermal"]) else 0.0,
	}


static func _danger_at(d_km: float, az: float, hob: float, r_lim: float, w: float, humidity: float, use_q: bool) -> bool:
	var s := _slant_at(d_km, az, hob)
	return s <= r_lim or (use_q and BlastPhysics.thermal_fluence(w, s, humidity) >= Q_WARN)


## Largest range (km) at which the bunker still gets >= p_lim psi (or >= Q_WARN cal/cm2 when
## use_q): 0 if not even at D_MIN, D_MAX if still at D_MAX. Inverts the pressure once
## (radius_for_pressure) instead of evaluating overpressure() per step, so it costs ~1 ms.
static func danger_range(b: Dictionary, az: float, humidity: float, p_lim: float, use_q: bool) -> float:
	var c := coupling(b)
	var r_lim := BlastPhysics.radius_for_pressure(float(c["w_air"]), p_lim, bool(c["surface"]), bool(c["conventional"]))
	var hob: float = c["hob"]
	var w: float = c["w"]
	var uq := use_q and bool(c["thermal"])
	if not _danger_at(D_MIN, az, hob, r_lim, w, humidity, uq):
		return 0.0
	if _danger_at(D_MAX, az, hob, r_lim, w, humidity, uq):
		return D_MAX
	var lo := log(D_MIN)
	var hi := log(D_MAX)
	for _i in 32:
		var mid := 0.5 * (lo + hi)
		if _danger_at(exp(mid), az, hob, r_lim, w, humidity, uq):
			lo = mid
		else:
			hi = mid
	return exp(0.5 * (lo + hi))


# ================================================================ build helpers

func _reg(node: Object, key: String, prop: String = "text") -> void:
	_tr.append([node, key, prop])
	node.set(prop, Game.tr_key(key))


func _plain_label(text: String, size: int = 0, color: Color = Color(0, 0, 0, 0), bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", UiTheme.font(true))
	return l


func _label(key: String, size: int = 0, color: Color = Color(0, 0, 0, 0), bold: bool = false) -> Label:
	var l := _plain_label("", size, color, bold)
	_reg(l, key)
	return l


func _button(key: String, cb: Callable, variation: StringName = &"") -> Button:
	var b := Button.new()
	_reg(b, key)
	b.focus_mode = Control.FOCUS_NONE
	if variation != &"":
		b.theme_type_variation = variation
	b.pressed.connect(cb)
	return b


func _section(title_key: String, accent: Color = UiTheme.AMBER) -> Array:
	var p := PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	if title_key != "":
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		var mark := ColorRect.new()
		mark.color = accent
		mark.custom_minimum_size = Vector2(6, 16)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(mark)
		hb.add_child(_label(title_key, UiTheme.FONT_SMALL, accent, true))
		v.add_child(hb)
		v.add_child(HSeparator.new())
	return [p, v]


func _caption(key: String, width: float = CAP_W) -> Label:
	var l := _label(key, UiTheme.FONT_SMALL, UiTheme.GREEN_DIM)
	l.custom_minimum_size.x = width
	return l


func _spacer(w: float = 0.0, expand: bool = true) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(w, 0)
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


func _vspacer() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


# ================================================================ build

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.015, 0.008, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 10)
	margin.add_child(root_v)
	root_v.add_child(_build_header())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	root_v.add_child(body)
	body.add_child(_build_list_column())
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)
	var top := HBoxContainer.new()
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.add_theme_constant_override("separation", 10)
	right.add_child(top)
	top.add_child(_build_dossier())
	top.add_child(_build_launch_panel())
	right.add_child(_build_settings())

	add_child(UiTheme.make_scanlines())
	_confirm = _build_confirm()
	add_child(_confirm)
	_build_preview_world()


func _build_header() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.BG, UiTheme.BORDER, 1, 14, 6))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	p.add_child(hb)
	hb.add_child(_plain_label("■", UiTheme.FONT_LARGE, UiTheme.AMBER))
	hb.add_child(_label("ui.title", UiTheme.FONT_LARGE, UiTheme.GREEN_BRIGHT, true))
	_cursor_l = _plain_label("█", UiTheme.FONT_LARGE, UiTheme.GREEN)
	hb.add_child(_cursor_l)
	hb.add_child(_spacer())
	hb.add_child(_label("ui.status", UiTheme.FONT_SMALL, UiTheme.GREEN_DIM))
	_clock_l = _plain_label("00:00:00", UiTheme.FONT_SIZE, UiTheme.AMBER)
	hb.add_child(_clock_l)
	hb.add_child(_button("ui.btn_close", func() -> void: close_pressed.emit()))
	hb.add_child(_button("ui.btn_reset", func() -> void: reset_pressed.emit()))
	hb.add_child(_button("ui.btn_quit", func() -> void: quit_pressed.emit()))
	return p


func _build_list_column() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(LIST_W, 0)
	col.add_theme_constant_override("separation", 10)
	var s := _section("ui.list_title")
	var p: PanelContainer = s[0]
	var v: VBoxContainer = s[1]
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(p)

	var hm := MarginContainer.new()
	hm.add_theme_constant_override("margin_left", 8)
	hm.add_theme_constant_override("margin_right", 8)
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	hm.add_child(hdr)
	var c1 := _label("ui.col_num", UiTheme.FONT_TINY, UiTheme.GREEN_FAINT)
	c1.custom_minimum_size.x = 30
	hdr.add_child(c1)
	var c2 := _label("ui.col_name", UiTheme.FONT_TINY, UiTheme.GREEN_FAINT)
	c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(c2)
	var c3 := _label("ui.col_yield", UiTheme.FONT_TINY, UiTheme.GREEN_FAINT)
	c3.custom_minimum_size.x = 84
	c3.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hdr.add_child(c3)
	v.add_child(hm)

	_list_scroll = ScrollContainer.new()
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_list_scroll)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 1)
	_list_scroll.add_child(_list_box)

	col.add_child(_build_keys())
	return col


func _make_row(i: int) -> Dictionary:
	var btn := Button.new()
	btn.theme_type_variation = &"ListRow"
	btn.toggle_mode = true
	btn.button_group = _row_group
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 31)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.clip_contents = true
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 8
	hb.offset_right = -8
	hb.add_theme_constant_override("separation", 8)
	btn.add_child(hb)
	var num := _plain_label("", UiTheme.FONT_SIZE, UiTheme.GREEN_DIM)
	num.custom_minimum_size.x = 30
	var nm := _plain_label("", UiTheme.FONT_SIZE, UiTheme.GREEN)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.size_flags_stretch_ratio = 1.45
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var og := _plain_label("", UiTheme.FONT_TINY, UiTheme.GREEN_FAINT)
	og.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	og.size_flags_stretch_ratio = 1.0
	og.clip_text = true
	og.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var yl := _plain_label("", UiTheme.FONT_SIZE, UiTheme.AMBER_DIM)
	yl.custom_minimum_size.x = 84
	yl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for l in [num, nm, og, yl]:
		hb.add_child(l)
	btn.pressed.connect(_on_row_pressed.bind(i))
	_list_box.add_child(btn)
	return {"btn": btn, "num": num, "name": nm, "orig": og, "yield": yl}


func _build_keys() -> Control:
	var s := _section("ui.keys", UiTheme.GREEN_DIM)
	var v: VBoxContainer = s[1]
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 2)
	var items := [
		["keycap.mouse", "key.mouse", true], ["keycap.wheel", "key.wheel", true],
		["Tab", "key.tab", false], ["keycap.space", "key.space", true],
		["[ ]", "key.brackets", false], ["R", "key.r", false],
		["C", "key.c", false], ["1–4", "key.num", false],
		["T", "key.t", false], ["H", "key.h", false],
		["F1", "key.f1", false], ["F12", "key.f12", false],
		["Esc", "key.esc", false],
	]
	for it in items:
		var cap: Label
		if bool(it[2]):
			cap = _label(String(it[0]), UiTheme.FONT_SMALL, UiTheme.AMBER, true)
		else:
			cap = _plain_label(String(it[0]), UiTheme.FONT_SMALL, UiTheme.AMBER, true)
		cap.custom_minimum_size.x = 62
		grid.add_child(cap)
		var d := _label(String(it[1]), UiTheme.FONT_SMALL, UiTheme.GREEN)
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(d)
	v.add_child(grid)
	return s[0]


func _build_dossier() -> Control:
	var s := _section("ui.dossier")
	var p: PanelContainer = s[0]
	var v: VBoxContainer = s[1]
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 5)

	_name_l = _plain_label("", UiTheme.FONT_TITLE, UiTheme.AMBER, true)
	_name_l.clip_text = true
	_name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_l.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	v.add_child(_name_l)
	_orig_l = _plain_label("", UiTheme.FONT_SIZE, UiTheme.GREEN_DIM)
	_orig_l.clip_text = true
	_orig_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(_orig_l)

	# --- 3D preview frame
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiTheme.box(Color(0.0, 0.022, 0.012, 0.65), UiTheme.BORDER_DIM, 1, 1, 1))
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size = Vector2(0, 230)
	v.add_child(frame)
	var holder := Control.new()
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(holder)
	_pv_rect = TextureRect.new()
	_pv_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pv_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pv_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_pv_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_pv_rect)
	_pv_rect.resized.connect(_on_preview_resized)
	var tl := _label("ui.preview", UiTheme.FONT_TINY, UiTheme.GREEN_DIM)
	tl.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	tl.position = Vector2(16, 9)
	holder.add_child(tl)
	_dims_l = _plain_label("", UiTheme.FONT_TINY, UiTheme.GREEN_DIM)
	_dims_l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_dims_l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_dims_l.offset_left = 16
	_dims_l.offset_bottom = -9
	holder.add_child(_dims_l)
	_ref_l = _plain_label("", UiTheme.FONT_TINY, UiTheme.GREEN_DIM)
	_ref_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ref_l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_ref_l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_ref_l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ref_l.offset_right = -16
	_ref_l.offset_bottom = -9
	holder.add_child(_ref_l)
	holder.add_child(Brackets.new())

	# --- facts
	var g1 := GridContainer.new()
	g1.columns = 2
	g1.add_theme_constant_override("h_separation", 14)
	g1.add_theme_constant_override("v_separation", 3)
	g1.add_child(_caption("ui.origin"))
	_origin_v = _plain_label("", UiTheme.FONT_SIZE, UiTheme.GREEN)
	g1.add_child(_origin_v)
	g1.add_child(_caption("ui.yield"))
	_yield_l = _plain_label("", UiTheme.FONT_LARGE, UiTheme.AMBER, true)
	g1.add_child(_yield_l)
	v.add_child(g1)
	_yield_bar = YieldBar.new()
	v.add_child(_yield_bar)
	var g2 := GridContainer.new()
	g2.columns = 2
	g2.add_theme_constant_override("h_separation", 14)
	g2.add_theme_constant_override("v_separation", 3)
	g2.add_child(_caption("ui.burst"))
	_burst_v = _plain_label("", UiTheme.FONT_SIZE, UiTheme.GREEN)
	g2.add_child(_burst_v)
	g2.add_child(_caption("ui.height"))
	_height_v = _plain_label("", UiTheme.FONT_SIZE, UiTheme.GREEN)
	g2.add_child(_height_v)
	g2.add_child(_caption("ui.confidence"))
	var tag_box := HBoxContainer.new()
	_conf_tag = PanelContainer.new()
	_conf_tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_conf_l = _plain_label("", UiTheme.FONT_SMALL, UiTheme.GREEN, true)
	_conf_tag.add_child(_conf_l)
	tag_box.add_child(_conf_tag)
	g2.add_child(tag_box)
	v.add_child(g2)
	_device_l = _label("ui.device_note", UiTheme.FONT_SIZE, UiTheme.AMBER, true)
	_device_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_device_l)
	_blurb_l = _plain_label("", UiTheme.FONT_SIZE, UiTheme.GREEN)
	_blurb_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb_l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_blurb_l.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	v.add_child(_blurb_l)
	return p


func _value_row(key: String, value_size: int = UiTheme.FONT_LARGE) -> Array:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	var cap := _label(key, UiTheme.FONT_SMALL, UiTheme.GREEN_DIM)
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(cap)
	var val := _plain_label("", value_size, UiTheme.AMBER, true)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(val)
	return [hb, val]


func _build_launch_panel() -> Control:
	var s := _section("ui.fire_control", UiTheme.RED)
	var p: PanelContainer = s[0]
	var v: VBoxContainer = s[1]
	p.custom_minimum_size = Vector2(FIRE_W, 0)
	v.add_theme_constant_override("separation", 5)

	var r1 := _value_row("ui.distance")
	v.add_child(r1[0])
	_dist_val = r1[1]
	_dist_slider = HSlider.new()
	_dist_slider.min_value = 0.0
	_dist_slider.max_value = 1.0
	_dist_slider.step = 0.0005
	_dist_slider.focus_mode = Control.FOCUS_NONE
	_dist_slider.custom_minimum_size = Vector2(0, 26)
	_dist_slider.value_changed.connect(_on_dist_slider)
	v.add_child(_dist_slider)
	_scale = RangeScale.new()
	v.add_child(_scale)
	_rec_btn = Button.new()
	_rec_btn.theme_type_variation = &"AmberButton"
	_rec_btn.focus_mode = Control.FOCUS_NONE
	_rec_btn.pressed.connect(_on_rec_pressed)
	v.add_child(_rec_btn)

	var r2 := _value_row("ui.azimuth", UiTheme.FONT_SIZE)
	v.add_child(r2[0])
	_az_val = r2[1]
	_az_slider = HSlider.new()
	_az_slider.min_value = -AZ_LIMIT
	_az_slider.max_value = AZ_LIMIT
	_az_slider.step = 1.0
	_az_slider.focus_mode = Control.FOCUS_NONE
	_az_slider.custom_minimum_size = Vector2(0, 26)
	_az_slider.value_changed.connect(_on_az_slider)
	v.add_child(_az_slider)
	var r3 := _value_row("ui.flight_time", UiTheme.FONT_SIZE)
	v.add_child(r3[0])
	_flight_val = r3[1]
	v.add_child(HSeparator.new())

	v.add_child(_label("ui.zones", UiTheme.FONT_SMALL, UiTheme.AMBER_DIM, true))
	var zg := GridContainer.new()
	zg.columns = 4
	zg.add_theme_constant_override("h_separation", 10)
	zg.add_theme_constant_override("v_separation", 2)
	for k in ZONES:
		var sw := ColorRect.new()
		sw.color = ZONE_COLORS[k]
		sw.custom_minimum_size = Vector2(10, 10)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		zg.add_child(sw)
		var nl := _label("zone." + k, 18, UiTheme.GREEN)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var vl := _plain_label("", 18, UiTheme.GREEN, true)
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vl.custom_minimum_size.x = 110
		var ml := _plain_label("", UiTheme.FONT_TINY, UiTheme.RED, true)
		ml.custom_minimum_size.x = 82
		zg.add_child(nl)
		zg.add_child(vl)
		zg.add_child(ml)
		_zone_rows[k] = [nl, vl, ml]
	v.add_child(zg)
	v.add_child(HSeparator.new())

	v.add_child(_label("ui.at_bunker", UiTheme.FONT_SMALL, UiTheme.AMBER_DIM, true))
	var bg := GridContainer.new()
	bg.columns = 2
	bg.add_theme_constant_override("h_separation", 10)
	bg.add_theme_constant_override("v_separation", 2)
	var caps := ["ui.p_bunker", "ui.q_bunker", "ui.t_shock"]
	var vals: Array = []
	for c in caps:
		var cl := _label(c, 18, UiTheme.GREEN)
		cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bg.add_child(cl)
		var vl2 := _plain_label("", 18, UiTheme.GREEN, true)
		vl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		bg.add_child(vl2)
		vals.append(vl2)
	_p_val = vals[0]
	_q_val = vals[1]
	_t_val = vals[2]
	v.add_child(bg)
	_warn_l = _plain_label("", UiTheme.FONT_SMALL, UiTheme.RED, true)
	_warn_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_warn_l)
	_map = RangeMap.new()
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_map)
	_launch_btn = _button("ui.launch", request_launch, &"LaunchButton")
	_launch_btn.custom_minimum_size = Vector2(0, 80)
	v.add_child(_launch_btn)
	var hint := _label("ui.launch_hint", UiTheme.FONT_TINY, UiTheme.GREEN_FAINT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	return p


func _build_settings() -> Control:
	var s := _section("ui.settings", UiTheme.GREEN_DIM)
	var v: VBoxContainer = s[1]
	v.add_theme_constant_override("separation", 8)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	v.add_child(row1)
	row1.add_child(_caption("set.tod", 128))
	for i in 4:
		var b := Button.new()
		_reg(b, "tod." + String(Game.TOD_NAMES[i]))
		b.toggle_mode = true
		b.button_group = _tod_group
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(112, 0)
		b.pressed.connect(_on_tod.bind(i))
		row1.add_child(b)
		_tod_btns.append(b)
	row1.add_child(VSeparator.new())
	row1.add_child(_caption("set.quality", 0))
	_quality_opt = OptionButton.new()
	_quality_opt.focus_mode = Control.FOCUS_NONE
	_quality_opt.custom_minimum_size = Vector2(170, 0)
	for i in 4:
		_quality_opt.add_item(Game.tr_key("q." + String(Game.QUALITY_NAMES[i])), i)
	_quality_opt.item_selected.connect(_on_quality)
	row1.add_child(_quality_opt)
	row1.add_child(VSeparator.new())
	row1.add_child(_caption("set.lang", 0))
	for l in ["ru", "en"]:
		var lb := Button.new()
		lb.text = String(l).to_upper()
		lb.toggle_mode = true
		lb.button_group = _lang_group
		lb.focus_mode = Control.FOCUS_NONE
		lb.custom_minimum_size = Vector2(58, 0)
		lb.pressed.connect(_on_lang.bind(l))
		row1.add_child(lb)
		_lang_btns.append(lb)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	v.add_child(row2)
	row2.add_child(_caption("set.humidity", 128))
	_hum_slider = HSlider.new()
	_hum_slider.min_value = 0.0
	_hum_slider.max_value = 1.0
	_hum_slider.step = 0.05
	_hum_slider.focus_mode = Control.FOCUS_NONE
	_hum_slider.custom_minimum_size = Vector2(300, 26)
	_hum_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hum_slider.value_changed.connect(_on_humidity)
	row2.add_child(_hum_slider)
	_hum_val = _plain_label("55 %", UiTheme.FONT_SIZE, UiTheme.AMBER, true)
	_hum_val.custom_minimum_size.x = 64
	row2.add_child(_hum_val)
	row2.add_child(VSeparator.new())
	_grain_cb = _check("set.grain", "grain")
	row2.add_child(_grain_cb)
	_clouds_cb = _check("set.clouds", "clouds")
	row2.add_child(_clouds_cb)
	_hud_cb = _check("set.hud", "hud")
	row2.add_child(_hud_cb)
	return s[0]


func _check(key: String, setting: String) -> CheckBox:
	var cb := CheckBox.new()
	_reg(cb, key)
	cb.focus_mode = Control.FOCUS_NONE
	cb.toggled.connect(_on_check.bind(setting))
	return cb


func _build_confirm() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cc)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.box(Color(0.07, 0.012, 0.006, 0.97), UiTheme.RED, 2, 32, 22))
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	p.add_child(v)
	var t := _label("dlg.title", UiTheme.FONT_TITLE, UiTheme.RED, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	_confirm_text = _plain_label("", UiTheme.FONT_SIZE, UiTheme.GREEN)
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_text.custom_minimum_size = Vector2(840, 0)
	v.add_child(_confirm_text)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 24)
	v.add_child(hb)
	var go := _button("dlg.launch", _do_launch, &"LaunchButton")
	go.add_theme_font_size_override("font_size", 26)
	go.custom_minimum_size = Vector2(300, 60)
	hb.add_child(go)
	var cancel := _button("dlg.cancel", close_confirm)
	cancel.add_theme_font_size_override("font_size", 24)
	cancel.custom_minimum_size = Vector2(220, 60)
	hb.add_child(cancel)
	return root


# ================================================================ 3D preview

func _build_preview_world() -> void:
	_sv = SubViewport.new()
	_sv.name = "PreviewViewport"
	_sv.own_world_3d = true
	_sv.transparent_bg = true
	_sv.msaa_3d = Viewport.MSAA_4X
	_sv.size = Vector2i(1400, 600)
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_sv)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.72, 0.64)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_sv.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.7
	key.light_color = Color(1.0, 0.95, 0.86)
	key.rotation_degrees = Vector3(-38.0, -35.0, 0.0)
	_sv.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.6
	fill.light_color = Color(0.55, 1.0, 0.7)
	fill.rotation_degrees = Vector3(-12.0, 145.0, 0.0)
	_sv.add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.light_energy = 0.8
	rim.light_color = Color(1.0, 0.78, 0.45)
	rim.rotation_degrees = Vector3(-55.0, 180.0, 0.0)
	_sv.add_child(rim)
	_pv_cam = Camera3D.new()
	_pv_cam.fov = 30.0
	_pv_cam.near = 0.05
	_pv_cam.far = 400.0
	_pv_cam.current = true
	_sv.add_child(_pv_cam)
	_pv_pivot = Node3D.new()
	_sv.add_child(_pv_pivot)

	_pv_grid = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80.0, 80.0)
	_pv_grid.mesh = pm
	var sh := Shader.new()
	sh.code = GRID_SHADER
	_pv_grid_mat = ShaderMaterial.new()
	_pv_grid_mat.shader = sh
	_pv_grid.material_override = _pv_grid_mat
	_pv_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sv.add_child(_pv_grid)
	_pv_human = _make_human()
	_sv.add_child(_pv_human)


func _make_human() -> Node3D:
	var n := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.45, 1.0, 0.6, 0.3)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.2
	cap.height = 1.5
	body.mesh = cap
	body.position = Vector3(0.0, 0.75, 0.0)
	body.material_override = mat
	n.add_child(body)
	var head := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.12
	sp.height = 0.24
	head.mesh = sp
	head.position = Vector3(0.0, 1.66, 0.0)
	head.material_override = mat
	n.add_child(head)
	return n


func _on_preview_resized() -> void:
	if _sv == null or _pv_rect == null:
		return
	var s := _pv_rect.size
	if s.x < 8.0 or s.y < 8.0:
		return
	# render at 2x of the layout size for crisp edges at 1440p
	_sv.size = Vector2i(int(s.x * 2.0), int(s.y * 2.0))
	_fit_camera()


func _load_models_script() -> void:
	_models_checked = true
	if not ResourceLoader.exists(MODELS_PATH):
		return
	var res: Resource = load(MODELS_PATH)
	if res is Script:
		_models_script = res as Script


func _build_model(b: Dictionary) -> Node3D:
	if not _models_checked:
		_load_models_script()
	if _models_script != null:
		var found := false
		var is_static := false
		for m in _models_script.get_script_method_list():
			if String(m.get("name", "")) == "build":
				found = true
				is_static = (int(m.get("flags", 0)) & METHOD_FLAG_STATIC) != 0
				break
		if found:
			var built: Variant = null
			if is_static:
				built = _models_script.call("build", b)
			elif _models_script.can_instantiate():
				var inst: Object = _models_script.new()
				built = inst.call("build", b)
				if inst is Node:
					(inst as Node).queue_free()
			if built is Node3D:
				return built as Node3D
	return _fallback_model(b)


static func _col(v: Variant, def: Color) -> Color:
	if v is Array and (v as Array).size() >= 3:
		var a: Array = v
		return Color(float(a[0]), float(a[1]), float(a[2]))
	return def


func _fallback_model(b: Dictionary) -> Node3D:
	var root := Node3D.new()
	var length := maxf(float(b.get("length_m", 3.0)), 0.3)
	var dia := maxf(float(b.get("diameter_m", 0.6)), 0.05)
	var cols: Dictionary = b.get("colors", {})
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _col(cols.get("body"), Color(0.35, 0.37, 0.3))
	mat.roughness = 0.55
	mat.metallic = 0.25
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = dia * 0.5
	cap.height = maxf(length, dia * 1.01)
	mi.mesh = cap
	mi.rotation = Vector3(0.0, 0.0, PI * 0.5)
	mi.material_override = mat
	root.add_child(mi)
	var band := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = dia * 0.515
	cyl.bottom_radius = dia * 0.515
	cyl.height = maxf(dia * 0.14, 0.03)
	band.mesh = cyl
	band.rotation = Vector3(0.0, 0.0, PI * 0.5)
	band.position = Vector3(length * 0.22, 0.0, 0.0)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = _col(cols.get("band"), Color(0.9, 0.75, 0.1))
	band.material_override = bm
	root.add_child(band)
	return root


func _acc_aabb(n: Node, xf: Transform3D, acc: Array) -> void:
	if n is GeometryInstance3D and not (n is GPUParticles3D) and not (n is CPUParticles3D):
		var a: AABB = xf * (n as GeometryInstance3D).get_aabb()
		if acc[0] == null:
			acc[0] = a
		else:
			acc[0] = (acc[0] as AABB).merge(a)
	for c in n.get_children():
		if c is Node3D:
			_acc_aabb(c, xf * (c as Node3D).transform, acc)


func _show_model(b: Dictionary) -> void:
	if _pv_model != null:
		_pv_model.queue_free()
		_pv_model = null
	var m := _build_model(b)
	var acc: Array = [null]
	_acc_aabb(m, m.transform, acc)
	var length := maxf(float(b.get("length_m", 3.0)), 0.3)
	var dia := maxf(float(b.get("diameter_m", 0.6)), 0.05)
	var box := AABB(Vector3(-length * 0.5, -dia * 0.5, -dia * 0.5), Vector3(length, dia, dia))
	if acc[0] != null:
		var mb: AABB = acc[0]
		if mb.size.x > length * 0.3 and mb.size.length() > 0.01:
			box = mb
	m.position -= box.get_center()
	_pv_pivot.add_child(m)
	_pv_model = m
	_pv_pivot.rotation = Vector3(0.0, deg_to_rad(-28.0), 0.0)
	var hy := box.size.y * 0.5
	var rxz := Vector2(box.size.x, box.size.z).length() * 0.5
	var floor_y := -hy - 0.01
	_pv_grid.position = Vector3(0.0, floor_y, 0.0)
	var show_h := maxf(length, dia) >= HUMAN_MIN_SIZE
	var hx := -(rxz + 0.55)
	_pv_human.visible = show_h
	_pv_human.position = Vector3(hx, floor_y, 0.0)
	if show_h:
		_pv_fit = {"x0": hx - 0.25, "x1": rxz, "y0": floor_y, "y1": maxf(hy, floor_y + 1.8), "rz": rxz}
	else:
		_pv_fit = {"x0": -rxz, "x1": rxz, "y0": floor_y, "y1": hy, "rz": rxz}
	_pv_grid_mat.set_shader_parameter("fade_r", maxf(rxz * 1.9, 3.5))
	_fit_camera()


func _fit_camera() -> void:
	if _pv_fit.is_empty() or _pv_cam == null:
		return
	var aspect := float(_sv.size.x) / maxf(float(_sv.size.y), 1.0)
	var tan_v := tan(deg_to_rad(_pv_cam.fov * 0.5))
	var tan_h := tan_v * aspect
	var x0: float = _pv_fit["x0"]
	var x1: float = _pv_fit["x1"]
	var y0: float = _pv_fit["y0"]
	var y1: float = _pv_fit["y1"]
	var rz: float = _pv_fit["rz"]
	var hw := (x1 - x0) * 0.5
	var hh := (y1 - y0) * 0.5
	var d := rz * 0.6 + maxf(hw / (tan_h * 0.86), hh / (tan_v * 0.7))
	var target := Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, 0.0)
	var elev := deg_to_rad(12.0)
	var pos := target + Vector3(0.0, sin(elev), cos(elev)) * d
	_pv_cam.transform = Transform3D(Basis.looking_at(target - pos, Vector3.UP), pos)
	_pv_cam.far = maxf(d * 6.0, 50.0)


# ================================================================ refresh

func _second_name(b: Dictionary) -> String:
	var nm := Game.bomb_text(b, "name")
	var orig := String(b.get("original", ""))
	if _norm(orig) == _norm(nm) or orig == "":
		var other: Variant = b.get("name", {})
		if other is Dictionary:
			var alt := String((other as Dictionary).get("en" if Game.lang == "ru" else "ru", ""))
			if _norm(alt) != _norm(nm):
				return alt
		return ""
	return orig


static func _norm(s: String) -> String:
	return s.replace("«", "").replace("»", "").replace("\"", "").strip_edges().to_lower()


func _refresh_rows() -> void:
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		var b: Dictionary = bombs[i]
		var on := i == sel
		var btn: Button = r["btn"]
		btn.set_pressed_no_signal(on)
		var bt := String(b.get("burst_type", ""))
		var nm := Game.bomb_text(b, "name")
		var orig := _second_name(b)
		(r["num"] as Label).text = "%02d" % int(b.get("num", i + 1))
		(r["name"] as Label).text = nm
		(r["orig"] as Label).text = orig
		(r["orig"] as Label).visible = orig != ""
		(r["yield"] as Label).text = UiTheme.fmt_yield_short(float(b.get("yield_kt", 0.0)), bt.begins_with("NUCLEAR"))
		btn.tooltip_text = nm + ("\n" + orig if orig != "" else "")
		(r["num"] as Label).add_theme_color_override("font_color", UiTheme.AMBER if on else UiTheme.GREEN_DIM)
		(r["name"] as Label).add_theme_color_override("font_color", UiTheme.AMBER if on else UiTheme.GREEN)
		(r["orig"] as Label).add_theme_color_override("font_color", UiTheme.AMBER_DIM if on else UiTheme.GREEN_FAINT)
		(r["yield"] as Label).add_theme_color_override("font_color", UiTheme.AMBER if on else UiTheme.AMBER_DIM)


func _height_text(b: Dictionary) -> String:
	var h := float(b.get("burst_height_m", 0.0))
	var medium := String(b.get("medium", ""))
	var hs := UiTheme.fmt_sig(absf(h), 3)
	if h < 0.0:
		return Game.tr_key("ui.h_water" if medium == "water" else "ui.h_below").format({"h": hs})
	if h < 5.0:
		return Game.tr_key("ui.h_surface").format({"h": hs})
	return Game.tr_key("ui.h_above").format({"h": hs})


func _refresh_details() -> void:
	if sel < 0 or sel >= bombs.size():
		return
	var b: Dictionary = bombs[sel]
	var w := float(b.get("yield_kt", 0.0))
	var bt := String(b.get("burst_type", ""))
	var nuclear := bt.begins_with("NUCLEAR")
	_name_l.text = Game.bomb_text(b, "name")
	_orig_l.text = _second_name(b)
	_origin_v.text = "%d · %s" % [int(b.get("year", 0)), Game.bomb_text(b, "country")]
	var ytxt := UiTheme.fmt_yield_full(w, nuclear)
	var charge := float(b.get("charge_kg", 0.0))
	if not nuclear and charge > 0.0:
		ytxt += " · " + Game.tr_key("ui.charge").format({"c": UiTheme.fmt_sig(charge, 3)})
	_yield_l.text = ytxt
	_yield_bar.set_value(w)
	_burst_v.text = Game.tr_key("burst." + bt)
	_height_v.text = _height_text(b)
	var conf := String(b.get("yield_conf", "estimate"))
	var cc: Color = CONF_COLORS.get(conf, UiTheme.AMBER)
	_conf_l.text = Game.tr_key("conf." + conf)
	_conf_l.add_theme_color_override("font_color", cc)
	_conf_tag.add_theme_stylebox_override("panel", UiTheme.box(Color(cc.r * 0.12, cc.g * 0.12, cc.b * 0.12, 0.9), Color(cc, 0.85), 1, 10, 2))
	_device_l.visible = bool(b.get("device", false))
	var blurb := Game.bomb_text(b, "blurb").strip_edges()
	_blurb_l.text = blurb
	_blurb_l.visible = blurb != ""
	var length := float(b.get("length_m", 0.0))
	var dia := float(b.get("diameter_m", 0.0))
	var mass := float(b.get("mass_kg", 0.0))
	var mass_s := ""
	if mass >= 1000.0:
		mass_s = UiTheme.fmt_sig(mass / 1000.0, 3) + " " + Game.tr_key("unit.t")
	else:
		mass_s = UiTheme.fmt_sig(mass, 3) + " " + Game.tr_key("unit.kg")
	_ref_l.text = Game.tr_key("ui.preview_ref" if maxf(length, dia) >= HUMAN_MIN_SIZE else "ui.preview_ref_grid")
	_dims_l.text = Game.tr_key("ui.dims").format({"l": UiTheme.fmt_sig(length, 3), "d": UiTheme.fmt_sig(dia, 3), "m": mass_s})
	var rec := float(b.get("rec_km", 25.0))
	_rec_btn.text = Game.tr_key("ui.rec_btn").format({"d": UiTheme.fmt_dist_round(rec * 1000.0)})
	_scale.rec_km = rec


func _update_estimates() -> void:
	if sel < 0 or sel >= bombs.size():
		return
	var b: Dictionary = bombs[sel]
	est = estimate(b, dist_km, az_deg, Game.humidity)
	_dist_val.text = UiTheme.fmt_km(dist_km)
	_az_val.text = UiTheme.fmt_signed_deg(az_deg)
	_flight_val.text = UiTheme.fmt_seconds(float(est["flight"]), 1)
	var d_m := dist_km * 1000.0
	for k in ZONES:
		var r: float = est["r_" + k]
		var row: Array = _zone_rows[k]
		var vl: Label = row[1]
		var ml: Label = row[2]
		var inside := r > 0.0 and d_m <= r
		if r < 0.0:
			vl.text = Game.tr_key("zone.na")
			vl.add_theme_color_override("font_color", UiTheme.GREEN_FAINT)
		elif r == 0.0:
			vl.text = Game.tr_key("zone.not_ground")
			vl.add_theme_color_override("font_color", UiTheme.GREEN_DIM)
		else:
			vl.text = UiTheme.fmt_dist_m(r)
			vl.add_theme_color_override("font_color", UiTheme.RED if inside else UiTheme.GREEN)
		ml.text = Game.tr_key("ui.in_zone") if inside else ""
		(row[0] as Label).add_theme_color_override("font_color", UiTheme.RED if inside else UiTheme.GREEN)
	var p: float = est["p"]
	var q: float = est["q"]
	_p_val.text = UiTheme.fmt_psi(p)
	_p_val.add_theme_color_override("font_color", UiTheme.RED if p >= P_WARN else (UiTheme.AMBER if p >= 1.0 else UiTheme.GREEN))
	if bool(est["thermal"]):
		var qs := ("< " + UiTheme.fmt_fixed(0.01, 2)) if q < 0.01 else UiTheme.fmt_sig(q, 3)
		_q_val.text = qs + " " + Game.tr_key("unit.cal")
		_q_val.add_theme_color_override("font_color", UiTheme.RED if q >= Q_WARN else (UiTheme.AMBER if q >= 1.0 else UiTheme.GREEN))
	else:
		_q_val.text = Game.tr_key("zone.na")
		_q_val.add_theme_color_override("font_color", UiTheme.GREEN_FAINT)
	_t_val.text = Game.tr_key("ui.t_after").format({"t": UiTheme.fmt_fixed(float(est["t_shock"]), 1)})
	var warns := PackedStringArray()
	if p >= P_DESTROY:
		warns.append(Game.tr_key("ui.warn_destroy"))
	elif p >= P_WARN:
		warns.append(Game.tr_key("ui.warn_glass"))
	if q >= Q_WARN:
		warns.append(Game.tr_key("ui.warn_heat"))
	_warn_l.text = "\n".join(warns)
	_warn_l.visible = not warns.is_empty()
	var dkey := "%d|%.2f|%.3f|%.6f" % [sel, az_deg, Game.humidity, float(b.get("yield_kt", 0.0))]
	if dkey != _danger_key:
		_danger_key = dkey
		_danger_cache = Vector2(danger_range(b, az_deg, Game.humidity, P_WARN, true), danger_range(b, az_deg, Game.humidity, P_DESTROY, false))
	_scale.danger_km = _danger_cache.x
	_scale.destroy_km = _danger_cache.y
	_scale.queue_redraw()
	var circles: Array = []
	for k in ZONES:
		circles.append([float(est["r_" + k]), ZONE_COLORS[k]])
	_map.set_data(d_m, az_deg, circles, p >= P_WARN or q >= Q_WARN)


func _open_confirm() -> void:
	var q_s := UiTheme.fmt_sig(float(est.get("q", 0.0)), 3) if bool(est.get("thermal", false)) else "—"
	_confirm_text.text = Game.tr_key("dlg.text").format({"p": UiTheme.fmt_psi(float(est.get("p", 0.0))), "q": q_s})
	_confirm.visible = true


func _do_launch() -> void:
	_confirm.visible = false
	if sel < 0:
		return
	Game.distance_km = dist_km
	Game.azimuth_deg = az_deg
	if Game.selected_bomb != sel and sel < Game.bombs.size():
		Game.select_bomb(sel)
	launch_pressed.emit(sel, dist_km, az_deg)


# ================================================================ callbacks

func _on_row_pressed(i: int) -> void:
	select_bomb(i)


func _on_dist_slider(v: float) -> void:
	if _syncing:
		return
	dist_km = slider_to_km(v)
	Game.distance_km = dist_km
	_update_estimates()


func _on_rec_pressed() -> void:
	if sel < 0:
		return
	set_distance(float((bombs[sel] as Dictionary).get("rec_km", 25.0)))


func _on_az_slider(v: float) -> void:
	if _syncing:
		return
	az_deg = v
	Game.azimuth_deg = v
	_update_estimates()


func _on_tod(i: int) -> void:
	if _syncing:
		return
	Game.tod = i
	setting_changed.emit("tod", i)


func _on_quality(i: int) -> void:
	if _syncing:
		return
	Game.quality = i
	setting_changed.emit("quality", i)


func _on_humidity(v: float) -> void:
	if _syncing:
		return
	Game.humidity = v
	_hum_val.text = str(roundi(v * 100.0)) + " %"
	_update_estimates()
	setting_changed.emit("humidity", v)


func _on_lang(l: String) -> void:
	if _syncing:
		return
	if Game.lang != l:
		Game.set_language(l)
	setting_changed.emit("lang", l)


func _on_check(on: bool, setting: String) -> void:
	if _syncing:
		return
	match setting:
		"grain":
			Game.film_grain = on
		"clouds":
			Game.high_clouds = on
		"hud":
			Game.hud_visible = on
	setting_changed.emit(setting, on)


func _on_language_changed() -> void:
	for e in _tr:
		var o: Object = e[0]
		if is_instance_valid(o):
			o.set(String(e[2]), Game.tr_key(String(e[1])))
	for i in 4:
		_quality_opt.set_item_text(i, Game.tr_key("q." + String(Game.QUALITY_NAMES[i])))
	_syncing = true
	_lang_btns[0].set_pressed_no_signal(Game.lang == "ru")
	_lang_btns[1].set_pressed_no_signal(Game.lang == "en")
	_syncing = false
	_refresh_rows()
	_refresh_details()
	_update_estimates()
	_yield_bar.queue_redraw()
	_map.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed:
		return
	if _confirm.visible:
		return
	match ke.keycode:
		KEY_UP:
			select_bomb(sel - 1)
			get_viewport().set_input_as_handled()
		KEY_DOWN:
			select_bomb(sel + 1)
			get_viewport().set_input_as_handled()
		KEY_PAGEUP:
			select_bomb(0)
			get_viewport().set_input_as_handled()
		KEY_PAGEDOWN:
			select_bomb(bombs.size() - 1)
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			if not ke.echo:
				request_launch()
				get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# the preview renders only while the menu is really on screen (menu or parent layer hidden -> off)
	var shown := is_visible_in_tree()
	var mode := SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED
	if _sv.render_target_update_mode != mode:
		_sv.render_target_update_mode = mode
	if not shown:
		_last_ms = 0
		return
	var now := Time.get_ticks_msec()
	var dt := 0.0
	if _last_ms > 0:
		dt = clampf(float(now - _last_ms) / 1000.0, 0.0, 0.1)
	_last_ms = now
	_anim_t += dt
	if _pv_pivot != null:
		_pv_pivot.rotate_y(dt * 0.42)
	_cursor_l.self_modulate.a = 1.0 if fmod(_anim_t, 1.0) < 0.55 else 0.0
	var clk := Time.get_time_string_from_system()
	if _clock_l.text != clk:
		_clock_l.text = clk
	if _reveal < 1.0:
		_reveal = minf(_reveal + dt * 2.4, 1.0)
		_name_l.visible_ratio = clampf(_reveal * 2.0, 0.0, 1.0)
		_blurb_l.visible_ratio = _reveal
	_sync_t += dt
	if _sync_t > 0.3:
		_sync_t = 0.0
		_poll_game()


## Game.* values the controls mirror. Compared against the snapshot taken at the last sync, so
## values the controls cannot represent exactly (humidity off the slider step or > 1, a range
## outside 0.5..200 km) do not trigger a re-sync every poll.
func _game_snapshot() -> Array:
	return [Game.tod, Game.humidity, Game.quality, Game.film_grain, Game.high_clouds, Game.hud_visible,
		Game.distance_km, Game.azimuth_deg, Game.lang]


func _poll_game() -> void:
	if _game_snapshot() != _game_snap:
		sync_from_game()


# ================================================================ inner widgets

## Logarithmic yield bar 0.0001 kt .. 100 000 kt with decade ticks.
class YieldBar extends Control:
	const UT = preload("res://scripts/ui/ui_theme.gd")
	const LO := 0.0001
	const HI := 100000.0
	var value_kt := 1.0

	func _init() -> void:
		custom_minimum_size = Vector2(0, 40)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_value(v: float) -> void:
		value_kt = v
		queue_redraw()

	func _frac(w: float) -> float:
		return clampf(log(maxf(w, 1e-9) / LO) / log(HI / LO), 0.0, 1.0)

	func _draw() -> void:
		var font := get_theme_font("font", "Label")
		var fs := UT.FONT_TINY
		var bar_h := 16.0
		var r := Rect2(0.0, 0.0, size.x, bar_h)
		draw_rect(r, Color(0.02, 0.07, 0.035, 1.0))
		var fx := _frac(value_kt) * size.x
		var seg := 7.0
		var x := 2.0
		while x < fx - 1.0:
			var t := x / maxf(size.x, 1.0)
			var c := UT.GREEN.lerp(UT.AMBER, smoothstep(0.3, 0.62, t)).lerp(UT.RED, smoothstep(0.72, 0.98, t))
			draw_rect(Rect2(x, 3.0, minf(seg - 2.0, fx - x - 1.0), bar_h - 6.0), c)
			x += seg
		draw_rect(r, UT.BORDER, false, 1.0)
		var units := ["unit.t", "unit.t", "unit.t", "unit.t", "unit.kt", "unit.kt", "unit.kt", "unit.mt", "unit.mt", "unit.mt"]
		var nums := ["0,1", "1", "10", "100", "1", "10", "100", "1", "10", "100"]
		for i in 10:
			var tx := float(i) / 9.0 * size.x
			draw_line(Vector2(tx, bar_h), Vector2(tx, bar_h + 5.0), UT.GREEN_DIM, 1.0)
			var n := String(nums[i])
			if i == 0 and Game.lang != "ru":
				n = "0.1"
			var s := n + " " + Game.tr_key(String(units[i]))
			var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var px := clampf(tx - w * 0.5, 0.0, size.x - w)
			draw_string(font, Vector2(px, bar_h + 6.0 + fs), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UT.GREEN_DIM)
		# value marker
		draw_colored_polygon(PackedVector2Array([Vector2(fx, bar_h - 1.0), Vector2(fx - 5.0, bar_h + 7.0), Vector2(fx + 5.0, bar_h + 7.0)]), UT.AMBER)
		draw_line(Vector2(fx, 0.0), Vector2(fx, bar_h), UT.AMBER, 2.0)


## Tick scale under the logarithmic range slider: labels, danger band, recommended marker.
class RangeScale extends Control:
	const UT = preload("res://scripts/ui/ui_theme.gd")
	const TICKS := [0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0, 200.0]
	var rec_km := -1.0
	var danger_km := 0.0
	var destroy_km := 0.0
	var inset := 7.0

	func _init() -> void:
		custom_minimum_size = Vector2(0, 32)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _x(km: float) -> float:
		var f := clampf(log(maxf(km, 1e-6) / 0.5) / log(400.0), 0.0, 1.0)
		return inset + f * (size.x - 2.0 * inset)

	func _draw() -> void:
		var font := get_theme_font("font", "Label")
		var fs := UT.FONT_TINY
		if danger_km > 0.5:
			draw_rect(Rect2(inset, 0.0, _x(danger_km) - inset, 4.0), Color(1.0, 0.45, 0.2, 0.75))
		if destroy_km > 0.5:
			draw_rect(Rect2(inset, 0.0, _x(destroy_km) - inset, 4.0), Color(1.0, 0.12, 0.06, 1.0))
		for t in TICKS:
			var x := _x(float(t))
			draw_line(Vector2(x, 5.0), Vector2(x, 11.0), UT.GREEN_DIM, 1.0)
			var s := UT.fmt_sig(float(t), 2)
			if float(t) >= 200.0:
				s += " " + Game.tr_key("unit.km")
			var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var px := clampf(x - w * 0.5, 0.0, size.x - w)
			draw_string(font, Vector2(px, 12.0 + fs), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UT.GREEN_DIM)
		if rec_km > 0.0:
			var rx := _x(rec_km)
			draw_colored_polygon(PackedVector2Array([Vector2(rx, 4.0), Vector2(rx - 6.0, 13.0), Vector2(rx + 6.0, 13.0)]), UT.AMBER)


## Corner brackets around the preview frame (targeting-reticle look).
class Brackets extends Control:
	const UT = preload("res://scripts/ui/ui_theme.gd")

	func _init() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var l := 22.0
		var m := 4.0
		var c := Color(UT.AMBER, 0.7)
		var w := size.x
		var h := size.y
		for p in [[Vector2(m, m), 1.0, 1.0], [Vector2(w - m, m), -1.0, 1.0], [Vector2(m, h - m), 1.0, -1.0], [Vector2(w - m, h - m), -1.0, -1.0]]:
			var o: Vector2 = p[0]
			var sx: float = p[1]
			var sy: float = p[2]
			draw_line(o, o + Vector2(l * sx, 0.0), c, 2.0)
			draw_line(o, o + Vector2(0.0, l * sy), c, 2.0)
		# centre cross
		var cc := Vector2(w * 0.5, h * 0.5)
		var cc_col := Color(UT.GREEN, 0.18)
		draw_line(cc - Vector2(10.0, 0.0), cc + Vector2(10.0, 0.0), cc_col, 1.0)
		draw_line(cc - Vector2(0.0, 10.0), cc + Vector2(0.0, 10.0), cc_col, 1.0)


## Top-down range map: bunker, target on its azimuth, zone circles, range rings, scale bar.
class RangeMap extends Control:
	const UT = preload("res://scripts/ui/ui_theme.gd")
	var dist_m := 25000.0
	var az := 0.0
	var circles: Array = []          # [radius m (<=0 ignored), Color], largest first after sort
	var danger := false

	func _init() -> void:
		custom_minimum_size = Vector2(0, 130)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func set_data(p_dist_m: float, p_az: float, p_circles: Array, p_danger: bool) -> void:
		dist_m = p_dist_m
		az = p_az
		circles = p_circles.duplicate()
		circles.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
		danger = p_danger
		queue_redraw()

	func _tag(font: Font, pos: Vector2, text: String, fs: int, col: Color) -> void:
		var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var p := Vector2(clampf(pos.x, 3.0, size.x - sz.x - 3.0), clampf(pos.y, fs + 2.0, size.y - 3.0))
		draw_rect(Rect2(p + Vector2(-3.0, -fs + 1.0), Vector2(sz.x + 6.0, fs + 3.0)), Color(0.0, 0.025, 0.012, 0.82))
		draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

	static func _nice(x: float) -> float:
		var e := pow(10.0, floorf(log(maxf(x, 1e-6)) / log(10.0)))
		var m := x / e
		if m < 1.5:
			return e
		if m < 3.5:
			return 2.0 * e
		if m < 7.5:
			return 5.0 * e
		return 10.0 * e

	func _draw() -> void:
		var font := get_theme_font("font", "Label")
		var fs := UT.FONT_TINY
		var w := size.x
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.03, 0.015, 0.75))
		var a := deg_to_rad(az)
		var tgt := Vector2(sin(a) * dist_m, cos(a) * dist_m)     # east, north (m)
		var rmax := dist_m * 0.04
		for c in circles:
			rmax = maxf(rmax, float(c[0]))
		var lo := Vector2(minf(0.0, tgt.x - rmax), minf(0.0, tgt.y - rmax))
		var hi := Vector2(maxf(0.0, tgt.x + rmax), maxf(0.0, tgt.y + rmax))
		var ext := hi - lo
		var pad := 18.0
		var s := minf((w - 2.0 * pad) / maxf(ext.x, 1.0), (h - 2.0 * pad - 10.0) / maxf(ext.y, 1.0))
		var mid := (lo + hi) * 0.5
		var org := Vector2(w * 0.5, h * 0.5 + 5.0)
		var to_px := func(p: Vector2) -> Vector2: return org + Vector2(p.x - mid.x, -(p.y - mid.y)) * s
		var bunker: Vector2 = to_px.call(Vector2.ZERO)
		var target: Vector2 = to_px.call(tgt)
		# range rings around the bunker
		var far_m := maxf(maxf(ext.x, ext.y), 1.0)
		var step := _nice(far_m / 4.0)
		var k := 1
		while k <= 8:
			var r_px := float(k) * step * s
			if r_px > maxf(w, h) * 1.5:
				break
			draw_arc(bunker, r_px, 0.0, TAU, 96, Color(UT.GREEN, 0.12), 1.0, true)
			k += 1
		# zone circles at the target
		for c in circles:
			var r := float(c[0])
			if r <= 0.0:
				continue
			var col: Color = c[1]
			draw_circle(target, r * s, Color(col, 0.10))
			draw_arc(target, maxf(r * s, 1.0), 0.0, TAU, 96, Color(col, 0.85), 1.5, true)
		# ground track
		draw_dashed_line(bunker, target, Color(UT.AMBER, 0.7), 1.0, 6.0)
		# target marker
		var tc := UT.AMBER
		draw_line(target - Vector2(7, 0), target + Vector2(7, 0), tc, 2.0)
		draw_line(target - Vector2(0, 7), target + Vector2(0, 7), tc, 2.0)
		draw_arc(target, 4.0, 0.0, TAU, 16, tc, 1.0, true)
		# bunker marker
		var bc := UT.RED if danger else UT.GREEN_BRIGHT
		draw_rect(Rect2(bunker - Vector2(5, 5), Vector2(10, 10)), bc)
		var bl := Game.tr_key("map.bunker")
		var bw := font.get_string_size(bl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var close := bunker.distance_to(target) < 46.0
		var bpos := bunker + Vector2(-bw * 0.5, 22.0)
		if bpos.y > h - 4.0:
			bpos = bunker + Vector2(12.0, 5.0)
		_tag(font, bpos, bl, fs, bc)
		var tl := Game.tr_key("map.target")
		var tpos := target + Vector2(10.0, -8.0)
		if close:
			tpos = target + Vector2(10.0, -18.0)
		_tag(font, tpos, tl, fs, tc)
		# north arrow
		var nx := Vector2(w - 18.0, 20.0)
		draw_colored_polygon(PackedVector2Array([nx + Vector2(0, -10), nx + Vector2(-5, 2), nx + Vector2(5, 2)]), UT.GREEN_DIM)
		var nl := Game.tr_key("map.north")
		var nw := font.get_string_size(nl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, nx + Vector2(-nw * 0.5, 2.0 + fs), nl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UT.GREEN_DIM)
		# scale bar
		var bar_m := _nice((w * 0.22) / s)
		var bar_px := bar_m * s
		var y := h - 10.0
		draw_line(Vector2(10, y), Vector2(10 + bar_px, y), UT.GREEN_DIM, 2.0)
		draw_line(Vector2(10, y - 4), Vector2(10, y + 1), UT.GREEN_DIM, 2.0)
		draw_line(Vector2(10 + bar_px, y - 4), Vector2(10 + bar_px, y + 1), UT.GREEN_DIM, 2.0)
		draw_string(font, Vector2(14.0 + bar_px, y + 4.0), UT.fmt_dist_round(bar_m), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UT.GREEN_DIM)
		# ring spacing legend
		var rl := "○ " + UT.fmt_dist_round(step)
		draw_string(font, Vector2(10.0, 4.0 + fs), rl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UT.GREEN, 0.45))
		draw_rect(Rect2(Vector2.ZERO, size), UT.BORDER_DIM, false, 1.0)
