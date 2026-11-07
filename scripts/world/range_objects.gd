extends Node3D
## Instrumented test-range structures (wooden and brick houses, trees and junipers, cars,
## trucks, tanks, a lattice tower and 120 ft masts, utility lines, a bridge over a dry wash,
## concrete bunkers, a hangar with parked aircraft, rail cars) laid out in overpressure rings
## around ground zero and destroyed by the blast in the physically correct order
## (docs/02_PHYSICS_REFERENCE.md section 6).
##
## Everything moves in shaders/destructible.gdshader as a pure function of the global uniform
## g_blast_age (scrubbable, pausable, deterministic). Per instance the CPU stores
## (shock arrival s, peak overpressure psi, ignition time s, fluence + seed) in INSTANCE_CUSTOM.
##
## API
##   setup(gz, w_kt, hob, surface, humidity, opts := {})   rebuild everything for a new target
##   clear()                                                remove all instances
##   set_age(age)                                           optional per-frame hook
##   rings() -> Array                                       [{psi, r, arrival}] placed rings
##   damage_summary(age) -> Dictionary                      CPU mirror of the main thresholds
##   instance_total() -> int
## opts (all optional): nuclear (bool, default w_kt >= 0.05), conventional (bool, default
##   not nuclear; selects the HE blast fits), blast_scale (air-blast coupling on the overpressure,
##   e.g. ExplosionProfile.blast_yield() / w_kt; arrival times always use the full w_kt, as in
##   explosion.gd), fireball_r (m), crater_r (m), exclude_r (m, keep-out radius around ground
##   zero, e.g. the Baker lagoon), density (0.2..2), seed (int).
## The node must stay at the world origin (it is top_level; instance transforms are world).

const SHADER := preload("res://shaders/destructible.gdshader")

enum { T_WOOD, T_BRICK, T_TREE, T_JUNIPER, T_CAR, T_TRUCK, T_TANK, T_TOWER, T_MAST, T_POLE,
	T_WIRE, T_BRIDGE, T_BUNKER, T_HANGAR, T_AIRCRAFT, T_RAILCAR, T_TRACK, T_COUNT }

const TYPE_NAMES := ["wood_house", "brick_house", "tree", "juniper", "car", "truck", "tank",
	"tower", "mast", "pole", "wire", "bridge", "bunker", "hangar", "aircraft", "railcar", "track"]
## shader "kind" per type
const SHADER_KIND := [0, 1, 2, 3, 4, 5, 6, 7, 7, 8, 9, 10, 11, 12, 13, 14, 15]
## collision footprint radius (m)
const FOOT := [6.0, 7.5, 3.0, 1.5, 2.6, 4.0, 4.0, 5.0, 2.0, 0.6, 0.0, 15.0, 9.0, 29.0, 22.0, 7.0, 0.0]
## height at which the overpressure / fluence is sampled (m)
const CENTER_H := [2.5, 3.5, 5.0, 1.5, 0.8, 1.5, 1.3, 20.0, 18.0, 5.0, 9.0, 4.0, 1.5, 7.0, 3.0, 2.2, 0.2]
## ignition material (BlastPhysics.ignition_threshold) and a multiplier on that threshold
const IGNITE := ["wood", "cotton", "leaves", "leaves", "cotton", "cotton", "", "", "", "wood",
	"", "", "", "", "cotton", "wood", ""]
const IGNITE_K := [1.0, 1.3, 1.6, 1.0, 1.4, 1.4, 1.0, 1.0, 1.0, 1.5, 1.0, 1.0, 1.0, 1.0, 2.0, 1.2, 1.0]
## smoke column source size (m; 0 = no smoke) and probability for a burning object to smoke
const SMOKE := [6.0, 5.0, 3.0, 1.4, 2.4, 3.0, 0.0, 0.0, 0.0, 0.8, 0.0, 0.0, 0.0, 0.0, 4.0, 4.0, 0.0]
const SMOKE_P := [1.0, 1.0, 0.35, 0.15, 0.8, 0.8, 0.0, 0.0, 0.0, 0.25, 0.0, 0.0, 0.0, 0.0, 0.8, 1.0, 0.0]
## dust cloud size (m; 0 = none), probability and delay after the shock arrival (s)
const DUST := [7.0, 9.0, 3.0, 0.0, 3.0, 4.0, 5.0, 7.0, 4.0, 0.0, 0.0, 14.0, 0.0, 20.0, 9.0, 6.0, 0.0]
const DUST_P := [1.0, 1.0, 0.25, 0.0, 0.7, 0.7, 1.0, 1.0, 1.0, 0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 1.0, 0.0]
const DUST_DELAY := [0.3, 0.4, 1.2, 0.0, 0.4, 0.4, 0.2, 2.6, 2.4, 0.0, 0.0, 0.8, 0.0, 0.6, 0.6, 0.8, 0.0]
const SHADOW := [true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, false]

# part ids (must match destructible.gdshader)
const P_BODY := 0
const P_GLASS := 1
const P_ROOF := 2
const P_WALL := 3
const P_LEAVES := 4
const P_TRUNK := 5
const P_WHEEL := 6
const P_FRAME := 7
const P_FOUND := 8
const P_DECK := 9
const P_PIER := 10
const P_EMBANK := 11
const P_TURRET := 12
const P_WING := 13
const P_CHIMNEY := 14
const P_STUMP := 15
const P_CLAD := 16
const P_DOOR := 17
const P_ROOT := 18
const P_GEAR := 19
const P_FIN := 20
const P_BOGIE := 21
const P_WIRE := 22
const P_SLAB := 23
const P_RAIL := 24
const P_GROUND := 25
const P_METAL := 26

const RING_PSI := [100.0, 50.0, 20.0, 10.0, 5.0, 3.0, 2.0, 1.0, 0.5]
const FIXED_R := [1000.0, 3000.0]
const GRID := 20.0
const MAX_RING_R := 120000.0
const MAX_SMOKE := 1000
const WIRE_H := 9.45
const WIRE_SAG := 0.6

var density := 1.0
var terrain_match := true
var flash_tint_gain := 1.0
var fire_gain := 1.0

var _meshes: Array = []
var _mats: Array = []
var _smoke_mesh: ArrayMesh
var _smoke_mat: ShaderMaterial
var _smoke_mmi: MultiMeshInstance3D
var _nodes: Array[Node] = []
var _buckets := {}
var _objects: Array = []        # [type, psi, arrival, seed_gpu]
var _smoke_list: Array = []     # [Vector3 pos, Color custom]
var _grid := {}
var _rings: Array = []
var _rng := RandomNumberGenerator.new()
var _terrain: Node = null
var _focus := Vector3.ZERO
var _age := -1.0
var _min_ign := INF

var _gz := Vector3.ZERO
var _gz2 := Vector2.ZERO
var _burst := Vector3.ZERO
var _w := 1.0
var _w_blast := 1.0
var _hob := 0.0
var _surface := false
var _humidity := 0.5
var _nuclear := true
var _t2 := 0.1
var _fb_r := 0.0
var _fb_ground := 0.0
var _crater_r := 0.0
var _r_min := 8.0
var _cell := 1000.0
var _conventional := false
var _psi_lr := PackedFloat64Array()   # log slant radius, ascending
var _psi_lp := PackedFloat64Array()   # log overpressure at that radius
var _ub := Vector2(0, 1)
var _up := Vector2(1, 0)
var _f32buf := PackedFloat32Array([0.0])
var _imp := 1.0


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_ensure_assets()


# =================================================================== public API

func setup(gz: Vector3, w_kt: float, hob: float, surface: bool, humidity: float, opts: Dictionary = {}) -> void:
	_ensure_assets()
	clear()
	_gz = gz
	_gz2 = Vector2(gz.x, gz.z)
	_w = maxf(w_kt, 1e-7)
	_hob = hob
	_surface = surface
	_humidity = humidity
	_nuclear = bool(opts.get("nuclear", w_kt >= 0.05))
	_conventional = bool(opts.get("conventional", not _nuclear))
	_w_blast = _w * float(opts.get("blast_scale", 1.0))
	var hob_eff := maxf(hob, 0.0)
	_burst = gz + Vector3(0, hob_eff, 0)
	if _nuclear:
		_t2 = BlastPhysics.t_second_max(_w)
		_fb_r = float(opts.get("fireball_r", BlastPhysics.fireball_r_max(_w, surface)))
	else:
		var kg := _w * 1.0e6
		_t2 = maxf(BlastPhysics.conventional_fireball_duration(kg) * 0.3, 0.01)
		_fb_r = float(opts.get("fireball_r", BlastPhysics.conventional_fireball_radius(kg)))
	if hob < 0.0:
		_fb_r = float(opts.get("fireball_r", 0.0))
	_fb_ground = sqrt(maxf(_fb_r * _fb_r - hob_eff * hob_eff, 0.0))
	var def_crater := 0.0
	if surface or hob < 0.0:
		if _nuclear:
			def_crater = BlastPhysics.crater_radius_nuclear(_w)
		else:
			def_crater = BlastPhysics.crater_diameter_conventional(_w * 1000.0) * 0.5
	_crater_r = float(opts.get("crater_r", def_crater))
	var game: Node = null
	var ml := Engine.get_main_loop() as SceneTree
	if ml != null and ml.root != null:
		game = ml.root.get_node_or_null("Game")
	if game != null and not opts.has("density"):
		var qi := clampi(int(game.get("quality")), 0, 3)
		density = [0.55, 0.8, 1.0, 1.25][qi]
	density = clampf(float(opts.get("density", density)), 0.2, 2.0)
	var seed_v: int = int(opts.get("seed", hash(Vector3i(roundi(gz.x), roundi(gz.z), roundi(log(_w) * 100.0)))))
	_rng.seed = seed_v
	var gl := _gz2.length()
	_ub = (-_gz2 / gl) if gl > 1.0 else Vector2(0, 1)
	_up = Vector2(-_ub.y, _ub.x)
	_r_min = maxf(maxf(_fb_ground * 1.15, _crater_r * 1.6), 8.0)
	# e.g. the Baker lagoon: nothing is placed inside this ground radius
	_r_min = maxf(_r_min, float(opts.get("exclude_r", 0.0)))
	_build_psi_table()
	_imp = clampf(sqrt(pow(_w_blast, 1.0 / 3.0) / 2.466), 0.25, 2.0)
	var r1psi := _ring_r(1.0)
	_cell = clampf((r1psi if r1psi > 0.0 else 2000.0) / 3.0, 400.0, 15000.0)
	_layout()
	_commit()
	_update_material_params()
	_focus = Vector3(INF, INF, INF)
	_terrain_searched = false
	_update_focus(true)


func clear() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	_buckets.clear()
	_objects.clear()
	_smoke_list.clear()
	_grid.clear()
	_rings.clear()
	_pole_positions.clear()
	_smoke_mmi = null
	_min_ign = INF


func set_age(age: float) -> void:
	_age = age


func rings() -> Array:
	return _rings.duplicate(true)


func instance_total() -> int:
	return _objects.size()


## Counts per object type: total, reached by the shock, damaged, destroyed at the given age.
## Uses the same per-instance thresholds as the shader (main failure modes only).
func damage_summary(age: float) -> Dictionary:
	var out := {}
	for o in _objects:
		var t: int = o[0]
		var nm: String = TYPE_NAMES[t]
		if not out.has(nm):
			out[nm] = {"total": 0, "hit": 0, "damaged": 0, "destroyed": 0}
		var d: Dictionary = out[nm]
		d["total"] += 1
		if age < 0.0 or age < float(o[2]):
			continue
		d["hit"] += 1
		var st := state_for(t, float(o[1]), float(o[3]))
		if st >= 1:
			d["damaged"] += 1
		if st >= 2:
			d["destroyed"] += 1
	return out


## 0 intact (at most glass), 1 damaged, 2 destroyed / displaced. Mirrors the shader thresholds.
static func state_for(t: int, psi: float, seed: float) -> int:
	if psi >= 999.0:
		return 2
	var dmg := 1e9
	var des := 1e9
	match t:
		T_WOOD:
			# roof peeled 2-3 psi, frame collapsed 2.9-4 psi (blown away at 4.8-5.8)
			dmg = 2.0 + rr(seed, 1.0)
			des = 2.9 + 1.1 * rr(seed, 2.0)
		T_BRICK:
			dmg = 3.0 + 0.6 * rr(seed, 1.0)
			des = 5.0 + 2.0 * rr(seed, 2.0)
		T_TREE:
			dmg = 1.2
			des = 2.35 + 2.3 * rr(seed, 1.0)
		T_JUNIPER:
			dmg = 3.0
			des = 5.0 + 4.0 * rr(seed, 1.0)
		T_CAR:
			dmg = 1.0
			des = 4.5 + 1.5 * rr(seed, 1.0)
		T_TRUCK:
			dmg = 1.0
			des = 5.0 + 2.0 * rr(seed, 1.0)
		T_TANK:
			dmg = 30.0 + 15.0 * rr(seed, 1.0)
			des = 70.0 + 40.0 * rr(seed, 2.0)
		T_TOWER, T_MAST:
			dmg = 1.3
			des = 4.5 + 1.5 * rr(seed, 1.0)
		T_POLE:
			dmg = 2.0
			des = pole_threshold(seed)
		T_BRIDGE:
			dmg = 10.0
			des = 18.0
		T_BUNKER:
			dmg = 100.0 + 60.0 * rr(seed, 1.0)
			des = 220.0 + 60.0 * rr(seed, 2.0)
		T_HANGAR:
			dmg = 1.5
			des = 3.1 + 0.6 * rr(seed, 1.0)
		T_AIRCRAFT:
			dmg = 1.0
			des = 2.0 + rr(seed, 1.0)
		T_RAILCAR:
			dmg = 6.0 + 0.8 * rr(seed, 1.0)
			des = 6.8 + 1.4 * rr(seed, 2.0)
		T_WIRE, T_TRACK:
			return 0
	if psi >= des:
		return 2
	if psi >= dmg:
		return 1
	return 0


