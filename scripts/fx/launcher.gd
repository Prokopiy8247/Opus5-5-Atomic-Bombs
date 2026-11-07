class_name Launcher
extends Node3D
## Launch pad (front-left of the bunker window), the generic booster carrying the selected bomb,
## the flight along a compressed ballistic arc, optional parachute phase and the detonation trigger.
## Driven by game time (respects slow motion / pause).

signal detonated(burst_world: Vector3)
signal phase_changed(phase: String)

const PAD_POS := Vector3(-185.0, 0.0, -380.0)

var bomb: Dictionary
var missile: Node3D
var payload: Node3D
var chute: Node3D
var flame: MeshInstance3D
var flame_mat: StandardMaterial3D
var flame_light: OmniLight3D
var smoke: GPUParticles3D
var pad_root: Node3D

var flying := false
var t := 0.0
var flight_time := 10.0
var p0 := Vector3.ZERO
var p1 := Vector3.ZERO
var p2 := Vector3.ZERO
var p3 := Vector3.ZERO
var burst := Vector3.ZERO
var chute_on := false
var chute_time := 0.0
var chute_drop := 0.0
var contact := false          # detonates on impact (surface / buried / underwater)
var missile_h := 10.0
var _models: Script


func _ready() -> void:
	_models = load("res://scripts/bombs/bomb_models.gd") if ResourceLoader.exists("res://scripts/bombs/bomb_models.gd") else null
	var gy := TerrainMath.height(PAD_POS.x, PAD_POS.z)
	pad_root = Node3D.new()
	pad_root.position = Vector3(PAD_POS.x, gy, PAD_POS.z)
	add_child(pad_root)
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.62, 0.6, 0.56)
	concrete.roughness = 0.9
	var slab := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(30, 1.2, 30)
	slab.mesh = bm
	slab.position.y = 0.3
	slab.material_override = concrete
	pad_root.add_child(slab)
	# flame trench and a service tower
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.55, 0.15, 0.1)
	steel.roughness = 0.6
	steel.metallic = 0.4
	for i in 4:
		var leg := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.35, 22.0, 0.35)
		leg.mesh = lm
		leg.material_override = steel
		leg.position = Vector3(-6.0 + (i % 2) * 2.5, 11.5, -2.0 + (i / 2) * 2.5)
		pad_root.add_child(leg)
	for k in 6:
		var brace := MeshInstance3D.new()
		var br := BoxMesh.new()
		br.size = Vector3(2.9, 0.25, 2.9)
		brace.mesh = br
		brace.material_override = steel
		brace.position = Vector3(-4.75, 3.0 + k * 3.5, -0.75)
		pad_root.add_child(brace)
	_build_smoke()


func _build_smoke() -> void:
	smoke = GPUParticles3D.new()
	smoke.amount = 2400
	smoke.lifetime = 40.0
	smoke.emitting = false
	smoke.local_coords = false
	smoke.fixed_fps = 30
	smoke.visibility_aabb = AABB(Vector3(-250000, -1000, -250000), Vector3(500000, 80000, 500000))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 8.0
	pm.gravity = Vector3(0, 0.15, 0)
	pm.damping_min = 0.5
	pm.damping_max = 1.0
	pm.scale_min = 1.0
	pm.scale_max = 1.8
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.25))
	sc.add_point(Vector2(0.15, 1.0))
	sc.add_point(Vector2(1, 3.5))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.75))
	grad.add_point(0.5, Color(0.95, 0.95, 0.95, 0.4))
	grad.set_color(grad.get_point_count() - 1, Color(0.9, 0.9, 0.9, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.turbulence_noise_scale = 6.0
	smoke.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(6, 6)
	var mat := StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _puff_texture()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.85, 0.85, 0.83)
	mat.disable_receive_shadows = true
	qm.material = mat
	smoke.draw_pass_1 = qm
	add_child(smoke)


func _puff_texture() -> Texture2D:
	var img := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	var n := FastNoiseLite.new()
	n.frequency = 0.08
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5).length() / 32.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (0.7 + 0.3 * n.get_noise_2d(x, y))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func load_bomb(b: Dictionary) -> void:
	bomb = b
	_clear_missile()
	if _models:
		missile = _models.build_missile(b)
		missile_h = float(missile.get_meta("height", 10.0))
		payload = missile.get_node_or_null("Payload")
	else:
		missile = Node3D.new()
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.4
		cm.bottom_radius = 0.45
		cm.height = 10.0
		mi.mesh = cm
		mi.position.y = 5.0
		missile.add_child(mi)
		missile_h = 10.0
	missile.position = pad_root.position + Vector3(0, 0.9, 0)
	add_child(missile)
	# exhaust flame
	flame = MeshInstance3D.new()
	var fm := CylinderMesh.new()
	var rad := maxf(float(b.get("diameter_m", 0.5)) * 0.8, 0.5)
	fm.top_radius = rad
	fm.bottom_radius = rad * 0.15
	fm.height = missile_h * 0.9
	flame.mesh = fm
	flame.position.y = -missile_h * 0.45
	flame_mat = StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.albedo_color = Color(1.0, 0.75, 0.4, 0.85)
	flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1.0, 0.6, 0.25)
	flame_mat.emission_energy_multiplier = 40.0
	flame.material_override = flame_mat
	flame.visible = false
	missile.add_child(flame)
	flame_light = OmniLight3D.new()
	flame_light.light_color = Color(1.0, 0.65, 0.35)
	flame_light.omni_range = 400.0
	flame_light.light_energy = 0.0
	flame_light.position.y = -2.0
	missile.add_child(flame_light)


