extends Node3D
## Main scene: builds the world, bunker, camera, explosion system, launcher, UI and audio,
## and runs the deterministic test rig when command-line args request it.

var env_ctl: EnvironmentCtl
var terrain: Terrain
var bunker: Bunker
var cam: PlayerCamera
var explosion: Explosion
var _world_ready := false


func _ready() -> void:
	print("BOOT main")
	env_ctl = EnvironmentCtl.new()
	env_ctl.name = "Environment"
	add_child(env_ctl)
	terrain = Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	bunker = Bunker.new()
	bunker.name = "Bunker"
	add_child(bunker)
	cam = PlayerCamera.new()
	cam.name = "Camera"
	add_child(cam)
	env_ctl.set_humidity(Game.humidity)
	if Args.has("shots"):
		Game.is_test_rig = true
		var rig := ShotRig.new()
		rig.main = self
		add_child(rig)
		rig.run.call_deferred()
	elif Args.has("world_test"):
		_run_world_test()


func prepare_world(tod_i: int, bomb_idx: int) -> void:
	Game.tod = tod_i
	env_ctl.apply_tod(tod_i)
	env_ctl.set_humidity(Game.humidity)
	var b := Game.bomb(bomb_idx)
	var snow := 1.0 if (bool(b.get("snow", false)) and Game.snow_override != 0) or Game.snow_override == 1 else 0.0
	RenderingServer.global_shader_parameter_set("g_snow", snow)
	RenderingServer.global_shader_parameter_set("g_quality", Game.quality_steps_scale())
	if not _world_ready:
		await FxResources.wait_ready(get_tree())
		_world_ready = true
	for i in 5:
		await get_tree().process_frame


func target_position(dist_km: float, az_deg: float) -> Vector3:
	var d := dist_km * 1000.0
	var az := deg_to_rad(az_deg)
	var x := sin(az) * d
	var z := -cos(az) * d
	return Vector3(x, TerrainMath.height(x, z), z)


func detonate_now(bomb_idx: int, dist_km: float, az_deg: float) -> Explosion:
	clear_explosion()
	var b := Game.bomb(bomb_idx)
	var gz := target_position(dist_km, az_deg)
	explosion = Explosion.new()
	explosion.name = "Explosion"
	explosion.observer = Vector3.ZERO
	add_child(explosion)
	explosion.setup(b, gz, env_ctl, bunker, cam)
	return explosion


func clear_explosion() -> void:
	if explosion:
		explosion.cleanup_globals()
		explosion.queue_free()
		explosion = null
	env_ctl.reset_adaptation()
	bunker.reset_state()


func after_age_set(_ex: Explosion, _dt: float) -> void:
	pass


func _process(delta: float) -> void:
	if explosion and not Game.is_test_rig and not Game.paused:
		var dt := delta * Game.time_scale
		explosion.advance(dt)
		explosion.step_exposure(explosion.age, dt)


func _run_world_test() -> void:
	var out := Args.get_str("out", OS.get_user_data_dir().path_join("shots"))
	DirAccess.make_dir_recursive_absolute(out)
	var tods := ["dawn", "noon", "dusk", "night"]
	for i in tods.size():
		Game.tod = i
		env_ctl.apply_tod(i)
		for f in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var p := out.path_join("world_%s.png" % tods[i])
		print("SHOT ", p, " err=", img.save_png(p))
	cam.fov = 10.0
	cam.target_fov = 10.0
	Game.tod = 1
	env_ctl.apply_tod(1)
	for f in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img2 := get_viewport().get_texture().get_image()
	print("SHOT zoom err=", img2.save_png(out.path_join("world_zoom.png")))
	print("READY")
	get_tree().quit()
