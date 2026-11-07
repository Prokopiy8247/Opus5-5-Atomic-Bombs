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
var screens_mats: Array[StandardMaterial3D] = []   # per-screen variants of the CRT display
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
	# cast concrete: fine, low-contrast neutral grey (review c3: the old 0.018 noise at 0.5 uv scale
	# read as brown camouflage blotches, and the strong normal map as carpet under the lamps)
	var g := Gradient.new()
	g.set_color(0, Color(0.43, 0.43, 0.42))
	g.add_point(0.5, Color(0.48, 0.48, 0.47))
	g.set_color(g.get_point_count() - 1, Color(0.53, 0.53, 0.52))
	concrete = StandardMaterial3D.new()
	concrete.albedo_texture = _noise_tex(0.045, 11, false, g)
	concrete.normal_enabled = true
	concrete.normal_texture = _noise_tex(0.11, 12, true)
	concrete.normal_scale = 0.12
	concrete.roughness = 0.92
	concrete.uv1_triplanar = true
	concrete.uv1_scale = Vector3(0.35, 0.35, 0.35)
	# the interior is lit by its lamps and the window, not by the open sky's ambient light (Godot has
	# no occlusion for it here: at dawn the whole ceiling turned sky-orange)
	concrete.disable_ambient_light = true
	concrete_floor = concrete.duplicate()
	concrete_floor.albedo_color = Color(0.72, 0.72, 0.72)
	concrete_floor.roughness = 0.8
	steel = StandardMaterial3D.new()
	steel.albedo_color = Color(0.20, 0.22, 0.20)
	steel.metallic = 0.6
	steel.roughness = 0.5
	steel.disable_ambient_light = true
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
	screens_mat = _screen_material(0)
	for v in 3:
		screens_mats.append(_screen_material(v))


## Procedural monochrome CRT display (phosphor green on near-black): status text rows, a range
## scale, a scrolling-trace graph and scanlines. `variant` changes the layout and the text.
func _screen_material(variant: int) -> StandardMaterial3D:
	var w := 384
	var h := 224
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGB8)
	var bg := Color(0.004, 0.018, 0.008)
	img.fill(bg)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9001 + variant * 77
	var ph := Color(0.30, 1.0, 0.45)
	var dim := Color(0.06, 0.24, 0.10)
	# frame and grid
	for x in range(6, w - 6):
		img.set_pixel(x, 6, dim)
		img.set_pixel(x, h - 7, dim)
	for y in range(6, h - 6):
		img.set_pixel(6, y, dim)
		img.set_pixel(w - 7, y, dim)
	# text rows: 5x7 'glyph' blocks with gaps (unreadable at desk distance, reads as text)
	var rows := 9 if variant != 1 else 6
	for r in rows:
		var y0 := 14 + r * 13
		var x := 14
		var line_len := rng.randi_range(14, 34)
		for c in line_len:
			if x > w / 2 - 8 and variant == 2:
				break
			if rng.randf() < 0.14:
				x += 7
				continue
			for gy in 7:
				for gx in 5:
					if rng.randf() < 0.55:
						img.set_pixel(x + gx, y0 + gy, ph if r != 0 else ph * 1.2)
			x += 7
			if x > w - 20:
				break
	# trace graph (seismic / pressure channel) in the lower part
	var gy0 := 150 if variant != 1 else 100
	var amp := 16.0 if variant != 1 else 36.0
	var prev := gy0
	for x in range(14, w - 14):
		var v := sin(x * 0.07 + variant) * 0.35 + sin(x * 0.23 + variant * 2.0) * 0.15 + rng.randf_range(-0.18, 0.18)
		if variant == 1:
			v *= exp(-pow((x - w * 0.55) / 60.0, 2.0)) * 2.2 + 0.15
		var y := int(gy0 + v * amp)
		for yy in range(mini(prev, y), maxi(prev, y) + 1):
			img.set_pixel(x, clampi(yy, 8, h - 9), ph)
		prev = y
		if x % 24 == 0:
			for yy in range(gy0 - 30, gy0 + 31, 3):
				img.set_pixel(x, clampi(yy, 8, h - 9), dim)
	# scanlines
	for y in range(0, h, 2):
		for x in w:
			img.set_pixel(x, y, img.get_pixel(x, y) * 0.55)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.0, 0.0, 0.0)
	m.roughness = 0.15
	m.metallic_specular = 0.6
	m.emission_enabled = true
	m.emission = Color(1, 1, 1)
	m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	m.emission_texture = tex
	m.emission_energy_multiplier = 1.6
	m.uv1_scale = Vector3(1, 1, 1)
	return m


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
	panel_mat.disable_ambient_light = true
	for i in 7:
		var x := -4.5 + i * 1.5
		var p := _box(Vector3(1.3, 0.35, 0.05), Vector3(x, desk_top + 0.2, dz - 0.35), panel_mat)
		p.rotation_degrees.x = -35.0
		# CRT face: a quad just in front of the sloped panel (a BoxMesh would show only one cell of
		# its UV atlas)
		var scr := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.42, 0.24)
		scr.mesh = qm
		scr.material_override = screens_mats[i % screens_mats.size()]
		scr.layers = LAYER_BUNKER
		scr.rotation_degrees.x = -35.0
		scr.position = Vector3(x - 0.3, desk_top + 0.21, dz - 0.33) + Vector3(0.0, 0.574, 0.819) * 0.031
		add_child(scr)
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
		l.light_color = Color(1.0, 0.93, 0.84)
		l.light_energy = 1.3
		l.omni_range = 11.0
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


var night_mode := false


## Night: dim red "night-vision" lighting so the range stays visible through the window.
func set_night(on: bool) -> void:
	night_mode = on
	for l in lamps:
		l.light_color = Color(1.0, 0.22, 0.12) if on else Color(1.0, 0.93, 0.84)
	lamp_mat.emission = Color(1.0, 0.2, 0.1) if on else Color(1.0, 0.92, 0.78)
	_apply_lamps(lights_health)


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
	var k := 0.12 if night_mode else 1.0
	for l in lamps:
		l.light_energy = 1.3 * level * k
	lamp_mat.emission_energy_multiplier = 4.0 * level * (0.25 if night_mode else 1.0)
	for m in screens_mats:
		m.emission_energy_multiplier = 1.6 * clampf(level * 1.2, 0.15, 1.0) * (0.35 if night_mode else 1.0)


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
