class_name FxLayersLib
extends RefCounted
## Secondary explosion layers (each is a Node3D with setup(ex) / update(age)):
## ShockLayer (refractive front + Mach stem), DustWallLayer (ground dust sweep),
## WilsonLayer (condensation shell), DebrisLayer (analytic ballistic fragments/clods).

const SHOCK_SHADER := preload("res://shaders/shockwave.gdshader")
const DUST_SHADER := preload("res://shaders/dust_wall.gdshader")
const WILSON_SHADER := preload("res://shaders/wilson.gdshader")
const DEBRIS_SHADER := preload("res://shaders/debris.gdshader")


static func _sphere_mesh(rings: int, segs: int) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.rings = rings
	s.radial_segments = segs
	return s


class ShockLayer extends Node3D:
	var ex: Explosion
	var shell: MeshInstance3D
	var mat: ShaderMaterial
	var burst_y := 0.0

	func setup(p_ex: Explosion) -> void:
		ex = p_ex
		shell = MeshInstance3D.new()
		shell.mesh = FxLayersLib._sphere_mesh(48, 96)
		mat = ShaderMaterial.new()
		mat.shader = FxLayersLib.SHOCK_SHADER
		mat.render_priority = 2
		shell.material_override = mat
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shell.extra_cull_margin = 100000.0
		add_child(shell)
		burst_y = maxf(ex.prof.hob, 0.0)

	func update(t: float) -> void:
		if t <= 0.0 or ex.prof.kind == ExplosionProfile.Kind.NUCLEAR_BURIED or ex.prof.kind == ExplosionProfile.Kind.CONVENTIONAL_BURIED:
			shell.visible = false
			return
		var slant := ex.shock_slant_radius(t)
		var p := BlastPhysics.overpressure(ex.prof.blast_yield(), slant, ex.prof.surface, ex.prof.conventional)
		var strength := clampf(log(1.0 + p) / log(1.0 + 20.0), 0.0, 1.0)
		# the front is hard to see once it is weak and far
		shell.visible = slant > 1.0 and p > 0.05
		if not shell.visible:
			return
		shell.global_position = ex.gz + Vector3(0, burst_y, 0)
		shell.scale = Vector3.ONE * slant
		mat.set_shader_parameter("strength", strength)
		mat.set_shader_parameter("radius", slant)
		mat.set_shader_parameter("age", t)
		mat.set_shader_parameter("ground_y", -burst_y)
		var stem := 0.0
		if ex.prof.hob > 0.0 and slant > ex.prof.hob * 1.1:
			stem = minf(slant * 0.25, ex.prof.hob * 1.5)
		mat.set_shader_parameter("stem_h", stem)
		mat.set_shader_parameter("condensation", Game.humidity * clampf(p / 3.0, 0.0, 1.0))


class DustWallLayer extends Node3D:
	var ex: Explosion
	var wall: MeshInstance3D
	var mat: ShaderMaterial
	var amount := 1.0

	func setup(p_ex: Explosion) -> void:
		ex = p_ex
		wall = MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 1.0
		cm.height = 1.0
		cm.radial_segments = 256
		cm.rings = 1
		cm.cap_top = false
		cm.cap_bottom = false
		wall.mesh = cm
		mat = ShaderMaterial.new()
		mat.shader = FxLayersLib.DUST_SHADER
		mat.set_shader_parameter("noise_b", FxResources.noise_billow())
		mat.set_shader_parameter("seed", float(ex.bomb.get("num", 1)) * 0.37)
		mat.render_priority = 1
		wall.material_override = mat
		wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wall.extra_cull_margin = 100000.0
		add_child(wall)
		var k := ex.prof.kind
		amount = 1.0 if (ex.prof.surface or ex.prof.dusty) else 0.55
		if k == ExplosionProfile.Kind.NUCLEAR_UNDERWATER:
			amount = 0.0
		amount *= float(ex.prof.a("dust_wall", 1.0))
		var dc: Array = ex.prof.a("dust_color", [0.66, 0.58, 0.48])
		mat.set_shader_parameter("dust_col", Vector3(dc[0], dc[1], dc[2]))
		mat.set_shader_parameter("ragged", 1.0 if ex.prof.a("precursor", false) else 0.35)

	func update(t: float) -> void:
		var r := ex.prof.shock_ground_radius(t, ex.arrival_tbl)
		if t <= 0.0 or r <= 1.0 or amount <= 0.0:
			wall.visible = false
			return
		var slant := sqrt(r * r + maxf(ex.prof.hob, 0.0) * maxf(ex.prof.hob, 0.0))
		var p := BlastPhysics.overpressure(ex.prof.blast_yield(), slant, ex.prof.surface, ex.prof.conventional)
		# dust is raised where the wind behind the front is strong (> ~0.5 psi)
		var op := clampf((p - 0.3) / 3.0, 0.0, 1.0) * amount
		wall.visible = op > 0.01
		if not wall.visible:
			return
		var h := clampf(r * 0.035, 3.0, 2500.0) * (1.0 + clampf(p / 10.0, 0.0, 2.0))
		if ex.prof.a("precursor", false):
			h *= 1.8
		wall.global_position = ex.gz + Vector3(0, h * 0.5 - 2.0, 0)
		wall.scale = Vector3(r, h, r)
		wall.custom_aabb = AABB(Vector3(-1.2, -50.0, -1.2), Vector3(2.4, 100.0, 2.4))
		mat.set_shader_parameter("radius", r)
		mat.set_shader_parameter("height", h)
		mat.set_shader_parameter("opacity", op)
		mat.set_shader_parameter("age", t)