static func rr(seed: float, k: float) -> float:
	return fposmod(seed * (1.0 + 6.17 * k) + 0.31 * k, 1.0)


static func pole_threshold(seed: float) -> float:
	return 4.0 + 3.0 * seed


# =================================================================== per frame

func _process(_delta: float) -> void:
	_update_focus(false)


func _update_focus(force: bool) -> void:
	if not is_inside_tree() or _mats.is_empty():
		return
	var p := _focus
	if not _terrain_searched or (_terrain != null and not is_instance_valid(_terrain)):
		_terrain_searched = true
		_terrain = get_tree().root.find_child("Terrain", true, false)
		if _terrain != null and not (_terrain.get("_focus") is Vector3):
			_terrain = null
	if _terrain != null:
		p = _terrain.get("_focus")
	else:
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		var cp := cam.global_position
		if force or cp.distance_squared_to(_focus) >= 0.25:
			p = cp
	if force or p != _focus:
		_focus = p
		for m in _mats:
			(m as ShaderMaterial).set_shader_parameter("terrain_focus", p)


func _update_material_params() -> void:
	var imp := _imp
	var th := _th_table()
	for m in _mats:
		var sm := m as ShaderMaterial
		sm.set_shader_parameter("burst_pos", _burst)
		sm.set_shader_parameter("t2", _t2)
		sm.set_shader_parameter("th_cdf", th)
		sm.set_shader_parameter("imp", imp)
		sm.set_shader_parameter("terrain_match", 1.0 if terrain_match else 0.0)
		sm.set_shader_parameter("flash_tint_gain", flash_tint_gain)
		sm.set_shader_parameter("fire_gain", fire_gain)
	_smoke_mat.set_shader_parameter("burst_pos", _burst)
	_smoke_mat.set_shader_parameter("w13", pow(_w_blast, 1.0 / 3.0))


# =================================================================== physics helpers

## Overpressure vs slant distance, tabulated by inverting BlastPhysics.radius_for_pressure
## (BlastPhysics.overpressure bisects that same function; the table keeps setup fast).
func _build_psi_table() -> void:
	_psi_lr = PackedFloat64Array()
	_psi_lp = PackedFloat64Array()
	var n := 160
	for i in n:
		var lp := lerpf(log(1.0e5), log(0.005), float(i) / (n - 1))
		var r := BlastPhysics.radius_for_pressure(_w_blast, exp(lp), _surface, _conventional)
		var lr := log(maxf(r, 1e-3))
		if _psi_lr.size() > 0 and lr <= _psi_lr[_psi_lr.size() - 1]:
			continue
		_psi_lr.append(lr)
		_psi_lp.append(lp)


## Peak overpressure (psi) at a slant distance from the burst point.
func psi_at(slant: float) -> float:
	var lr := log(maxf(slant, 0.01))
	var n := _psi_lr.size()
	if n < 2:
		return BlastPhysics.overpressure(_w_blast, slant, _surface, _conventional)
	if lr <= _psi_lr[0]:
		return exp(_psi_lp[0])
	if lr >= _psi_lr[n - 1]:
		return exp(_psi_lp[n - 1] - (lr - _psi_lr[n - 1]))
	var lo := 0
	var hi := n - 1
	while hi - lo > 1:
		var mid := (lo + hi) >> 1
		if _psi_lr[mid] <= lr:
			lo = mid
		else:
			hi = mid
	var f := (lr - _psi_lr[lo]) / (_psi_lr[hi] - _psi_lr[lo])
	return exp(lerpf(_psi_lp[lo], _psi_lp[hi], f))


## Shock arrival time (s) at a slant distance from the burst point. Uses the full yield, exactly
## like explosion.gd (bunker shock time, visible ground shock ring); blast_scale only reduces
## the overpressure, so objects fail exactly when the visible front passes them.
func arrival_at(slant: float) -> float:
	return BlastPhysics.arrival_time(_w, maxf(slant, 0.01), _surface, _conventional)


## Ground distance from ground zero at which the given overpressure is reached (-1: never).
func _ring_r(p_psi: float) -> float:
	var R := BlastPhysics.radius_for_pressure(_w_blast, p_psi, _surface, _conventional)
	var h := maxf(_hob, 0.0) + 2.0
	if R <= h:
		return -1.0
	return sqrt(R * R - h * h)


const TH_N := 32
const TH_LO := -2.0      # log10(t / t2) range of the thermal CDF table passed to the shader
const TH_HI := 2.0


## Fraction of the thermal energy received by x = t / t2 (the BlastPhysics pulse; the same
## normalised curve serves as a short flash for conventional charges).
func _th_frac(x: float) -> float:
	if x <= 0.0:
		return 0.0
	return BlastPhysics.thermal_fraction(1.0, x * BlastPhysics.t_second_max(1.0))


func _th_table() -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(TH_N)
	for i in TH_N:
		a[i] = _th_frac(pow(10.0, lerpf(TH_LO, TH_HI, float(i) / (TH_N - 1))))
	return a


func _ign_time(q: float, thr: float) -> float:
	if thr <= 0.0 or q <= thr:
		return -1.0
	var target := thr / q
	var lo := 0.0
	var hi := 100.0
	for i in 34:
		var mid := 0.5 * (lo + hi)
		if _th_frac(mid) < target:
			lo = mid
		else:
			hi = mid
	return hi * _t2


func _f32(x: float) -> float:
	_f32buf[0] = x
	return _f32buf[0]


# =================================================================== layout

func _dir(phi_deg: float) -> Vector2:
	var a := deg_to_rad(phi_deg)
	return _ub * cos(a) + _up * sin(a)


func _site_ok(xz: Vector2, foot: float) -> bool:
	if xz.y > 0.0:
		return false
	if xz.length() < 300.0 + foot:
		return false
	var gl := _gz2.length()
	if gl > 1.0:
		var t := xz.dot(_gz2) / (gl * gl)
		if t > 0.0 and t < 1.0:
			var perp := (xz - _gz2 * t).length()
			if perp < 20.0 + foot + 0.005 * t * gl:
				return false
	if xz.distance_to(_gz2) < _r_min * 0.9:
		return false
	return _grid_free(xz, foot)


func _area_ok(xz: Vector2) -> bool:
	if TerrainMath.mountain_mask(xz.x, xz.y) > 0.02:
		return false
	if xz.y > 0.0 or xz.length() < 250.0:
		return false
	if xz.length() > 190000.0:
		return false
	var nrm := TerrainMath.normal_at(xz.x, xz.y, 4.0)
	return nrm.y > 0.985


func _grid_free(xz: Vector2, r: float) -> bool:
	if r <= 0.0:
		return true
	var reach := int(ceil((r + 30.0) / GRID))
	var cx := floori(xz.x / GRID)
	var cz := floori(xz.y / GRID)
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			var arr: Variant = _grid.get(Vector2i(cx + dx, cz + dz))
			if arr == null:
				continue
			for e: Vector3 in arr:
				if xz.distance_to(Vector2(e.x, e.y)) < r + e.z:
					return false
	return true


func _occupy(xz: Vector2, r: float) -> void:
	if r <= 0.0:
		return
	var key := Vector2i(floori(xz.x / GRID), floori(xz.y / GRID))
	if not _grid.has(key):
		_grid[key] = []
	(_grid[key] as Array).append(Vector3(xz.x, xz.y, r))


func _place(type: int, xz: Vector2, yaw: float, scale: float = 1.0, check: bool = true) -> int:
	var foot: float = FOOT[type] * scale
	if check and not _site_ok(xz, foot):
		return -1
	_occupy(xz, foot)
	var y := TerrainMath.height(xz.x, xz.y)
	var pos := Vector3(xz.x, y, xz.y)
	_last_pos = pos
	var b := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
	return _add_instance(type, Transform3D(b, pos), pos + Vector3(0, CENTER_H[type] * scale, 0))


func _add_instance(type: int, xf: Transform3D, sample: Vector3) -> int:
	var slant := maxf(sample.distance_to(_burst), 0.5)
	var ground_d := Vector2(sample.x - _gz.x, sample.z - _gz.z).length()
	var psi := psi_at(slant)
	var arr := arrival_at(slant)
	var oblit := (_fb_r > 0.0 and slant < _fb_r * 0.92) or (_crater_r > 0.0 and ground_d < _crater_r * 1.35)
	if oblit:
		psi = 1000.0
	var q := 0.0
	if _nuclear and _hob >= 0.0:
		q = BlastPhysics.thermal_fluence(_w, slant, _humidity)
	if _fb_r > 0.0 and slant < _fb_r * 1.3 and _hob >= 0.0:
		q = maxf(q, 60.0)
	q = minf(q, 9999.0)
	var ign := -1.0
	var mat: String = IGNITE[type]
	if mat != "" and q > 0.0:
		ign = _ign_time(q, BlastPhysics.ignition_threshold(_w, mat) * float(IGNITE_K[type]))
	var seed := _rng.randf()
	var wv := _f32(floorf(q) + seed * 0.999)
	var seed_gpu := wv - floorf(wv)
	_push(type, xf, Color(arr, minf(psi, 1000.0), ign, wv))
	_objects.append([type, psi, arr, seed_gpu])
	var ss: float = SMOKE[type]
	if ign >= 0.0 and ss > 0.0 and psi < 999.0 and _smoke_list.size() < MAX_SMOKE and _rng.randf() < float(SMOKE_P[type]):
		var veg := type == T_TREE or type == T_JUNIPER
		var sz := ss * xf.basis.get_scale().x * _rng.randf_range(0.8, 1.25)
		var delay := _rng.randf_range(0.3, 2.5)
		var top := xf.origin + Vector3(0, CENTER_H[type] * 0.6, 0)
		var cw := _f32(floorf(minf(psi, 500.0) * 10.0) + _rng.randf() * 0.99)
		_smoke_list.append([top, Color(ign + delay, -sz if veg else sz, arr, cw), _move_offset(type, psi, seed_gpu, sample)])
		_min_ign = minf(_min_ign, ign + delay)
	# a dust cloud where something collapses, tumbles or crashes down
	var ds: float = DUST[type]
	if ds > 0.0 and psi < 999.0 and _smoke_list.size() < MAX_SMOKE:
		var need := 1 if (type == T_TANK or type == T_BRIDGE) else 2
		if state_for(type, psi, seed_gpu) >= need and _rng.randf() < float(DUST_P[type]):
			var dsz := ds * xf.basis.get_scale().x * _rng.randf_range(0.85, 1.2)
			var dcw := _f32(floorf(minf(psi, 500.0) * 10.0) + _rng.randf() * 0.99)
			_smoke_list.append([xf.origin, Color(arr + float(DUST_DELAY[type]), dsz + 1000.0, arr, dcw), _move_offset(type, psi, seed_gpu, sample) * 0.5])
			_min_ign = minf(_min_ign, arr)
	return _objects.size() - 1


## Approximate horizontal displacement of an object's burning / dusty core after the shock
## (mirrors the shader's main motion so smoke rises from where the wreck comes to rest).
func _move_offset(type: int, psi: float, seed: float, sample: Vector3) -> Vector2:
	var wd := sample - _burst
	var h := Vector2(wd.x, wd.z)
	var hl := h.length()
	if hl < 0.01 or psi >= 999.0:
		return Vector2.ZERO
	var hfs := smoothstep(0.15, 0.75, hl / maxf(wd.length(), 1.0))
	var push := h / hl
	var S := 0.0
	match type:
		T_CAR, T_TRUCK:
			var tthr := 4.5 + 1.5 * rr(seed, 1.0) if type == T_CAR else 5.0 + 2.0 * rr(seed, 1.0)
			if psi >= tthr:
				var x := clampf((psi - tthr) / 25.0, 0.0, 1.0)
				S = minf((2.0 + 2.2 * (psi - tthr) + 30.0 * x) * _imp * hfs, 150.0)
		T_WOOD:
			var blow := 4.8 + rr(seed, 3.0)
			if psi >= blow:
				S = 0.5 * (10.0 + 25.0 * clampf((psi - blow) / 5.0, 0.0, 1.0) + 90.0 * clampf((psi - 10.0) / 30.0, 0.0, 1.0)) * _imp * (0.15 + 0.85 * hfs)
			elif psi >= 2.9 + 1.1 * rr(seed, 2.0):
				S = 2.0 * hfs
		T_RAILCAR:
			if psi >= 9.0 + 1.5 * rr(seed, 3.0):
				S = minf((5.0 + 2.0 * (psi - 9.0)) * _imp * hfs, 100.0)
			elif psi >= 6.8 + 1.4 * rr(seed, 2.0):
				S = 2.0 * _imp * hfs
		T_AIRCRAFT:
			var thr := 2.0 + rr(seed, 1.0)
			if psi >= thr:
				S = minf((8.0 + 25.0 * (psi - thr)) * _imp * hfs, 250.0)
		T_TREE:
			if psi >= 2.35 + 2.3 * rr(seed, 1.0):
				S = 6.0 * hfs
		T_JUNIPER:
			if psi >= 5.0 + 4.0 * rr(seed, 1.0):
				S = 1.5 * hfs
	return push * S


