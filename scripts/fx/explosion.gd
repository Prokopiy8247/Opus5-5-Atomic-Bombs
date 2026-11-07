class_name Explosion
extends Node3D
## One explosion instance. Everything is a function of `age` (seconds since detonation):
## set_age() can scrub to any time (test rig), advance() plays it with the game's time scale.

signal shock_arrived(pressure_psi: float)
signal stage_changed(stage: String)

const VOLUME_SHADER := preload("res://shaders/explosion_volume.gdshader")

var prof: ExplosionProfile
var bomb: Dictionary
var gz := Vector3.ZERO            # ground zero (world, on the terrain surface)
var age := -1.0
var observer := Vector3.ZERO      # bunker eye position
var obs_dist := 1000.0            # slant distance burst -> observer
var obs_ground_dist := 1000.0
var arrival_tbl: PackedFloat64Array
var t_shock_obs := 0.0            # blast arrival at the bunker
var t_sound_obs := 0.0
var t_seismic_obs := 0.0
var p_obs := 0.0                  # peak overpressure at the bunker (psi)
var q_obs := 0.0                  # thermal fluence at the bunker (cal/cm2)
var shock_done := false
var seismic_done := false
var stage := ""

var env_ctl: EnvironmentCtl
var bunker: Bunker
var cam: Camera3D

var volume: MeshInstance3D
var vol_mat: ShaderMaterial
var fire_light: OmniLight3D
var layers: Array = []            # extra layer nodes with update(age) methods


func setup(b: Dictionary, ground_zero: Vector3, p_env: EnvironmentCtl, p_bunker: Bunker, p_cam: Camera3D) -> void:
	bomb = b
	prof = ExplosionProfile.new(b)
	gz = ground_zero
	env_ctl = p_env
	bunker = p_bunker
	cam = p_cam
	arrival_tbl = prof.build_arrival_table()
	var burst := gz + Vector3(0, maxf(prof.hob, 0.0), 0)
	obs_dist = burst.distance_to(observer)
	obs_ground_dist = Vector2(gz.x, gz.z).length()
	t_shock_obs = BlastPhysics.arrival_time(prof.w_kt, obs_dist, prof.surface)
	if prof.kind == ExplosionProfile.Kind.NUCLEAR_BURIED or prof.kind == ExplosionProfile.Kind.CONVENTIONAL_BURIED:
		# coupled into the ground: weaker air blast
		p_obs = BlastPhysics.overpressure(prof.w_kt * 0.1, obs_dist, true)
	elif prof.kind == ExplosionProfile.Kind.NUCLEAR_UNDERWATER:
		p_obs = BlastPhysics.overpressure(prof.w_kt * 0.3, obs_dist, true)
	else:
		p_obs = BlastPhysics.overpressure(prof.w_kt, obs_dist, prof.surface)
	t_sound_obs = maxf(t_shock_obs, 0.0)
	t_seismic_obs = BlastPhysics.seismic_delay(obs_ground_dist)
	q_obs = BlastPhysics.thermal_fluence(prof.w_kt, obs_dist, Game.humidity) if prof.nuclear else 0.0
	_build()
	set_age(0.0)


func _build() -> void:
	volume = MeshInstance3D.new()
	volume.name = "Volume"
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	volume.mesh = bm
	vol_mat = ShaderMaterial.new()
	vol_mat.shader = VOLUME_SHADER
	vol_mat.set_shader_parameter("noise_a", FxResources.noise_fbm())
	vol_mat.set_shader_parameter("noise_b", FxResources.noise_billow())
	vol_mat.set_shader_parameter("seed", float(int(bomb.get("num", 1)) * 3.17))
	vol_mat.set_shader_parameter("origin_world", gz)
	vol_mat.render_priority = 0
	volume.material_override = vol_mat
	volume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	volume.extra_cull_margin = 1000.0
	add_child(volume)
	_apply_art_static()

	fire_light = OmniLight3D.new()
	fire_light.name = "FireLight"
	fire_light.light_cull_mask = 1
	fire_light.shadow_enabled = true
	fire_light.omni_attenuation = 1.0
	fire_light.light_energy = 0.0
	add_child(fire_light)