func _clear_missile() -> void:
	if missile:
		missile.queue_free()
	missile = null
	# under a parachute the payload was re-parented to the launcher: free it too (QA leak fix)
	if payload and is_instance_valid(payload) and payload.get_parent() == self:
		payload.queue_free()
	payload = null
	if chute:
		chute.queue_free()
	chute = null


static func flight_time_for(dist_km: float) -> float:
	return lerpf(6.0, 25.0, clampf(log(dist_km / 0.5) / log(400.0), 0.0, 1.0))


## Starts the flight toward `burst_world` (detonation point). contact: impact-fused.
func launch(target_gz: Vector3, burst_world: Vector3, dist_km: float, p_contact: bool) -> void:
	if missile == null:
		return
	flying = true
	t = 0.0
	contact = p_contact
	burst = burst_world
	flight_time = flight_time_for(dist_km)
	chute_on = bool(bomb.get("parachute", false)) and not contact
	chute_time = 0.0
	chute_drop = 0.0
	var end := burst_world
	if chute_on:
		chute_drop = clampf(burst_world.y - target_gz.y, 150.0, 1500.0) * 0.6 + 150.0
		chute_time = clampf(chute_drop / 60.0, 3.0, 6.0)
		end = burst_world + Vector3(0, chute_drop, 0)
	if contact:
		end = target_gz + Vector3(0, 0.5, 0)
	p0 = missile.position
	var d := Vector2(end.x - p0.x, end.z - p0.z).length()
	var apex := clampf(d * 0.28, 400.0, 45000.0)
	p1 = p0 + Vector3(0, apex * 0.9, 0)
	var dir_h := Vector3(end.x - p0.x, 0, end.z - p0.z).normalized()
	p2 = end + Vector3(0, apex * 0.55, 0) - dir_h * d * 0.15
	p3 = end
	flame.visible = true
	smoke.emitting = true
	phase_changed.emit("flight")


func _bezier(s: float) -> Vector3:
	var u := 1.0 - s
	return u * u * u * p0 + 3.0 * u * u * s * p1 + 3.0 * u * s * s * p2 + s * s * s * p3


func flight_progress() -> float:
	return clampf(t / maxf(flight_time + chute_time, 0.01), 0.0, 1.0)


func time_to_detonation() -> float:
	if not flying:
		return 0.0
	return flight_time + chute_time - t


func advance(dt: float) -> void:
	if not flying or missile == null:
		return
	t += dt
	if t <= flight_time:
		# accelerate off the pad, then near-constant speed along the arc
		var x := t / flight_time
		var s := x * x * (2.2 - 1.2 * x) if x < 1.0 else 1.0
		s = clampf(s, 0.0, 1.0)
		var pos := _bezier(s)
		var ahead := _bezier(minf(s + 0.01, 1.0))
		var dir := (ahead - pos).normalized() if s < 0.999 else (p3 - _bezier(0.98)).normalized()
		missile.global_position = pos
		_orient(dir)
		smoke.global_position = pos
		var burn := clampf(1.0 - x * 1.4, 0.0, 1.0)  # engine burnout at ~70% of the flight
		flame.visible = burn > 0.0
		flame_light.light_energy = 30.0 * burn
		smoke.emitting = burn > 0.0
		if chute_on and t + dt > flight_time:
			_open_chute()
	else:
		flame.visible = false
		smoke.emitting = false
		if chute_on:
			var y := (t - flight_time) / maxf(chute_time, 0.01)
			var pos2 := (p3).lerp(burst, clampf(y, 0.0, 1.0))
			if payload:
				payload.global_position = pos2
			if chute:
				chute.global_position = pos2 + Vector3(0, 2.0, 0)
		if t >= flight_time + chute_time:
			flying = false
			_detonate()


func _orient(dir: Vector3) -> void:
	if dir.length_squared() < 1e-6:
		return
	var up := dir
	var ref := Vector3.FORWARD if absf(up.dot(Vector3.UP)) > 0.99 else Vector3.UP
	var x := ref.cross(up).normalized()
	var z := x.cross(up).normalized()
	missile.global_basis = Basis(x, up, z)


func _open_chute() -> void:
	if payload == null:
		return
	# separate the payload from the booster (booster tumbles away = hidden)
	var gt := payload.global_transform
	payload.get_parent().remove_child(payload)
	add_child(payload)
	payload.global_transform = Transform3D(Basis.from_euler(Vector3(0, 0, -PI * 0.5)), gt.origin)
	missile.visible = false
	var dia := maxf(float(bomb.get("diameter_m", 1.0)) * 8.0, 8.0)
	if _models:
		chute = _models.build_parachute(dia, Color(0.92, 0.9, 0.85) if bomb.get("country", {}).get("en", "") != "USSR" else Color(0.95, 0.55, 0.15))
	else:
		chute = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = dia * 0.5
		sm.height = dia * 0.5
		sm.is_hemisphere = true
		(chute as MeshInstance3D).mesh = sm
	add_child(chute)
	phase_changed.emit("parachute")


func _detonate() -> void:
	if missile:
		missile.visible = false
	if payload:
		payload.visible = false
	if chute:
		chute.visible = false
	phase_changed.emit("detonation")
	detonated.emit(burst)


func reset() -> void:
	flying = false
	t = 0.0
	smoke.emitting = false
	smoke.restart()
	if bomb:
		load_bomb(bomb)


func current_position() -> Vector3:
	if chute_on and t > flight_time and payload:
		return payload.global_position
	return missile.global_position if missile else Vector3.ZERO
