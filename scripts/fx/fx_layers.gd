class_name FxLayersLib
extends RefCounted
## Secondary explosion layers (each is a Node3D with setup(ex) / update(age)):
## ShockLayer (refraction of the background through the blast front + Mach stem),
## DustWallLayer (ragged dust ring raised by the front), WilsonLayer (condensation shell),
## DebrisLayer (analytic ballistic clods + fragment-impact ground puffs).
## Everything is a pure function of the explosion age (deterministic scrubbing).
##
## Draw order vs the raymarched volume (render_priority 0, no depth write): layers that surround
## the cloud are split into a FAR half drawn before the volume (priority < 0) and a NEAR half drawn
## after it (priority > 0), so the cloud hides what is behind it and is hidden by what is in front.

const SHOCK_SHADER := preload("res://shaders/shockwave.gdshader")
const DUST_SHADER := preload("res://shaders/dust_wall.gdshader")
const WILSON_SHADER := preload("res://shaders/wilson.gdshader")
const DEBRIS_SHADER := preload("res://shaders/debris.gdshader")

const PRIO_SHOCK := -2       # refraction of the opaque scene only: before everything translucent
const PRIO_FAR := -1         # far halves (behind the cloud)
const PRIO_NEAR_DUST := 1    # near halves (in front of the cloud)
const PRIO_NEAR_WILSON := 3
const MK82_CHARGE_KG := 89.0


static func _sphere_mesh(rings: int, segs: int) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.rings = rings
	s.radial_segments = segs
	return s


## Two MeshInstance3D sharing one mesh: [far, near]; each gets its own ShaderMaterial with
## `part` = 0 (far) / 1 (near). Returns [instances, materials].
static func _split_pair(parent: Node3D, mesh: Mesh, shader: Shader, prio_far: int, prio_near: int) -> Array:
	var insts: Array[GeometryInstance3D] = []
	var mats: Array[ShaderMaterial] = []
	for part in 2:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var m := ShaderMaterial.new()
		m.shader = shader
		m.render_priority = prio_far if part == 0 else prio_near
		m.set_shader_parameter("part", float(part))
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 100000.0
		parent.add_child(mi)
		insts.append(mi)
		mats.append(m)
	return [insts, mats]


## QA switch: `--fx_off shock,dust,wilson,debris` hides those layers (isolates them in renders).
static func is_off(layer: String) -> bool:
	return Args.has("fx_off") and Args.get_str("fx_off").contains(layer)


static func _set_all(mats: Array, key: String, value: Variant) -> void:
	for m in mats:
		(m as ShaderMaterial).set_shader_parameter(key, value)


## HE charge size relative to a Mk 82 (cube root), 1.0 for nuclear.
static func he_scale(prof: ExplosionProfile) -> float:
	if not prof.conventional:
		return 1.0
	var kg := prof.charge_kg if prof.charge_kg > 0.0 else prof.w_kt * 1.0e6
	return pow(maxf(kg, 1.0) / MK82_CHARGE_KG, 1.0 / 3.0)


# ---------------------------------------------------------------------------------------- shock

