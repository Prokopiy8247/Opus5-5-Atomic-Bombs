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
var wind_v := Vector3.ZERO        # cloud drift velocity (m/s) at mid-cloud height


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
	t_shock_obs = BlastPhysics.arrival_time(prof.w_kt, obs_dist, prof.surface, prof.conventional)
	p_obs = BlastPhysics.overpressure(prof.blast_yield(), obs_dist, prof.surface, prof.conventional)
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

	_build_layers()

	fire_light = OmniLight3D.new()
	fire_light.name = "FireLight"
	fire_light.light_cull_mask = 1
	fire_light.shadow_enabled = true
	fire_light.omni_attenuation = 1.0
	fire_light.light_energy = 0.0
	add_child(fire_light)


func _build_layers() -> void:
	var k := prof.kind
	var shock := FxLayersLib.ShockLayer.new()
	shock.name = "Shock"
	add_child(shock)
	shock.setup(self)
	layers.append(shock)
	var dust := FxLayersLib.DustWallLayer.new()
	dust.name = "DustWall"
	add_child(dust)
	dust.setup(self)
	layers.append(dust)
	var wil := FxLayersLib.WilsonLayer.new()
	wil.name = "Wilson"
	add_child(wil)
	wil.setup(self)
	layers.append(wil)
	# ejecta / fragments for ground-coupled bursts
	var deb_n := int(prof.a("debris_count", 0))
	if deb_n == 0 and (prof.surface or k in [ExplosionProfile.Kind.NUCLEAR_BURIED, ExplosionProfile.Kind.CONVENTIONAL_BURIED, ExplosionProfile.Kind.CONVENTIONAL_SURFACE]):
		deb_n = 2500
	if deb_n > 0:
		var deb := FxLayersLib.DebrisLayer.new()
		deb.name = "Debris"
		add_child(deb)
		var spd := float(prof.a("debris_speed", clampf(sqrt(prof.crater_r * 9.81 * 2.0) * 1.6, 15.0, 400.0)))
		var dc: Array = prof.a("debris_color", [0.33, 0.27, 0.21])
		var size := float(prof.a("debris_size", clampf(prof.crater_r * 0.025, 0.15, 25.0)))
		var ddelay := float(prof.a("debris_delay", float(prof.a("dome_burst", 0.0))))
		deb.setup(self, deb_n, spd, float(prof.a("debris_cone", 50.0)), size, Vector3(dc[0], dc[1], dc[2]), float(prof.a("debris_hot", 0.0)), prof.crater_r * 0.6, ddelay)
		layers.append(deb)


## Slant radius of the shock front at time t (from the cumulative arrival table).
func shock_slant_radius(t: float) -> float:
	if t <= 0.0:
		return 0.0
	var n := arrival_tbl.size()
	for k in n:
		if arrival_tbl[k] >= t:
			if k == 0:
				return 10.0 * t / maxf(arrival_tbl[0], 1e-6)
			var r0 := 10.0 * pow(1.06, k - 1)
			var r1 := 10.0 * pow(1.06, k)
			var f := (t - arrival_tbl[k - 1]) / maxf(arrival_tbl[k] - arrival_tbl[k - 1], 1e-9)
			return lerpf(r0, r1, f)
	return 10.0 * pow(1.06, n - 1)


