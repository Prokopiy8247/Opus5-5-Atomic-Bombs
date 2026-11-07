extends RefCounted
## Military-terminal UI theme (phosphor green / amber on translucent black, thin borders,
## monospace system font with Cyrillic) plus shared localized formatting helpers.
## Usage: const UiTheme = preload("res://scripts/ui/ui_theme.gd"); control.theme = UiTheme.get_theme()

const GREEN := Color(0.45, 1.0, 0.58)
const GREEN_BRIGHT := Color(0.78, 1.0, 0.83)
const GREEN_DIM := Color(0.32, 0.7, 0.43)
const GREEN_FAINT := Color(0.2, 0.46, 0.28)
const AMBER := Color(1.0, 0.76, 0.3)
const AMBER_DIM := Color(0.78, 0.56, 0.22)
const RED := Color(1.0, 0.34, 0.28)
const RED_DIM := Color(0.55, 0.13, 0.1)
const BG := Color(0.008, 0.028, 0.016, 0.9)
const BG_PANEL := Color(0.012, 0.045, 0.024, 0.88)
const BG_BUTTON := Color(0.035, 0.11, 0.06, 0.95)
const BG_BUTTON_HOVER := Color(0.065, 0.2, 0.1, 0.98)
const BG_BUTTON_PRESSED := Color(0.13, 0.36, 0.19, 1.0)
const BORDER := Color(0.32, 0.88, 0.48, 0.6)
const BORDER_DIM := Color(0.26, 0.62, 0.36, 0.38)

const FONT_SIZE := 19
const FONT_SMALL := 16
const FONT_TINY := 14
const FONT_LARGE := 24
const FONT_TITLE := 30
const FONT_HUGE := 44

const SCANLINE_SHADER := """
shader_type canvas_item;
uniform float line_strength = 0.07;
uniform float vignette = 0.32;
uniform float roll_strength = 0.025;
void fragment() {
	float line = step(0.5, fract(FRAGCOORD.y / 3.0));
	vec2 c = UV - vec2(0.5);
	float vig = smoothstep(0.42, 0.95, length(c * vec2(1.0, 1.25)));
	float roll = smoothstep(0.0, 0.12, 0.12 - abs(fract(UV.y - TIME * 0.045) - 0.5));
	vec3 col = mix(vec3(0.0), vec3(0.4, 1.0, 0.55), roll);
	float a = line * line_strength + vig * vignette;
	COLOR = vec4(col, max(a, roll * roll_strength));
}
"""

static var _theme: Theme = null
static var _font: Font = null
static var _font_bold: Font = null
static var _scan_shader: Shader = null


## Drops the static caches at exit so no GPU resources outlive the RenderingServer.
static func release() -> void:
	_theme = null
	_font = null
	_font_bold = null
	_scan_shader = null


# ---------------------------------------------------------------- fonts

static func font(bold: bool = false) -> Font:
	if bold:
		if _font_bold == null:
			_font_bold = _make_font(700)
		return _font_bold
	if _font == null:
		_font = _make_font(400)
	return _font


static func _make_font(weight: int) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Consolas", "Lucida Console", "Courier New", "monospace"])
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_LIGHT
	f.allow_system_fallback = true
	return f


# ---------------------------------------------------------------- styles

