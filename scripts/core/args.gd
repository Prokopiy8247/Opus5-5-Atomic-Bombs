class_name Args
extends RefCounted
## Parses user command-line arguments (everything after `--`).
## Example: -- --bomb 11 --dist 25 --tod dawn --humidity 0.7 --quality high --shots 0.1,1,5 --out C:/tmp/x --quit

static var _cache: Dictionary = {}
static var _parsed := false


static func get_all() -> Dictionary:
	if _parsed:
		return _cache
	_parsed = true
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		var s: String = a[i]
		if s.begins_with("--"):
			var key := s.substr(2)
			if key.contains("="):
				var kv := key.split("=", true, 1)
				_cache[kv[0]] = kv[1]
			elif i + 1 < a.size() and not String(a[i + 1]).begins_with("--"):
				_cache[key] = a[i + 1]
				i += 1
			else:
				_cache[key] = "true"
		i += 1
	return _cache


static func has(key: String) -> bool:
	return get_all().has(key)


static func get_str(key: String, def: String = "") -> String:
	return String(get_all().get(key, def))


static func get_float(key: String, def: float = 0.0) -> float:
	if not has(key):
		return def
	return get_str(key).to_float()


static func get_int(key: String, def: int = 0) -> int:
	if not has(key):
		return def
	return get_str(key).to_int()


static func get_float_list(key: String) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	if not has(key):
		return out
	for p in get_str(key).split(",", false):
		out.append(p.strip_edges().to_float())
	return out