func _apply_art_static() -> void:
	var c := func(key: String, def: Array) -> Vector3:
		var v: Array = prof.a(key, def)
		return Vector3(v[0], v[1], v[2])
	var ca: Vector3 = c.call("head_color_early", [0.34, 0.17, 0.08] if not prof.dusty else [0.32, 0.20, 0.11])
	var cb: Vector3 = c.call("head_color_late", [0.62, 0.56, 0.50] if not prof.dusty else [0.52, 0.44, 0.36])
	vol_mat.set_shader_parameter("head_col_a", Vector4(ca.x, ca.y, ca.z, 0.0))
	vol_mat.set_shader_parameter("head_col_b", Vector4(cb.x, cb.y, cb.z, float(prof.a("dark_base", 0.6))))
	var sc: Vector3 = c.call("stem_color", [0.27, 0.20, 0.14] if prof.dusty else [0.42, 0.36, 0.30])
	vol_mat.set_shader_parameter("stem_col", Vector4(sc.x, sc.y, sc.z, float(prof.a("stem_stretch", 1.6))))
	var kc: Vector3 = c.call("skirt_color", [0.60, 0.55, 0.48] if (prof.surface or prof.dusty) else [0.52, 0.48, 0.43])
	vol_mat.set_shader_parameter("skirt_col", Vector4(kc.x, kc.y, kc.z, 0.0))
	var gcv: Vector3 = c.call("ground_color", [0.55, 0.47, 0.38])
	vol_mat.set_shader_parameter("ground_col", gcv)
	var tint: Array = prof.a("fireball_tint", [1.0, 1.0, 1.0, 0.0])
	vol_mat.set_shader_parameter("fb_tint", Vector4(tint[0], tint[1], tint[2], tint[3]))
	vol_mat.set_shader_parameter("head_detail", Vector4(float(prof.a("head_noise_amp", 0.30)), float(prof.a("billow_sharp", 0.6)), float(prof.a("erosion", 0.8)), 0.0))
	vol_mat.set_shader_parameter("base_steps", float(prof.a("steps", 64.0)))
	vol_mat.set_shader_parameter("debug_mode", Args.get_int("vdebug", 0))
	var empty: Array[Vector4] = [Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO]
	vol_mat.set_shader_parameter("rings", empty)


func current_stage(t: float) -> String:
	if t < 0.0:
		return ""
	if not prof.nuclear:
		if t < prof.fb_duration * 0.4:
			return "flash"
		if t < prof.fb_duration * 1.2:
			return "fireball"
		if t < prof.t_stab * 0.5:
			return "rise"
		return "stabilization"
	if t < prof.tmin * 3.0:
		return "flash"
	if t < prof.t_fb_max * 2.0:
		return "fireball"
	if t < prof.t_fb_max * 6.0:
		return "breakaway"
	if t < prof.t_stab * 0.8:
		return "rise"
	return "stabilization"


func advance(dt: float) -> void:
	set_age(age + dt, dt)


func set_age(t: float, dt: float = 0.0) -> void:
	var prev := age
	age = t
	_update_volume(t)
	_update_lights(t)
	_update_globals(t)
	for l in layers:
		l.update(t)
	var s := current_stage(t)
	if s != stage:
		stage = s
		stage_changed.emit(s)
	# observer events
	if not seismic_done and t >= t_seismic_obs:
		seismic_done = true
		if cam is PlayerCamera:
			(cam as PlayerCamera).tremor = clampf(0.15 + log(1.0 + p_obs) * 0.25, 0.0, 1.2)
	if not shock_done and t >= t_shock_obs:
		shock_done = true
		shock_arrived.emit(p_obs)
		if bunker:
			bunker.apply_shock(p_obs)
		if cam is PlayerCamera:
			(cam as PlayerCamera).shake = clampf(0.1 + p_obs * 0.35, 0.0, 3.0)
	if prev > t:
		# scrubbed backwards
		shock_done = t >= t_shock_obs
		seismic_done = t >= t_seismic_obs