class ShockLayer extends Node3D:
	var ex: Explosion
	var shell: MeshInstance3D
	var mat: ShaderMaterial
	var burst_y := 0.0
	var amp := 1.0            # refraction scale by burst type
	var cond_k := 0.0         # condensation band (large yields in humid air only)

	func setup(p_ex: Explosion) -> void:
		ex = p_ex
		shell = MeshInstance3D.new()
		shell.mesh = FxLayersLib._sphere_mesh(32, 64)
		mat = ShaderMaterial.new()
		mat.shader = FxLayersLib.SHOCK_SHADER
		# refraction samples the screen texture (opaque scene only): it must be drawn before the
		# volume, otherwise it would paint the background over the cloud (the old pen-line arcs)
		mat.render_priority = FxLayersLib.PRIO_SHOCK
		mat.set_shader_parameter("noise_b", FxResources.noise_billow())
		shell.material_override = mat
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shell.extra_cull_margin = 100000.0
		add_child(shell)
		var prof := ex.prof
		burst_y = maxf(prof.hob, 0.0)
		# at kilometres an HE or sub-kiloton front is a faint shimmer, not a line
		if prof.conventional:
			amp = 0.2
		else:
			amp = lerpf(0.2, 1.0, smoothstep(0.5, 3.0, prof.blast_yield()))
		if prof.kind == ExplosionProfile.Kind.NUCLEAR_UNDERWATER:
			amp *= 0.2
		amp *= float(prof.a("shock_refraction", 1.0))
		# a visible condensation band in the front is only justified for big yields in humid air
		var big := smoothstep(300.0, 5000.0, prof.w_kt) if prof.nuclear else 0.0
		cond_k = big * float(prof.a("shock_condensation", 1.0))

	func update(t: float) -> void:
		var prof := ex.prof
		if t <= 0.0 or prof.kind == ExplosionProfile.Kind.NUCLEAR_BURIED or prof.kind == ExplosionProfile.Kind.CONVENTIONAL_BURIED or FxLayersLib.is_off("shock"):
			shell.visible = false
			return
		var slant := ex.shock_slant_radius(t)
		var w := prof.blast_yield()
		var p := BlastPhysics.overpressure(w, slant, prof.surface, prof.conventional)
		var fsr: float = prof.fireball_state(t)["radius"]
		# the front is not separable from the fireball until it has left it
		var out := smoothstep(1.2, 1.6, slant / maxf(fsr, 1.0))
		shell.visible = slant > 1.0 and p > 0.05 and out > 0.0 and amp > 0.0
		if not shell.visible:
			return
		# optical thickness of the compressed layer: leading part of the positive phase
		var tp := BlastPhysics.positive_phase(w, p, prof.surface)
		var thick := clampf(0.15 * BlastPhysics.C0 * tp, 0.1, slant * 0.08)
		var centre := ex.gz + Vector3(0, burst_y, 0)
		shell.global_position = centre
		shell.scale = Vector3.ONE * slant * 1.02
		mat.set_shader_parameter("centre", centre)
		mat.set_shader_parameter("radius", slant)
		mat.set_shader_parameter("p_psi", p)
		mat.set_shader_parameter("thick", thick)
		mat.set_shader_parameter("amp", amp * out)
		mat.set_shader_parameter("ground_y", -burst_y)
		var stem := 0.0
		if prof.hob > 0.0 and slant > prof.hob * 1.1:
			stem = minf(slant * 0.25, prof.hob * 1.5)
		mat.set_shader_parameter("stem_h", stem)
		var hum := clampf((Game.humidity - 0.45) / 0.35, 0.0, 1.0)
		# a free-air condensation veil exists only for seconds near the strong front (cycle 3: gated by
		# p > 1-2 psi it stayed on for minutes as a pen-line 'glass dome' across the sky)
		mat.set_shader_parameter("condensation", cond_k * hum * smoothstep(4.0, 10.0, p) * (1.0 - smoothstep(6.0, 12.0, t)) * out)
		mat.set_shader_parameter("cond_w", slant * 0.06)


# ------------------------------------------------------------------------------------ dust ring

