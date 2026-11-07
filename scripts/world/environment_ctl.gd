class_name EnvironmentCtl
extends Node3D
## WorldEnvironment, sun/moon, procedural sky, fog/aerial perspective, time-of-day presets
## and the eye-adaptation (exposure) model driven by the explosion's light at the observer.

const SKY_SHADER := preload("res://shaders/sky.gdshader")

var env: Environment
var world_env: WorldEnvironment
var cam_attr: CameraAttributesPractical
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var sky_mat: ShaderMaterial

## Base exposure per time of day (multiplier) and current adaptation state.
var base_exposure := 1.0
var adapt_log := 0.0          # log2 of the luminance the eye is adapted to (relative to base)
var flash_lum := 0.0          # current relative luminance of the explosion at the observer
var white_out := 0.0          # extra glare (0..1), drives post white-out
var exposure_override := -1.0
var max_comp := 6.5           # max stops of compensation (raised when the fireball fills the view)

var tod_params := {}


func _ready() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_AUTOMATIC
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_white = 12.0
	env.tonemap_agx_white = Args.get_float("agxw", 16.0)
	env.tonemap_agx_contrast = Args.get_float("agxc", 1.9)
	if Args.get_str("tonemap", "") == "aces":
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		env.tonemap_white = 8.0
	env.glow_enabled = not Args.has("noglow")
	env.glow_normalized = false
	env.glow_intensity = 0.3
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.8
	env.glow_hdr_scale = 1.2
	env.glow_hdr_luminance_cap = 6.0
	for i in 7:
		env.set_glow_level(i, [0.0, 1.0, 0.7, 0.35, 0.12, 0.05, 0.02][i])
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.00003
	env.fog_aerial_perspective = 0.75
	env.fog_sky_affect = 0.0
	env.fog_sun_scatter = 0.25
	env.fog_height = 400.0
	env.fog_height_density = 0.0
	env.ssao_enabled = false
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.02
	env.adjustment_contrast = 1.03
	world_env = WorldEnvironment.new()
	world_env.environment = env
	cam_attr = CameraAttributesPractical.new()
	cam_attr.auto_exposure_enabled = false
	cam_attr.exposure_multiplier = 1.0
	world_env.camera_attributes = cam_attr
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 3000.0
	sun.directional_shadow_split_1 = 0.01
	sun.directional_shadow_split_2 = 0.06
	sun.directional_shadow_split_3 = 0.3
	sun.shadow_blur = 1.0
	sun.light_angular_distance = 0.53
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.shadow_enabled = false
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	moon.light_color = Color(0.62, 0.72, 1.0)
	add_child(moon)
	apply_tod(Game.tod)


static func dir_from_az_el(az_deg: float, el_deg: float) -> Vector3:
	## az measured from north (-Z) clockwise toward east (+X). Returns direction TOWARD the body.
	var az := deg_to_rad(az_deg)
	var el := deg_to_rad(el_deg)
	return Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el)).normalized()


func _orient_light(l: DirectionalLight3D, to_body: Vector3) -> void:
	# DirectionalLight3D shines along its -Z axis.
	var up := Vector3.UP if absf(to_body.y) < 0.99 else Vector3.FORWARD
	l.global_transform = Transform3D(Basis.looking_at(-to_body, up), Vector3.ZERO)