func _update_volume(t: float) -> void:
	var fs := prof.fireball_state(t)
	var hs := prof.head_state(t)
	var ss := prof.stem_state(t)
	var shock_r := prof.shock_ground_radius(t, arrival_tbl)
	var ks := prof.skirt_state(t, shock_r)
	vol_mat.set_shader_parameter("age", t)
	var fr: float = fs["radius"]
	vol_mat.set_shader_parameter("fb", Vector4(0.0, fs["center_y"], 0.0, fr if float(fs["opacity"]) > 0.001 else 0.0))
	vol_mat.set_shader_parameter("fb_look", Vector4(fs["temp"], fs["emis"], float(prof.a("fireball_noise", 0.22)), fs["opacity"]))
	vol_mat.set_shader_parameter("fb_shape", Vector4(fs["squash"], fs["mottle"], float(prof.a("fireball_noise_scale", 6.0)), fs["skin"]))
	var hr: float = hs["radius"] if float(hs["density"]) > 0.001 else 0.0
	vol_mat.set_shader_parameter("head", Vector4(0.0, hs["center_y"], 0.0, hr))
	vol_mat.set_shader_parameter("head_shape", Vector4(hs["half"], hs["torus"], hs["density"], hs["roll"]))
	var ca: Vector4 = vol_mat.get_shader_parameter("head_col_a")
	ca.w = hs["col_mix"]
	vol_mat.set_shader_parameter("head_col_a", ca)
	var core_r := lerpf(1.1, float(prof.a("core_radius", 0.5)), clampf(t / maxf(prof.t_stab * 0.12, 1.0), 0.0, 1.0))
	vol_mat.set_shader_parameter("head_heat", Vector4(hs["heat_temp"], hs["heat_glow"], core_r, float(prof.a("head_noise_scale", 0.55))))
	var sr: float = ss["radius"] if float(ss["density"]) > 0.001 and float(ss["top"]) > 1.0 else 0.0
	vol_mat.set_shader_parameter("stem", Vector4(ss["bottom"], ss["top"], sr, ss["density"]))
	vol_mat.set_shader_parameter("stem_shape", Vector4(ss["flare"], ss["waist"], ss["hollow"], ss["rise"]))
	var kr: float = ks["radius"] if float(ks["density"]) > 0.001 else 0.0
	vol_mat.set_shader_parameter("skirt", Vector4(kr, ks["height"], ks["density"], ks["inner"]))
	# proxy bounds (local, relative to ground zero)
	var mn := Vector3(1e9, 1e9, 1e9)
	var mx := Vector3(-1e9, -1e9, -1e9)
	if fr > 0.0:
		var e := fr * (1.0 + float(prof.a("fireball_noise", 0.22)) * 2.0) + 2.0
		mn = mn.min(Vector3(-e, float(fs["center_y"]) - e, -e))
		mx = mx.max(Vector3(e, float(fs["center_y"]) + e, e))
	if hr > 0.0:
		var hh: float = hs["half"]
		var amp := float(prof.a("head_noise_amp", 0.30)) * hh * 1.6
		mn = mn.min(Vector3(-hr - amp, float(hs["center_y"]) - hh - amp, -hr - amp))
		mx = mx.max(Vector3(hr + amp, float(hs["center_y"]) + hh + amp, hr + amp))
	if sr > 0.0:
		var se: float = sr * float(ss["flare"]) * 1.6
		mn = mn.min(Vector3(-se, ss["bottom"], -se))
		mx = mx.max(Vector3(se, float(ss["top"]) + sr, se))
	if kr > 0.0:
		var kh: float = ks["height"]
		mn = mn.min(Vector3(-kr - kh, -kh * 0.3, -kr - kh))
		mx = mx.max(Vector3(kr + kh, kh * 2.2, kr + kh))
	volume.visible = mn.x < mx.x
	if volume.visible:
		vol_mat.set_shader_parameter("box_min", mn)
		vol_mat.set_shader_parameter("box_max", mx)
		volume.global_position = gz + (mn + mx) * 0.5
		volume.scale = (mx - mn).max(Vector3(0.1, 0.1, 0.1))


func fireball_world() -> Vector3:
	var fs := prof.fireball_state(maxf(age, 0.0))
	return gz + Vector3(0, fs["center_y"], 0)


func _update_lights(t: float) -> void:
	var pw := prof.light_power(t)
	var fs := prof.fireball_state(maxf(t, 0.0))
	var fpos := gz + Vector3(0, float(fs["center_y"]), 0)
	var temp: float = maxf(float(fs["temp"]), 1500.0)
	var col := _bb_color(temp)
	var to_obs := observer - fpos
	var d := to_obs.length()
	# illuminance at the observer in "noon suns"
	var illum := 0.0
	if prof.nuclear:
		illum = BlastPhysics.flash_illuminance(prof.w_kt, t, d, Game.humidity)
	else:
		var fr: float = fs["radius"]
		illum = pw * 20.0 * (fr * fr) / maxf(d * d, 1.0) * 1000.0 * BlastPhysics.transmittance(d, Game.humidity)
	# omni light on the range
	var rng := clampf(d * 3.0, 2000.0, 400000.0)
	fire_light.global_position = fpos
	fire_light.omni_range = rng
	# energy so that the ground at the observer receives ~illum * sun energy
	fire_light.light_energy = illum * 3.0 * d * d / maxf(rng * rng, 1.0) * 6.0 if illum > 0.0 else 0.0
	fire_light.light_color = col
	fire_light.visible = illum > 0.00005
	fire_light.shadow_enabled = illum > 0.01
	# bunker directional flash (energy capped; exposure handles the rest)
	if bunker:
		var vis := clampf(illum * 3.0, 0.0, 400.0)
		bunker.set_flash(-to_obs.normalized(), vis, col)
	# eye adaptation: relative luminance vs ambient scene
	if env_ctl:
		var amb := 1.0 if Game.tod != Game.TimeOfDay.NIGHT else 0.03
		var lum := illum / amb
		# the visible fireball adds glare even when the illuminance is modest
		env_ctl.flash_lum = lum