class DustWallLayer extends Node3D:
	var ex: Explosion
	var walls: Array[GeometryInstance3D] = []
	var mats: Array[ShaderMaterial] = []
	var amount := 1.0
	var hes := 1.0            # HE charge scale (Mk 82 = 1)
	var h_cap := 4.0          # max dust height (m)
	var tau := 1.0            # fade time constant after the ring forms (s)
	var t_start := 0.0        # when the front leaves ~1.5 fireball radii
	var p0 := 1.0             # overpressure (psi) below which no dust is raised
	var precursor := false

	func setup(p_ex: Explosion) -> void:
		ex = p_ex
		var prof := ex.prof
		var cm := CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 1.0
		cm.height = 1.0
		cm.radial_segments = 256
		cm.rings = 1
		cm.cap_top = false
		cm.cap_bottom = false
		var pair := FxLayersLib._split_pair(self, cm, FxLayersLib.DUST_SHADER, FxLayersLib.PRIO_FAR, FxLayersLib.PRIO_NEAR_DUST)
		walls.assign(pair[0])
		mats.assign(pair[1])
		FxLayersLib._set_all(mats, "noise_b", FxResources.noise_billow())
		FxLayersLib._set_all(mats, "noise_a", FxResources.noise_fbm())
		FxLayersLib._set_all(mats, "seed", float(ex.bomb.get("num", 1)) * 0.37)
		FxLayersLib._set_all(mats, "centre", ex.gz)
		FxLayersLib._set_all(mats, "mode", 0)
		var k := prof.kind
		amount = 1.0 if (prof.surface or prof.dusty) else 0.55
		if k == ExplosionProfile.Kind.NUCLEAR_UNDERWATER:
			amount = 0.0
		amount *= float(prof.a("dust_wall", 1.0))
		var dc: Array = prof.a("dust_color", [0.66, 0.58, 0.48])
		FxLayersLib._set_all(mats, "dust_col", Vector3(dc[0], dc[1], dc[2]))
		precursor = bool(prof.a("precursor", false))
		FxLayersLib._set_all(mats, "ragged", 1.0 if precursor else (0.6 if prof.conventional else 0.45))
		hes = FxLayersLib.he_scale(prof)
		var wc := pow(maxf(prof.blast_yield(), 1e-6), 1.0 / 3.0)
		if prof.conventional:
			h_cap = 4.0 * hes
		else:
			h_cap = 20.0 * wc * (1.8 if precursor else 1.0)
		h_cap = float(prof.a("dust_wall_h_max", h_cap))
		# fade time once the ring forms: HE ~0.25 s (Mk 82) .. 1.2 s (MOAB); nuclear 2.5 s x W^1/3
		tau = float(prof.a("dust_wall_tau", (5.4 if prof.conventional else 2.5) * wc))
		p0 = 0.6 if precursor else 1.0
		var r_on := prof.r_fb_max * 1.5
		t_start = BlastPhysics.arrival_time(prof.w_kt, sqrt(r_on * r_on + burst_h() * burst_h()), prof.surface, prof.conventional)

	func burst_h() -> float:
		return maxf(ex.prof.hob, 0.0)

	func _hide() -> void:
		for w in walls:
			w.visible = false

	func update(t: float) -> void:
		var prof := ex.prof
		var r := prof.shock_ground_radius(t, ex.arrival_tbl)
		if t <= 0.0 or r <= 1.0 or amount <= 0.0 or FxLayersLib.is_off("dust"):
			_hide()
			return
		var hb := burst_h()
		var slant := sqrt(r * r + hb * hb)
		var p := BlastPhysics.overpressure(prof.blast_yield(), slant, prof.surface, prof.conventional)
		# dust is raised only where the wind behind the front is strong (> ~1 psi)
		var op := clampf((p - p0) / 2.5, 0.0, 1.0) * amount
		# never inside or hugging the fireball (the old grey 'puck' under the ball)
		var fsr: float = prof.fireball_state(t)["radius"]
		var r_ref := maxf(fsr, prof.r_fb_max if prof.conventional else 0.0)
		op *= smoothstep(1.3, 1.8, slant / maxf(r_ref, 0.5))
		if prof.conventional:
			op *= exp(-r / (120.0 * hes))
		# the ring thins out as it races away (dust settles / spreads behind the front)
		op *= exp(-maxf(t - t_start, 0.0) / maxf(tau, 0.05))
		if op <= 0.01:
			_hide()
			return
		var h: float
		if prof.conventional:
			h = clampf(r * 0.02, 1.0 * hes, 4.0 * hes)
		else:
			h = clampf(r * 0.02, 2.0, h_cap) * (1.0 + clampf(p / 10.0, 0.0, 1.0))
			if precursor:
				h *= 1.8
		h = minf(h, h_cap)
		# mesh: 2 m below the ground up to the tallest ragged lumps
		var hm := h * 2.3 + 2.0
		for w in walls:
			w.visible = true
			w.global_position = ex.gz + Vector3(0, hm * 0.5 - 2.0, 0)
			w.scale = Vector3(r, hm, r)
			(w as MeshInstance3D).custom_aabb = AABB(Vector3(-1.2, -50.0, -1.2), Vector3(2.4, 100.0, 2.4))
		FxLayersLib._set_all(mats, "radius", r)
		FxLayersLib._set_all(mats, "lean", minf(h * 2.0 / r, 0.15))
		FxLayersLib._set_all(mats, "height", h)
		FxLayersLib._set_all(mats, "mesh_h", hm)
		FxLayersLib._set_all(mats, "opacity", op)
		FxLayersLib._set_all(mats, "age", t)


# --------------------------------------------------------------------------------- Wilson cloud