func apply_tod(t: int) -> void:
	# The haze colours (g_fog_color / g_fog_sun) are derived from the sky model (see _haze_colors);
	# "fog_bright" scales them (1 = distant terrain fades exactly into the horizon sky).
	var p := {}
	match t:
		Game.TimeOfDay.DAWN:
			p = {"az": 68.0, "el": 1.6, "sun_col": Color(1.0, 0.80, 0.55), "sun_e": 1.6, "sky_i": 20.0,
				"exposure": 1.5, "fog": 0.000028, "turb": 1.6, "night": 0.0, "amb": 1.0,
				"amb_col": Color(0.22, 0.24, 0.32), "amb_scale": 1.0, "fog_bright": 1.0}
		Game.TimeOfDay.NOON:
			p = {"az": 100.0, "el": 46.0, "sun_col": Color(1.0, 0.96, 0.9), "sun_e": 3.2, "sky_i": 22.0,
				"exposure": 0.42, "fog": 0.000018, "turb": 1.0, "night": 0.0, "amb": 1.0,
				"amb_col": Color(0.30, 0.38, 0.52), "amb_scale": 1.0, "fog_bright": 1.0}
		Game.TimeOfDay.DUSK:
			p = {"az": 292.0, "el": 2.2, "sun_col": Color(1.0, 0.74, 0.48), "sun_e": 1.5, "sky_i": 20.0,
				"exposure": 1.6, "fog": 0.00003, "turb": 1.8, "night": 0.0, "amb": 1.0,
				"amb_col": Color(0.25, 0.22, 0.30), "amb_scale": 1.0, "fog_bright": 1.0}
		Game.TimeOfDay.PREDAWN:
			# civil twilight, sun ~5 deg below the eastern horizon: deep blue sky, a warm band at the
			# horizon, no direct sun; clouds are lit softly from the bright eastern sky
			p = {"az": 68.0, "el": -3.0, "sun_col": Color(1.0, 0.8, 0.6), "sun_e": 0.0, "sky_i": 22.0,
				"exposure": 4.0, "fog": 0.000022, "turb": 1.4, "night": 0.1, "amb": 0.7,
				"amb_col": Color(0.07, 0.08, 0.13), "amb_scale": 1.0, "fog_bright": 1.0,
				"light_el": 4.0, "light_col": Color(0.30, 0.27, 0.36)}
		_:
			# night: keep a readable ambient so dark cloud silhouettes stay legible against the sky
			p = {"az": 0.0, "el": -28.0, "sun_col": Color(1.0, 0.8, 0.6), "sun_e": 0.0, "sky_i": 20.0,
				"exposure": 3.2, "fog": 0.000015, "turb": 1.0, "night": 1.0, "amb": 0.3,
				"amb_col": Color(0.015, 0.019, 0.032), "amb_scale": 1.0, "fog_bright": 1.0}
	tod_params = p
	var sd := dir_from_az_el(p["az"], p["el"])
	_orient_light(sun, sd)
	sun.light_color = p["sun_col"]
	sun.light_energy = p["sun_e"]
	sun.visible = p["sun_e"] > 0.0
	sun.shadow_enabled = p["sun_e"] > 0.0
	var md := dir_from_az_el(135.0, 34.0)
	_orient_light(moon, md)
	moon.light_energy = 0.045 * float(p["night"])
	moon.visible = p["night"] > 0.0
	sky_mat.set_shader_parameter("sun_dir", sd)
	sky_mat.set_shader_parameter("moon_dir", md)
	sky_mat.set_shader_parameter("sun_intensity", p["sky_i"])
	sky_mat.set_shader_parameter("turbidity", p["turb"])
	sky_mat.set_shader_parameter("star_intensity", 60.0 * float(p["night"]))
	var light_dir := sd if sd.y > 0.0 else md
	if p.has("light_el"):
		light_dir = dir_from_az_el(p["az"], p["light_el"])
	RenderingServer.global_shader_parameter_set("g_sun_dir", light_dir)
	RenderingServer.global_shader_parameter_set("g_night", float(p["night"]))
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = float(p["amb"])
	base_exposure = p["exposure"]
	adapt_log = 0.0
	# globals for custom shaders (volumes, terrain fog)
	var sc: Color = p["sun_col"]
	var se: float = p["sun_e"]
	var night: float = p["night"]
	var sun_light := Vector4(sc.r * se, sc.g * se, sc.b * se, 1.0)
	if p.has("light_col"):
		var lc: Color = p["light_col"]
		sun_light = Vector4(lc.r, lc.g, lc.b, 1.0)
	elif night > 0.0:
		sun_light = Vector4(0.62 * 0.11, 0.72 * 0.11, 1.0 * 0.11, 1.0)
	RenderingServer.global_shader_parameter_set("g_sun_light", sun_light)
	var amb: Color = p.get("amb_col", Color(0.32, 0.42, 0.58))
	var amb_s: float = p.get("amb_scale", 1.0)
	RenderingServer.global_shader_parameter_set("g_ambient", Vector4(amb.r, amb.g, amb.b, amb_s))
	# Haze colours for the aerial perspective, taken from the sky itself just above the horizon so
	# that distant terrain fades into exactly the sky colour behind it (no horizon seam, no grey band).
	var haze := _haze_colors(sd, md, p)
	var fc: Color = haze[0]
	var fsun: Color = haze[1]
	if Args.has("envdbg"):
		print("HAZE tod=%d away=%s fwd=%s zenith=%s" % [t, fc, fsun, _sky_radiance(Vector3.UP, sd, md, p)])
	RenderingServer.global_shader_parameter_set("g_fog_color", Vector4(fc.r, fc.g, fc.b, p.get("fog_bright", 1.0)))
	RenderingServer.global_shader_parameter_set("g_fog_sun", Vector4(fsun.r, fsun.g, fsun.b, 0.0))
	_apply_fog_density()


