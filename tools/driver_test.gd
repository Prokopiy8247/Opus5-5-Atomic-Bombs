extends SceneTree
## Driver smoke test: renders a simple lit scene, measures FPS, saves a PNG.
## godot --path . --rendering-driver vulkan -s res://tools/driver_test.gd -- --out C:/abs/dir

var frames := 0
var t0 := 0
var cam: Camera3D

func _init() -> void:
	var root3d := Node3D.new()
	root.add_child(root3d)
	cam = Camera3D.new()
	cam.position = Vector3(0, 2, 8)
	cam.far = 300000.0
	cam.near = 0.05
	root3d.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.shadow_enabled = true
	root3d.add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = Sky.new()
	e.sky.sky_material = ProceduralSkyMaterial.new()
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.glow_enabled = true
	env.environment = e
	root3d.add_child(env)
	var mm := MultiMeshInstance3D.new()
	var m := MultiMesh.new()
	m.transform_format = MultiMesh.TRANSFORM_3D
	m.mesh = BoxMesh.new()
	m.instance_count = 20000
	for i in m.instance_count:
		m.set_instance_transform(i, Transform3D(Basis(), Vector3((i % 200) * 2.0 - 200.0, 0, -float(i / 200) * 2.0)))
	mm.multimesh = m
	root3d.add_child(mm)
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2000, 2000)
	plane.mesh = pm
	plane.position.y = -0.5
	root3d.add_child(plane)
	t0 = Time.get_ticks_msec()


func _process(_delta: float) -> bool:
	frames += 1
	cam.rotation.y = sin(frames * 0.01) * 0.3
	if frames == 400:
		var dt := (Time.get_ticks_msec() - t0) / 1000.0
		print("DRIVER ", RenderingServer.get_current_rendering_driver_name(), " ", RenderingServer.get_video_adapter_name(), " FPS=", 400.0 / dt)
		_shot()
	return false


func _shot() -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var out := Args.get_str("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(out)
	var path := out.path_join("driver_%s.png" % RenderingServer.get_current_rendering_driver_name())
	var err := img.save_png(path)
	print("SHOT ", path, " err=", err, " size=", img.get_size())
	print("READY")
	quit()