class WilsonLayer extends Node3D:
	var ex: Explosion
	var shells: Array[GeometryInstance3D] = []
	var mats: Array[ShaderMaterial] = []
	var t0 := 0.0
	var dur := 1.0
	var amount := 0.0
	var flatten := 1.0
	var clear_bottom := 1.0
	var tau_k := 1.0

	func setup(p_ex: Explosion) -> void:
		ex = p_ex
		var prof := ex.prof
		var pair := FxLayersLib._split_pair(self, FxLayersLib._sphere_mesh(32, 64), FxLayersLib.WILSON_SHADER, FxLayersLib.PRIO_FAR, FxLayersLib.PRIO_NEAR_WILSON)
		shells.assign(pair[0])
		mats.assign(pair[1])
		FxLayersLib._set_all(mats, "noise_b", FxResources.noise_billow())
		FxLayersLib._set_all(mats, "noise_a", FxResources.noise_fbm())
		FxLayersLib._set_all(mats, "seed", float(ex.bomb.get("num", 1)) * 1.7)
		# appears when the rarefaction behind the front cools humid air (~RH > 0.55)
		var hum := Game.humidity
		# a spherical shell is a kiloton phenomenon; above ~150 kt only bombs whose profile asks for
		# it (King, RDS-37: 'wilson' > 0) get one, rendered as flattened stacked discs
		var big := prof.w_kt > 150.0
		var default_w := 0.0 if big else 1.0
		# wilson_hum_min: the documented shot had humid air even if the player's humidity is lower
		amount = clampf((maxf(hum, float(prof.a("wilson_hum_min", 0.0))) - 0.45) / 0.35, 0.0, 1.0) * float(prof.a("wilson", default_w))
		# duration: wilson_dur_s in SECONDS if given, else wilson_duration as a multiplier of the
		# physics duration (cycle 3: King's 5.0 multiplier meant a 48 s opaque igloo)
		dur = maxf(prof.wilson_t, 0.25) * float(prof.a("wilson_duration", 1.0))
		if prof.art.has("wilson_dur_s"):
			dur = float(prof.art["wilson_dur_s"])
		t0 = float(prof.a("wilson_start", 0.0))
		if t0 <= 0.0:
			# when the front reaches ~ the Wilson radius
			t0 = prof.wilson_t0
		# flattened: the condensation sits in the humid low layers (dome for surface bursts,
		# a flattened shell with disc banding for airbursts, stacked discs for megatons)
		flatten = float(prof.a("wilson_flatten", 0.55 if big else (0.9 if prof.surface else 0.75)))
		FxLayersLib._set_all(mats, "flatten", flatten)
		FxLayersLib._set_all(mats, "thick", float(prof.a("wilson_thick", 0.3)))
		FxLayersLib._set_all(mats, "discs", float(prof.a("wilson_discs", 0.6 if big else (0.0 if prof.surface else 0.3))))
		# the dome evaporates from the bottom up (Baker) - airbursts thin out evenly
		clear_bottom = float(prof.a("wilson_clear", 1.0 if prof.surface else 0.4))
		# optical depth across one wall: Baker's dome is milky, nearly opaque; airburst veils thinner
		tau_k = float(prof.a("wilson_opacity", 1.4 if prof.surface else 0.9))

	func _hide() -> void:
		for s in shells:
			s.visible = false

	func update(t: float) -> void:
		if amount <= 0.0 or t < t0 or t > t0 + dur * 2.2 or FxLayersLib.is_off("wilson"):
			_hide()
			return
		var x := (t - t0) / dur
		var op := smoothstep(0.0, 0.15, x) * (1.0 - smoothstep(0.9, 2.2, x)) * amount
		if op <= 0.005:
			_hide()
			return
		var prof := ex.prof
		# the condensation forms in the air the front has just crossed and stays in that air: the
		# shell grows with the front only while it forms, then stays put and evaporates
		var slant := ex.shock_slant_radius(minf(t, t0 + dur * 0.6)) * 0.92
		var cy := maxf(prof.hob, 0.0)
		if prof.kind == ExplosionProfile.Kind.NUCLEAR_UNDERWATER:
			cy = 0.0
		var centre := ex.gz + Vector3(0, cy, 0)
		for s in shells:
			s.visible = true
			s.global_position = centre
			s.scale = Vector3(slant, slant * flatten, slant) * 1.03
		FxLayersLib._set_all(mats, "centre", centre)
		FxLayersLib._set_all(mats, "radius", slant)
		FxLayersLib._set_all(mats, "tau", tau_k * op)
		# droplets evaporate in growing holes, and from the bottom up
		FxLayersLib._set_all(mats, "evap", smoothstep(0.35, 2.0, x))
		FxLayersLib._set_all(mats, "clear_y", lerpf(-1.2, 0.55, smoothstep(0.3, 1.8, x) * clear_bottom))
		FxLayersLib._set_all(mats, "ground_y", -cy)
		FxLayersLib._set_all(mats, "age", t)
		# fireball light, on the same scale as the volume's own fireball-lit cloud (bb_lum x emis)
		var fs := prof.fireball_state(t)
		var temp := float(fs["temp"])
		var lum := pow(temp / 8000.0, 4.0) * smoothstep(650.0, 1500.0, temp) * float(fs["emis"]) * float(fs["opacity"])
		var c := ex._bb_color(maxf(temp, 1000.0))
		var fire := Vector3(pow(c.r, 2.2), pow(c.g, 2.2), pow(c.b, 2.2)) * lum
		FxLayersLib._set_all(mats, "fire", Vector4(fire.x, fire.y, fire.z, float(fs["radius"])))
		FxLayersLib._set_all(mats, "fire_pos", ex.gz + Vector3(0, float(fs["center_y"]), 0))