## g_fog_color = mean horizon radiance away from the sun (90, 180, 270 deg of azimuth from it);
## g_fog_sun = forward lobe fitted 30 deg from the sun with the atm_haze_color() shape.
func _haze_colors(sd: Vector3, md: Vector3, p: Dictionary) -> Array:
	var el := deg_to_rad(0.6)
	var sun_az := atan2(sd.x, -sd.z)
	var away := Vector3.ZERO
	for k in [0.5, 1.0, 1.5]:
		var a: float = sun_az + PI * k
		away += _sky_radiance(Vector3(sin(a) * cos(el), sin(el), -cos(a) * cos(el)), sd, md, p) / 3.0
	var a30 := sun_az + deg_to_rad(30.0)
	var d30 := Vector3(sin(a30) * cos(el), sin(el), -cos(a30) * cos(el))
	var c30 := _sky_radiance(d30, sd, md, p)
	var mu: float = maxf(d30.dot(sd), 0.0)
	var sun_k := pow(mu, 6.0) * 0.8 + pow(mu, 40.0) * 1.5
	var fwd := Vector3.ZERO
	if sun_k > 1e-3:
		fwd = (c30 - away) / sun_k
		fwd = Vector3(maxf(fwd.x, 0.0), maxf(fwd.y, 0.0), maxf(fwd.z, 0.0))
	return [Color(away.x, away.y, away.z), Color(fwd.x, fwd.y, fwd.z)]


## Radiance of the sky shader (without sun disc, stars and explosion) in direction `dir`.
func _sky_radiance(dir: Vector3, sd: Vector3, md: Vector3, p: Dictionary) -> Vector3:
	var col := Vector3.ZERO
	if sd.y > -0.2:
		col = sky_scatter(dir, sd, float(p["sky_i"]), float(p["turb"]))
	var night: float = p["night"]
	if night > 0.0:
		col += sky_scatter(dir, md, 0.012, float(p["turb"])) * night
		col += Vector3(0.0010, 0.0014, 0.0026) * (1.0 + 1.5 * exp(-maxf(dir.y, 0.0) * 8.0)) * night
	return col


# ---------------------------------------------------------------- CPU twin of shaders/sky.gdshader
const SKY_R_E := 6360e3
const SKY_R_A := 6420e3
const SKY_BETA_R := Vector3(5.8e-6, 13.5e-6, 33.1e-6)
const SKY_BETA_M := 21e-6
const SKY_BETA_O := Vector3(0.650e-6, 1.881e-6, 0.085e-6)
const SKY_H_R := 7994.0
const SKY_H_M := 1200.0
const SKY_R_OZ := 6385e3
const SKY_OZ_COL := 15000.0
const SKY_MS := 0.03
const SKY_MS_TINT := Vector3(0.6, 0.8, 1.0)
const SKY_MS_TINT_LOW := Vector3(0.35, 0.6, 1.0)


static func _vexp(v: Vector3) -> Vector3:
	return Vector3(exp(v.x), exp(v.y), exp(v.z))


static func _ch_up(x: float, mu: float) -> float:
	var c := sqrt(0.5 * PI * x)
	return c / ((c - 1.0) * mu + 1.0)


static func _chapman_od(r: float, mu: float, h: float) -> float:
	var e := exp(-(r - SKY_R_E) / h)
	if mu >= 0.0:
		return h * e * _ch_up(r / h, mu)
	var r0 := r * sqrt(maxf(1.0 - mu * mu, 0.0))
	if r0 < SKY_R_E:
		return 1e7
	return h * (2.0 * exp(-(r0 - SKY_R_E) / h) * sqrt(0.5 * PI * r0 / h) - e * _ch_up(r / h, -mu))


static func _light_tau(r: float, mu: float, bm: float) -> Vector3:
	var rr := minf(r / SKY_R_OZ, 0.999)
	var od_o := SKY_OZ_COL / sqrt(maxf(1.0 - rr * rr * (1.0 - mu * mu), 0.0081))
	return SKY_BETA_R * _chapman_od(r, mu, SKY_H_R) + Vector3.ONE * (bm * 1.1 * _chapman_od(r, mu, SKY_H_M)) + SKY_BETA_O * od_o


