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
	env.glow_enabled = true
	env.glow_normalized = false
	env.glow_intensity = 0.3
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.6
	env.glow_hdr_scale = 1.5
	env.glow_hdr_luminance_cap = 30.0
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
	var p := {}
	match t:
		Game.TimeOfDay.DAWN:
			p = {"az": 68.0, "el": 1.6, "sun_col": Color(1.0, 0.62, 0.38), "sun_e": 1.6, "sky_i": 20.0,
				"exposure": 1.5, "fog": 0.000035, "turb": 1.6, "night": 0.0, "amb": 1.0,
				"amb_col": Color(0.22, 0.24, 0.32), "amb_scale": 1.0, "fog_col": Color(0.42, 0.38, 0.40), "fog_sun": Color(1.0, 0.55, 0.28), "fog_bright": 0.9}
		Game.TimeOfDay.NOON:
			p = {"az": 100.0, "el": 46.0, "sun_col": Color(1.0, 0.96, 0.9), "sun_e": 3.2, "sky_i": 22.0,
				"exposure": 0.42, "fog": 0.000026, "turb": 1.0, "night": 0.0, "amb": 1.0,
				"amb_col": Color(0.30, 0.38, 0.52), "amb_scale": 1.0, "fog_col": Color(0.50, 0.58, 0.70), "fog_sun": Color(0.6, 0.55, 0.45), "fog_bright": 0.85}
		Game.TimeOfDay.DUSK:
			p = {"az": 292.0, "el": 2.2, "sun_col": Color(1.0, 0.55, 0.3), "sun_e": 1.5, "sky_i": 20.0,
				"exposure": 1.6, "fog": 0.000038, "turb": 1.8, "night": 0.0, "amb": 1.0,
				"amb_col": Color(0.25, 0.22, 0.30), "amb_scale": 1.0, "fog_col": Color(0.42, 0.36, 0.38), "fog_sun": Color(1.0, 0.5, 0.25), "fog_bright": 0.9}
		_:
			p = {"az": 0.0, "el": -28.0, "sun_col": Color(1.0, 0.8, 0.6), "sun_e": 0.0, "sky_i": 20.0,
				"exposure": 2.2, "fog": 0.00002, "turb": 1.0, "night": 1.0, "amb": 0.3,
				"amb_col": Color(0.010, 0.013, 0.022), "amb_scale": 1.0, "fog_col": Color(0.008, 0.010, 0.016), "fog_sun": Color(0.02, 0.025, 0.04), "fog_bright": 1.0}
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
	RenderingServer.global_shader_parameter_set("g_sun_dir", sd if sd.y > 0.0 else md)
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
	if night > 0.0:
		sun_light = Vector4(0.62 * 0.05, 0.72 * 0.05, 1.0 * 0.05, 1.0)
	RenderingServer.global_shader_parameter_set("g_sun_light", sun_light)
	var amb: Color = p.get("amb_col", Color(0.32, 0.42, 0.58))
	var amb_s: float = p.get("amb_scale", 1.0)
	RenderingServer.global_shader_parameter_set("g_ambient", Vector4(amb.r, amb.g, amb.b, amb_s))
	var fc: Color = p.get("fog_col", Color(0.62, 0.68, 0.78))
	var fsun: Color = p.get("fog_sun", Color(1.0, 0.85, 0.65))
	RenderingServer.global_shader_parameter_set("g_fog_color", Vector4(fc.r, fc.g, fc.b, p.get("fog_bright", 1.0)))
	RenderingServer.global_shader_parameter_set("g_fog_sun", Vector4(fsun.r, fsun.g, fsun.b, 0.0))
	_apply_fog_density()


func set_humidity(h: float) -> void:
	Game.humidity = h
	_apply_fog_density()
	RenderingServer.global_shader_parameter_set("g_humidity", h)


func _apply_fog_density() -> void:
	var base: float = tod_params.get("fog", 0.00003)
	var k := lerpf(0.7, 1.7, Game.humidity)
	env.fog_density = 0.0000005
	RenderingServer.global_shader_parameter_set("g_fog", Vector4(base * k, lerpf(2200.0, 1400.0, Game.humidity), 5e-6, 0.0))


## Advances the eye-adaptation model. `lum` is the explosion luminance at the observer
## relative to the ambient scene luminance (0 = no explosion).
func step_adaptation(lum: float, dt: float) -> void:
	flash_lum = lum
	var target := log(1.0 + lum) / log(2.0)
	if target > adapt_log:
		# fast adaptation to bright light (pupil + bleaching): ~0.15-0.4 s
		adapt_log = lerpf(adapt_log, target, 1.0 - exp(-dt / 0.1))
	else:
		# slow recovery: ~8 s time constant
		adapt_log = lerpf(adapt_log, target, 1.0 - exp(-dt / 4.5))
	# glare: how far the stimulus exceeds what the eye is adapted to
	white_out = clampf((target - adapt_log) / 4.0, 0.0, 1.0)


func reset_adaptation() -> void:
	adapt_log = 0.0
	flash_lum = 0.0
	white_out = 0.0


func current_exposure() -> float:
	if exposure_override > 0.0:
		return exposure_override
	# the eye compensates at most ~8 stops
	var comp := clampf(adapt_log, 0.0, 7.5)
	return base_exposure * pow(2.0, -comp)


func _process(_delta: float) -> void:
	cam_attr.exposure_multiplier = current_exposure()