func _push(type: int, xf: Transform3D, cu: Color) -> void:
	var o := xf.origin
	var key := "%d_%d_%d" % [type, floori(o.x / _cell), floori(o.z / _cell)]
	if not _buckets.has(key):
		_buckets[key] = {"type": type, "xf": [], "cu": []}
	var b: Dictionary = _buckets[key]
	(b["xf"] as Array).append(xf)
	(b["cu"] as Array).append(cu)


func _layout() -> void:
	# --- the rings of the bomb's own pressure radii
	var prev_r := -1.0
	var ring_i := 0
	for p: float in RING_PSI:
		var r := _ring_r(p)
		if r < _r_min or r > MAX_RING_R:
			continue
		if prev_r > 0.0 and r / prev_r < 1.22:
			continue
		prev_r = r
		_rings.append({"psi": p, "r": r, "arrival": arrival_at(sqrt(r * r + maxf(_hob, 0.0) * maxf(_hob, 0.0)))})
		var off := 11.0 * ring_i * (1.0 if ring_i % 2 == 0 else -1.0)
		for phi: float in [72.0, -72.0, 128.0, -128.0]:
			_cluster(_gz2 + _dir(phi + off) * r, p, r)
		ring_i += 1
	# --- directly beneath an air burst (regular-reflection zone: vertical push, crushed roofs)
	if _hob > 2.0 * maxf(_fb_r, 1.0):
		var rh := maxf(0.25 * _hob, _r_min)
		var ph := psi_at(sqrt(rh * rh + _hob * _hob))
		_cluster(_gz2 + _dir(95.0) * rh, ph, rh)
	# --- a few fixed-distance stations (intact for small yields)
	for rf: float in FIXED_R:
		if rf < _r_min:
			continue
		var near_ring := false
		for rg: Dictionary in _rings:
			if absf(float(rg["r"]) / rf - 1.0) < 0.2:
				near_ring = true
		if near_ring:
			continue
		var pf := psi_at(sqrt(rf * rf + maxf(_hob, 0.0) * maxf(_hob, 0.0)))
		_cluster(_gz2 + _dir(100.0) * rf, pf, rf)
		_cluster(_gz2 + _dir(-100.0) * rf, pf, rf)
	# --- special test structures at their threshold radii
	_special_bridge(_ring_r(14.0))
	_special_airfield(_ring_r(2.5), -102.0)
	_special_rail(_ring_r(7.5), 50.0)
	_special_towers()
	for e: Array in [[2.5, 100.0], [3.5, -88.0], [4.5, 160.0]]:
		_windbreak(_ring_r(float(e[0])), float(e[1]), int(round(20 * density)))


func _frame(center: Vector2) -> Array:
	var u_r := center - _gz2
	u_r = u_r / maxf(u_r.length(), 1e-3)
	return [u_r, Vector2(-u_r.y, u_r.x)]


static func _yaw_of(d: Vector2) -> float:
	# yaw that maps local +Z onto the 2D world direction d (x, z)
	return atan2(d.x, d.y)


func _try_place(type: int, center: Vector2, u_r: Vector2, u_t: Vector2, t_rng: Vector2, r_rng: Vector2,
		yaw: float, scale: float = 1.0, tries: int = 10, yaw_jitter: float = 0.08) -> int:
	for i in tries:
		var t := _rng.randf_range(t_rng.x, t_rng.y)
		var r := _rng.randf_range(r_rng.x, r_rng.y)
		var id := _place(type, center + u_t * t + u_r * r, yaw + _rng.randf_range(-yaw_jitter, yaw_jitter), scale)
		if id >= 0:
			return id
	return -1


## A test station: a short street with houses, parked vehicles, a windbreak, a pole line,
## junipers and (at high pressure) tanks and bunkers.
func _cluster(center: Vector2, p: float, r_ring: float) -> void:
	if not _area_ok(center):
		return
	var fr := _frame(center)
	var u_r: Vector2 = fr[0]
	var u_t: Vector2 = fr[1]
	var lt := clampf(0.22 * r_ring, 6.0, 260.0)
	var lr := clampf(0.07 * r_ring, 4.0, 90.0)
	var dn := density
	var n_wood := 2
	var n_brick := 1
	var n_car := 3
	var n_truck := 1
	var n_tank := 0
	var n_bunker := 0
	var n_trees := 8
	var n_juni := 12
	var n_poles := 4
	if p >= 50.0:
		n_wood = 0
		n_car = 1
		n_tank = 2
		n_bunker = 2
		n_trees = 4
		n_juni = 6
		n_poles = 0
	elif p >= 20.0:
		n_wood = 1
		n_car = 2
		n_tank = 2
		n_bunker = 1
		n_trees = 6
		n_juni = 8
	elif p >= 10.0:
		n_tank = 1
		n_bunker = 1
	elif p >= 5.0:
		n_tank = 1
	elif p < 1.5:
		n_car = 2
		n_trees = 6
		n_juni = 8
		n_poles = 3
	var face_in := _yaw_of(-u_r)
	var street := _yaw_of(u_t)
	# houses on both sides of a street running along the ring
	for i in n_wood:
		var side := 1.0 if i % 2 == 0 else -1.0
		_try_place(T_WOOD, center, u_r, u_t, Vector2(-lt * 0.8, lt * 0.8), Vector2(side * lr * 0.3, side * lr * 0.45),
			_yaw_of(-u_r * side), _rng.randf_range(0.9, 1.1))
	for i in n_brick:
		_try_place(T_BRICK, center, u_r, u_t, Vector2(-lt * 0.8, lt * 0.8), Vector2(-lr * 0.45, -lr * 0.3),
			_yaw_of(u_r), _rng.randf_range(0.92, 1.08))
	for i in n_bunker:
		_try_place(T_BUNKER, center, u_r, u_t, Vector2(-lt, lt), Vector2(-lr * 0.9, lr * 0.9), face_in, 1.0, 12, 0.1)
	for i in n_tank:
		_try_place(T_TANK, center, u_r, u_t, Vector2(-lt, lt), Vector2(-lr * 0.8, -lr * 0.4), _rng.randf() * TAU, 1.0, 10, 0.0)
	for i in int(round(n_car * dn)):
		var yaw := street + (PI if _rng.randf() < 0.5 else 0.0)
		if _rng.randf() < 0.3:
			yaw = _rng.randf() * TAU
		_try_place(T_CAR, center, u_r, u_t, Vector2(-lt, lt), Vector2(-lr * 0.12, lr * 0.12), yaw, 1.0, 10, 0.1)
	for i in n_truck:
		_try_place(T_TRUCK, center, u_r, u_t, Vector2(-lt, lt), Vector2(-lr * 0.15, lr * 0.15), street + (PI if _rng.randf() < 0.5 else 0.0))
	# windbreak row along the street
	var nt := int(round(n_trees * dn))
	var sp := 9.0
	var t0 := -sp * (nt - 1) * 0.5 + _rng.randf_range(-lt * 0.2, lt * 0.2)
	for i in nt:
		var xz := center + u_t * (t0 + i * sp + _rng.randf_range(-1.0, 1.0)) + u_r * (lr * 0.75 + _rng.randf_range(-1.0, 1.0))
		_place(T_TREE, xz, _rng.randf() * TAU, _rng.randf_range(0.8, 1.2))
	# junipers scattered around the station
	for i in int(round(n_juni * dn)):
		var xz := center + u_t * _rng.randf_range(-lt * 1.6, lt * 1.6) + u_r * _rng.randf_range(-lr * 2.0, lr * 2.0)
		_place(T_JUNIPER, xz, _rng.randf() * TAU, _rng.randf_range(0.7, 1.4))
	# utility line along the far side of the street
	if n_poles >= 2 and lt >= 20.0:
		var sp2 := clampf(2.0 * lt / (n_poles - 1), 25.0, 48.0)
		var a := -sp2 * (n_poles - 1) * 0.5
		var line: Array = []
		for i in n_poles:
			var xz := center + u_t * (a + i * sp2) - u_r * lr * 0.85
			var id := _place(T_POLE, xz, street)
			if id >= 0:
				_pole_positions[id] = _last_pos
			line.append(id)
		_wires(line, street)


## Wires between consecutive poles of one line. A span drops when one of its poles falls.
func _wires(ids: Array, yaw: float) -> void:
	for i in range(ids.size() - 1):
		var ia: int = ids[i]
		var ib: int = ids[i + 1]
		if ia < 0 or ib < 0:
			continue
		var pa := _pole_pos(ia)
		var pb := _pole_pos(ib)
		if pa.distance_to(pb) > 70.0:
			continue
		var oa: Array = _objects[ia]
		var ob: Array = _objects[ib]
		var fall_a := float(oa[1]) >= pole_threshold(float(oa[3]))
		var fall_b := float(ob[1]) >= pole_threshold(float(ob[3]))
		var drop := fall_a or fall_b
		var t_drop := INF
		if fall_a:
			t_drop = minf(t_drop, float(oa[2]))
		if fall_b:
			t_drop = minf(t_drop, float(ob[2]))
		var perp := Basis(Vector3.UP, yaw) * Vector3.RIGHT
		var b := Basis(pb - pa, Vector3.UP, perp.normalized())
		var cu := Color((t_drop + 0.5) if drop else 1e6, 100.0 if drop else 0.0, -1.0, 0.5)
		_push(T_WIRE, Transform3D(b, pa), cu)


func _pole_pos(id: int) -> Vector3:
	return _pole_positions.get(id, Vector3.ZERO)


var _pole_positions := {}
var _last_pos := Vector3.ZERO
var _terrain_searched := false


func _special_bridge(r: float) -> void:
	if r < _r_min or r > MAX_RING_R:
		return
	var best := INF
	var best_xz := Vector2.ZERO
	var found := false
	for k in 48:
		var phi := 62.0 + k * 2.2
		for sgn: float in [1.0, -1.0]:
			var xz := _gz2 + _dir(phi * sgn) * r
			if not _area_ok(xz):
				continue
			var ok := true
			for s: float in [-75.0, 0.0, 75.0]:
				for s2: float in [-1.0, 1.0]:
					if not _site_ok(xz + _frame(xz)[1] * s * s2, 15.0):
						ok = false
			if not ok:
				continue
			var w := absf(TerrainMath.fbm(xz.x * 0.00052 + 11.0, xz.y * 0.00052 + 3.0, 4))
			if w < best:
				best = w
				best_xz = xz
				found = true
	if not found:
		return
	# road axis across the wash: along the gradient of the wash noise
	var e := 25.0
	var gx := absf(TerrainMath.fbm((best_xz.x + e) * 0.00052 + 11.0, best_xz.y * 0.00052 + 3.0, 4)) - absf(TerrainMath.fbm((best_xz.x - e) * 0.00052 + 11.0, best_xz.y * 0.00052 + 3.0, 4))
	var gz := absf(TerrainMath.fbm(best_xz.x * 0.00052 + 11.0, (best_xz.y + e) * 0.00052 + 3.0, 4)) - absf(TerrainMath.fbm(best_xz.x * 0.00052 + 11.0, (best_xz.y - e) * 0.00052 + 3.0, 4))
	var axis := Vector2(gx, gz)
	if axis.length() < 1e-6 or best > 0.08:
		axis = _frame(best_xz)[1]
	axis = axis.normalized()
	# the bridge mesh runs along local +X
	var yaw := atan2(-axis.y, axis.x)
	for s in range(-4, 5):
		_occupy(best_xz + axis * (s * 18.0), 15.0)
	_place(T_BRIDGE, best_xz, yaw, 1.0, false)


func _special_airfield(r: float, phi: float) -> void:
	if r < _r_min or r > MAX_RING_R:
		return
	for k in 6:
		var ph := phi + (k * 14.0 if k % 2 == 0 else -k * 14.0)
		var c := _gz2 + _dir(ph) * r
		if not _area_ok(c):
			continue
		var fr := _frame(c)
		var u_r: Vector2 = fr[0]
		var u_t: Vector2 = fr[1]
		if not _site_ok(c - u_t * 45.0, 29.0):
			continue
		_place(T_HANGAR, c - u_t * 45.0, _yaw_of(u_t))
		for j in range(-2, 3):
			var p := c + u_t * 26.0 + u_r * (j * 48.0)
			_place(T_AIRCRAFT, p, _yaw_of(-u_t) + _rng.randf_range(-0.35, 0.35))
		return


func _special_rail(r: float, phi: float) -> void:
	if r < _r_min or r > MAX_RING_R:
		return
	for k in 6:
		var ph := phi + (k * 12.0 if k % 2 == 0 else -k * 12.0)
		var c := _gz2 + _dir(ph) * r
		if not _area_ok(c):
			continue
		var u_t: Vector2 = _frame(c)[1]
		var ok := true
		for s: float in [-75.0, 0.0, 75.0]:
			if not _site_ok(c + u_t * s, 8.0):
				ok = false
		if not ok:
			continue
		var yaw := _yaw_of(u_t)
		for j in range(-3, 4):
			_place(T_TRACK, c + u_t * (j * 25.0), yaw, 1.0, false)
		for j in range(-3, 3):
			_place(T_RAILCAR, c + u_t * ((j + 0.5) * 14.2), yaw)
		return


