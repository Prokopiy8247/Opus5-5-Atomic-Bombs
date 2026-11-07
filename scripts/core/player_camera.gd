class_name PlayerCamera
extends Camera3D
## Observer camera: mouse look inside the bunker, smooth binocular zoom (wheel, FOV 75 -> 3),
## blast shake, and the cinematographer mode (free flight, director angles).

signal mode_changed(cine: bool)

const FOV_DEFAULT := 80.0
const FOV_MIN := 3.0
const BUNKER_EYE := Vector3.ZERO
const EMBRASURE_EYE := Vector3(0.0, 0.3, -3.55)

var yaw := 0.0
var pitch := 0.0
var target_fov := FOV_DEFAULT
var cine := false
var cine_speed := 60.0
var look_enabled := true
var shake := 0.0            # current shake amplitude (0..1+)
var tremor := 0.0           # low-frequency ground tremor
var _shake_t := 0.0
var _noise := FastNoiseLite.new()
var _orbit := false
var _orbit_target := Vector3.ZERO
var _orbit_angle := 0.0
var _orbit_radius := 1000.0
var _orbit_height := 300.0


func _ready() -> void:
	keep_aspect = Camera3D.KEEP_WIDTH
	fov = FOV_DEFAULT
	near = 0.05
	far = 420000.0
	_noise.seed = 7
	_noise.frequency = 1.0
	current = true


func set_look(y: float, p: float) -> void:
	yaw = y
	pitch = p
	_apply_rotation()


func _apply_rotation() -> void:
	if not cine:
		yaw = clampf(yaw, deg_to_rad(-85.0), deg_to_rad(85.0))
		pitch = clampf(pitch, deg_to_rad(-45.0), deg_to_rad(60.0))
	else:
		pitch = clampf(pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
	basis = Basis.from_euler(Vector3(pitch, yaw, 0.0), EULER_ORDER_YXZ)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and look_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := 0.0022 * (fov / FOV_DEFAULT)
		yaw -= event.relative.x * sens
		pitch -= event.relative.y * sens
		_apply_rotation()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_fov = maxf(FOV_MIN, target_fov / 1.18)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_fov = minf(FOV_DEFAULT, target_fov * 1.18)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			target_fov = FOV_DEFAULT


func set_cine(on: bool) -> void:
	cine = on
	_orbit = false
	if not on:
		position = BUNKER_EYE
		_apply_rotation()
	mode_changed.emit(on)


func director_angle(idx: int, blast_pos: Vector3, cloud_h: float, cap_r: float) -> void:
	# 1 bunker, 2 side view of the shock wave, 3 low angle at the cloud, 4 orbit
	if not cine:
		set_cine(true)
	_orbit = false
	var to_blast := blast_pos - BUNKER_EYE
	var dist := Vector2(to_blast.x, to_blast.z).length()
	var fwd := Vector3(to_blast.x, 0, to_blast.z).normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	match idx:
		1:
			position = BUNKER_EYE + Vector3(0, 0, -6.0)
			_look_at(blast_pos + Vector3(0, cloud_h * 0.35, 0))
		2:
			var side_d := maxf(cap_r * 3.0, dist * 0.6)
			position = blast_pos + right * side_d - fwd * dist * 0.15
			position.y = TerrainMath.height(position.x, position.z) + 30.0
			_look_at(blast_pos + Vector3(0, cloud_h * 0.3, 0))
		3:
			position = blast_pos - fwd * maxf(cap_r * 2.2, 2000.0)
			position.y = TerrainMath.height(position.x, position.z) + 4.0
			_look_at(blast_pos + Vector3(0, cloud_h * 0.75, 0))
		4:
			_orbit = true
			_orbit_target = blast_pos
			_orbit_radius = maxf(cap_r * 3.5, 1500.0)
			_orbit_height = maxf(cloud_h * 0.25, 200.0)
			_orbit_angle = atan2(-fwd.x, -fwd.z)
	target_fov = 60.0


func _look_at(p: Vector3) -> void:
	var d := (p - global_position).normalized()
	yaw = atan2(-d.x, -d.z)
	pitch = asin(clampf(d.y, -1.0, 1.0))
	_apply_rotation()


func _process(delta: float) -> void:
	var rdelta := delta / maxf(Engine.time_scale, 0.0001) if Engine.time_scale > 0.0 else delta
	# smooth, stabilised zoom
	fov = lerpf(fov, target_fov, 1.0 - exp(-rdelta * 6.0))
	if not cine:
		# with binoculars the observer leans into the embrasure, so the roof no longer cuts the sky
		var k := clampf((55.0 - fov) / 35.0, 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		position = BUNKER_EYE.lerp(EMBRASURE_EYE, k)
	if cine:
		_cine_move(rdelta)
	# shake (applied as a small rotation + position jitter around the base pose)
	_shake_t += rdelta
	var amp := shake
	var trem := tremor
	h_offset = 0.0
	v_offset = 0.0
	if amp > 0.0005 or trem > 0.0005:
		var zoom_k := fov / FOV_DEFAULT
		var sx := _noise.get_noise_2d(_shake_t * 23.0, 0.0) * amp + _noise.get_noise_2d(_shake_t * 4.0, 50.0) * trem
		var sy := _noise.get_noise_2d(0.0, _shake_t * 21.0) * amp + _noise.get_noise_2d(70.0, _shake_t * 5.0) * trem
		var sr := _noise.get_noise_2d(_shake_t * 17.0, 99.0) * amp
		basis = Basis.from_euler(Vector3(pitch + sy * 0.05 * zoom_k, yaw + sx * 0.05 * zoom_k, sr * 0.03), EULER_ORDER_YXZ)
		h_offset = sx * 0.06
		v_offset = sy * 0.06
	shake = maxf(shake - rdelta * (0.6 + shake * 0.8), 0.0)
	tremor = maxf(tremor - rdelta * 0.35, 0.0)


func _cine_move(delta: float) -> void:
	if _orbit:
		_orbit_angle += delta * 0.08
		position = _orbit_target + Vector3(sin(_orbit_angle) * _orbit_radius, _orbit_height, cos(_orbit_angle) * _orbit_radius)
		_look_at(_orbit_target + Vector3(0, _orbit_height * 1.5, 0))
		return
	var v := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		v -= basis.z
	if Input.is_key_pressed(KEY_S):
		v += basis.z
	if Input.is_key_pressed(KEY_A):
		v -= basis.x
	if Input.is_key_pressed(KEY_D):
		v += basis.x
	if Input.is_key_pressed(KEY_E):
		v += Vector3.UP
	if Input.is_key_pressed(KEY_Q):
		v -= Vector3.UP
	if v.length_squared() > 0.0:
		var spd := cine_speed
		if Input.is_key_pressed(KEY_SHIFT):
			spd *= 12.0
		if Input.is_key_pressed(KEY_CTRL):
			spd *= 0.15
		position += v.normalized() * spd * delta
		var g := TerrainMath.height(position.x, position.z) + 1.5
		if position.y < g:
			position.y = g