static func box(bg: Color, border: Color, bw: int = 1, mh: float = 10.0, mv: float = 5.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = mh
	s.content_margin_right = mh
	s.content_margin_top = mv
	s.content_margin_bottom = mv
	s.anti_aliasing = false
	return s


static func panel_style(border: Color = BORDER, bg: Color = BG_PANEL, bw: int = 1) -> StyleBoxFlat:
	return box(bg, border, bw, 14.0, 10.0)


static func empty_style(m: float = 0.0) -> StyleBoxEmpty:
	var s := StyleBoxEmpty.new()
	s.content_margin_left = m
	s.content_margin_right = m
	s.content_margin_top = m
	s.content_margin_bottom = m
	return s


static func make_scanlines(strength: float = 0.07, vig: float = 0.32) -> ColorRect:
	if _scan_shader == null:
		_scan_shader = Shader.new()
		_scan_shader.code = SCANLINE_SHADER
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = _scan_shader
	m.set_shader_parameter("line_strength", strength)
	m.set_shader_parameter("vignette", vig)
	r.material = m
	return r


# ---------------------------------------------------------------- procedural icons

static func _img(w: int, h: int) -> Image:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


static func _tex_check(sz: int, checked: bool, col: Color) -> ImageTexture:
	var img := _img(sz, sz)
	for y in sz:
		for x in sz:
			var edge := x == 0 or y == 0 or x == sz - 1 or y == sz - 1
			if edge:
				img.set_pixel(x, y, col)
			elif checked and x >= 4 and y >= 4 and x < sz - 4 and y < sz - 4:
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func _tex_radio(sz: int, checked: bool, col: Color) -> ImageTexture:
	var img := _img(sz, sz)
	var c := (sz - 1) * 0.5
	for y in sz:
		for x in sz:
			var d := Vector2(x - c, y - c).length()
			if absf(d - (c - 0.5)) < 0.75:
				img.set_pixel(x, y, col)
			elif checked and d < c - 3.5:
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func _tex_grabber(w: int, h: int, fill: Color, edge: Color) -> ImageTexture:
	var img := _img(w, h)
	for y in h:
		for x in w:
			var e := x == 0 or y == 0 or x == w - 1 or y == h - 1
			img.set_pixel(x, y, edge if e else fill)
	# centre notch
	for y in range(4, h - 4):
		img.set_pixel(w / 2, y, edge)
	return ImageTexture.create_from_image(img)


static func _tex_arrow(w: int, h: int, col: Color) -> ImageTexture:
	var img := _img(w, h)
	for y in h:
		var half := (w * 0.5) * (1.0 - float(y) / float(h))
		for x in w:
			if absf(x + 0.5 - w * 0.5) <= half:
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func _tex_empty() -> ImageTexture:
	return ImageTexture.create_from_image(_img(1, 1))


# ---------------------------------------------------------------- theme

static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = FONT_SIZE

	# Label
	t.set_color("font_color", "Label", GREEN)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	t.set_constant("line_spacing", "Label", 2)

	# Panels
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())

	# Buttons
	t.set_stylebox("normal", "Button", box(BG_BUTTON, BORDER_DIM))
	t.set_stylebox("hover", "Button", box(BG_BUTTON_HOVER, BORDER))
	t.set_stylebox("pressed", "Button", box(BG_BUTTON_PRESSED, GREEN))
	t.set_stylebox("hover_pressed", "Button", box(BG_BUTTON_PRESSED.lightened(0.08), GREEN_BRIGHT))
	t.set_stylebox("disabled", "Button", box(Color(BG_BUTTON, 0.5), Color(BORDER_DIM, 0.2)))
	t.set_stylebox("focus", "Button", empty_style())
	t.set_color("font_color", "Button", GREEN)
	t.set_color("font_hover_color", "Button", GREEN_BRIGHT)
	t.set_color("font_pressed_color", "Button", AMBER)
	t.set_color("font_hover_pressed_color", "Button", AMBER)
	t.set_color("font_focus_color", "Button", GREEN)
	t.set_color("font_disabled_color", "Button", GREEN_FAINT)
	t.set_constant("h_separation", "Button", 8)

	# List rows (flat toggle buttons)
	t.set_type_variation("ListRow", "Button")
	var row_n := box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 8.0, 2.0)
	var row_h := box(Color(0.06, 0.18, 0.09, 0.75), Color(0, 0, 0, 0), 0, 8.0, 2.0)
	var row_p := box(Color(0.1, 0.27, 0.13, 0.95), AMBER, 0, 8.0, 2.0)
	row_p.border_width_left = 4
	var row_hp := row_p.duplicate() as StyleBoxFlat
	row_hp.bg_color = Color(0.12, 0.31, 0.15, 0.98)
	t.set_stylebox("normal", "ListRow", row_n)
	t.set_stylebox("hover", "ListRow", row_h)
	t.set_stylebox("pressed", "ListRow", row_p)
	t.set_stylebox("hover_pressed", "ListRow", row_hp)
	t.set_stylebox("focus", "ListRow", empty_style())

	# Big launch button
	t.set_type_variation("LaunchButton", "Button")
	t.set_stylebox("normal", "LaunchButton", box(Color(0.22, 0.05, 0.03, 0.95), Color(1.0, 0.42, 0.25, 0.9), 2, 16, 10))
	t.set_stylebox("hover", "LaunchButton", box(Color(0.38, 0.08, 0.04, 0.98), Color(1.0, 0.7, 0.4, 1.0), 2, 16, 10))
	t.set_stylebox("pressed", "LaunchButton", box(Color(0.62, 0.14, 0.05, 1.0), AMBER, 3, 16, 10))
	t.set_stylebox("hover_pressed", "LaunchButton", box(Color(0.62, 0.14, 0.05, 1.0), AMBER, 3, 16, 10))
	t.set_stylebox("focus", "LaunchButton", empty_style())
	t.set_color("font_color", "LaunchButton", Color(1.0, 0.62, 0.42))
	t.set_color("font_hover_color", "LaunchButton", Color(1.0, 0.86, 0.6))
	t.set_color("font_pressed_color", "LaunchButton", Color(1.0, 0.95, 0.8))
	t.set_color("font_hover_pressed_color", "LaunchButton", Color(1.0, 0.95, 0.8))
	t.set_font("font", "LaunchButton", font(true))
	t.set_font_size("font_size", "LaunchButton", 40)

	# Amber accent button (recommended range, retry)
	t.set_type_variation("AmberButton", "Button")
	t.set_stylebox("normal", "AmberButton", box(Color(0.14, 0.09, 0.02, 0.95), Color(AMBER, 0.55)))
	t.set_stylebox("hover", "AmberButton", box(Color(0.25, 0.16, 0.03, 0.98), AMBER))
	t.set_stylebox("pressed", "AmberButton", box(Color(0.4, 0.26, 0.05, 1.0), AMBER))
	t.set_stylebox("hover_pressed", "AmberButton", box(Color(0.4, 0.26, 0.05, 1.0), AMBER))
	t.set_stylebox("focus", "AmberButton", empty_style())
	t.set_color("font_color", "AmberButton", AMBER)
	t.set_color("font_hover_color", "AmberButton", Color(1.0, 0.9, 0.6))
	t.set_color("font_pressed_color", "AmberButton", Color(1.0, 0.95, 0.8))
	t.set_color("font_hover_pressed_color", "AmberButton", Color(1.0, 0.95, 0.8))

	# Check boxes
	var ck_on := _tex_check(18, true, GREEN)
	var ck_off := _tex_check(18, false, GREEN_DIM)
	t.set_icon("checked", "CheckBox", ck_on)
	t.set_icon("unchecked", "CheckBox", ck_off)
	t.set_icon("checked_disabled", "CheckBox", _tex_check(18, true, GREEN_FAINT))
	t.set_icon("unchecked_disabled", "CheckBox", _tex_check(18, false, GREEN_FAINT))
	t.set_icon("radio_checked", "CheckBox", _tex_radio(18, true, GREEN))
	t.set_icon("radio_unchecked", "CheckBox", _tex_radio(18, false, GREEN_DIM))
	for st in ["normal", "pressed", "hover", "hover_pressed", "disabled", "focus"]:
		t.set_stylebox(st, "CheckBox", empty_style(4.0))
	t.set_color("font_color", "CheckBox", GREEN)
	t.set_color("font_hover_color", "CheckBox", GREEN_BRIGHT)
	t.set_color("font_pressed_color", "CheckBox", GREEN)
	t.set_color("font_hover_pressed_color", "CheckBox", GREEN_BRIGHT)
	t.set_color("font_focus_color", "CheckBox", GREEN)
	t.set_constant("h_separation", "CheckBox", 8)

	# Option button + popup
	t.set_icon("arrow", "OptionButton", _tex_arrow(12, 7, GREEN))
	t.set_constant("arrow_margin", "OptionButton", 8)
	t.set_stylebox("normal", "OptionButton", box(BG_BUTTON, BORDER_DIM))
	t.set_stylebox("hover", "OptionButton", box(BG_BUTTON_HOVER, BORDER))
	t.set_stylebox("pressed", "OptionButton", box(BG_BUTTON_PRESSED, GREEN))
	t.set_stylebox("focus", "OptionButton", empty_style())
	t.set_stylebox("panel", "PopupMenu", box(Color(0.01, 0.05, 0.025, 0.98), BORDER, 1, 6, 6))
	t.set_stylebox("hover", "PopupMenu", box(BG_BUTTON_PRESSED, Color(0, 0, 0, 0), 0))
	t.set_color("font_color", "PopupMenu", GREEN)
	t.set_color("font_hover_color", "PopupMenu", AMBER)
	t.set_color("font_disabled_color", "PopupMenu", GREEN_FAINT)
	t.set_icon("radio_checked", "PopupMenu", _tex_radio(16, true, AMBER))
	t.set_icon("radio_unchecked", "PopupMenu", _tex_radio(16, false, GREEN_DIM))
	t.set_icon("checked", "PopupMenu", _tex_check(16, true, AMBER))
	t.set_icon("unchecked", "PopupMenu", _tex_check(16, false, GREEN_DIM))
	t.set_constant("v_separation", "PopupMenu", 8)

	# Sliders
	var track := box(Color(0.03, 0.1, 0.05, 1.0), BORDER_DIM, 1, 0.0, 3.0)
	var area := box(Color(0.18, 0.55, 0.28, 0.9), Color(0, 0, 0, 0), 0, 0.0, 3.0)
	var area_h := box(Color(0.26, 0.72, 0.38, 0.95), Color(0, 0, 0, 0), 0, 0.0, 3.0)
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", area)
	t.set_stylebox("grabber_area_highlight", "HSlider", area_h)
	t.set_icon("grabber", "HSlider", _tex_grabber(14, 26, AMBER_DIM, AMBER))
	t.set_icon("grabber_highlight", "HSlider", _tex_grabber(14, 26, AMBER, Color(1.0, 0.95, 0.8)))
	t.set_icon("grabber_disabled", "HSlider", _tex_grabber(14, 26, GREEN_FAINT, GREEN_DIM))
	t.set_icon("tick", "HSlider", _tex_empty())
	t.set_stylebox("focus", "HSlider", empty_style())

	# Scroll bars
	t.set_stylebox("scroll", "VScrollBar", box(Color(0.02, 0.07, 0.035, 0.8), Color(0, 0, 0, 0), 0, 3.0, 0.0))
	t.set_stylebox("scroll_focus", "VScrollBar", box(Color(0.02, 0.07, 0.035, 0.8), Color(0, 0, 0, 0), 0, 3.0, 0.0))
	t.set_stylebox("grabber", "VScrollBar", box(GREEN_FAINT, Color(0, 0, 0, 0), 0, 3.0, 0.0))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(GREEN_DIM, Color(0, 0, 0, 0), 0, 3.0, 0.0))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(GREEN, Color(0, 0, 0, 0), 0, 3.0, 0.0))
	t.set_icon("increment", "VScrollBar", _tex_empty())
	t.set_icon("decrement", "VScrollBar", _tex_empty())
	t.set_stylebox("panel", "ScrollContainer", empty_style())

	# Separators
	var sep := StyleBoxLine.new()
	sep.color = Color(GREEN_FAINT, 0.8)
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 8)
	var vsep := StyleBoxLine.new()
	vsep.color = Color(GREEN_FAINT, 0.8)
	vsep.thickness = 1
	vsep.vertical = true
	t.set_stylebox("separator", "VSeparator", vsep)
	t.set_constant("separation", "VSeparator", 12)

	# Tooltips
	t.set_stylebox("panel", "TooltipPanel", box(Color(0.01, 0.05, 0.025, 0.97), BORDER, 1, 8, 5))
	t.set_color("font_color", "TooltipLabel", GREEN)

	# Rich text
	t.set_color("default_color", "RichTextLabel", GREEN)
	t.set_font("normal_font", "RichTextLabel", font())
	t.set_font("bold_font", "RichTextLabel", font(true))
	t.set_font_size("normal_font_size", "RichTextLabel", FONT_SIZE)
	t.set_font_size("bold_font_size", "RichTextLabel", FONT_SIZE)

	_theme = t
	return t