func _apply_art_static() -> void:
	var c := func(key: String, def: Array) -> Vector3:
		var v: Array = prof.a(key, def)
		return Vector3(v[0], v[1], v[2])
	var ca: Vector3 = c.call("head_color_early", [0.34, 0.17, 0.08] if not prof.dusty else [0.32, 0.20, 0.11])
	var cb: Vector3 = c.call("head_color_late", [0.62, 0.56, 0.50] if not prof.dusty else [0.52, 0.44, 0.36])
	vol_mat.set_shader_parameter("head_col_a", Vector4(ca.x, ca.y, ca.z, 0.0))
	vol_mat.set_shader_parameter("head_col_b", Vector4(cb.x, cb.y, cb.z, float(prof.a("dark_base", 0.6))))
	var sc: Vector3 = c.call("stem_color", [0.27, 0.20, 0.14] if prof.dusty else [0.42, 0.36, 0.30])
	vol_mat.set_shader_parameter("stem_col", Vector4(sc.x, sc.y, sc.z, float(prof.a("stem_stretch", 1.1))))
	var kc: Vector3 = c.call("skirt_color", [0.60, 0.55, 0.48] if (prof.surface or prof.dusty) else [0.52, 0.48, 0.43])
	vol_mat.set_shader_parameter("skirt_col", Vector4(kc.x, kc.y, kc.z, 0.0))
	var gcv: Vector3 = c.call("ground_color", [0.55, 0.47, 0.38])
	vol_mat.set_shader_parameter("ground_col", gcv)
	var tint: Array = prof.a("fireball_tint", [1.0, 1.0, 1.0, 0.0])
	vol_mat.set_shader_parameter("fb_tint", Vector4(tint[0], tint[1], tint[2], tint[3]))
	vol_mat.set_shader_parameter("head_detail", Vector4(float(prof.a("head_noise_amp", 0.30)), float(prof.a("billow_sharp", 1.3)), float(prof.a("erosion", 0.8)), 0.0))
	vol_mat.set_shader_parameter("base_steps", float(prof.a("steps", 72.0)))
	var wv: Array = prof.a("wind", [2.5, -1.5])
	wind_v = Vector3(float(wv[0]), 0.0, float(wv[1]))
	vol_mat.set_shader_parameter("wind", wind_v)
	vol_mat.set_shader_parameter("wind_h", maxf(prof.cloud_top * 0.5, 50.0))
	# boiling speed (noise cells / s): nuclear clouds scale with their stabilisation time; HE smoke
	# and ejecta columns boil on an absolute (seconds) scale or they freeze for seconds (review c2)
	if prof.nuclear and not prof.is_column_kind():
		vol_mat.set_shader_parameter("churn", float(prof.a("churn", 1.2)) / maxf(prof.t_stab, 10.0))
	else:
		vol_mat.set_shader_parameter("churn", float(prof.a("churn_abs", 0.12)))
	vol_mat.set_shader_parameter("debug_mode", Args.get_int("vdebug", 0))
	vol_mat.set_shader_parameter("fb_grad", 0.0 if prof.nuclear else 1.0)
	vol_mat.set_shader_parameter("head_lobes", float(prof.a("head_lobes", 0.0)))
	vol_mat.set_shader_parameter("col_detail", float(prof.a("col_detail", 0.0)))
	vol_mat.set_shader_parameter("skirt_front", 1.0 if prof.is_column_kind() else 0.0)
	var dcol: Array = prof.a("dome_color", [-1.0, -1.0, -1.0])
	vol_mat.set_shader_parameter("dome_col", Vector3(dcol[0], dcol[1], dcol[2]))
	vol_mat.set_shader_parameter("stem_twist", float(prof.a("stem_twist", 0.0)))
	# attached nuclear stems meander a little by default (straight pipes read as CG)
	vol_mat.set_shader_parameter("stem_wobble", float(prof.a("stem_wobble", 0.35 if (prof.nuclear and not prof.is_column_kind()) else 0.0)))
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
	vol_mat.set_shader_parameter("fb_look", Vector4(fs["temp"], fs["emis"], float(prof.a("fireball_noise", 0.14)), fs["opacity"]))
	vol_mat.set_shader_parameter("fb_shape", Vector4(fs["squash"], fs["mottle"], float(prof.a("fireball_noise_scale", 10.0)), fs["skin"]))
	vol_mat.set_shader_parameter("fb_cut_y", prof.fireball_cut_y(t))
	var tint: Array = prof.a("fireball_tint", [1.0, 1.0, 1.0, 0.0])
	if float(tint[3]) > 0.0:
		var tw := float(tint[3]) * clampf(1.0 - t / float(prof.a("tint_time", 5.0)), 0.0, 1.0)
		vol_mat.set_shader_parameter("fb_tint", Vector4(tint[0], tint[1], tint[2], tw))
	var hr: float = hs["radius"] if float(hs["density"]) > 0.001 else 0.0
	vol_mat.set_shader_parameter("head", Vector4(0.0, hs["center_y"], 0.0, hr))
	vol_mat.set_shader_parameter("head_shape", Vector4(hs["half"], hs["torus"], hs["density"], hs["roll"]))
	var ca: Vector4 = vol_mat.get_shader_parameter("head_col_a")
	ca.w = hs["col_mix"]
	vol_mat.set_shader_parameter("head_col_a", ca)
	var core_r := lerpf(0.6, float(prof.a("core_radius", 0.28)), clampf(t / maxf(prof.t_stab * 0.06, 1.0), 0.0, 1.0))
	vol_mat.set_shader_parameter("head_heat", Vector4(hs["heat_temp"], hs["heat_glow"], core_r, float(prof.a("head_noise_scale", 0.55))))
	var sr: float = ss["radius"] if float(ss["density"]) > 0.001 and float(ss["top"]) > 1.0 else 0.0
	vol_mat.set_shader_parameter("stem", Vector4(ss["bottom"], ss["top"], sr, ss["density"]))
	vol_mat.set_shader_parameter("stem_shape", Vector4(ss["flare"], ss["waist"], ss["hollow"], ss["rise"]))
	vol_mat.set_shader_parameter("stem_cone", float(prof.a("col_cone", 0.0)) if prof.is_column_kind() else 0.0)
	vol_mat.set_shader_parameter("stem_top_flare", 0.0 if prof.is_column_kind() else float(prof.a("stem_top_flare", 0.0)))
	if ss.has("front"):
		vol_mat.set_shader_parameter("stem_wake", Vector4(ss["front"], ss["wake_bottom"], ss["wake"], ss["dust_ramp"]))
	else:
		var jfade := 1.0
		if prof.art.has("jet_fade_s"):
			var jf: Array = prof.art["jet_fade_s"]
			jfade = 1.0 - smoothstep(float(jf[0]), float(jf[1]), t)
		vol_mat.set_shader_parameter("stem_wake", Vector4(1.0e9, 0.0, float(prof.a("jet_amount", 1.0)) * jfade, 1.0))
	var dm := prof.dome_state(t)
	vol_mat.set_shader_parameter("dome_u", Vector4(dm.x, dm.y, clampf((t - float(prof.a("dome_time", 1.0)) * 0.6) / maxf(float(prof.a("dome_time", 1.0)), 0.1), 0.0, 1.0), 0.0))
	var kr: float = ks["radius"] if float(ks["density"]) > 0.001 else 0.0
	vol_mat.set_shader_parameter("skirt", Vector4(kr, ks["height"], ks["density"], ks["inner"]))
	var rings := prof.rings_state(t)
	vol_mat.set_shader_parameter("rings", rings)
	var ice0 := prof.ice_state(t, 0)
	var ice1 := prof.ice_state(t, 1)
	vol_mat.set_shader_parameter("ice", ice0)
	vol_mat.set_shader_parameter("ice2", ice1)
	# proxy bounds (local, relative to ground zero)
	var mn := Vector3(1e9, 1e9, 1e9)
	var mx := Vector3(-1e9, -1e9, -1e9)
	if fr > 0.0:
		var e := fr * (1.0 + float(prof.a("fireball_noise", 0.14)) * 2.0) + 2.0
		mn = mn.min(Vector3(-e, float(fs["center_y"]) - e, -e))
		mx = mx.max(Vector3(e, float(fs["center_y"]) + e, e))
	if hr > 0.0:
		var hh: float = hs["half"]
		# lobes reach ~1.1 R and the noise displacement ~amp beyond: the box must not cut them
		var amp := float(prof.a("head_noise_amp", 0.30)) * minf(hr, hh * 1.8) * 1.2 + hh * 0.3
		var exh := hr * 1.15 + amp
		mn = mn.min(Vector3(-exh, float(hs["center_y"]) - hh * 1.1 - amp, -exh))
		mx = mx.max(Vector3(exh, float(hs["center_y"]) + hh * 1.1 + amp, exh))
	if sr > 0.0:
		var se: float = sr * maxf(float(ss["flare"]), 1.0 + float(prof.a("col_cone", 0.0))) * 1.6
		mn = mn.min(Vector3(-se, ss["bottom"], -se))
		var stop: float = float(ss["top"]) * (1.4 if float(prof.a("col_cone", 0.0)) > 0.0 and prof.is_column_kind() else 1.0) + sr
		mx = mx.max(Vector3(se * (1.0 + float(prof.a("stem_top_flare", 0.0))), stop, se * (1.0 + float(prof.a("stem_top_flare", 0.0)))))
	if kr > 0.0:
		var kh: float = ks["height"]
		mn = mn.min(Vector3(-kr * 1.32 - kh * 1.5, -kh * 0.3, -kr * 1.32 - kh * 1.5))
		mx = mx.max(Vector3(kr * 1.32 + kh * 1.5, kh * 2.6, kr * 1.32 + kh * 1.5))
	for rg in rings:
		if rg.w > 0.0:
			var e2: float = rg.y + rg.z * 3.0 + 500.0
			mn = mn.min(Vector3(-e2, rg.x - rg.z * 2.0 - 500.0, -e2))
			mx = mx.max(Vector3(e2, rg.x + rg.z * 2.0 + 500.0, e2))
	for sh in [ice0, ice1]:
		if sh.w > 0.0:
			var e3: float = sh.y * 1.1
			mn = mn.min(Vector3(-e3, sh.x - sh.z * 0.3, -e3))
			mx = mx.max(Vector3(e3, sh.x + sh.z * 1.2, e3))
	if dm.y > 0.05:
		mn = mn.min(Vector3(-dm.x * 1.7, -1.0, -dm.x * 1.7))
		mx = mx.max(Vector3(dm.x * 1.7, dm.y * 1.3 + 1.0, dm.x * 1.7))
	if mn.x < mx.x:
		var drift := wind_v * t * 2.1
		mn = mn.min(mn + Vector3(drift.x, 0.0, drift.z))
		mx = mx.max(mx + Vector3(drift.x, 0.0, drift.z))
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
	if prof.nuclear and not prof.is_column_kind():
		illum = BlastPhysics.flash_illuminance(prof.w_kt, t, d, Game.humidity)
	elif prof.nuclear:
		illum = pw * 50.0 * BlastPhysics.transmittance(d, Game.humidity)
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
		var amb := Game.ambient_level()
		var lum := illum / amb
		# the visible fireball adds glare even when the illuminance is modest
		var wo := float(prof.a("whiteout_s", 0.0))
		if wo > 0.0 and t < wo:
			lum = maxf(lum, 4.0 * (1.0 - t / wo))
		env_ctl.flash_lum = lum