var _last_adapt_age := 0.0


## Integrates the eye adaptation from the last update to `t` (deterministic for scrubbing).
func step_exposure(t: float, dt: float) -> void:
	if env_ctl == null:
		return
	if dt <= 0.0:
		return
	var amb := 1.0 if Game.tod != Game.TimeOfDay.NIGHT else 0.03
	var steps := maxi(1, int(ceil(dt / 0.02)))
	if dt > 60.0:
		steps = maxi(1, int(ceil(dt / 0.25)))
	var h := dt / steps
	var t0 := t - dt
	for i in steps:
		var ti := t0 + h * (i + 1)
		env_ctl.step_adaptation(metered_luminance(ti, amb), h)


## Camera-metering model: average of the flash-lit scene and the fireball's own surface
## luminance weighted by how much of the view it covers (zooming in on the ball darkens).
func metered_luminance(ti: float, amb: float) -> float:
	var ill := 0.0
	var fs := prof.fireball_state(ti)
	if prof.nuclear:
		ill = BlastPhysics.flash_illuminance(prof.w_kt, ti, obs_dist, Game.humidity)
	else:
		var fr: float = fs["radius"]
		ill = prof.light_power(ti) * 20.0 * fr * fr / maxf(obs_dist * obs_dist, 1.0) * 1000.0
	var lum := ill / amb
	if cam and float(fs["radius"]) > 0.0 and float(fs["opacity"]) > 0.0:
		var fpos := gz + Vector3(0, float(fs["center_y"]), 0)
		var to := fpos - cam.global_position
		var d := to.length()
		var fwd := -cam.global_transform.basis.z
		var half_fov := deg_to_rad(cam.fov * 0.5)
		var ang := acos(clampf(fwd.dot(to / maxf(d, 1.0)), -1.0, 1.0))
		var ang_r := atan(float(fs["radius"]) / maxf(d, 1.0))
		if ang < half_fov + ang_r:
			var cov := clampf(pow(ang_r / half_fov, 2.0) * 6.0, 0.0, 1.0)
			var tt: float = fs["temp"]
			var x := tt / 8000.0
			var l_fb := float(fs["emis"]) * x * x * x * x * float(fs["opacity"]) / (1.5 * amb)
			lum = maxf(lum, (1.0 - cov) * (1.0 + lum) + cov * l_fb - 1.0)
	return lum


func _bb_color(temp: float) -> Color:
	var t := clampf(temp, 1000.0, 40000.0) / 100.0
	var r := 1.0 if t <= 66.0 else clampf(1.29293618606 * pow(t - 60.0, -0.1332047592), 0.0, 1.0)
	var g := clampf(0.39008157876 * log(t) - 0.63184144378, 0.0, 1.0) if t <= 66.0 else clampf(1.12989086089 * pow(t - 60.0, -0.0755148492), 0.0, 1.0)
	var b := 1.0 if t >= 66.0 else (0.0 if t <= 19.0 else clampf(0.54320678911 * log(t - 10.0) - 1.19625408914, 0.0, 1.0))
	return Color(r, g, b)