class WilsonLayer extends Node3D:
	var ex: Explosion
	var shell: MeshInstance3D
	var mat: ShaderMaterial
	var t0 := 0.0
	var dur := 1.0
	var amount := 0.0

	func setup(p_ex: Explosion) -> void:
		ex = p_ex
		shell = MeshInstance3D.new()
		shell.mesh = FxLayersLib._sphere_mesh(32, 64)
		mat = ShaderMaterial.new()
		mat.shader = FxLayersLib.WILSON_SHADER
		mat.set_shader_parameter("noise_b", FxResources.noise_billow())
		mat.set_shader_parameter("seed", float(ex.bomb.get("num", 1)) * 1.7)
		mat.render_priority = 3
		shell.material_override = mat
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shell.extra_cull_margin = 100000.0
		add_child(shell)
		# appears when the rarefaction behind the front cools humid air (~RH > 0.55)
		var hum := Game.humidity
		amount = clampf((hum - 0.45) / 0.35, 0.0, 1.0) * float(ex.prof.a("wilson", 1.0))
		dur = maxf(ex.prof.wilson_t, 0.25) * float(ex.prof.a("wilson_duration", 1.0))
		t0 = float(ex.prof.a("wilson_start", 0.0))
		if t0 <= 0.0:
			# when the front reaches ~ the Wilson radius
			t0 = ex.prof.wilson_t0

	func update(t: float) -> void:
		if amount <= 0.0 or t < t0 or t > t0 + dur * 2.2:
			shell.visible = false
			return
		var x := (t - t0) / dur
		var op := smoothstep(0.0, 0.15, x) * (1.0 - smoothstep(0.6, 2.2, x)) * amount
		shell.visible = op > 0.005
		if not shell.visible:
			return
		var slant := ex.shock_slant_radius(t) * 0.92
		var cy := maxf(ex.prof.hob, 0.0)
		if ex.prof.kind == ExplosionProfile.Kind.NUCLEAR_UNDERWATER:
			cy = 0.0
		shell.global_position = ex.gz + Vector3(0, cy, 0)
		shell.scale = Vector3(slant, slant * float(ex.prof.a("wilson_flatten", 1.0)), slant)
		mat.set_shader_parameter("opacity", op)
		mat.set_shader_parameter("radius", slant)
		mat.set_shader_parameter("ground_y", -cy)
		mat.set_shader_parameter("age", t)


class DebrisLayer extends Node3D:
	var ex: Explosion
	var mmi: MultiMeshInstance3D
	var mat: ShaderMaterial

	func setup(p_ex: Explosion, count: int, speed: float, cone_deg: float, size: float, color: Vector3, hot: float, spread_r: float, delay: float = 0.0) -> void:
		ex = p_ex
		mmi = MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		var bm := BoxMesh.new()
		bm.size = Vector3(1.0, 0.6, 0.8)
		mm.mesh = bm
		var n := int(count * clampf(Game.quality_steps_scale(), 0.4, 1.5))
		mm.instance_count = n
		var rng := RandomNumberGenerator.new()
		rng.seed = int(ex.bomb.get("num", 1)) * 7919
		for i in n:
			var az := rng.randf() * TAU
			var el := deg_to_rad(90.0 - rng.randf() * cone_deg)
			var dir := Vector3(cos(el) * cos(az), sin(el), cos(el) * sin(az))
			var v := dir * speed * pow(rng.randf(), 0.6)
			var start := Vector3(cos(az), 0.0, sin(az)) * spread_r * rng.randf() + Vector3(0, 0.5, 0)
			mm.set_instance_transform(i, Transform3D(Basis(), start))
			mm.set_instance_custom_data(i, Color(v.x, v.y, v.z, rng.randf() * 100.0))
		mmi.multimesh = mm
		mat = ShaderMaterial.new()
		mat.shader = FxLayersLib.DEBRIS_SHADER
		mat.set_shader_parameter("size_scale", size)
		mat.set_shader_parameter("base_col", color)
		mat.set_shader_parameter("hot", hot)
		mat.set_shader_parameter("drag", 0.12)
		mat.set_shader_parameter("t_launch", delay)
		mmi.material_override = mat
		mmi.extra_cull_margin = 50000.0
		mmi.custom_aabb = AABB(Vector3(-20000, -2000, -20000), Vector3(40000, 30000, 40000))
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		mmi.global_position = ex.gz

	func update(_t: float) -> void:
		pass