# --------------------------------------------------------------------------- debris and puffs

class DebrisLayer extends Node3D:
	var ex: Explosion
	var mmi: MultiMeshInstance3D
	var mat: ShaderMaterial
	var puffs: Array[GeometryInstance3D] = []
	var puff_mats: Array[ShaderMaterial] = []

	func setup(p_ex: Explosion, count: int, speed: float, cone_deg: float, size: float, color: Vector3, hot: float, spread_r: float, delay: float = 0.0) -> void:
		ex = p_ex
		var prof := ex.prof
		mmi = MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = FxLayersLib.rock_mesh()
		# fewer pieces: most of the ejecta mass is dust (volume); a few clods read, a cloud of specks does not
		var n := int(count * clampf(Game.quality_steps_scale(), 0.4, 1.5) * float(prof.a("debris_frac", 0.6)))
		mm.instance_count = n
		var rng := RandomNumberGenerator.new()
		rng.seed = int(ex.bomb.get("num", 1)) * 7919
		for i in n:
			# wide, small-skewed size spread: 0.25..2.3 x the nominal size (log distributed)
			var f := 0.25 * pow(9.2, pow(rng.randf(), 1.8))
			var sz := size * f
			var big := clampf((f - 0.25) / 2.05, 0.0, 1.0)
			var az := rng.randf() * TAU
			var el := deg_to_rad(90.0 - rng.randf() * cone_deg)
			var dir := Vector3(cos(el) * cos(az), sin(el), cos(el) * sin(az))
			# speeds skewed slow; big blocks are thrown slower than small clods
			var v := dir * speed * (0.1 + 0.9 * pow(rng.randf(), 1.6)) * lerpf(1.0, 0.6, big)
			var start := Vector3(cos(az), 0.0, sin(az)) * spread_r * sqrt(rng.randf()) + Vector3(0, 0.5, 0)
			var axis := (Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() - 0.5) + Vector3(0.0, 1e-3, 0.0)).normalized()
			var shape := Basis(axis, rng.randf() * TAU) * Basis.from_scale(Vector3(rng.randf_range(0.8, 1.25), rng.randf_range(0.5, 0.9), rng.randf_range(0.7, 1.1)) * sz)
			mm.set_instance_transform(i, Transform3D(shape, start))
			mm.set_instance_custom_data(i, Color(v.x, v.y, v.z, rng.randf() * 100.0))
		mmi.multimesh = mm
		mat = ShaderMaterial.new()
		mat.shader = FxLayersLib.DEBRIS_SHADER
		mat.set_shader_parameter("base_col", color)
		mat.set_shader_parameter("hot", hot)
		mat.set_shader_parameter("drag", float(prof.a("debris_drag", 0.6)))
		mat.set_shader_parameter("t_launch", delay)
		mmi.material_override = mat
		mmi.extra_cull_margin = 50000.0
		mmi.custom_aabb = AABB(Vector3(-20000, -2000, -20000), Vector3(40000, 30000, 40000))
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		mmi.global_position = ex.gz
		_setup_puffs(rng)

	## Fragment fan of cased HE bombs: small tan dust puffs where casing fragments hit the ground.
	func _setup_puffs(rng: RandomNumberGenerator) -> void:
		var prof := ex.prof
		var hes := FxLayersLib.he_scale(prof)
		var def_n := roundi(36.0 * sqrt(hes)) if prof.kind == ExplosionProfile.Kind.CONVENTIONAL_SURFACE else 0
		var n := int(prof.a("frag_puffs", def_n))
		if n <= 0:
			return
		var r_max := float(prof.a("frag_puff_r", 150.0 * hes))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		var qm := QuadMesh.new()
		qm.size = Vector2.ONE
		mm.mesh = qm
		mm.instance_count = n
		for i in n:
			var az := rng.randf() * TAU
			# dense near the crater, sparse far out
			var rr := lerpf(20.0 * minf(hes, 2.0), r_max, pow(rng.randf(), 1.5))
			var px := ex.gz.x + cos(az) * rr
			var pz := ex.gz.z + sin(az) * rr
			var pos := Vector3(px, TerrainMath.height(px, pz), pz) - ex.gz
			# fragments (~1-2 km/s) land within ~0.1-0.5 s, the near ones first
			var t_birth := 0.1 + 0.25 * rr / r_max + rng.randf() * 0.15
			var s := rng.randf_range(2.5, 4.5) * sqrt(hes)
			mm.set_instance_transform(i, Transform3D(Basis(), pos))
			mm.set_instance_custom_data(i, Color(t_birth, s, s * 0.6, rng.randf() * 10.0))
		# the puffs are the ground itself thrown up: soil colour, not the pale dust-wall colour
		var dc: Array = prof.a("ground_color", [0.55, 0.47, 0.38])
		for part in 2:
			var inst := MultiMeshInstance3D.new()
			inst.multimesh = mm
			var m := ShaderMaterial.new()
			m.shader = FxLayersLib.DUST_SHADER
			m.render_priority = FxLayersLib.PRIO_FAR if part == 0 else FxLayersLib.PRIO_NEAR_DUST
			m.set_shader_parameter("mode", 1)
			m.set_shader_parameter("part", float(part))
			m.set_shader_parameter("centre", ex.gz)
			m.set_shader_parameter("noise_b", FxResources.noise_billow())
			m.set_shader_parameter("noise_a", FxResources.noise_fbm())
			m.set_shader_parameter("dust_col", Vector3(dc[0], dc[1], dc[2]))
			m.set_shader_parameter("puff_life", float(prof.a("frag_puff_life", 3.0)))
			m.set_shader_parameter("opacity", 0.9)
			inst.material_override = m
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			inst.extra_cull_margin = 5000.0
			inst.custom_aabb = AABB(Vector3(-r_max - 50.0, -100.0, -r_max - 50.0), Vector3(r_max * 2.0 + 100.0, 200.0, r_max * 2.0 + 100.0))
			add_child(inst)
			inst.global_position = ex.gz
			puffs.append(inst)
			puff_mats.append(m)

	func update(t: float) -> void:
		var off := FxLayersLib.is_off("debris")
		mmi.visible = not off
		for p in puffs:
			p.visible = not off
		for m in puff_mats:
			m.set_shader_parameter("age", t)