func _special_towers() -> void:
	var r5 := _ring_r(5.0)
	if r5 >= _r_min and r5 <= MAX_RING_R:
		for k in 5:
			var xz := _gz2 + _dir(-150.0 + k * 9.0) * r5
			if _area_ok(xz) and _place(T_TOWER, xz, _rng.randf() * TAU) >= 0:
				break
	var i := 0
	for p: float in [4.0, 5.5, 7.0]:
		var r := _ring_r(p)
		i += 1
		if r < _r_min or r > MAX_RING_R:
			continue
		for k in 5:
			var xz := _gz2 + _dir(146.0 + i * 5.0 + k * 7.0) * r
			if _area_ok(xz) and _place(T_MAST, xz, _rng.randf() * TAU) >= 0:
				break


## A radial windbreak: a row of trees pointing at ground zero, so the transition from
## standing to toppled trees is visible along the row.
func _windbreak(r: float, phi: float, n: int) -> void:
	if r < _r_min or r > MAX_RING_R or n <= 0:
		return
	var u := _dir(phi)
	var c := _gz2 + u * r
	if not _area_ok(c):
		return
	var perp := Vector2(-u.y, u.x)
	var spacing := clampf(r * 0.01, 7.0, 14.0)
	# keep the row short compared with its radius (small yields: everything is within ~100 m)
	n = mini(n, int(r * 0.6 / spacing))
	if n < 4:
		return
	for i in n:
		var rr_i := r + (i - n * 0.5) * spacing
		_place(T_TREE, _gz2 + u * rr_i + perp * _rng.randf_range(-1.2, 1.2), _rng.randf() * TAU, _rng.randf_range(0.85, 1.2))


# =================================================================== commit to the GPU

func _commit() -> void:
	for key: String in _buckets:
		var b: Dictionary = _buckets[key]
		var type: int = b["type"]
		var xfs: Array = b["xf"]
		var cus: Array = b["cu"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = false
		mm.use_custom_data = true
		mm.mesh = _meshes[type]
		mm.instance_count = xfs.size()
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for i in xfs.size():
			var xf: Transform3D = xfs[i]
			mm.set_instance_transform(i, xf)
			mm.set_instance_custom_data(i, cus[i])
			lo = lo.min(xf.origin)
			hi = hi.max(xf.origin)
			if type == T_WIRE:
				lo = lo.min(xf.origin + xf.basis.x)
				hi = hi.max(xf.origin + xf.basis.x)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%d" % [TYPE_NAMES[type], _nodes.size()]
		mmi.multimesh = mm
		mmi.material_override = _mats[type]
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if SHADOW[type] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.custom_aabb = AABB(lo - Vector3(340, 80, 340), (hi - lo) + Vector3(680, 260, 680))
		mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(mmi)
		_nodes.append(mmi)
	if not _smoke_list.is_empty():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = false
		mm.use_custom_data = true
		mm.mesh = _smoke_mesh
		mm.instance_count = _smoke_list.size()
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for i in _smoke_list.size():
			var e: Array = _smoke_list[i]
			var p: Vector3 = e[0]
			var off: Vector2 = e[2]
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.RIGHT, Vector3(off.x, 1.0, off.y), Vector3.BACK), p))
			mm.set_instance_custom_data(i, e[1])
			lo = lo.min(p)
			hi = hi.max(p)
		_smoke_mmi = MultiMeshInstance3D.new()
		_smoke_mmi.name = "smoke"
		_smoke_mmi.multimesh = mm
		_smoke_mmi.material_override = _smoke_mat
		_smoke_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_smoke_mmi.custom_aabb = AABB(lo - Vector3(800, 50, 800), (hi - lo) + Vector3(1600, 1400, 1600))
		_smoke_mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(_smoke_mmi)
		_nodes.append(_smoke_mmi)


# =================================================================== assets

func _ensure_assets() -> void:
	if not _meshes.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	_meshes.resize(T_COUNT)
	_meshes[T_WOOD] = _build_wood(rng)
	_meshes[T_BRICK] = _build_brick(rng)
	_meshes[T_TREE] = _build_tree(rng)
	_meshes[T_JUNIPER] = _build_juniper(rng)
	_meshes[T_CAR] = _build_car(rng)
	_meshes[T_TRUCK] = _build_truck(rng)
	_meshes[T_TANK] = _build_tank()
	_meshes[T_TOWER] = _build_tower()
	_meshes[T_MAST] = _build_mast()
	_meshes[T_POLE] = _build_pole()
	_meshes[T_WIRE] = _build_wire()
	_meshes[T_BRIDGE] = _build_bridge(rng)
	_meshes[T_BUNKER] = _build_bunker()
	_meshes[T_HANGAR] = _build_hangar(rng)
	_meshes[T_AIRCRAFT] = _build_aircraft(rng)
	_meshes[T_RAILCAR] = _build_railcar(rng)
	_meshes[T_TRACK] = _build_track()
	_mats.resize(T_COUNT)
	for t in T_COUNT:
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("kind", SHADER_KIND[t])
		_mats[t] = m
	_mats[T_CAR].set_shader_parameter("body_c", Vector3(0, 0.8, 0))
	_mats[T_CAR].set_shader_parameter("body_half", Vector2(0.9, 2.3))
	_mats[T_TRUCK].set_shader_parameter("body_c", Vector3(0, 1.55, 0))
	_mats[T_TRUCK].set_shader_parameter("body_half", Vector2(1.2, 3.5))
	_mats[T_TANK].set_shader_parameter("body_c", Vector3(0, 1.3, 0))
	_mats[T_TANK].set_shader_parameter("body_half", Vector2(2.1, 3.3))
	_mats[T_AIRCRAFT].set_shader_parameter("body_c", Vector3(0, 3.2, 0))
	_mats[T_AIRCRAFT].set_shader_parameter("body_half", Vector2(1.5, 15.0))
	_mats[T_AIRCRAFT].set_shader_parameter("gear_h", 1.7)
	_mats[T_RAILCAR].set_shader_parameter("body_c", Vector3(0, 2.4, 0))
	_mats[T_RAILCAR].set_shader_parameter("body_half", Vector2(1.5, 6.6))
	_mats[T_TOWER].set_shader_parameter("tower_h", 45.0)
	_mats[T_MAST].set_shader_parameter("tower_h", 36.6)
	_smoke_mesh = _build_smoke_strip()
	var sh := Shader.new()
	sh.code = SMOKE_SHADER
	_smoke_mat = ShaderMaterial.new()
	_smoke_mat.shader = sh


# ------------------------------------------------------------------- mesh builder

static var _ico_v := PackedVector3Array()
static var _ico_f := PackedInt32Array()


static func _icosphere() -> void:
	if not _ico_v.is_empty():
		return
	var t := (1.0 + sqrt(5.0)) * 0.5
	var base := [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var f0 := [0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6,
		7, 1, 8, 3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1]
	var vs: Array = []
	for v: Vector3 in base:
		vs.append(v.normalized())
	var mids := {}
	var faces: Array = []
	for i in range(0, f0.size(), 3):
		var a: int = f0[i]
		var b: int = f0[i + 1]
		var c: int = f0[i + 2]
		var ab := _ico_mid(vs, mids, a, b)
		var bc := _ico_mid(vs, mids, b, c)
		var ca := _ico_mid(vs, mids, c, a)
		faces.append_array([a, ab, ca, b, bc, ab, c, ca, bc, ab, bc, ca])
	for v: Vector3 in vs:
		_ico_v.append(v)
	for f: int in faces:
		_ico_f.append(f)


static func _ico_mid(vs: Array, mids: Dictionary, a: int, b: int) -> int:
	var key := mini(a, b) * 1000 + maxi(a, b)
	if mids.has(key):
		return mids[key]
	var m: Vector3 = ((vs[a] as Vector3) + (vs[b] as Vector3)).normalized()
	vs.append(m)
	mids[key] = vs.size() - 1
	return vs.size() - 1


class MB:
	extends RefCounted
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var cu0 := PackedFloat32Array()
	var cu1 := PackedFloat32Array()
	var idx := PackedInt32Array()
	var color := Color.WHITE
	var part := 0
	var pivot := Vector3.ZERO
	var prnd := 0.0
	var faxis := Vector3.RIGHT
	var fang := 0.0
	var ext := Vector2.ZERO
	var uv_override := Vector2(-1, -1)

	func piece(p_pivot: Vector3, p_rnd: float, p_axis: Vector3 = Vector3.RIGHT, p_ang: float = 0.0, p_ext: Vector2 = Vector2.ZERO) -> void:
		pivot = p_pivot
		prnd = p_rnd
		faxis = p_axis.normalized()
		fang = p_ang
		ext = p_ext

	func vert(p: Vector3, nn: Vector3, uv: Vector2 = Vector2(-1e9, 0)) -> int:
		verts.append(p)
		norms.append(nn.normalized())
		cols.append(Color(color.r, color.g, color.b, float(part) / 255.0))
		if uv_override.x >= 0.0:
			uvs.append(uv_override)
		elif uv.x > -1e8:
			uvs.append(uv)
		else:
			uvs.append(Vector2(p.x + p.z, p.y))
		uv2s.append(ext)
		cu0.append(pivot.x)
		cu0.append(pivot.y)
		cu0.append(pivot.z)
		cu0.append(prnd)
		cu1.append(faxis.x)
		cu1.append(faxis.y)
		cu1.append(faxis.z)
		cu1.append(fang)
		return verts.size() - 1

	func tri(a: int, b: int, c: int, nn: Vector3) -> void:
		# Godot front faces wind clockwise: flip when the geometric normal agrees with nn
		var cr := (verts[b] - verts[a]).cross(verts[c] - verts[a])
		if cr.dot(nn) > 0.0:
			idx.append(a)
			idx.append(c)
			idx.append(b)
		else:
			idx.append(a)
			idx.append(b)
			idx.append(c)

	func quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, nn: Vector3) -> void:
		var a := vert(p0, nn)
		var b := vert(p1, nn)
		var c := vert(p2, nn)
		var d := vert(p3, nn)
		tri(a, b, c, nn)
		tri(a, c, d, nn)

	func tri_flat(p0: Vector3, p1: Vector3, p2: Vector3, nn: Vector3) -> void:
		var a := vert(p0, nn)
		var b := vert(p1, nn)
		var c := vert(p2, nn)
		tri(a, b, c, nn)

	func box(center: Vector3, size: Vector3, b: Basis = Basis.IDENTITY) -> void:
		var hx := b.x * size.x * 0.5
		var hy := b.y * size.y * 0.5
		var hz := b.z * size.z * 0.5
		_face(center + hx, hy, hz, b.x)
		_face(center - hx, hy, hz, -b.x)
		_face(center + hy, hx, hz, b.y)
		_face(center - hy, hx, hz, -b.y)
		_face(center + hz, hx, hy, b.z)
		_face(center - hz, hx, hy, -b.z)

	func _face(c: Vector3, a: Vector3, bb: Vector3, nn: Vector3) -> void:
		quad(c - a - bb, c + a - bb, c + a + bb, c - a + bb, nn.normalized())

	func beam(a: Vector3, b: Vector3, w: float, d: float = -1.0) -> void:
		var dir := b - a
		var L := dir.length()
		if L < 1e-4:
			return
		var y := dir / L
		var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
		var z := x.cross(y).normalized()
		box((a + b) * 0.5, Vector3(w, L, d if d > 0.0 else w), Basis(x, y, z))

	func hexa(c: Array) -> void:
		var cen := Vector3.ZERO
		for p: Vector3 in c:
			cen += p
		cen /= 8.0
		var faces := [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]
		for f: Array in faces:
			var p0: Vector3 = c[f[0]]
			var p1: Vector3 = c[f[1]]
			var p2: Vector3 = c[f[2]]
			var p3: Vector3 = c[f[3]]
			var nn := (p2 - p0).cross(p3 - p1)
			if nn.length() < 1e-8:
				continue
			nn = nn.normalized()
			if nn.dot((p0 + p1 + p2 + p3) * 0.25 - cen) < 0.0:
				nn = -nn
			quad(p0, p1, p2, p3, nn)

	func prism(a: Vector3, b: Vector3, c: Vector3, e: Vector3) -> void:
		var cen := (a + b + c) / 3.0 + e * 0.5
		var nn := e.normalized()
		tri_flat(a + e, b + e, c + e, nn)
		tri_flat(a, b, c, -nn)
		for pair: Array in [[a, b], [b, c], [c, a]]:
			var p: Vector3 = pair[0]
			var q: Vector3 = pair[1]
			var fn := (q - p).cross(e).normalized()
			if fn.dot((p + q) * 0.5 + e * 0.5 - cen) < 0.0:
				fn = -fn
			quad(p, q, q + e, p + e, fn)

	func cyl(base: Vector3, dir: Vector3, r0: float, r1: float, seg: int, cap0: bool = false, cap1: bool = true) -> void:
		var L := dir.length()
		var ay := dir / L
		var ax := ay.cross(Vector3.RIGHT if absf(ay.x) < 0.9 else Vector3.FORWARD).normalized()
		var az := ax.cross(ay).normalized()
		var top := base + dir
		var slope := (r0 - r1) / L
		var i0 := verts.size()
		for i in seg + 1:
			var a := TAU * i / seg
			var rd := ax * cos(a) + az * sin(a)
			var nn := (rd + ay * slope).normalized()
			vert(base + rd * r0, nn)
			vert(top + rd * r1, nn)
		for i in seg:
			var a := i0 + i * 2
			var am := TAU * (i + 0.5) / seg
			var fn := ax * cos(am) + az * sin(am)
			tri(a, a + 2, a + 1, fn)
			tri(a + 1, a + 2, a + 3, fn)
		if cap1 and r1 > 0.001:
			_cap(top, ay, ax, az, r1, seg)
		if cap0 and r0 > 0.001:
			_cap(base, -ay, ax, az, r0, seg)

	func _cap(c: Vector3, nn: Vector3, ax: Vector3, az: Vector3, r: float, seg: int) -> void:
		var ci := vert(c, nn)
		var first := verts.size()
		for i in seg:
			var a := TAU * i / seg
			vert(c + (ax * cos(a) + az * sin(a)) * r, nn)
		for i in seg:
			tri(ci, first + i, first + (i + 1) % seg, nn)

	func blob(center: Vector3, radius: Vector3, lump: float, rng: RandomNumberGenerator, ico_v: PackedVector3Array, ico_f: PackedInt32Array) -> void:
		var n := ico_v.size()
		var pos := PackedVector3Array()
		pos.resize(n)
		for i in n:
			var d: Vector3 = ico_v[i]
			pos[i] = center + Vector3(d.x * radius.x, d.y * radius.y, d.z * radius.z) * (1.0 + rng.randf_range(-lump, lump))
		var nrm := PackedVector3Array()
		nrm.resize(n)
		for i in range(0, ico_f.size(), 3):
			var a: int = ico_f[i]
			var b: int = ico_f[i + 1]
			var c: int = ico_f[i + 2]
			var fn := (pos[b] - pos[a]).cross(pos[c] - pos[a])
			if fn.dot(pos[a] - center) < 0.0:
				fn = -fn
			nrm[a] += fn
			nrm[b] += fn
			nrm[c] += fn
		var base := verts.size()
		for i in n:
			vert(pos[i], nrm[i])
		for i in range(0, ico_f.size(), 3):
			var a: int = ico_f[i]
			var b: int = ico_f[i + 1]
			var c: int = ico_f[i + 2]
			var fn := (pos[b] - pos[a]).cross(pos[c] - pos[a])
			if fn.dot(pos[a] - center) < 0.0:
				fn = -fn
			tri(base + a, base + b, base + c, fn)

	func glass(center: Vector3, hu: Vector3, hv: Vector3, nn: Vector3, id: float) -> void:
		var sp := part
		var sc := color
		part = 1
		color = Color(0.05, 0.06, 0.07)
		uv_override = Vector2(id, 0.5)
		quad(center - hu - hv, center + hu - hv, center + hu + hv, center - hu + hv, nn)
		uv_override = Vector2(-1, -1)
		part = sp
		color = sc

	func commit() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = norms
		arrays[Mesh.ARRAY_COLOR] = cols
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_TEX_UV2] = uv2s
		arrays[Mesh.ARRAY_CUSTOM0] = cu0
		arrays[Mesh.ARRAY_CUSTOM1] = cu1
		arrays[Mesh.ARRAY_INDEX] = idx
		var fmt := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, fmt)
		return m


