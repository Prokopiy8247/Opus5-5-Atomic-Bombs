class_name FxResources
extends RefCounted
## Shared FX resources: tileable 3D noise volumes generated synchronously (C++ FastNoiseLite)
## so that the first explosion never waits or hitches. Deterministic seeds.

static var _noise_fbm: ImageTexture3D
static var _noise_billow: ImageTexture3D
const SIZE := 96


static func _make(noise: FastNoiseLite, invert: bool) -> ImageTexture3D:
	var imgs: Array[Image] = noise.get_seamless_image_3d(SIZE, SIZE, SIZE, invert, 0.1, true)
	var tex := ImageTexture3D.new()
	var fmt := imgs[0].get_format()
	tex.create(fmt, SIZE, SIZE, SIZE, false, imgs)
	return tex


static func noise_fbm() -> ImageTexture3D:
	if _noise_fbm == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.seed = 4242
		n.frequency = 0.035
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = 4
		n.fractal_gain = 0.5
		_noise_fbm = _make(n, false)
	return _noise_fbm


static func noise_billow() -> ImageTexture3D:
	if _noise_billow == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.seed = 777
		n.frequency = 0.06
		n.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
		n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = 3
		n.fractal_gain = 0.45
		_noise_billow = _make(n, true)
	return _noise_billow


static func wait_ready(_tree: SceneTree) -> void:
	var t0 := Time.get_ticks_msec()
	noise_fbm()
	noise_billow()
	print("FX noise ready in %d ms" % (Time.get_ticks_msec() - t0))