## Low-poly jittered rock (icosahedron with per-vertex radial noise, flat shaded), built once.
static var _rock: ArrayMesh


static func rock_mesh() -> ArrayMesh:
	if _rock != null:
		return _rock
	var g := (1.0 + sqrt(5.0)) * 0.5
	var v := [Vector3(-1, g, 0), Vector3(1, g, 0), Vector3(-1, -g, 0), Vector3(1, -g, 0),
		Vector3(0, -1, g), Vector3(0, 1, g), Vector3(0, -1, -g), Vector3(0, 1, -g),
		Vector3(g, 0, -1), Vector3(g, 0, 1), Vector3(-g, 0, -1), Vector3(-g, 0, 1)]
	var f := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4],
		[11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var pts: Array[Vector3] = []
	for p in v:
		pts.append((p as Vector3).normalized() * 0.5 * rng.randf_range(0.7, 1.2))
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for tri in f:
		var a: Vector3 = pts[tri[0]]
		var b: Vector3 = pts[tri[1]]
		var c: Vector3 = pts[tri[2]]
		var nrm := (b - a).cross(c - a)
		if nrm.dot(a + b + c) < 0.0:
			# make (a, b, c) counter-clockwise seen from outside
			nrm = -nrm
			var tmp := b
			b = c
			c = tmp
		nrm = nrm.normalized()
		# Godot front faces are clockwise as seen from outside: emit (a, c, b)
		verts.append_array([a, c, b])
		norms.append_array([nrm, nrm, nrm])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	_rock = ArrayMesh.new()
	_rock.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _rock