static func sky_scatter(rd: Vector3, l: Vector3, intensity: float, turb: float) -> Vector3:
	var r0 := SKY_R_E + 30.0
	var b := r0 * rd.y
	var t_end := -b + sqrt(b * b - (r0 * r0 - SKY_R_A * SKY_R_A))
	var dg := b * b - (r0 * r0 - SKY_R_E * SKY_R_E)
	if dg >= 0.0 and -b - sqrt(dg) > 0.0:
		t_end = minf(t_end, -b - sqrt(dg))
	var mu := rd.dot(l)
	var pr := 3.0 / (16.0 * PI) * (1.0 + mu * mu)
	var g := 0.76
	var pm := 3.0 / (8.0 * PI) * ((1.0 - g * g) * (1.0 + mu * mu)) / ((2.0 + g * g) * pow(1.0 + g * g - 2.0 * g * mu, 1.5))
	var bm := SKY_BETA_M * turb
	var t_hi := _vexp(-_light_tau(SKY_R_E + 12000.0, l.y, bm))
	var tint := SKY_MS_TINT_LOW.lerp(SKY_MS_TINT, smoothstep(0.05, 0.4, l.y))
	var ms := t_hi * tint * (SKY_MS * clampf(l.y * 4.0 + 0.6, 0.0, 1.0))
	var tau_v := Vector3.ZERO
	var sum_r := Vector3.ZERO
	var sum_m := Vector3.ZERO
	var sum_ms := Vector3.ZERO
	var t_prev := 0.0
	for i in 16:
		var x1 := float(i + 1) / 16.0
		var t_cur := t_end * x1 * x1 * x1
		var seg := t_cur - t_prev
		var tm := 0.5 * (t_prev + t_cur)
		t_prev = t_cur
		var px := rd.x * tm
		var py := r0 + rd.y * tm
		var pz := rd.z * tm
		var r := sqrt(px * px + py * py + pz * pz)
		var h := r - SKY_R_E
		var dr := exp(-h / SKY_H_R) * seg
		var dm := exp(-h / SKY_H_M) * seg
		var d_o := maxf(0.0, 1.0 - absf(h - 25000.0) / 15000.0) * seg
		var dtau := SKY_BETA_R * dr + Vector3.ONE * (bm * 1.1 * dm) + SKY_BETA_O * d_o
		var tv := _vexp(-(tau_v + dtau * 0.5))
		var att := tv * _vexp(-_light_tau(r, (px * l.x + py * l.y + pz * l.z) / r, bm))
		sum_r += att * dr
		sum_m += att * dm
		sum_ms += (SKY_BETA_R * dr + Vector3.ONE * (bm * dm)) * tv
		tau_v += dtau
	return (sum_r * SKY_BETA_R * pr + sum_m * (bm * pm) + sum_ms * ms) * intensity


func set_humidity(h: float) -> void:
	Game.humidity = h
	_apply_fog_density()
	RenderingServer.global_shader_parameter_set("g_humidity", h)


func _apply_fog_density() -> void:
	var base: float = tod_params.get("fog", 0.00003)
	var k := lerpf(0.6, 1.5, Game.humidity)
	env.fog_density = 0.0000005
	RenderingServer.global_shader_parameter_set("g_fog", Vector4(base * k, lerpf(2200.0, 1400.0, Game.humidity), 5e-6, 0.0))


## Advances the eye-adaptation model. `lum` is the explosion luminance at the observer
## relative to the ambient scene luminance (0 = no explosion).
func step_adaptation(lum: float, dt: float) -> void:
	flash_lum = lum
	var target := log(1.0 + lum) / log(2.0)
	if target > adapt_log:
		# fast adaptation to bright light (pupil + bleaching): ~0.15-0.4 s
		adapt_log = lerpf(adapt_log, target, 1.0 - exp(-dt / 0.05))
	else:
		# slow recovery: ~8 s time constant
		adapt_log = lerpf(adapt_log, target, 1.0 - exp(-dt / 2.2))
	# glare: how far the stimulus exceeds what the eye is adapted to
	white_out = clampf((target - adapt_log) / 4.0, 0.0, 1.0)


func reset_adaptation() -> void:
	max_comp = 6.5
	adapt_log = 0.0
	flash_lum = 0.0
	white_out = 0.0


func current_exposure() -> float:
	if Args.has("expo"):
		return Args.get_float("expo", 1.0)
	if exposure_override > 0.0:
		return exposure_override
	# the eye compensates at most ~8 stops
	var comp := clampf(adapt_log, 0.0, max_comp)
	return base_exposure * pow(2.0, -comp)


func _process(_delta: float) -> void:
	var e := current_exposure()
	cam_attr.exposure_multiplier = e
	RenderingServer.global_shader_parameter_set("g_exposure", e)
