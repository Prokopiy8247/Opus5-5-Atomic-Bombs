extends Node
## Global state and settings (autoload "Game").

signal settings_changed
signal language_changed
signal bomb_selected(index: int)

enum Quality { LOW, MEDIUM, HIGH, CINEMATIC }
enum TimeOfDay { DAWN, NOON, DUSK, NIGHT }

const TOD_NAMES := ["dawn", "noon", "dusk", "night"]
const QUALITY_NAMES := ["low", "medium", "high", "cine"]

var bombs: Array = []              # parsed data/bombs.json "bombs"
var locale: Dictionary = {}        # parsed data/locale.json
var lang := "ru"

var selected_bomb := 10            # 0-based index
var distance_km := 25.0
var azimuth_deg := 0.0
var tod: int = TimeOfDay.NOON
var humidity := 0.55
var quality: int = Quality.HIGH
var auto_quality := true
var time_scale := 1.0
var paused := false
var hud_visible := true
var film_grain := true
var high_clouds := true
var snow_override := -1            # -1 auto (per bomb), 0 off, 1 on

var is_movie := false
var is_test_rig := false


func _init() -> void:
	is_movie = OS.has_feature("movie")
	_load_data()


func _load_data() -> void:
	var f := FileAccess.open("res://data/bombs.json", FileAccess.READ)
	if f:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			bombs = parsed.get("bombs", [])
	else:
		push_error("Cannot open res://data/bombs.json")
	var lf := FileAccess.open("res://data/locale.json", FileAccess.READ)
	if lf:
		var lp: Variant = JSON.parse_string(lf.get_as_text())
		if lp is Dictionary:
			locale = lp
	else:
		push_error("Cannot open res://data/locale.json")


func bomb(i: int = -1) -> Dictionary:
	if i < 0:
		i = selected_bomb
	if i < 0 or i >= bombs.size():
		return {}
	return bombs[i]


func tr_key(key: String) -> String:
	var table: Dictionary = locale.get("strings", {})
	if table.has(key):
		var e: Dictionary = table[key]
		return String(e.get(lang, e.get("en", key)))
	return key


func bomb_text(b: Dictionary, field: String) -> String:
	# fields stored as {"ru": "...", "en": "..."}
	var v: Variant = b.get(field, "")
	if v is Dictionary:
		return String(v.get(lang, v.get("en", "")))
	return String(v)


func set_language(l: String) -> void:
	lang = l
	language_changed.emit()


func toggle_language() -> void:
	set_language("en" if lang == "ru" else "ru")


func select_bomb(i: int) -> void:
	selected_bomb = clampi(i, 0, bombs.size() - 1)
	bomb_selected.emit(selected_bomb)


func quality_steps_scale() -> float:
	match quality:
		Quality.LOW:
			return 0.5
		Quality.MEDIUM:
			return 0.75
		Quality.HIGH:
			return 1.0
		_:
			return 2.0