# ------------------------------------------------------------------- meshes

func _build_wood(rng: RandomNumberGenerator) -> ArrayMesh:
	_icosphere()
	var mb := MB.new()
	var W := 8.0
	var D := 6.0
	var fl := 0.15
	var hw := 2.7
	var t := 0.14
	var ridge := 2.0
	var top := fl + hw
	mb.part = P_FOUND
	mb.color = Color(0.58, 0.57, 0.54)
	mb.box(Vector3(0, -0.45, 0), Vector3(W + 0.3, 1.2, D + 0.3))
	var wall_col := Color(0.86, 0.84, 0.80)
	# front / back walls in two panels each (they break apart separately)
	for s: float in [1.0, -1.0]:
		var zf := s * (D * 0.5 + 0.012)
		for hx: float in [-1.0, 1.0]:
			var c := Vector3(hx * W * 0.25, fl + hw * 0.5, s * (D * 0.5 - t * 0.5))
			mb.part = P_WALL
			mb.color = wall_col
			mb.piece(c, rng.randf(), Vector3(s, 0, 0), PI * 0.5, Vector2(hw * 0.5, t * 0.5))
			mb.box(c, Vector3(W * 0.5, hw, t))
			mb.glass(Vector3(hx * 2.4, fl + 1.55, zf), Vector3(0.55, 0, 0), Vector3(0, 0.62, 0), Vector3(0, 0, s), rng.randf())
			if hx > 0.0 and s > 0.0:
				mb.part = P_DOOR
				mb.color = Color(0.36, 0.24, 0.16)
				mb.quad(Vector3(0.45, fl, zf), Vector3(1.4, fl, zf), Vector3(1.4, fl + 2.05, zf), Vector3(0.45, fl + 2.05, zf), Vector3(0, 0, 1))
			elif hx < 0.0 and s < 0.0:
				mb.glass(Vector3(-0.8, fl + 1.55, zf), Vector3(0.4, 0, 0), Vector3(0, 0.5, 0), Vector3(0, 0, -1), rng.randf())
	for s: float in [1.0, -1.0]:
		var c := Vector3(s * (W * 0.5 - t * 0.5), fl + hw * 0.5, 0)
		mb.part = P_WALL
		mb.color = wall_col
		mb.piece(c, rng.randf(), Vector3(0, 0, -s), PI * 0.5, Vector2(hw * 0.5, t * 0.5))
		mb.box(c, Vector3(t, hw, D - 2.0 * t))
		var x0 := s * (W * 0.5 - t)
		mb.prism(Vector3(x0, top, -D * 0.5), Vector3(x0, top, D * 0.5), Vector3(x0, top + ridge, 0), Vector3(s * t, 0, 0))
		mb.glass(Vector3(s * (W * 0.5 + 0.012), fl + 1.55, 0), Vector3(0, 0, 0.55), Vector3(0, 0.62, 0), Vector3(s, 0, 0), rng.randf())
	var alpha := atan2(ridge, D * 0.5)
	var slope_len := sqrt(ridge * ridge + D * D * 0.25) + 0.45
	for s: float in [1.0, -1.0]:
		mb.part = P_ROOF
		mb.color = Color(0.32, 0.29, 0.27)
		var mid := Vector3(0, top + ridge * 0.5, s * D * 0.25)
		var down := Vector3(0, -sin(alpha), s * cos(alpha))
		var nrm := Vector3(0, cos(alpha), s * sin(alpha))
		# each slope in three sections that tear off on their own
		for k in 3:
			var c := mid + down * 0.22 + nrm * 0.09 + Vector3((k - 1) * (W + 0.6) / 3.0, 0, 0)
			mb.piece(c, rng.randf(), Vector3(-s, 0, 0), alpha, Vector2(slope_len * 0.5, 0.09))
			mb.box(c, Vector3((W + 0.6) / 3.0, 0.16, slope_len), Basis(Vector3.RIGHT, s * alpha))
	mb.part = P_CHIMNEY
	mb.color = Color(0.46, 0.23, 0.17)
	var cc := Vector3(2.4, top + 1.3, -1.1)
	mb.piece(cc, rng.randf(), Vector3(1, 0, 0), PI * 0.5, Vector2(1.1, 0.3))
	mb.box(cc, Vector3(0.6, 2.2, 0.6))
	return mb.commit()