func _update_globals(t: float) -> void:
	RenderingServer.global_shader_parameter_set("g_blast_center", gz)
	RenderingServer.global_shader_parameter_set("g_blast_age", t)
	var fs := prof.fireball_state(maxf(t, 0.0))
	var fpos := gz + Vector3(0, float(fs["center_y"]), 0)
	RenderingServer.global_shader_parameter_set("g_fireball", Vector4(fpos.x, fpos.y, fpos.z, float(fs["radius"])))
	var pw := prof.light_power(t)
	var col := _bb_color(maxf(float(fs["temp"]), 1500.0))
	var inten := pw * pow(maxf(prof.w_kt, 0.0001), 0.33) * 40.0 * BlastPhysics.transmittance(obs_dist, Game.humidity)
	RenderingServer.global_shader_parameter_set("g_fireball_color", Vector4(col.r, col.g, col.b, inten))
	RenderingServer.global_shader_parameter_set("g_flash", clampf(pw * pow(maxf(prof.w_kt, 0.0001), 0.3) * BlastPhysics.transmittance(obs_dist, Game.humidity) * 0.3, 0.0, 20.0))
	# cloud shadow on the ground
	var hs := prof.head_state(t)
	var ss := prof.stem_state(t)
	var opacity := clampf(float(hs["density"]) * 0.85, 0.0, 0.85)
	RenderingServer.global_shader_parameter_set("g_cloud_pos", Vector4(gz.x, gz.y + float(hs["center_y"]), gz.z, opacity))
	RenderingServer.global_shader_parameter_set("g_cloud_shape", Vector4(hs["radius"], hs["half"], ss["radius"], gz.y + float(ss["top"])))
	# crater forms during the first moments (excavation ~ a few seconds)
	var cr_prog := 0.0
	if prof.a("crater", prof.surface or prof.kind in [ExplosionProfile.Kind.NUCLEAR_BURIED, ExplosionProfile.Kind.CONVENTIONAL_BURIED]):
		cr_prog = clampf(t / maxf(float(prof.a("crater_time", 2.0)), 0.05), 0.0, 1.0)
		cr_prog = 1.0 - pow(1.0 - cr_prog, 3.0)
		RenderingServer.global_shader_parameter_set("g_crater", Vector4(prof.crater_r, prof.crater_depth, prof.crater_r * 0.12, cr_prog))
	else:
		RenderingServer.global_shader_parameter_set("g_crater", Vector4(0, 0, 0, 0))
	# scorched ground: char radius where fluence > ~35 cal/cm2, burn radius ~ 10 cal/cm2
	if prof.nuclear and prof.kind != ExplosionProfile.Kind.NUCLEAR_UNDERWATER and prof.kind != ExplosionProfile.Kind.NUCLEAR_BURIED:
		var frac := BlastPhysics.thermal_fraction(prof.w_kt, t)
		var r_char := _fluence_radius(35.0)
		var r_burn := _fluence_radius(10.0)
		var glow := clampf(1.0 - t / maxf(prof.t2 * 30.0, 1.0), 0.0, 1.0) * clampf(t / maxf(prof.t2, 0.001), 0.0, 1.0)
		RenderingServer.global_shader_parameter_set("g_scorch", Vector4(r_char * frac, r_burn * frac, glow, float(prof.a("trinitite", 0.0))))
	else:
		RenderingServer.global_shader_parameter_set("g_scorch", Vector4(0, 0, 0, 0))
	var shock_r := prof.shock_ground_radius(t, arrival_tbl)
	RenderingServer.global_shader_parameter_set("g_shock", Vector4(shock_r, 1.0, maxf(shock_r * 0.02, 5.0), 1.0 if (prof.surface or prof.dusty) else 0.4))


func _fluence_radius(q: float) -> float:
	# solve thermal_fluence(W, r) = q by bisection (monotonic)
	var lo := 1.0
	var hi := 500000.0
	for i in 40:
		var mid := sqrt(lo * hi)
		if BlastPhysics.thermal_fluence(prof.w_kt, mid, Game.humidity) > q:
			lo = mid
		else:
			hi = mid
	var r2 := lo * lo - maxf(prof.hob, 0.0) * maxf(prof.hob, 0.0)
	return sqrt(maxf(r2, 0.0))


func cleanup_globals() -> void:
	RenderingServer.global_shader_parameter_set("g_blast_age", -1.0)
	RenderingServer.global_shader_parameter_set("g_fireball_color", Vector4(0, 0, 0, 0))
	RenderingServer.global_shader_parameter_set("g_flash", 0.0)
	RenderingServer.global_shader_parameter_set("g_cloud_pos", Vector4(0, -10000, 0, 0))
	RenderingServer.global_shader_parameter_set("g_crater", Vector4(0, 0, 0, 0))
	RenderingServer.global_shader_parameter_set("g_scorch", Vector4(0, 0, 0, 0))
	RenderingServer.global_shader_parameter_set("g_shock", Vector4(0, 0, 0, 0))
	RenderingServer.global_shader_parameter_set("g_dome", Vector4(0, 0, 0, 0))
	if bunker:
		bunker.set_flash(Vector3.FORWARD, 0.0, Color.WHITE)
