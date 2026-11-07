class_name Bunker
extends Node3D
## Procedural concrete observation bunker with a panoramic window, console desk,
## ceiling lights, emergency light, glass panes (crack/shatter), ceiling dust and shake response.

const LAYER_BUNKER := 2           # bit index 1 -> value 2
const ROOM_X := 7.2
const ROOM_Z_FRONT := -3.2
const ROOM_Z_BACK := 4.2
const FLOOR_Y := -1.7
const CEIL_Y := 1.65
const WIN_X := 6.4
const WIN_Y0 := -0.55
const WIN_Y1 := 1.12
const WALL_T := 1.4
const MULLIONS := [-4.3, -2.15, 2.15, 4.3]

var concrete: StandardMaterial3D
var concrete_floor: StandardMaterial3D
var steel: StandardMaterial3D
var glass_mats: Array[ShaderMaterial] = []
var lamps: Array[OmniLight3D] = []
var lamp_meshes: Array[MeshInstance3D] = []
var lamp_mat: StandardMaterial3D
var emergency: OmniLight3D
var emergency_mat: StandardMaterial3D
var dust: GPUParticles3D
var dust_mat: ParticleProcessMaterial
var screens_mat: StandardMaterial3D
var flash_light: DirectionalLight3D
var probe: ReflectionProbe

var lights_health := 1.0        # 1 = fine, 0 = dead
var crack := 0.0
var shattered := false
var _flicker_t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 1337
	_make_materials()
	_build_room()
	_build_window()
	_build_desk()
	_build_lights()
	_build_dust()
	_build_flash_light()
	probe = ReflectionProbe.new()
	probe.size = Vector3(ROOM_X * 2.0, CEIL_Y - FLOOR_Y, ROOM_Z_BACK - ROOM_Z_FRONT)
	probe.position = Vector3(0, (CEIL_Y + FLOOR_Y) * 0.5, (ROOM_Z_BACK + ROOM_Z_FRONT) * 0.5)
	probe.box_projection = true
	probe.interior = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	probe.ambient_color = Color(0.05, 0.05, 0.05)
	probe.ambient_color_energy = 0.3
	add_child(probe)


func _noise_tex(freq: float, seed: int, normal := false, ramp: Gradient = null) -> Texture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.seed = seed
	n.fractal_octaves = 5
	var t := NoiseTexture2D.new()
	t.width = 1024
	t.height = 1024
	t.seamless = true
	t.noise = n
	if normal:
		t.as_normal_map = true
		t.bump_strength = 6.0
	if ramp:
		t.color_ramp = ramp
	return t


func _make_materials() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0.34, 0.33, 0.31))
	g.set_color(1, Color(0.58, 0.57, 0.54))
	concrete = StandardMaterial3D.new()
	concrete.albedo_texture = _noise_tex(0.004, 11, false, g)
	concrete.normal_enabled = true
	concrete.normal_texture = _noise_tex(0.02, 12, true)
	concrete.normal_scale = 0.5
	concrete.roughness = 0.92
	concrete.uv1_triplanar = true
	concrete.uv1_scale = Vector3(0.35, 0.35, 0.35)
	concrete_floor = concrete.duplicate()
	concrete_floor.albedo_color = Color(0.72, 0.72, 0.72)
	concrete_floor.roughness = 0.8
	steel = StandardMaterial3D.new()
	steel.albedo_color = Color(0.20, 0.22, 0.20)
	steel.metallic = 0.6
	steel.roughness = 0.5
	lamp_mat = StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(1, 1, 1)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.92, 0.78)
	lamp_mat.emission_energy_multiplier = 6.0
	emergency_mat = StandardMaterial3D.new()
	emergency_mat.albedo_color = Color(0.3, 0.02, 0.02)
	emergency_mat.emission_enabled = true
	emergency_mat.emission = Color(1.0, 0.08, 0.04)
	emergency_mat.emission_energy_multiplier = 0.0
	screens_mat = StandardMaterial3D.new()
	screens_mat.albedo_color = Color(0.02, 0.05, 0.03)
	screens_mat.emission_enabled = true
	screens_mat.emission = Color(0.25, 1.0, 0.45)
	screens_mat.emission_energy_multiplier = 0.9