# ---------------------------------------------------------------- formatting (localized)

static func tr_key(key: String) -> String:
	return Game.tr_key(key)


static func _is_ru() -> bool:
	return Game.lang == "ru"


## Fixed-decimals number with locale separators (ru: "15 000,5", en: "15,000.5").
static func fmt_fixed(v: float, decimals: int, trim: bool = false) -> String:
	if is_nan(v) or is_inf(v):
		return "—"
	var neg := v < 0.0
	var s := ("%." + str(maxi(decimals, 0)) + "f") % absf(v)
	var ip := s
	var fp := ""
	var dot := s.find(".")
	if dot >= 0:
		ip = s.substr(0, dot)
		fp = s.substr(dot + 1)
	if trim:
		while fp.ends_with("0"):
			fp = fp.substr(0, fp.length() - 1)
	var gsep := " " if _is_ru() else ","
	var grouped := ""
	var n := ip.length()
	for i in n:
		grouped += ip[i]
		var rem := n - 1 - i
		if rem > 0 and rem % 3 == 0 and n > 4:
			grouped += gsep
	var out := grouped
	if fp != "":
		out += ("," if _is_ru() else ".") + fp
	if neg and out.strip_edges() != "0":
		out = "−" + out
	return out


## Number with `sig` significant digits, trailing zeros trimmed.
static func fmt_sig(v: float, sig: int = 3) -> String:
	if v == 0.0:
		return "0"
	var mag := floori(log(absf(v)) / log(10.0))
	var dec := clampi(sig - 1 - mag, 0, 5)
	return fmt_fixed(v, dec, true)


