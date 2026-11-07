class_name TerrainMath
extends RefCounted
## CPU twin of the terrain height function in shaders/terrain_common.gdshaderinc.
## Both MUST stay in sync (same hash, same octaves, same constants).
## World convention: origin = observer's eye in the bunker, Y up, the range lies toward -Z.

const EARTH_R_EFF := 8.5e6          # effective Earth radius with standard refraction (4/3 R)
const PLAYA_Y := -22.0              # playa level relative to the eye
const BERM_TOP_Y := -2.4            # ground at the bunker
const MASK32 := 0xFFFFFFFF


static func _hash(x: int, y: int) -> int:
	var h: int = (x * 374761393 + y * 668265263) & MASK32
	h = ((h ^ (h >> 13)) * 1274126177) & MASK32
	return (h ^ (h >> 16)) & MASK32


static func _rnd(x: int, y: int) -> float:
	return float(_hash(x & MASK32, y & MASK32) & 0xFFFFFF) / 16777215.0


static func value_noise(px: float, py: float) -> float:
	var ix := floori(px)
	var iy := floori(py)
	var fx := px - ix
	var fy := py - iy
	var ux := fx * fx * fx * (fx * (fx * 6.0 - 15.0) + 10.0)
	var uy := fy * fy * fy * (fy * (fy * 6.0 - 15.0) + 10.0)
	var a := _rnd(ix, iy)
	var b := _rnd(ix + 1, iy)
	var c := _rnd(ix, iy + 1)
	var d := _rnd(ix + 1, iy + 1)
	return lerpf(lerpf(a, b, ux), lerpf(c, d, ux), uy) * 2.0 - 1.0


static func fbm(px: float, py: float, octaves: int) -> float:
	var s := 0.0
	var amp := 0.5
	var x := px
	var y := py
	for i in octaves:
		s += amp * value_noise(x, y)
		# rotate + scale (same matrix as shader)
		var nx := 1.6 * x + 1.2 * y
		var ny := -1.2 * x + 1.6 * y
		x = nx + 17.3
		y = ny + 9.1
		amp *= 0.5
	return s


static func ridged(px: float, py: float, octaves: int) -> float:
	var s := 0.0
	var amp := 0.5
	var x := px
	var y := py
	var prev := 1.0
	for i in octaves:
		var n := 1.0 - absf(value_noise(x, y))
		n = n * n
		s += amp * n * prev
		prev = clampf(n * 1.6, 0.0, 1.0)
		var nx := 1.6 * x + 1.2 * y
		var ny := -1.2 * x + 1.6 * y
		x = nx + 31.7
		y = ny + 4.3
		amp *= 0.5
	return s


## Mountain mask: 0 in the firing corridor, 1 on the flanks and at the far horizon.
static func mountain_mask(x: float, z: float) -> float:
	var r := sqrt(x * x + z * z)
	var fwd := -z
	# angle from the forward axis
	var side := absf(x) - 0.35 * maxf(fwd, 0.0) - 6000.0
	var flank := clampf(side / 14000.0, 0.0, 1.0)
	var behind := clampf((-fwd - 4000.0) / 12000.0, 0.0, 1.0)
	var far := clampf((r - 235000.0) / 40000.0, 0.0, 1.0)
	var m := maxf(maxf(flank, behind), far)
	return m * m * (3.0 - 2.0 * m)


## Terrain height WITHOUT Earth curvature (metres, relative to the eye).
static func height_flat(x: float, z: float) -> float:
	var r := sqrt(x * x + z * z)
	# gentle desert undulation
	var h := PLAYA_Y + 6.0 * fbm(x * 0.00035, z * 0.00035, 5) + 1.2 * fbm(x * 0.004, z * 0.004, 3)
	# playa flatness: the firing corridor floor is flatter
	# bunker berm
	var berm := clampf((520.0 - r) / 420.0, 0.0, 1.0)
	berm = berm * berm * (3.0 - 2.0 * berm)
	h = lerpf(h, BERM_TOP_Y - 0.0006 * r * r / 10.0, berm)
	# mountains
	var mm := mountain_mask(x, z)
	if mm > 0.0:
		var rid := ridged(x * 0.000045, z * 0.000045, 6)
		var hills := 0.5 + 0.5 * fbm(x * 0.00012 + 3.1, z * 0.00012 - 7.7, 4)
		var amp := 2600.0 * clampf(r / 120000.0, 0.25, 1.0)
		h += mm * (rid * amp * (0.55 + 0.45 * hills))
	return h


static func curvature_drop(x: float, z: float) -> float:
	return (x * x + z * z) / (2.0 * EARTH_R_EFF)


## Final ground height in world space (includes Earth curvature).
static func height(x: float, z: float) -> float:
	return height_flat(x, z) - curvature_drop(x, z)


static func height_at(p: Vector3) -> float:
	return height(p.x, p.z)


static func normal_at(x: float, z: float, eps: float = 2.0) -> Vector3:
	var hx := height(x + eps, z) - height(x - eps, z)
	var hz := height(x, z + eps) - height(x, z - eps)
	return Vector3(-hx, 2.0 * eps, -hz).normalized()