func _build_brick(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var W := 10.0
	var D := 8.0
	var fl := 0.2
	var H := 5.6
	var t := 0.3
	var rise := 1.95
	var ch := H * 0.5
	mb.part = P_FOUND
	mb.color = Color(0.55, 0.54, 0.51)
	mb.box(Vector3(0, -0.45, 0), Vector3(W + 0.4, 1.3, D + 0.4))
	var brick := Color(0.56, 0.29, 0.21)
	for s: float in [1.0, -1.0]:
		var cw := W / 3.0
		for i in 3:
			for j in 2:
				var c := Vector3(-W * 0.5 + cw * (i + 0.5), fl + ch * (j + 0.5), s * (D * 0.5 - t * 0.5))
				mb.part = P_WALL
				mb.color = brick
				mb.piece(c, rng.randf(), Vector3(s, 0, 0), PI * 0.5, Vector2(ch * 0.5, t * 0.5))
				mb.box(c, Vector3(cw, ch, t))
				var zf := s * (D * 0.5 + 0.012)
				if s > 0.0 and j == 0 and i == 1:
					mb.part = P_DOOR
					mb.color = Color(0.25, 0.17, 0.12)
					mb.quad(Vector3(c.x - 0.5, fl, zf), Vector3(c.x + 0.5, fl, zf), Vector3(c.x + 0.5, fl + 2.1, zf), Vector3(c.x - 0.5, fl + 2.1, zf), Vector3(0, 0, 1))
				else:
					mb.glass(Vector3(c.x, c.y + 0.1, zf), Vector3(0.55, 0, 0), Vector3(0, 0.68, 0), Vector3(0, 0, s), rng.randf())
	for s: float in [1.0, -1.0]:
		var cw := (D - 2.0 * t) / 3.0
		for i in 3:
			for j in 2:
				var c := Vector3(s * (W * 0.5 - t * 0.5), fl + ch * (j + 0.5), -(D * 0.5 - t) + cw * (i + 0.5))
				mb.part = P_WALL
				mb.color = brick
				mb.piece(c, rng.randf(), Vector3(0, 0, -s), PI * 0.5, Vector2(ch * 0.5, t * 0.5))
				mb.box(c, Vector3(t, ch, cw))
				if i == 1:
					mb.glass(Vector3(s * (W * 0.5 + 0.012), c.y + 0.1, c.z), Vector3(0, 0, 0.5), Vector3(0, 0.65, 0), Vector3(s, 0, 0), rng.randf())
		var x0 := s * (W * 0.5 - t)
		var gc := Vector3(s * (W * 0.5 - t * 0.5), fl + H + rise / 3.0, 0)
		mb.part = P_WALL
		mb.color = brick
		mb.piece(gc, rng.randf(), Vector3(0, 0, -s), PI * 0.5, Vector2(rise / 3.0, t * 0.5))
		mb.prism(Vector3(x0, fl + H, -D * 0.5), Vector3(x0, fl + H, D * 0.5), Vector3(x0, fl + H + rise, 0), Vector3(s * t, 0, 0))
	var alpha := atan2(rise, D * 0.5)
	var slope_len := sqrt(rise * rise + D * D * 0.25) + 0.5
	var top := fl + H
	for s: float in [1.0, -1.0]:
		mb.part = P_ROOF
		mb.color = Color(0.40, 0.20, 0.15)
		var mid := Vector3(0, top + rise * 0.5, s * D * 0.25)
		var down := Vector3(0, -sin(alpha), s * cos(alpha))
		var nrm := Vector3(0, cos(alpha), s * sin(alpha))
		for k in 3:
			var c := mid + down * 0.25 + nrm * 0.1 + Vector3((k - 1) * (W + 0.7) / 3.0, 0, 0)
			mb.piece(c, rng.randf(), Vector3(-s, 0, 0), alpha, Vector2(slope_len * 0.5, 0.1))
			mb.box(c, Vector3((W + 0.7) / 3.0, 0.18, slope_len), Basis(Vector3.RIGHT, s * alpha))
	mb.part = P_CHIMNEY
	mb.color = Color(0.45, 0.22, 0.16)
	var cc := Vector3(-3.0, top + 1.6, 1.2)
	mb.piece(cc, rng.randf(), Vector3(1, 0, 0), PI * 0.5, Vector2(1.2, 0.35))
	mb.box(cc, Vector3(0.7, 2.4, 0.7))
	return mb.commit()


func _build_tree(rng: RandomNumberGenerator) -> ArrayMesh:
	_icosphere()
	var mb := MB.new()
	mb.part = P_ROOT
	mb.color = Color(0.27, 0.22, 0.16)
	mb.cyl(Vector3(0, -0.5, 0), Vector3(0, 0.56, 0), 1.25, 1.1, 8, false, true)
	mb.part = P_STUMP
	mb.color = Color(0.33, 0.28, 0.23)
	mb.cyl(Vector3(0, -0.4, 0), Vector3(0, 1.65, 0), 0.3, 0.26, 7, false, false)
	mb.part = P_TRUNK
	mb.cyl(Vector3(0, 1.2, 0), Vector3(0.15, 4.6, 0.1), 0.26, 0.13, 7, false, true)
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		var b0 := Vector3(0.05, 3.4 + k * 0.45, 0.03)
		var b1 := b0 + Vector3(cos(a) * 1.9, 2.2, sin(a) * 1.9)
		mb.cyl(b0, b1 - b0, 0.11, 0.05, 5, false, true)
	mb.part = P_LEAVES
	mb.color = Color(0.33, 0.40, 0.18)
	var centers := [Vector3(0.1, 8.5, 0.0)]
	for k in 5:
		var a := TAU * k / 5.0 + 0.3
		centers.append(Vector3(cos(a) * 1.55, 6.7 + 0.35 * sin(a * 3.0), sin(a) * 1.55))
	for i in centers.size():
		var c: Vector3 = centers[i]
		var r := 2.1 if i == 0 else rng.randf_range(1.65, 1.95)
		mb.piece(c, rng.randf())
		mb.blob(c, Vector3(r, r * 0.85, r), 0.16, rng, _ico_v, _ico_f)
	return mb.commit()


func _build_juniper(rng: RandomNumberGenerator) -> ArrayMesh:
	_icosphere()
	var mb := MB.new()
	mb.part = P_ROOT
	mb.color = Color(0.28, 0.23, 0.17)
	mb.cyl(Vector3(0, -0.35, 0), Vector3(0, 0.38, 0), 0.55, 0.5, 6, false, true)
	mb.part = P_TRUNK
	mb.color = Color(0.34, 0.28, 0.22)
	mb.cyl(Vector3(0, -0.3, 0), Vector3(0.05, 1.1, 0), 0.12, 0.07, 5, false, true)
	mb.part = P_LEAVES
	mb.color = Color(0.22, 0.27, 0.15)
	var bl := [[Vector3(0, 0.95, 0), Vector3(1.0, 0.75, 1.0)], [Vector3(0.15, 1.6, -0.1), Vector3(0.8, 0.7, 0.8)],
		[Vector3(-0.05, 2.15, 0.05), Vector3(0.55, 0.6, 0.55)], [Vector3(0.6, 1.1, 0.45), Vector3(0.55, 0.5, 0.55)]]
	for e: Array in bl:
		mb.piece(e[0], rng.randf())
		mb.blob(e[0], e[1], 0.18, rng, _ico_v, _ico_f)
	return mb.commit()


func _wheel(mb: MB, c: Vector3, r: float, w: float, side: float) -> void:
	mb.cyl(c - Vector3(side * w * 0.5, 0, 0), Vector3(side * w, 0, 0), r, r, 10, true, true)


func _hexa_glass(mb: MB, c: Array, f: Array, id: float, inset: float = 0.18) -> void:
	var p: Array = []
	var cen := Vector3.ZERO
	for i: int in f:
		p.append(c[i])
		cen += c[i]
	cen *= 0.25
	var nn := ((p[2] as Vector3) - (p[0] as Vector3)).cross((p[3] as Vector3) - (p[1] as Vector3)).normalized()
	var all := Vector3.ZERO
	for q: Vector3 in c:
		all += q
	all /= 8.0
	if nn.dot(cen - all) < 0.0:
		nn = -nn
	var sp := mb.part
	var sc := mb.color
	mb.part = P_GLASS
	mb.color = Color(0.05, 0.06, 0.07)
	mb.uv_override = Vector2(id, 0.5)
	var q: Array = []
	for i in 4:
		q.append(cen + ((p[i] as Vector3) - cen) * (1.0 - inset) + nn * 0.012)
	mb.quad(q[0], q[1], q[2], q[3], nn)
	mb.uv_override = Vector2(-1, -1)
	mb.part = sp
	mb.color = sc


func _build_car(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	mb.part = P_BODY
	mb.color = Color(0.5, 0.5, 0.5)
	mb.box(Vector3(0, 0.68, 0), Vector3(1.8, 0.72, 4.6))
	var cab := [Vector3(-0.84, 1.04, -1.35), Vector3(0.84, 1.04, -1.35), Vector3(0.84, 1.04, 0.95), Vector3(-0.84, 1.04, 0.95),
		Vector3(-0.72, 1.56, -1.05), Vector3(0.72, 1.56, -1.05), Vector3(0.72, 1.56, 0.5), Vector3(-0.72, 1.56, 0.5)]
	mb.hexa(cab)
	_hexa_glass(mb, cab, [1, 2, 6, 5], rng.randf(), 0.15)
	_hexa_glass(mb, cab, [3, 0, 4, 7], rng.randf(), 0.15)
	_hexa_glass(mb, cab, [2, 3, 7, 6], rng.randf(), 0.12)
	_hexa_glass(mb, cab, [0, 1, 5, 4], rng.randf(), 0.15)
	mb.part = P_METAL
	mb.color = Color(0.72, 0.72, 0.74)
	mb.box(Vector3(0, 0.48, 2.32), Vector3(1.86, 0.16, 0.14))
	mb.box(Vector3(0, 0.48, -2.32), Vector3(1.86, 0.16, 0.14))
	mb.part = P_WHEEL
	mb.color = Color(0.06, 0.06, 0.06)
	for z: float in [1.45, -1.45]:
		for s: float in [1.0, -1.0]:
			_wheel(mb, Vector3(s * 0.8, 0.34, z), 0.34, 0.24, s)
	return mb.commit()


func _build_truck(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var od := Color(0.31, 0.33, 0.22)
	mb.part = P_BODY
	mb.color = od
	mb.box(Vector3(0, 0.88, 0), Vector3(1.9, 0.32, 6.8))
	mb.box(Vector3(0, 1.66, 2.35), Vector3(2.3, 1.25, 1.8))
	mb.box(Vector3(0, 1.38, 3.68), Vector3(1.9, 0.8, 0.95))
	var cabv := [Vector3(-1.15, 2.29, 1.45), Vector3(1.15, 2.29, 1.45), Vector3(1.15, 2.29, 3.25), Vector3(-1.15, 2.29, 3.25),
		Vector3(-1.1, 2.95, 1.5), Vector3(1.1, 2.95, 1.5), Vector3(1.1, 2.95, 2.95), Vector3(-1.1, 2.95, 2.95)]
	mb.hexa(cabv)
	_hexa_glass(mb, cabv, [2, 3, 7, 6], rng.randf(), 0.12)
	_hexa_glass(mb, cabv, [1, 2, 6, 5], rng.randf(), 0.2)
	_hexa_glass(mb, cabv, [3, 0, 4, 7], rng.randf(), 0.2)
	mb.box(Vector3(0, 1.32, -1.05), Vector3(2.4, 0.58, 4.3))
	mb.part = P_CLAD
	mb.color = Color(0.37, 0.38, 0.28)
	var cov := [Vector3(-1.18, 1.6, -3.15), Vector3(1.18, 1.6, -3.15), Vector3(1.18, 1.6, 1.05), Vector3(-1.18, 1.6, 1.05),
		Vector3(-1.0, 3.05, -3.1), Vector3(1.0, 3.05, -3.1), Vector3(1.0, 3.05, 1.0), Vector3(-1.0, 3.05, 1.0)]
	mb.hexa(cov)
	mb.part = P_WHEEL
	mb.color = Color(0.07, 0.07, 0.07)
	for z: float in [3.0, -0.55, -1.95]:
		for s: float in [1.0, -1.0]:
			_wheel(mb, Vector3(s * 0.95, 0.52, z), 0.52, 0.36, s)
	return mb.commit()


func _build_tank() -> ArrayMesh:
	var mb := MB.new()
	var od := Color(0.29, 0.31, 0.21)
	mb.part = P_BODY
	mb.color = od
	mb.box(Vector3(0, 1.05, -0.2), Vector3(3.3, 1.0, 5.8))
	mb.box(Vector3(0, 1.18, 2.95), Vector3(3.2, 0.3, 1.6), Basis(Vector3.RIGHT, 0.55))
	mb.part = P_WHEEL
	mb.color = Color(0.13, 0.13, 0.12)
	for s: float in [1.0, -1.0]:
		mb.box(Vector3(s * 1.78, 0.5, 0), Vector3(0.62, 1.0, 6.6))
	mb.part = P_TURRET
	mb.color = od
	mb.piece(Vector3(0, 2.0, -0.3), 0.37, Vector3(1, 0, 0), 0.0, Vector2(1.3, 0.45))
	mb.cyl(Vector3(0, 1.55, -0.3), Vector3(0, 0.85, 0), 1.45, 1.15, 10, false, true)
	mb.box(Vector3(0, 2.0, 0.95), Vector3(0.9, 0.6, 0.5))
	mb.cyl(Vector3(0, 2.05, 1.1), Vector3(0, 0.04, 4.6), 0.11, 0.09, 6, false, true)
	return mb.commit()


func _build_tower() -> ArrayMesh:
	var mb := MB.new()
	var H := 45.0
	var n := 9
	mb.part = P_FRAME
	mb.color = Color(0.42, 0.42, 0.43)
	var corners: Array = []
	for k in n + 1:
		var y := H * k / n
		var hw := lerpf(3.5, 1.0, float(k) / n)
		corners.append([Vector3(-hw, y, -hw), Vector3(hw, y, -hw), Vector3(hw, y, hw), Vector3(-hw, y, hw)])
	for k in n:
		var lo: Array = corners[k]
		var hi: Array = corners[k + 1]
		for i in 4:
			var a0: Vector3 = lo[i]
			var a1: Vector3 = hi[i]
			if k == 0:
				a0 = a0 + (a0 - a1).normalized() * 1.2
			mb.beam(a0, a1, 0.24)
			var b0: Vector3 = lo[(i + 1) % 4]
			var b1: Vector3 = hi[(i + 1) % 4]
			mb.beam(lo[i], b1, 0.08)
			mb.beam(b0, hi[i], 0.08)
			mb.beam(hi[i], b1, 0.1)
	mb.part = P_BODY
	mb.color = Color(0.56, 0.56, 0.53)
	mb.box(Vector3(0, H + 1.2, 0), Vector3(2.6, 2.4, 2.6))
	return mb.commit()


func _build_mast() -> ArrayMesh:
	var mb := MB.new()
	var H := 36.6
	var n := 12
	var r := 0.55
	mb.part = P_FRAME
	var pts: Array = []
	for k in n + 1:
		var y := H * k / n
		var ring: Array = []
		for i in 3:
			var a := TAU * i / 3.0
			ring.append(Vector3(cos(a) * r, y, sin(a) * r))
		pts.append(ring)
	for k in n:
		mb.color = Color(0.80, 0.33, 0.12) if (k / 2) % 2 == 0 else Color(0.85, 0.85, 0.83)
		var lo: Array = pts[k]
		var hi: Array = pts[k + 1]
		for i in 3:
			var a0: Vector3 = lo[i]
			if k == 0:
				a0 = a0 - Vector3(0, 1.0, 0)
			mb.beam(a0, hi[i], 0.09)
			mb.beam(lo[i], hi[(i + 1) % 3], 0.045)
			mb.beam(hi[i], hi[(i + 1) % 3], 0.045)
	mb.part = P_BODY
	mb.color = Color(0.9, 0.1, 0.05)
	mb.box(Vector3(0, H + 0.25, 0), Vector3(0.35, 0.5, 0.35))
	return mb.commit()


func _build_pole() -> ArrayMesh:
	var mb := MB.new()
	mb.part = P_TRUNK
	mb.color = Color(0.36, 0.28, 0.20)
	mb.cyl(Vector3(0, -1.5, 0), Vector3(0, 11.5, 0), 0.15, 0.12, 7, false, true)
	mb.part = P_FRAME
	mb.box(Vector3(0, 9.3, 0), Vector3(2.2, 0.12, 0.12))
	mb.part = P_METAL
	mb.color = Color(0.75, 0.76, 0.74)
	for x: float in [-0.9, 0.0, 0.9]:
		mb.cyl(Vector3(x, 9.36, 0), Vector3(0, 0.12, 0), 0.05, 0.04, 5, false, true)
	return mb.commit()


func _build_wire() -> ArrayMesh:
	var mb := MB.new()
	mb.part = P_WIRE
	mb.color = Color(0.1, 0.1, 0.1)
	var seg := 10
	var h := 0.028
	for z: float in [-0.9, 0.0, 0.9]:
		for i in seg:
			var u0 := float(i) / seg
			var u1 := float(i + 1) / seg
			var y0 := WIRE_H - WIRE_SAG * 4.0 * u0 * (1.0 - u0)
			var y1 := WIRE_H - WIRE_SAG * 4.0 * u1 * (1.0 - u1)
			mb.quad(Vector3(u0, y0 + h, z - h), Vector3(u1, y1 + h, z - h), Vector3(u1, y1 + h, z + h), Vector3(u0, y0 + h, z + h), Vector3.UP)
			mb.quad(Vector3(u0, y0 - h, z - h), Vector3(u1, y1 - h, z - h), Vector3(u1, y1 - h, z + h), Vector3(u0, y0 - h, z + h), Vector3.DOWN)
			mb.quad(Vector3(u0, y0 - h, z + h), Vector3(u1, y1 - h, z + h), Vector3(u1, y1 + h, z + h), Vector3(u0, y0 + h, z + h), Vector3.BACK)
			mb.quad(Vector3(u0, y0 - h, z - h), Vector3(u1, y1 - h, z - h), Vector3(u1, y1 + h, z - h), Vector3(u0, y0 + h, z - h), Vector3.FORWARD)
	return mb.commit()


func _build_bridge(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var concrete := Color(0.63, 0.61, 0.57)
	# dry wash bed under the bridge (vertices snapped to the terrain in the shader)
	# a meandering gravel channel whose banks dip under the terrain (irregular outline)
	mb.part = P_GROUND
	var nx := 10
	var nz := 44
	var zs := 120.0
	var base := mb.verts.size()
	for j in nz + 1:
		var z := -zs + 2.0 * zs * j / nz
		var xc := 5.0 * sin(z * 0.027) + 2.0 * sin(z * 0.11 + 1.3)
		var hw := (9.0 + 3.5 * sin(z * 0.05 + 0.7) + rng.randf_range(-1.5, 1.5)) * (1.0 - 0.6 * pow(absf(z) / zs, 4.0))
		for i in nx + 1:
			var u := -1.0 + 2.0 * i / nx
			var x := xc + u * hw * (1.0 + rng.randf_range(-0.12, 0.12) * absf(u))
			var edge := maxf(absf(u), absf(z) / zs)
			var y := 0.05 if edge < 0.75 else lerpf(0.05, -0.5, (edge - 0.75) / 0.25)
			var g := rng.randf_range(0.9, 1.08)
			mb.color = Color(0.62 * g, 0.585 * g, 0.53 * g)
			mb.vert(Vector3(x, y, z), Vector3.UP)
	for j in nz:
		for i in nx:
			var a := base + j * (nx + 1) + i
			mb.tri(a, a + 1, a + nx + 1, Vector3.UP)
			mb.tri(a + 1, a + nx + 2, a + nx + 1, Vector3.UP)
	# deck spans
	for k in 4:
		var xc := -27.0 + k * 18.0
		mb.part = P_DECK
		mb.color = concrete
		var c := Vector3(xc, 4.9, 0)
		mb.piece(c, rng.randf(), Vector3(1, 0, 0), 0.0, Vector2(4.0, 0.6))
		mb.box(c, Vector3(17.9, 1.2, 8.0))
		mb.box(Vector3(xc, 5.95, 3.9), Vector3(17.9, 0.9, 0.2))
		mb.box(Vector3(xc, 5.95, -3.9), Vector3(17.9, 0.9, 0.2))
		mb.color = Color(0.22, 0.22, 0.22)
		mb.box(Vector3(xc, 5.53, 0), Vector3(17.9, 0.06, 7.0))
	# piers
	for x: float in [-18.0, 0.0, 18.0]:
		mb.part = P_PIER
		mb.color = concrete
		mb.piece(Vector3(x, 0, 0), rng.randf(), Vector3(1, 0, 0), 0.0, Vector2(3.0, 0.7))
		mb.box(Vector3(x, 1.15, 0), Vector3(1.4, 6.3, 6.5))
	# abutments and approach embankments
	mb.piece(Vector3.ZERO, 0.0)
	for s: float in [1.0, -1.0]:
		mb.part = P_EMBANK
		mb.color = concrete
		mb.box(Vector3(s * 36.6, 2.25, 0), Vector3(1.2, 6.5, 9.5))
		mb.color = Color(0.55, 0.47, 0.36)
		var x0 := s * 37.2
		var x1 := s * 78.0
		mb.hexa([Vector3(x0, -3.0, -7.0), Vector3(x1, -3.0, -7.0), Vector3(x1, -3.0, 7.0), Vector3(x0, -3.0, 7.0),
			Vector3(x0, 5.5, -6.0), Vector3(x1, -0.5, -6.0), Vector3(x1, -0.5, 6.0), Vector3(x0, 5.5, 6.0)])
		mb.color = Color(0.22, 0.22, 0.22)
		mb.hexa([Vector3(x0, 5.45, -3.6), Vector3(x1, -0.55, -3.6), Vector3(x1, -0.55, 3.6), Vector3(x0, 5.45, 3.6),
			Vector3(x0, 5.56, -3.5), Vector3(x1, -0.44, -3.5), Vector3(x1, -0.44, 3.5), Vector3(x0, 5.56, 3.5)])
	return mb.commit()


func _build_bunker() -> ArrayMesh:
	var mb := MB.new()
	mb.part = P_BODY
	mb.color = Color(0.62, 0.61, 0.57)
	mb.box(Vector3(0, 0.9, 0), Vector3(8.0, 3.4, 6.0))
	mb.color = Color(0.03, 0.03, 0.03)
	mb.quad(Vector3(-1.6, 1.55, 3.012), Vector3(1.6, 1.55, 3.012), Vector3(1.6, 1.9, 3.012), Vector3(-1.6, 1.9, 3.012), Vector3(0, 0, 1))
	mb.part = P_SLAB
	mb.color = Color(0.60, 0.59, 0.55)
	mb.piece(Vector3(0, 3.0, 0), 0.5, Vector3(1, 0, 0), 0.0, Vector2(3.3, 0.4))
	mb.box(Vector3(0, 3.0, 0), Vector3(8.8, 0.8, 6.8))
	mb.part = P_EMBANK
	mb.color = Color(0.55, 0.47, 0.36)
	mb.piece(Vector3.ZERO, 0.0)
	mb.hexa([Vector3(-4.0, -0.8, -3.0), Vector3(4.0, -0.8, -3.0), Vector3(6.0, -0.8, -8.5), Vector3(-6.0, -0.8, -8.5),
		Vector3(-4.0, 2.55, -3.0), Vector3(4.0, 2.55, -3.0), Vector3(6.0, -0.5, -8.5), Vector3(-6.0, -0.5, -8.5)])
	for s: float in [1.0, -1.0]:
		mb.hexa([Vector3(s * 4.0, -0.8, -3.0), Vector3(s * 4.0, -0.8, 3.0), Vector3(s * 9.0, -0.8, 3.5), Vector3(s * 9.0, -0.8, -3.5),
			Vector3(s * 4.0, 2.55, -3.0), Vector3(s * 4.0, 2.55, 3.0), Vector3(s * 9.0, -0.5, 3.5), Vector3(s * 9.0, -0.5, -3.5)])
	return mb.commit()


func _build_hangar(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var W := 40.0
	var D := 30.0
	var Hc := 10.3
	var rise := 4.0
	mb.part = P_FOUND
	mb.color = Color(0.55, 0.55, 0.53)
	mb.box(Vector3(0, -0.45, 0), Vector3(W + 1.0, 1.5, D + 1.0))
	# portal frames
	mb.part = P_FRAME
	mb.color = Color(0.30, 0.31, 0.32)
	for k in 6:
		var z := -D * 0.5 + 0.3 + k * (D - 0.6) / 5.0
		for s: float in [1.0, -1.0]:
			mb.beam(Vector3(s * (W * 0.5 - 0.3), 0.3, z), Vector3(s * (W * 0.5 - 0.3), Hc, z), 0.4)
			mb.beam(Vector3(s * (W * 0.5 - 0.3), Hc, z), Vector3(0, Hc + rise, z), 0.4)
	var clad := Color(0.63, 0.64, 0.63)
	var alpha := atan2(rise, W * 0.5)
	var slope_len := sqrt(rise * rise + W * W * 0.25) + 0.4
	# side walls: 5 panels each
	for s: float in [1.0, -1.0]:
		for k in 5:
			var zc := -D * 0.5 + D * (k + 0.5) / 5.0
			var c := Vector3(s * (W * 0.5 + 0.05), 0.3 + (Hc - 0.3) * 0.5, zc)
			mb.part = P_CLAD
			mb.color = clad
			mb.piece(c, rng.randf(), Vector3(0, 0, -s), PI * 0.5, Vector2((Hc - 0.3) * 0.5, 0.04))
			mb.box(c, Vector3(0.07, Hc - 0.3, D / 5.0))
	# back wall + gable
	for k in 5:
		var xc := -W * 0.5 + W * (k + 0.5) / 5.0
		var c := Vector3(xc, 0.3 + (Hc - 0.3) * 0.5, -D * 0.5 - 0.05)
		mb.piece(c, rng.randf(), Vector3(-1, 0, 0), PI * 0.5, Vector2((Hc - 0.3) * 0.5, 0.04))
		mb.box(c, Vector3(W / 5.0, Hc - 0.3, 0.07))
	for zf: float in [-D * 0.5 - 0.05, D * 0.5 + 0.05]:
		var sg := signf(zf)
		mb.piece(Vector3(0, Hc + rise / 3.0, zf), rng.randf(), Vector3(sg, 0, 0), PI * 0.5, Vector2(rise / 3.0, 0.04))
		mb.prism(Vector3(-W * 0.5, Hc, zf), Vector3(W * 0.5, Hc, zf), Vector3(0, Hc + rise, zf), Vector3(0, 0, 0.07 * sg))
	# front header over the doors
	var hc := Vector3(0, Hc - 1.4, D * 0.5 + 0.05)
	mb.piece(hc, rng.randf(), Vector3(1, 0, 0), PI * 0.5, Vector2(1.4, 0.04))
	mb.box(hc, Vector3(W, 2.8, 0.07))
	# door leaves
	for k in 4:
		var xc := -W * 0.5 + 1.0 + (W - 2.0) * (k + 0.5) / 4.0
		var c := Vector3(xc, 0.3 + 3.6, D * 0.5 + 0.15)
		mb.part = P_DOOR
		mb.color = Color(0.50, 0.54, 0.50)
		mb.piece(c, rng.randf(), Vector3(1, 0, 0), PI * 0.5, Vector2(3.6, 0.05))
		mb.box(c, Vector3((W - 2.0) / 4.0 - 0.05, 7.2, 0.1))
	mb.part = P_FRAME
	mb.color = Color(0.30, 0.31, 0.32)
	mb.box(Vector3(-W * 0.5 + 0.5, 3.9, D * 0.5 + 0.1), Vector3(1.0, 7.2, 0.3))
	mb.box(Vector3(W * 0.5 - 0.5, 3.9, D * 0.5 + 0.1), Vector3(1.0, 7.2, 0.3))
	# roof: 2 slopes x 5 panels
	for s: float in [1.0, -1.0]:
		for k in 5:
			var zc := -D * 0.5 + D * (k + 0.5) / 5.0
			var mid := Vector3(s * W * 0.25, Hc + rise * 0.5, zc)
			var down := Vector3(s * cos(alpha), -sin(alpha), 0)
			var nrm := Vector3(s * sin(alpha), cos(alpha), 0)
			var c := mid + down * 0.2 + nrm * 0.25
			mb.part = P_CLAD
			mb.color = clad * 0.92
			mb.piece(c, rng.randf(), Vector3(0, 0, s), alpha, Vector2(slope_len * 0.5, 0.04))
			mb.box(c, Vector3(slope_len, 0.07, D / 5.0 + 0.05), Basis(Vector3.BACK, -s * alpha))
	return mb.commit()


func _build_aircraft(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var alu := Color(0.74, 0.75, 0.77)
	var yc := 3.2
	var rf := 1.45
	mb.part = P_BODY
	mb.color = alu
	mb.cyl(Vector3(0, yc, -13.0), Vector3(0, 0, 24.0), rf, rf, 12, false, false)
	mb.cyl(Vector3(0, yc, 11.0), Vector3(0, 0, 3.6), rf, 0.45, 12, false, true)
	mb.cyl(Vector3(0, yc + 0.2, -13.0), Vector3(0, 0.6, -4.6), rf, 0.3, 12, false, true)
	_glass_ring(mb, Vector3(0, yc + 0.35, 12.4), rf * 0.82, 1.6, rng.randf())
	# horizontal stabilisers
	for s: float in [1.0, -1.0]:
		mb.hexa([Vector3(0, yc + 0.5, -14.6), Vector3(s * 6.2, yc + 0.5, -15.6), Vector3(s * 6.2, yc + 0.5, -17.4), Vector3(0, yc + 0.5, -18.0),
			Vector3(0, yc + 0.75, -14.6), Vector3(s * 6.2, yc + 0.65, -15.6), Vector3(s * 6.2, yc + 0.65, -17.4), Vector3(0, yc + 0.75, -18.0)])
	# fin (bends over when wrecked)
	mb.part = P_FIN
	mb.piece(Vector3(0, yc + rf - 0.1, -15.5), rng.randf())
	mb.hexa([Vector3(-0.15, yc + rf - 0.1, -13.6), Vector3(0.15, yc + rf - 0.1, -13.6), Vector3(0.15, yc + rf - 0.1, -17.8), Vector3(-0.15, yc + rf - 0.1, -17.8),
		Vector3(-0.1, yc + 7.2, -16.0), Vector3(0.1, yc + 7.2, -16.0), Vector3(0.1, yc + 7.2, -18.2), Vector3(-0.1, yc + 7.2, -18.2)])
	# wings with nacelles (snap off when wrecked)
	for s: float in [1.0, -1.0]:
		mb.part = P_WING
		mb.color = alu
		mb.piece(Vector3(s * 9.0, yc - 0.2, 1.0), rng.randf(), Vector3(1, 0, 0), 0.0, Vector2(1.8, 0.6))
		mb.hexa([Vector3(s * 1.2, yc - 0.45, 3.4), Vector3(s * 21.5, yc - 0.1, 1.5), Vector3(s * 21.5, yc - 0.1, -0.3), Vector3(s * 1.2, yc - 0.45, -1.6),
			Vector3(s * 1.2, yc + 0.05, 3.4), Vector3(s * 21.5, yc + 0.15, 1.5), Vector3(s * 21.5, yc + 0.15, -0.3), Vector3(s * 1.2, yc + 0.05, -1.6)])
		for x: float in [5.5, 11.0]:
			mb.cyl(Vector3(s * x, yc - 0.55, -1.8), Vector3(0, 0, 6.0), 0.62, 0.55, 8, true, true)
	# landing gear (folds into the belly when the aircraft is thrown)
	mb.part = P_GEAR
	mb.color = Color(0.2, 0.2, 0.2)
	for g: Vector3 in [Vector3(5.5, 2.6, 1.6), Vector3(-5.5, 2.6, 1.6), Vector3(0, 2.0, 10.0)]:
		mb.piece(g, rng.randf())
		mb.cyl(Vector3(g.x, 0.6, g.z), Vector3(0, g.y - 0.6, 0), 0.14, 0.14, 6, false, true)
		_wheel(mb, Vector3(g.x, 0.55, g.z), 0.55, 0.4, 1.0)
	return mb.commit()


func _glass_ring(mb: MB, c: Vector3, r: float, len: float, id: float) -> void:
	var sp := mb.part
	var sc := mb.color
	mb.part = P_GLASS
	mb.color = Color(0.05, 0.06, 0.07)
	mb.uv_override = Vector2(id, 0.5)
	for i in 6:
		var a0 := PI * (0.15 + 0.7 * i / 6.0)
		var a1 := PI * (0.15 + 0.7 * (i + 1) / 6.0)
		var d0 := Vector3(cos(a0), sin(a0), 0) * (r + 0.02)
		var d1 := Vector3(cos(a1), sin(a1), 0) * (r + 0.02)
		var nn := Vector3(cos(0.5 * (a0 + a1)), sin(0.5 * (a0 + a1)), 0)
		mb.quad(c + d0 - Vector3(0, 0, len * 0.5), c + d1 - Vector3(0, 0, len * 0.5), c + d1 * 0.8 + Vector3(0, 0, len * 0.5), c + d0 * 0.8 + Vector3(0, 0, len * 0.5), nn)
	mb.uv_override = Vector2(-1, -1)
	mb.part = sp
	mb.color = sc


func _build_railcar(rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MB.new()
	var y0 := 0.3
	mb.part = P_BODY
	mb.color = Color(0.46, 0.18, 0.11)
	mb.box(Vector3(0, y0 + 2.6, 0), Vector3(3.0, 3.2, 13.0))
	mb.color = Color(0.36, 0.14, 0.09)
	for s: float in [1.0, -1.0]:
		mb.quad(Vector3(s * 1.512, y0 + 1.15, -1.0), Vector3(s * 1.512, y0 + 1.15, 1.0), Vector3(s * 1.512, y0 + 3.9, 1.0), Vector3(s * 1.512, y0 + 3.9, -1.0), Vector3(s, 0, 0))
	mb.color = Color(0.30, 0.30, 0.30)
	mb.box(Vector3(0, y0 + 4.27, 0), Vector3(0.6, 0.06, 13.0))
	mb.box(Vector3(0, y0 + 0.92, 6.7), Vector3(0.4, 0.3, 0.6))
	mb.box(Vector3(0, y0 + 0.92, -6.7), Vector3(0.4, 0.3, 0.6))
	for z: float in [4.8, -4.8]:
		mb.part = P_BOGIE
		mb.color = Color(0.13, 0.13, 0.13)
		mb.piece(Vector3(0, y0 + 0.5, z), rng.randf(), Vector3(1, 0, 0), 0.0, Vector2(1.2, 0.45))
		mb.box(Vector3(0, y0 + 0.62, z), Vector3(2.3, 0.5, 2.6))
		for dz: float in [0.9, -0.9]:
			for s: float in [1.0, -1.0]:
				mb.cyl(Vector3(s * 0.72, y0 + 0.45, z + dz), Vector3(s * 0.14, 0, 0), 0.45, 0.45, 8, true, true)
	return mb.commit()


func _build_track() -> ArrayMesh:
	var mb := MB.new()
	mb.part = P_EMBANK
	mb.color = Color(0.44, 0.40, 0.36)
	mb.hexa([Vector3(-2.4, -0.6, -12.5), Vector3(2.4, -0.6, -12.5), Vector3(2.4, -0.6, 12.5), Vector3(-2.4, -0.6, 12.5),
		Vector3(-1.5, 0.15, -12.5), Vector3(1.5, 0.15, -12.5), Vector3(1.5, 0.15, 12.5), Vector3(-1.5, 0.15, 12.5)])
	mb.part = P_BODY
	mb.color = Color(0.30, 0.24, 0.18)
	for i in 40:
		mb.box(Vector3(0, 0.2, -12.2 + i * 0.625), Vector3(2.6, 0.12, 0.24))
	mb.part = P_RAIL
	mb.color = Color(0.36, 0.33, 0.31)
	for x: float in [-0.72, 0.72]:
		mb.box(Vector3(x, 0.33, 0), Vector3(0.08, 0.14, 25.0))
	return mb.commit()


func _build_smoke_strip() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var n := 14
	for j in n + 1:
		var y := float(j) / n
		for x: float in [0.0, 1.0]:
			verts.append(Vector3(x - 0.5, y, 0))
			uvs.append(Vector2(x, y))
			norms.append(Vector3(0, 0, 1))
	for j in n:
		var a := j * 2
		idx.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## Smoke plumes over burning objects and dust clouds where structures collapse: camera-facing
## strips. INSTANCE_CUSTOM: x start time (s), y size (m; negative = vegetation smoke,
## +1000 = dust cloud), z shock arrival (s), w = floor(psi * 10) + seed. Plumes grow from the
## ignition time, are torn downwind by the blast wind at the shock arrival (fresh smoke then
## rises again from the source) and glow orange at the foot; dust clouds billow out, drift with
## the blast wind and settle.
const SMOKE_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
#include "res://shaders/atmos.gdshaderinc"
global uniform float g_blast_age;
global uniform vec4 g_sun_light;
global uniform vec4 g_ambient;
uniform vec3 burst_pos = vec3(0.0, -10000.0, 0.0);
uniform float w13 = 1.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
varying float v_a;
varying float v_h;
varying float v_fire;
varying vec2 v_uv;
varying vec3 v_wp;
varying float v_seed;
varying float v_mode;
varying float v_size;
varying float v_brk;
varying float v_old;

float sat(float x) {
	return clamp(x, 0.0, 1.0);
}

float wind_u(float psi) {
	return 5.0 * psi / (7.0 * 14.7) * 343.0 / sqrt(1.0 + 6.0 * psi / (7.0 * 14.7));
}

void vertex() {
	vec4 ic = INSTANCE_CUSTOM;
	float age = g_blast_age;
	float ti = age - ic.x;
	bool dust = ic.y > 500.0;
	float size = dust ? ic.y - 1000.0 : abs(ic.y);
	v_mode = dust ? 2.0 : (ic.y < 0.0 ? 1.0 : 0.0);
	float psi = floor(ic.w) * 0.1;
	v_seed = fract(ic.w);
	vec3 o = MODEL_MATRIX[3].xyz;
	vec3 src_off = vec3(MODEL_MATRIX[1].x, 0.0, MODEL_MATRIX[1].z);
	v_a = 0.0;
	v_fire = 0.0;
	v_h = 0.0;
	v_size = size;
	v_uv = UV;
	v_brk = 0.0;
	v_old = 0.0;
	vec3 wpos = o;
	if (age >= 0.0 && ti > 0.0) {
		vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z) + vec3(1e-5, 0.0, 0.0));
		vec3 wd = o - burst_pos;
		vec3 push = length(wd.xz) > 0.1 ? normalize(vec3(wd.x, 0.0, wd.z)) : vec3(1.0, 0.0, 0.0);
		float tb = age - ic.z;
		float tp = max(0.5 * w13, 0.05);
		float u = wind_u(psi);
		// the burning wreck / dust source moves with the object it belongs to
		o += src_off * (1.0 - pow(1.0 - sat(tb / 1.5), 3.0));
		if (dust) {
			float R = size * (0.6 + 2.2 * (1.0 - exp(-ti / 1.4)) + 0.04 * ti);
			float H = R * (0.55 + 0.15 * sat(ti / 6.0));
			float y = UV.y * H;
			float w = 2.0 * R * (1.0 - 0.3 * UV.y * UV.y);
			float D = min(u * tp * 0.35 * (1.0 - exp(-max(tb, 0.0) / tp)), size * 6.0);
			wpos = o + right * (UV.x - 0.5) * w + vec3(0.0, y - 0.3 * size, 0.0) + push * D;
			v_h = y;
			v_a = sat(ti / 0.25) * exp(-ti / 10.0);
		} else {
			float rise = 2.0 + size * 0.5;
			float Hmax = size * 15.0 + 40.0;
			float H = Hmax * (1.0 - exp(-rise * ti / Hmax));
			float y = UV.y * H;
			float w = size * (0.8 + 2.4 * UV.y) + y * 0.28;
			vec3 drift = vec3(0.9, 0.0, 0.35) * y * 0.12 * (0.5 + UV.y);
			if (tb > 0.0 && psi > 0.3) {
				float D = min(u * tp * 0.8 * (1.0 - exp(-tb / tp)), 600.0);
				float ynew = rise * tb;
				float old = smoothstep(ynew - 0.1 * H - 2.0, ynew + 0.1 * H + 2.0, y);
				// The smoke above the fresh column is torn off and swept downwind while it disperses
				// (about a second). Afterwards those vertices are fully transparent and drop back
				// onto the column, so no stretched strip is left lying across the sky.
				float carry = 1.0 - smoothstep(0.9, 1.3, tb);
				drift += push * D * old * carry;
				v_brk = 4.0 * old * (1.0 - old) * sat(D / max(size * 2.0, 1.0)) * carry;
				v_old = old * (sat(tb / 1.0) + 4.0 * smoothstep(0.8, 0.9, tb));
			}
			wpos = o + right * (UV.x - 0.5) * w + vec3(0.0, y, 0.0) + drift;
			v_h = y;
			v_a = sat(ti / 2.0) * mix(1.0, 0.5, sat(ti / 600.0));
			float fire = sat(ti) * mix(1.0, 0.3, sat(ti / 240.0));
			if (tb > 0.0 && psi > 1.5) {
				fire *= 1.0 - 0.85 * sat(tb / 0.15) * exp(-tb / 4.0);
			}
			v_fire = v_mode > 0.5 ? fire * 0.5 : fire;
		}
	}
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wpos, 1.0)).xyz;
	v_wp = wpos;
}

float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), u.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm2(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * vn(p);
		p = p * 2.03 + vec2(7.1, 3.7);
		a *= 0.5;
	}
	return s;
}

void fragment() {
	float age = max(g_blast_age, 0.0);
	vec2 uv = v_uv;
	float xs = (uv.x - 0.5) * 2.0;
	vec3 lit = g_ambient.rgb * g_ambient.w * 0.9 + g_sun_light.rgb * max(g_sun_dir.y, 0.0) * 0.5;
	vec3 col;
	float a;
	if (v_mode > 1.5) {
		float n = fbm2(vec2(uv.x * 2.2 + v_seed * 17.0, uv.y * 1.6 - age * 0.05) * 1.5);
		float d = length(vec2(xs, uv.y * 1.15));
		float m = 1.0 - smoothstep(0.2, 1.0, d + (n - 0.5) * 0.8);
		a = sat(m * (0.6 + 0.9 * n)) * v_a * 0.92 * smoothstep(0.0, 0.18, uv.y);
		col = vec3(0.42, 0.35, 0.27) * lit * (0.7 + 0.5 * n + 0.2 * uv.y);
	} else {
		float scale = max(v_size * 2.0, 1.0);
		float n = fbm2(vec2(uv.x * 2.0 + v_seed * 13.0, v_h / scale - age * 0.25));
		float n2 = fbm2(vec2(uv.x * 4.5 - v_seed * 7.0, v_h / scale * 2.2 - age * 0.4));
		float nn = n * 0.65 + n2 * 0.35;
		float edge = 1.0 - smoothstep(0.25, 1.0, abs(xs) + (nn - 0.5) * 1.1);
		float top = 1.0 - smoothstep(0.6, 1.0, uv.y + (nn - 0.5) * 0.4);
		float bottom = smoothstep(0.0, max(v_size * 0.6, 1.5), v_h);
		float dil = mix(1.0, 0.45, uv.y);
		a = sat(edge * top * bottom * dil * (0.3 + 1.2 * nn)) * v_a * (v_mode > 0.5 ? 0.55 : 0.9) * (1.0 - 0.9 * v_brk);
		// smoke torn off by the blast wind is mixed away within about a second (ragged edge)
		float vo = v_old > 0.0 ? v_old + (nn - 0.5) * 0.2 : 0.0;
		a *= 1.0 - smoothstep(0.0, 0.6, vo);
		vec3 base = v_mode > 0.5 ? vec3(0.36, 0.34, 0.31) : vec3(0.07, 0.065, 0.06);
		col = base * lit * (0.65 + 0.7 * nn);
		float glow = v_fire * exp(-v_h / max(v_size * 0.4, 0.4));
		float fl = 0.65 + 0.35 * sin(age * 13.0 + v_seed * 40.0) * sin(age * 7.3 + uv.x * 5.0);
		col += vec3(1.0, 0.38, 0.08) * glow * fl * 1.8;
		a = max(a, sat(glow * 1.2) * edge * bottom * v_a);
	}
	if (g_fireball_color.w > 0.0 && g_fireball.w > 0.0) {
		float d = length(g_fireball.xyz - v_wp);
		float k = pow(g_fireball.w / max(d, g_fireball.w), 2.0);
		col += col * g_fireball_color.rgb * min(g_fireball_color.w * k * 0.5, 3.0);
	}
	// soft intersection with the ground and the wrecks (no hard cut where the strip meets them)
	float zd = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, zd, 1.0);
	float scene_d = -sv.z / sv.w;
	a *= sat((scene_d + VERTEX.z) / max(v_size * 0.7, 1.5));
	ALBEDO = col;
	ALPHA = sat(a);
	FOG = atm_fog(CAMERA_POSITION_WORLD, v_wp);
}
"""