func _box(size: Vector3, pos: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	mi.layers = LAYER_BUNKER
	parent.add_child(mi)
	return mi


func _build_room() -> void:
	var w := ROOM_X * 2.0
	var depth := ROOM_Z_BACK - ROOM_Z_FRONT
	var zc := (ROOM_Z_BACK + ROOM_Z_FRONT) * 0.5
	var t := 0.6
	# floor, ceiling, back and side walls
	_box(Vector3(w + 2 * t, t, depth + WALL_T + t), Vector3(0, FLOOR_Y - t * 0.5, zc - WALL_T * 0.5), concrete_floor)
	_box(Vector3(w + 2 * t, 1.6, depth + WALL_T + t), Vector3(0, CEIL_Y + 0.8, zc - WALL_T * 0.5), concrete)
	_box(Vector3(w + 2 * t, CEIL_Y - FLOOR_Y, t), Vector3(0, (CEIL_Y + FLOOR_Y) * 0.5, ROOM_Z_BACK + t * 0.5), concrete)
	_box(Vector3(t, CEIL_Y - FLOOR_Y, depth + WALL_T), Vector3(-ROOM_X - t * 0.5, (CEIL_Y + FLOOR_Y) * 0.5, zc - WALL_T * 0.5), concrete)
	_box(Vector3(t, CEIL_Y - FLOOR_Y, depth + WALL_T), Vector3(ROOM_X + t * 0.5, (CEIL_Y + FLOOR_Y) * 0.5, zc - WALL_T * 0.5), concrete)
	# front wall around the window opening
	var fz := ROOM_Z_FRONT - WALL_T * 0.5
	_box(Vector3(w, WIN_Y0 - FLOOR_Y, WALL_T), Vector3(0, (WIN_Y0 + FLOOR_Y) * 0.5, fz), concrete)
	_box(Vector3(w, CEIL_Y - WIN_Y1, WALL_T), Vector3(0, (CEIL_Y + WIN_Y1) * 0.5, fz), concrete)
	var side_w := ROOM_X - WIN_X
	_box(Vector3(side_w, WIN_Y1 - WIN_Y0, WALL_T), Vector3(-ROOM_X + side_w * 0.5, (WIN_Y0 + WIN_Y1) * 0.5, fz), concrete)
	_box(Vector3(side_w, WIN_Y1 - WIN_Y0, WALL_T), Vector3(ROOM_X - side_w * 0.5, (WIN_Y0 + WIN_Y1) * 0.5, fz), concrete)
	# outer shell: thick earth-covered concrete mass so the bunker looks solid from outside
	var shell := _box(Vector3(w + 6.0, CEIL_Y - FLOOR_Y + 3.0, depth + WALL_T + 5.0), Vector3(0, (CEIL_Y + FLOOR_Y) * 0.5 + 0.6, zc - WALL_T * 0.5 + 1.2), concrete)
	shell.layers = 1 # visible from the cine camera; hidden from inside by the room walls
	var sm := shell.mesh as BoxMesh
	sm.flip_faces = false
	shell.visible = false # enabled in cine mode by main
	shell.name = "OuterShell"
	# ceiling beams
	for i in 5:
		var x := -ROOM_X + 1.4 + i * (ROOM_X * 2.0 - 2.8) / 4.0
		_box(Vector3(0.35, 0.35, depth), Vector3(x, CEIL_Y - 0.175, zc), concrete)
	# conduit pipes along the ceiling
	for k in 2:
		var pipe := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = 0.05
		cm.height = ROOM_X * 2.0
		pipe.mesh = cm
		pipe.rotation_degrees = Vector3(0, 0, 90)
		pipe.position = Vector3(0, CEIL_Y - 0.45 - k * 0.14, ROOM_Z_BACK - 0.4)
		pipe.material_override = steel
		pipe.layers = LAYER_BUNKER
		add_child(pipe)


func _build_window() -> void:
	var fz := ROOM_Z_FRONT - WALL_T * 0.5
	var glass_shader: Shader = load("res://shaders/glass.gdshader")
	# frame
	var fr := 0.09
	_box(Vector3(WIN_X * 2.0 + 0.2, fr, 0.25), Vector3(0, WIN_Y0 + fr * 0.5, fz), steel)
	_box(Vector3(WIN_X * 2.0 + 0.2, fr, 0.25), Vector3(0, WIN_Y1 - fr * 0.5, fz), steel)
	var xs: Array = [-WIN_X] + MULLIONS + [WIN_X]
	for x in xs:
		_box(Vector3(0.12, WIN_Y1 - WIN_Y0, 0.28), Vector3(x, (WIN_Y0 + WIN_Y1) * 0.5, fz), steel)
	# panes
	for i in xs.size() - 1:
		var x0: float = xs[i]
		var x1: float = xs[i + 1]
		var pw := x1 - x0 - 0.12
		var ph := WIN_Y1 - WIN_Y0 - fr * 2.0
		var mi := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(pw, ph)
		mi.mesh = qm
		mi.position = Vector3((x0 + x1) * 0.5, (WIN_Y0 + WIN_Y1) * 0.5, fz)
		var mat := ShaderMaterial.new()
		mat.shader = glass_shader
		mat.set_shader_parameter("pane_size", Vector2(pw, ph))
		mat.set_shader_parameter("seed", float(i) * 13.7)
		mat.set_shader_parameter("impact", Vector4(_rng.randf_range(0.2, 0.8), _rng.randf_range(0.3, 0.8), _rng.randf_range(0.1, 0.9), _rng.randf_range(0.2, 0.7)))
		mi.material_override = mat
		mi.layers = LAYER_BUNKER
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = not Args.has("noglass")
		add_child(mi)
		glass_mats.append(mat)
	# window sill (sloped concrete ledge)
	_box(Vector3(WIN_X * 2.0, 0.08, 0.6), Vector3(0, WIN_Y0 - 0.04, ROOM_Z_FRONT - 0.1), concrete)


func _build_desk() -> void:
	var desk_top := FLOOR_Y + 0.95
	var dz := ROOM_Z_FRONT + 0.55
	_box(Vector3(10.5, 0.06, 1.0), Vector3(0, desk_top, dz), steel)
	_box(Vector3(10.5, 0.9, 0.06), Vector3(0, FLOOR_Y + 0.47, dz + 0.47), steel)
	# sloped instrument panel with screens
	var panel_mat := StandardMaterial3D.new()
	panel_mat.albedo_color = Color(0.32, 0.36, 0.30)
	panel_mat.roughness = 0.6
	for i in 7:
		var x := -4.5 + i * 1.5
		var p := _box(Vector3(1.3, 0.35, 0.05), Vector3(x, desk_top + 0.2, dz - 0.35), panel_mat)
		p.rotation_degrees.x = -35.0
		var scr := _box(Vector3(0.42, 0.24, 0.01), Vector3(x - 0.3, desk_top + 0.21, dz - 0.33), screens_mat)
		scr.rotation_degrees.x = -35.0
		# small indicator lamps
		for k in 4:
			var lampm := StandardMaterial3D.new()
			lampm.emission_enabled = true
			var c: Color = [Color(1, 0.2, 0.1), Color(0.2, 1, 0.3), Color(1, 0.8, 0.2), Color(0.3, 0.6, 1)][(i + k) % 4]
			lampm.albedo_color = c * 0.3
			lampm.emission = c
			lampm.emission_energy_multiplier = 1.5
			var b := _box(Vector3(0.04, 0.04, 0.02), Vector3(x + 0.12 + k * 0.1, desk_top + 0.22, dz - 0.33), lampm)
			b.rotation_degrees.x = -35.0
	# chairs (simple)
	for x in [-3.0, 0.9, 3.6]:
		_box(Vector3(0.5, 0.06, 0.5), Vector3(x, FLOOR_Y + 0.48, dz + 1.1), steel)
		_box(Vector3(0.5, 0.6, 0.06), Vector3(x, FLOOR_Y + 0.8, dz + 1.35), steel)


func _build_lights() -> void:
	for i in 3:
		var x := -4.4 + i * 4.4
		var l := OmniLight3D.new()
		l.position = Vector3(x, CEIL_Y - 0.5, 0.6)
		l.light_color = Color(1.0, 0.88, 0.7)
		l.light_energy = 1.4
		l.omni_range = 9.0
		l.shadow_enabled = i == 1
		l.light_cull_mask = LAYER_BUNKER
		add_child(l)
		lamps.append(l)
		var m := _box(Vector3(1.2, 0.06, 0.18), Vector3(x, CEIL_Y - 0.37, 0.6), lamp_mat)
		lamp_meshes.append(m)
	emergency = OmniLight3D.new()
	emergency.position = Vector3(0, CEIL_Y - 0.3, ROOM_Z_BACK - 0.6)
	emergency.light_color = Color(1.0, 0.1, 0.05)
	emergency.light_energy = 0.0
	emergency.omni_range = 14.0
	emergency.light_cull_mask = LAYER_BUNKER
	add_child(emergency)
	_box(Vector3(0.25, 0.15, 0.15), Vector3(0, CEIL_Y - 0.12, ROOM_Z_BACK - 0.2), emergency_mat)


func _build_dust() -> void:
	dust = GPUParticles3D.new()
	dust.amount = 6000
	dust.lifetime = 4.0
	dust.emitting = true
	dust.amount_ratio = 0.0
	dust.visibility_aabb = AABB(Vector3(-ROOM_X, FLOOR_Y, ROOM_Z_FRONT), Vector3(ROOM_X * 2.0, CEIL_Y - FLOOR_Y, ROOM_Z_BACK - ROOM_Z_FRONT))
	dust.position = Vector3(0, CEIL_Y - 0.05, 0.5)
	dust_mat = ParticleProcessMaterial.new()
	dust_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	dust_mat.emission_box_extents = Vector3(ROOM_X - 0.3, 0.02, (ROOM_Z_BACK - ROOM_Z_FRONT) * 0.5 - 0.3)
	dust_mat.gravity = Vector3(0, -2.5, 0)
	dust_mat.initial_velocity_min = 0.0
	dust_mat.initial_velocity_max = 0.4
	dust_mat.direction = Vector3(0, -1, 0)
	dust_mat.spread = 30.0
	dust_mat.damping_min = 0.6
	dust_mat.damping_max = 1.4
	dust_mat.scale_min = 0.4
	dust_mat.scale_max = 1.6
	dust_mat.turbulence_enabled = true
	dust_mat.turbulence_noise_strength = 0.4
	dust.process_material = dust_mat
	var qm := QuadMesh.new()
	qm.size = Vector2(0.012, 0.012)
	var dm := StandardMaterial3D.new()
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(0.7, 0.66, 0.6, 0.8)
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	qm.material = dm
	dust.draw_pass_1 = qm
	dust.layers = LAYER_BUNKER
	add_child(dust)


func _build_flash_light() -> void:
	# Directional light representing the explosion as seen from the bunker (only affects the
	# bunker layer so the window frame throws crisp moving shadows into the room).
	flash_light = DirectionalLight3D.new()
	flash_light.name = "FlashLight"
	flash_light.light_cull_mask = LAYER_BUNKER
	flash_light.shadow_enabled = true
	flash_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	flash_light.directional_shadow_max_distance = 30.0
	flash_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	flash_light.light_energy = 0.0
	flash_light.visible = false
	add_child(flash_light)


## Called every frame by the explosion manager.
## dir_to_blast: unit vector from the observer to the fireball; energy: light energy at the bunker.
func set_flash(dir_to_blast: Vector3, energy: float, color: Color) -> void:
	if energy <= 0.0001:
		flash_light.visible = false
		return
	flash_light.visible = true
	var up := Vector3.UP if absf(dir_to_blast.y) < 0.98 else Vector3.FORWARD
	flash_light.global_transform = Transform3D(Basis.looking_at(-dir_to_blast, up), Vector3.ZERO)
	flash_light.light_energy = energy
	flash_light.light_color = color


## Shock response. pressure_psi: peak overpressure at the bunker (window rating 10 psi).
func apply_shock(pressure_psi: float) -> void:
	if pressure_psi >= 10.0:
		crack = clampf(0.35 + (pressure_psi - 10.0) / 15.0, 0.0, 1.0)
	elif pressure_psi >= 4.0:
		crack = maxf(crack, (pressure_psi - 4.0) / 6.0 * 0.25)
	for m in glass_mats:
		m.set_shader_parameter("crack", crack)
	if pressure_psi >= 25.0:
		shattered = true
		for m in glass_mats:
			m.set_shader_parameter("shatter", 1.0)
	lights_health = minf(lights_health, clampf(1.0 - (pressure_psi - 0.5) / 3.0, 0.0, 1.0))
	dust.amount_ratio = clampf(pressure_psi / 3.0, 0.0, 1.0)
	_flicker_t = 3.0 + pressure_psi


func reset_state() -> void:
	crack = 0.0
	shattered = false
	lights_health = 1.0
	_flicker_t = 0.0
	dust.amount_ratio = 0.0
	for m in glass_mats:
		m.set_shader_parameter("crack", 0.0)
		m.set_shader_parameter("shatter", 0.0)
	_apply_lamps(1.0)
	emergency.light_energy = 0.0
	emergency_mat.emission_energy_multiplier = 0.0


func _apply_lamps(level: float) -> void:
	for l in lamps:
		l.light_energy = 1.4 * level
	lamp_mat.emission_energy_multiplier = 6.0 * level
	screens_mat.emission_energy_multiplier = 0.9 * clampf(level * 1.2, 0.15, 1.0)


func _process(delta: float) -> void:
	if _flicker_t > 0.0:
		_flicker_t = maxf(_flicker_t - delta, 0.0)
		var flick := 1.0
		if _rng.randf() < 0.35:
			flick = _rng.randf_range(0.0, 0.6)
		var target := lights_health
		_apply_lamps(clampf(target * flick if _flicker_t > 0.0 else target, 0.0, 1.0))
		dust.amount_ratio = maxf(dust.amount_ratio - delta * 0.12, 0.0)
	if lights_health < 0.6:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
		emergency.light_energy = 1.2 * pulse
		emergency_mat.emission_energy_multiplier = 4.0 * pulse