var _last_adapt_age := 0.0


## Integrates the eye adaptation from the last update to `t` (deterministic for scrubbing).
func step_exposure(t: float, dt: float) -> void:
	if env_ctl == null:
		return
	if dt <= 0.0:
		return
	var amb := Game.ambient_level()
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
	if prof.nuclear and not prof.is_column_kind():
		ill = BlastPhysics.flash_illuminance(prof.w_kt, ti, obs_dist, Game.humidity)
	elif prof.nuclear:
		ill = prof.light_power(ti) * 50.0 * BlastPhysics.transmittance(obs_dist, Game.humidity)
	else:
		var fr: float = fs["radius"]
		ill = prof.light_power(ti) * 20.0 * fr * fr / maxf(obs_dist * obs_dist, 1.0) * 1000.0
	var lum := ill / amb
	if not prof.nuclear:
		# HE flames are not bright enough to make a camera stop down hard (cycle 3: ~1 stop was still
		# too much at noon): a fraction of a stop at most
		env_ctl.max_comp = 0.25
		var wo_he := float(prof.a("whiteout_s", 0.0))
		if wo_he > 0.0 and ti < wo_he:
			return maxf(0.08 * lum, 30.0 * (1.0 - ti / wo_he))
		return 0.08 * lum
	if cam and float(fs["radius"]) > 0.0 and float(fs["opacity"]) > 0.3 and float(fs["temp"]) > 1500.0:
		var fpos := gz + Vector3(0, float(fs["center_y"]), 0)
		var to := fpos - cam.global_position
		var d := to.length()
		var fwd := -cam.global_transform.basis.z
		var half_fov := deg_to_rad(cam.fov * 0.5)
		var ang := acos(clampf(fwd.dot(to / maxf(d, 1.0)), -1.0, 1.0))
		var ang_r := atan(float(fs["radius"]) / maxf(d, 1.0))
		if ang < half_fov + ang_r:
			# the auto-framed binocular view is not the eye filled by the ball: coverage capped
			var cov := clampf(pow(ang_r / half_fov, 2.0) * 6.0, 0.0, 0.35)
			# a camera / binocular stopped down on a fireball that fills the view (rapatronic look)
			# the camera opens up gradually as the ball cools (a hard switch at 3 t2 flashed the frame
			# to white for megatons)
			var kc := smoothstep(3.0 * prof.t2, 15.0 * prof.t2, ti)
			env_ctl.max_comp = lerpf(lerpf(4.5, 6.0, cov), lerpf(1.6, 2.6, cov), kc)
			var tt: float = fs["temp"]
			var x := tt / 8000.0
			# metering keeps the ball ~4 stops above middle grey: blinding white core, structure only
			# at the limb (cycle-2 review: the ball must not turn into grey-beige cotton)
			# ~4 stops above middle grey while blinding (< 3 t2), then the camera keeps the cooling
			# ball's colour (yellow -> orange -> red) instead of letting it clip to white
			var l_fb := float(fs["emis"]) * x * x * x * x * float(fs["opacity"]) / (lerpf(16.0, 6.0, kc) * amb)
			lum = maxf(lum, (1.0 - cov) * (1.0 + lum) + cov * l_fb - 1.0)
			if prof.w_kt < 1.0 and ti > 3.0 * prof.t2:
				# a sub-kiloton ball at 10+ km does not keep a camera stopped down
				env_ctl.max_comp = 0.5
	var wo := float(prof.a("whiteout_s", 0.0))
	if wo > 0.0 and ti < wo:
		lum = maxf(lum, 30.0 * (1.0 - ti / wo))
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
	RenderingServer.global_shader_parameter_set("g_fireball", Vector4(fpos.x, fpos.y, fpos.z, float(fs["radius"]) if float(fs["opacity"]) > 0.02 or prof.conventional else 0.0))
	var pw := prof.light_power(t)
	if prof.is_column_kind():
		pw *= 0.05
	if prof.nuclear and not prof.is_column_kind():
		var hs0 := prof.head_state(t)
		pw *= maxf(float(fs["opacity"]), 0.3 if float(hs0["heat_glow"]) > 0.0 else 0.0)
	var col := _bb_color(maxf(float(fs["temp"]), 1500.0))
	var inten := pw * pow(maxf(prof.w_kt, 0.0001), 0.33) * 40.0 * BlastPhysics.transmittance(obs_dist, Game.humidity)
	if prof.nuclear and not prof.is_column_kind():
		var tphys := BlastPhysics.fireball_temperature(prof.w_kt, maxf(t, 1e-4), prof.surface)
		inten *= float(prof.a("fireball_brightness", 1.0)) * clampf(pow(float(fs["temp"]) / maxf(tphys, 1.0), 4.0), 0.0, 1.0)
	if prof.conventional:
		inten *= 0.12
	var crim := float(prof.a("crimson", 0.0))
	if crim > 0.0:
		# Bravo: the flash dyed the sky and clouds crimson (dark maroon/orange, not a red filter),
		# fading by ~2.5 min
		col = col.lerp(Color(0.80, 0.28, 0.12), crim * 0.75)
		inten = maxf(inten, crim * 6.0 * exp(-t / 45.0) * clampf(t / 0.5, 0.0, 1.0) * (1.0 - smoothstep(60.0, 150.0, t)))
	RenderingServer.global_shader_parameter_set("g_fireball_color", Vector4(col.r, col.g, col.b, inten))
	var gflash := clampf(pw * pow(maxf(prof.w_kt, 0.0001), 0.3) * BlastPhysics.transmittance(obs_dist, Game.humidity) * 0.3, 0.0, 20.0)
	if prof.conventional:
		gflash *= 0.2
	RenderingServer.global_shader_parameter_set("g_flash", gflash)
	# cloud shadow on the ground
	var hs := prof.head_state(t)
	var ss := prof.stem_state(t)
	var opacity := clampf(float(hs["density"]) * 0.85, 0.0, 0.85)
	var hc: float = float(hs["center_y"])
	var drift := wind_v * t * pow(clampf(maxf(hc, 0.0) / maxf(prof.cloud_top * 0.5, 50.0), 0.0, 1.5), 1.0)
	RenderingServer.global_shader_parameter_set("g_cloud_pos", Vector4(gz.x + drift.x, gz.y + hc, gz.z + drift.z, opacity))
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
	var dmv := prof.dome_state(t)
	RenderingServer.global_shader_parameter_set("g_dome", Vector4(dmv.x, 0.0, 0.0, 0.0))


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