## Distance in metres -> "640 м" / "2,35 км" / "25,0 км" / "150 км".
static func fmt_dist_m(m: float) -> String:
	if is_nan(m) or is_inf(m):
		return "—"
	if m < 1000.0:
		var r := m
		if m >= 100.0:
			r = roundf(m / 10.0) * 10.0
		return fmt_fixed(r, 0) + " " + tr_key("unit.m")
	return fmt_km(m / 1000.0)


## Round distances for scale bars and ring legends, trailing zeros trimmed: "500 м", "5 км", "2,5 км".
static func fmt_dist_round(m: float) -> String:
	if is_nan(m) or is_inf(m):
		return "—"
	if m < 1000.0:
		return fmt_sig(m, 3) + " " + tr_key("unit.m")
	return fmt_sig(m / 1000.0, 3) + " " + tr_key("unit.km")


static func fmt_km(km: float) -> String:
	var dec := 2
	if km >= 100.0:
		dec = 0
	elif km >= 10.0:
		dec = 1
	return fmt_fixed(km, dec) + " " + tr_key("unit.km")


## Short yield for lists: "0,1 т", "18 т", "0,3 кт", "15 кт", "1,2 Мт", "50 Мт".
static func fmt_yield_short(w_kt: float, nuclear: bool) -> String:
	if w_kt >= 1000.0:
		return fmt_sig(w_kt / 1000.0, 3) + " " + tr_key("unit.mt")
	if w_kt >= 0.1 or (nuclear and w_kt >= 0.01):
		return fmt_sig(w_kt, 3) + " " + tr_key("unit.kt")
	return fmt_sig(w_kt * 1000.0, 3) + " " + tr_key("unit.t")


## Full yield with the TNT equivalent in tonnes: "15 кт (15 000 т ТНТ)".
static func fmt_yield_full(w_kt: float, nuclear: bool) -> String:
	var tonnes := fmt_sig(w_kt * 1000.0, 4) + " " + tr_key("unit.t") + " " + tr_key("ui.tnt")
	if w_kt >= 0.1 or nuclear:
		return fmt_yield_short(w_kt, true) + " (" + tonnes + ")"
	return tonnes


static func fmt_seconds(s: float, dec: int = 1) -> String:
	return fmt_fixed(s, dec) + " " + tr_key("unit.s")


static func fmt_psi(p: float) -> String:
	if p > 0.0 and p < 0.01:
		return "< " + fmt_fixed(0.01, 2) + " psi"
	if p >= 100.0:
		return fmt_fixed(p, 0) + " psi"
	if p >= 10.0:
		return fmt_fixed(p, 1) + " psi"
	return fmt_fixed(p, 2) + " psi"


static func fmt_signed_deg(d: float) -> String:
	var r := roundi(d)
	if r > 0:
		return "+" + str(r) + "°"
	if r < 0:
		return "−" + str(-r) + "°"
	return "0°"
