extends SceneTree
## Test for scripts/bombs/bomb_models.gd: builds all 20 bomb models in a row
## over a metre ruler, plus boosters and a parachute; checks sizes against
## data/bombs.json and (windowed) saves screenshots and contact sheets.
##
## Logic check:  godot --headless --path . -s res://tools/test_models.gd
## Visual check: godot --path . --resolution 1600x900 -s res://tools/test_models.gd -- --out C:/abs/dir

const BM = preload("res://scripts/bombs/bomb_models.gd")

var out_dir := ""
var bombs: Array = []
var world: Node3D
var cam: Camera3D
var sun: DirectionalLight3D
var models: Array[Node3D] = []
var extras: Array[Node3D] = []
var labels: Array[Node3D] = []
var hud: Label
var failures := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			out_dir = args[i + 1]
	if out_dir == "":
		out_dir = OS.get_user_data_dir().path_join("test_models")
	var game: Node = root.get_node_or_null("Game")
	if game != null:
		bombs = game.get("bombs")
	if bombs.is_empty():
		var f := FileAccess.open("res://data/bombs.json", FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		bombs = (parsed as Dictionary).get("bombs", [])
	print("bombs loaded: ", bombs.size(), " (Game autoload: ", game != null, ")")
	_build_scene()
	_check_sizes()
	_check_missiles()
	_check_api()
	_check_geometry()
	_check_robustness()
	_run_async()


## The leak check spans real frames (the rendering server frees mesh
## buffers on its own sync), then either quits or takes the screenshots.
func _run_async() -> void:
	await _check_leaks()
	if DisplayServer.get_name() == "headless":
		_finish()
	else:
		await _shoot()


func _finish() -> void:
	if failures == 0:
		print("ALL CHECKS PASSED")
	else:
		print("CHECK FAILURES: ", failures)
	print("READY")
	quit()


# ----------------------------------------------------------------- scene ---

func _build_scene() -> void:
	world = Node3D.new()
	root.add_child(world)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.48, 0.72)
	sky_mat.sky_horizon_color = Color(0.72, 0.74, 0.76)
	sky_mat.ground_horizon_color = Color(0.6, 0.58, 0.55)
	sky_mat.ground_bottom_color = Color(0.35, 0.33, 0.3)
	env.sky.sky_material = sky_mat
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	we.environment = env
	world.add_child(we)
	sun = DirectionalLight3D.new()
	sun.basis = Basis.looking_at(Vector3(-0.35, -1.0, -0.75).normalized(), Vector3.UP)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.basis = Basis.looking_at(Vector3(0.6, -0.3, 0.7).normalized(), Vector3.UP)
	fill.light_energy = 0.35
	world.add_child(fill)
	cam = Camera3D.new()
	cam.near = 0.02
	cam.far = 2000.0
	world.add_child(cam)
	cam.current = true
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 600)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.55, 0.52, 0.47)
	gm.roughness = 0.95
	ground.material_override = gm
	ground.position = Vector3(0, -0.002, 0)
	world.add_child(ground)
	# Bomb row: tails aligned at x = 0, rows along -Z.
	var z := 0.0
	var prev_half := 0.0
	var build_us := 0
	for i in bombs.size():
		var b: Dictionary = bombs[i]
		var t0 := Time.get_ticks_usec()
		var m := BM.build(b)
		build_us += Time.get_ticks_usec() - t0
		var box: AABB = m.get_meta("aabb")
		var half_w := maxf(-box.position.z, box.end.z)
		z -= prev_half + half_w + 0.9
		prev_half = half_w
		m.position = Vector3(-box.position.x, -box.position.y + 0.02, z)
		world.add_child(m)
		models.append(m)
		var lb := Label3D.new()
		lb.text = "%d %s\n%.2f x %.2f m" % [i + 1, String(b.get("id", "")), float(b.get("length_m", 0.0)), float(b.get("diameter_m", 0.0))]
		lb.font_size = 48
		lb.pixel_size = 0.0045
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.outline_size = 10
		lb.position = Vector3(-1.4, 0.4, z)
		world.add_child(lb)
		labels.append(lb)
	print("build time of 20 models: %.1f ms" % (build_us / 1000.0))
	var row_len := -z + 3.0
	# Ruler: alternating 1 m floor stripes under the row + 0.1 m ticks at the front.
	for mtr in 12:
		var st := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.0, 0.004, row_len)
		st.mesh = bm
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.12, 0.12, 0.12) if mtr % 2 == 0 else Color(0.9, 0.9, 0.88)
		sm.roughness = 0.9
		st.material_override = sm
		st.position = Vector3(float(mtr) + 0.5, 0.002, -row_len * 0.5 + 1.5)
		world.add_child(st)
		extras.append(st)
		var nl := Label3D.new()
		nl.text = str(mtr)
		nl.font_size = 64
		nl.pixel_size = 0.006
		nl.outline_size = 10
		nl.rotation_degrees = Vector3(-90, 0, 0)
		nl.position = Vector3(float(mtr), 0.01, 2.0)
		world.add_child(nl)
		labels.append(nl)
	for k in 10:
		var tk := MeshInstance3D.new()
		var tb := BoxMesh.new()
		tb.size = Vector3(0.02, 0.006, 0.25 if k == 5 else 0.15)
		tk.mesh = tb
		tk.position = Vector3(0.1 * float(k), 0.006, 1.4)
		world.add_child(tk)
		extras.append(tk)
	# Boosters for a small, a medium and the largest bombs.
	var mx := 18.0
	for id in ["mk82", "little_boy", "ivy_mike", "tsar"]:
		var bi := _find(id)
		if bi < 0:
			continue
		var ms := BM.build_missile(bombs[bi])
		ms.position = Vector3(mx, 0.0, -14.0)
		world.add_child(ms)
		extras.append(ms)
		mx += float(ms.get_meta("diameter")) * 3.0 + 3.0
	# Parachute with a B83 hanging below it.
	var pd := 14.0
	var bi83 := _find("b83")
	if bi83 >= 0:
		pd = BM.parachute_diameter(bombs[bi83])
	var pc := BM.build_parachute(pd, Color(0.85, 0.42, 0.12))
	pc.position = Vector3(mx + pd * 0.8, 5.0, -16.0)
	world.add_child(pc)
	extras.append(pc)
	if bi83 >= 0:
		var hb := BM.build(bombs[bi83])
		var hbox: AABB = hb.get_meta("aabb")
		hb.basis = Basis(Vector3(0, 0, 1), -PI * 0.5)  # nose down
		hb.position = pc.position + Vector3(0, -hbox.end.x - 0.3, 0)
		world.add_child(hb)
		extras.append(hb)
	print("parachute d=%.1f m height=%.1f m" % [pd, float(pc.get_meta("height"))])
	var cl := CanvasLayer.new()
	root.add_child(cl)
	hud = Label.new()
	hud.position = Vector2(24, 16)
	hud.add_theme_font_size_override("font_size", 60)
	hud.add_theme_color_override("font_color", Color(1, 1, 1))
	hud.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hud.add_theme_constant_override("outline_size", 12)
	cl.add_child(hud)


func _find(id: String) -> int:
	for i in bombs.size():
		if String((bombs[i] as Dictionary).get("id", "")) == id:
			return i
	return -1


# ---------------------------------------------------------------- checks ---

func _node_aabb(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	for c in n.get_children():
		if c is Node3D:
			var cxf := xf * (c as Node3D).transform
			var sub := AABB()
			var has := false
			if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
				sub = cxf * (c as MeshInstance3D).mesh.get_aabb()
				has = true
			var deep := _node_aabb(c, cxf)
			if deep.size != Vector3.ZERO:
				sub = deep if not has else sub.merge(deep)
				has = true
			if has:
				out = sub if first else out.merge(sub)
				first = false
	return out


func _check_sizes() -> void:
	print("id               model         L_data  L_model   D_data  D_body  AABB(x,y,z)            tris  result")
	var total_tris := 0
	for i in models.size():
		var b: Dictionary = bombs[i]
		var m := models[i]
		var L := float(b.get("length_m", 0.0))
		var D := float(b.get("diameter_m", 0.0))
		var meta_box: AABB = m.get_meta("aabb")
		var box := _node_aabb(m, Transform3D.IDENTITY)
		var body_d := float(m.get_meta("diameter"))
		var tris := int(m.get_meta("tris"))
		total_tris += tris
		var ok := true
		if absf(box.size.x - L) / L > 0.04:
			ok = false
		if absf(body_d - D) / D > 0.04:
			ok = false
		if maxf(box.size.y, box.size.z) < D * 0.97:
			ok = false
		if absf(box.get_center().x) > 0.02 * L:
			ok = false
		if not meta_box.size.is_equal_approx(box.size) and (meta_box.size - box.size).length() > 0.01:
			print("  meta/mesh AABB mismatch for ", b.get("id"), ": ", meta_box, " vs ", box)
			ok = false
		if tris <= 0 or tris > 20000:
			ok = false
		if not ok:
			failures += 1
		print("%-16s %-13s %6.2f  %6.2f   %6.3f  %6.3f  (%5.2f,%5.2f,%5.2f)  %6d  %s" % [String(b.get("id", "")), String(b.get("model", "")), L, box.size.x, D, body_d, box.size.x, box.size.y, box.size.z, tris, "OK" if ok else "BAD"])
	print("total triangles of 20 models: ", total_tris)


func _check_missiles() -> void:
	for id in ["mk82", "davy_crockett", "little_boy", "trinity", "ivy_mike", "tsar"]:
		var bi := _find(id)
		if bi < 0:
			continue
		var b: Dictionary = bombs[bi]
		var ms := BM.build_missile(b)
		var ok := true
		for child in ["Body", "Payload", "Nozzle"]:
			if ms.get_node_or_null(child) == null:
				print("  missile ", id, " missing child ", child)
				ok = false
		if ms.get_node_or_null("Payload/Bomb/Cradle") != null:
			print("  missile ", id, " still has the cradle")
			ok = false
		var box := _node_aabb(ms, Transform3D.IDENTITY)
		var h := float(ms.get_meta("height"))
		var dm := float(ms.get_meta("diameter"))
		var exp_d := maxf(1.2 * float(b.get("diameter_m", 0.5)), 0.6)
		if absf(box.position.y) > 0.01:
			ok = false
		if absf(box.end.y - h) > 0.02 * h:
			ok = false
		if absf(dm - exp_d) > 0.001:
			ok = false
		var bl := float(ms.get_meta("body_length"))
		if bl < 7.99 * dm or bl > 12.01 * dm:
			ok = false
		var nz: Marker3D = ms.get_node_or_null("Nozzle")
		if nz == null or nz.position.length() > 0.01:
			ok = false
		if not ok:
			failures += 1
		var tris := 0
		var bmesh: Mesh = (ms.get_node("Body") as MeshInstance3D).mesh
		for si in bmesh.get_surface_count():
			tris += int((bmesh as ArrayMesh).surface_get_array_index_len(si) / 3.0)
		print("missile %-14s D=%.2f body=%.2f (%.1fD) height=%.2f aabb_y=[%.2f..%.2f] body_tris=%d %s" % [id, dm, bl, bl / dm, h, box.position.y, box.end.y, tris, "OK" if ok else "BAD"])
		ms.free()
	var pc := BM.build_parachute(20.0, Color(0.9, 0.5, 0.1))
	var pbox := _node_aabb(pc, Transform3D.IDENTITY)
	var pok := absf(pbox.end.y - float(pc.get_meta("height"))) < 0.3 and pbox.position.y > -0.2 and pbox.position.y < 0.2 and pbox.size.x > 19.0
	if not pok:
		failures += 1
	print("parachute d=20: aabb=", pbox, " height=", pc.get_meta("height"), " ", "OK" if pok else "BAD")
	pc.free()


func _fail(msg: String) -> void:
	failures += 1
	print("  FAIL: ", msg)


## The public functions exist, are static and take the documented arguments.
func _check_api() -> void:
	var want := {"build": 1, "build_missile": 1, "build_parachute": 2, "parachute_diameter": 1}
	var found := {}
	for m in (BM as Script).get_script_method_list():
		var nm := String(m.get("name", ""))
		if want.has(nm):
			found[nm] = true
			if (int(m.get("flags", 0)) & METHOD_FLAG_STATIC) == 0:
				_fail("api: %s is not static" % nm)
			if (m.get("args", []) as Array).size() != int(want[nm]):
				_fail("api: %s takes %d args" % [nm, (m.get("args", []) as Array).size()])
	for nm in want:
		if not found.has(nm):
			_fail("api: missing " + String(nm))
	var b0: Dictionary = bombs[0]
	var m0 := BM.build(b0)
	for k in ["id", "model", "length", "diameter", "aabb", "tris", "conceptual"]:
		if not m0.has_meta(k):
			_fail("api: build() lacks meta " + k)
	if m0.get_node_or_null("Mesh") == null:
		_fail("api: build() lacks child Mesh")
	m0.free()
	var ms := BM.build_missile(b0)
	for k in ["height", "diameter", "body_length", "nozzle_radius", "seat_y"]:
		if not ms.has_meta(k):
			_fail("api: build_missile() lacks meta " + k)
	ms.free()
	var pc := BM.build_parachute(10.0, Color.WHITE)
	for k in ["height", "diameter", "skirt_y"]:
		if not pc.has_meta(k):
			_fail("api: build_parachute() lacks meta " + k)
	for c in ["Canopy", "Lines"]:
		if pc.get_node_or_null(c) == null:
			_fail("api: build_parachute() lacks child " + c)
	pc.free()
	var bi := _find("ivy_mike")
	if bi >= 0:
		var im := BM.build(bombs[bi])
		if not bool(im.get_meta("conceptual")) or im.get_node_or_null("Cradle") == null:
			_fail("api: ivy_mike must be conceptual and have a Cradle")
		im.free()
	print("api check done")


## Scans every vertex/normal of a node tree: finite positions, unit normals.
## Returns [vertex_count, bad_count].
func _scan_tree(n: Node) -> Array:
	var verts := 0
	var bad := 0
	for c in n.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			var mesh := (c as MeshInstance3D).mesh as ArrayMesh
			for si in mesh.get_surface_count():
				var arr := mesh.surface_get_arrays(si)
				var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
				var ids: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				verts += vs.size()
				for i in vs.size():
					var p: Vector3 = vs[i]
					if not p.is_finite():
						bad += 1
					elif i < ns.size():
						var nn: Vector3 = ns[i]
						if not nn.is_finite() or absf(nn.length() - 1.0) > 0.01:
							bad += 1
				for i in ids.size():
					if ids[i] < 0 or ids[i] >= vs.size():
						bad += 1
				if mesh.surface_get_material(si) == null:
					bad += 1
		var sub := _scan_tree(c)
		verts += int(sub[0])
		bad += int(sub[1])
	return [verts, bad]


## Signed volume of surface 0 of a mesh (closed solids). Godot front faces are
## clockwise, so an outward-facing closed surface gives a positive value here.
func _volume(mesh: ArrayMesh, si: int) -> float:
	var arr := mesh.surface_get_arrays(si)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ids: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var v := 0.0
	for t in range(0, ids.size(), 3):
		v -= vs[ids[t]].dot(vs[ids[t + 1]].cross(vs[ids[t + 2]]))
	return v / 6.0


func _check_geometry() -> void:
	var total_v := 0
	var total_bad := 0
	for i in bombs.size():
		var b: Dictionary = bombs[i]
		var m := BM.build(b)
		var r := _scan_tree(m)
		total_v += int(r[0])
		total_bad += int(r[1])
		# Surface 0 is the closed body solid: it must enclose a positive
		# volume close to that of the cylinder L x D (outward normals).
		var mesh := (m.get_node("Mesh") as MeshInstance3D).mesh as ArrayMesh
		var vol := _volume(mesh, 0)
		var L := float(b.get("length_m", 1.0))
		var R := float(b.get("diameter_m", 1.0)) * 0.5
		var ratio := vol / (PI * R * R * L)
		if ratio < 0.25 or ratio > 1.3:
			_fail("body volume of %s: %.3f m3 (%.2f of cylinder)" % [String(b.get("id", "")), vol, ratio])
		var ms := BM.build_missile(b)
		r = _scan_tree(ms)
		total_v += int(r[0])
		total_bad += int(r[1])
		var mvol := _volume((ms.get_node("Body") as MeshInstance3D).mesh as ArrayMesh, 0)
		if mvol <= 0.0:
			_fail("missile body of %s is inside-out (volume %.3f)" % [String(b.get("id", "")), mvol])
		ms.free()
		var pc := BM.build_parachute(BM.parachute_diameter(b), Color(0.9, 0.5, 0.1))
		r = _scan_tree(pc)
		total_v += int(r[0])
		total_bad += int(r[1])
		pc.free()
		m.free()
	if total_v == 0:
		print("  geometry scan: no vertex data readable (rendering server without mesh storage), skipped")
	elif total_bad > 0:
		_fail("geometry scan: %d bad vertices/normals/indices/materials of %d" % [total_bad, total_v])
	else:
		print("geometry scan: %d vertices, all finite, unit normals, valid indices, materials set, bodies outward" % total_v)
	# Trinity detonator directions: 32 distinct, evenly spread.
	var dirs: Array[Vector3] = BM._ti_dirs()
	var min_ang := PI
	for a in dirs.size():
		for c in range(a + 1, dirs.size()):
			min_ang = minf(min_ang, dirs[a].angle_to(dirs[c]))
	if dirs.size() != 32 or rad_to_deg(min_ang) < 35.0:
		_fail("gadget directions: %d dirs, min separation %.1f deg" % [dirs.size(), rad_to_deg(min_ang)])
	else:
		print("gadget directions: 32, min separation %.1f deg" % rad_to_deg(min_ang))


## Odd inputs must not crash or produce NaN.
func _check_robustness() -> void:
	var cases: Array[Dictionary] = [
		{},
		{"model": "no_such_model", "length_m": 0.0, "diameter_m": -1.0},
		{"model": "tsar", "length_m": 500.0, "diameter_m": 0.001, "colors": {"body": [1, 0]}},
		{"model": "gadget", "length_m": 0.01, "diameter_m": 0.01, "colors": "bad"},
		{"model": "sausage", "id": 42, "device": true},
	]
	for b in cases:
		var m := BM.build(b)
		var r := _scan_tree(m)
		var box: AABB = m.get_meta("aabb")
		if int(r[1]) > 0 or not box.position.is_finite() or not box.size.is_finite() or int(m.get_meta("tris")) <= 0:
			_fail("robustness: build(%s)" % str(b))
		m.free()
		var ms := BM.build_missile(b)
		r = _scan_tree(ms)
		if int(r[1]) > 0 or not is_finite(float(ms.get_meta("height"))):
			_fail("robustness: build_missile(%s)" % str(b))
		ms.free()
		var d := BM.parachute_diameter(b)
		if not is_finite(d) or d < 5.0 or d > 50.0:
			_fail("robustness: parachute_diameter(%s) = %f" % [str(b), d])
	for dm: float in [-3.0, 0.0, 0.5, 200.0]:
		var pc := BM.build_parachute(dm, Color(1, 1, 1, 0.5))
		if int(_scan_tree(pc)[1]) > 0 or not is_finite(float(pc.get_meta("height"))):
			_fail("robustness: build_parachute(%f)" % dm)
		pc.free()
	print("robustness check done")


## Builds and frees everything 20 times (also the launcher's payload
## separation), one cycle per frame so the rendering server can release the
## freed meshes; object counts and memory must not grow.
func _check_leaks() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var t_build := 0
	var t_missile := 0
	var t_chute := 0
	var n_calls := 0
	var counts: Array = []
	for cycle in 21:
		for b: Dictionary in bombs:
			var t0 := Time.get_ticks_usec()
			var m := BM.build(b)
			var t1 := Time.get_ticks_usec()
			var ms := BM.build_missile(b)
			var t2 := Time.get_ticks_usec()
			var pc := BM.build_parachute(BM.parachute_diameter(b), Color(0.9, 0.5, 0.1))
			var t3 := Time.get_ticks_usec()
			if cycle > 0:
				t_build += t1 - t0
				t_missile += t2 - t1
				t_chute += t3 - t2
				n_calls += 1
			holder.add_child(m)
			holder.add_child(ms)
			holder.add_child(pc)
			# Payload separation: reparent keeping the world transform.
			var p: Node3D = ms.get_node("Payload")
			var gt := ms.transform * p.transform
			ms.remove_child(p)
			holder.add_child(p)
			p.transform = gt
			m.free()
			ms.free()
			p.free()
			pc.free()
		await process_frame
		if cycle == 0 or cycle == 20:
			for k in 6:
				await process_frame
			counts.append([
				Performance.get_monitor(Performance.OBJECT_COUNT),
				Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
				Performance.get_monitor(Performance.MEMORY_STATIC),
				Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED),
				Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
			])
	holder.free()
	var a: Array = counts[0]
	var z: Array = counts[1]
	var mb := 1048576.0
	print("leak check (after cycle 1 -> after cycle 21): objects %d -> %d, orphan nodes %d -> %d, static mem %.2f -> %.2f MB, render buffers %.2f -> %.2f MB, video mem %.2f -> %.2f MB" % [int(a[0]), int(z[0]), int(a[1]), int(z[1]), float(a[2]) / mb, float(z[2]) / mb, float(a[3]) / mb, float(z[3]) / mb, float(a[4]) / mb, float(z[4]) / mb])
	if int(z[0]) > int(a[0]) or int(z[1]) > int(a[1]):
		_fail("leak: object/orphan node counts grew over 20 cycles")
	if float(z[2]) - float(a[2]) > 2.0 * mb:
		_fail("leak: static memory grew by %.1f MB" % ((float(z[2]) - float(a[2])) / mb))
	if float(z[3]) - float(a[3]) > 2.0 * mb or float(z[4]) - float(a[4]) > 2.0 * mb:
		_fail("leak: render memory grew")
	var nb := float(maxi(n_calls, 1))
	print("timing per call: build %.2f ms, build_missile %.2f ms, build_parachute %.2f ms" % [t_build / nb / 1000.0, t_missile / nb / 1000.0, t_chute / nb / 1000.0])
	if t_build / nb > 20000.0 or t_missile / nb > 40000.0 or t_chute / nb > 20000.0:
		_fail("timing: a builder takes more than 20-40 ms per call")


# ----------------------------------------------------------- screenshots ---

func _snap(path: String) -> Image:
	for k in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if path != "":
		var err := img.save_png(path)
		print("SHOT ", path, " err=", err)
	return img


func _set_view(pos: Vector3, target: Vector3, fov: float) -> void:
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = fov
	cam.transform = Transform3D(Basis.looking_at(target - pos, Vector3.UP), pos)


func _show_all(v: bool) -> void:
	for m in models:
		m.visible = v
	for e in extras:
		e.visible = v
	for l in labels:
		l.visible = v


func _shoot() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	_show_all(true)
	hud.text = ""
	# 1. Overview of the row with ruler.
	_set_view(Vector3(-9.0, 13.0, 10.0), Vector3(6.0, 0.0, -24.0), 60.0)
	await _snap(out_dir.path_join("overview.png"))
	# 2. Orthographic top view: lengths against the metre stripes.
	# Two halves of the row so the 1 m stripes stay readable.
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var z_first := models[0].position.z
	var z_last := models[models.size() - 1].position.z
	for half in 2:
		var za := lerpf(z_first, z_last, 0.5 * float(half))
		var zb := lerpf(z_first, z_last, 0.5 * float(half + 1))
		cam.size = absf(zb - za) + 6.0
		cam.position = Vector3(5.5, 60.0, (za + zb) * 0.5)
		cam.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		await _snap(out_dir.path_join("top_ruler_%d.png" % half))
	# 3. Boosters and parachute.
	_set_view(Vector3(34.0, 14.0, 42.0), Vector3(38.0, 12.0, -14.0), 50.0)
	await _snap(out_dir.path_join("missiles.png"))
	# 4. Close-up of the small booster adapter.
	if extras.size() > 0:
		var first_missile: Node3D = null
		for e in extras:
			if e.name == "Missile":
				first_missile = e
				break
		if first_missile != null:
			var h := float(first_missile.get_meta("height"))
			var p := first_missile.position
			_set_view(p + Vector3(2.5, h * 0.75, 4.0), p + Vector3(0, h * 0.7, 0), 40.0)
			await _snap(out_dir.path_join("missile_top.png"))
			_set_view(p + Vector3(2.5, 0.8, 4.0), p + Vector3(0, 0.9, 0), 40.0)
			await _snap(out_dir.path_join("missile_base.png"))
	# 5. Parachute seen from below (double-sided cloth, lines, scalloped hem).
	for e in extras:
		if e.name == "Parachute":
			var ph := float(e.get_meta("height"))
			var pdm := float(e.get_meta("diameter"))
			_set_view(e.position + Vector3(pdm * 1.1, ph * 0.25, pdm * 1.3), e.position + Vector3(0, ph * 0.6, 0), 45.0)
			await _snap(out_dir.path_join("parachute.png"))
	# 6. Full-resolution "menu preview" hero shots of a few models.
	_show_all(false)
	for id in ["baker", "trinity", "tsar", "moab"]:
		var bi := _find(id)
		if bi < 0:
			continue
		var hm := models[bi]
		hm.visible = true
		var hbox: AABB = hm.get_meta("aabb")
		var hc := hm.position + hbox.get_center()
		var hdir := Vector3(0.55, 0.3, 0.78).normalized()
		_set_view(hc + hdir * hbox.size.length() * 1.25, hc, 35.0)
		hud.text = id
		await _snap(out_dir.path_join("hero_%s.png" % id))
		hm.visible = false
	# 7. Contact sheets: each bomb alone, side view and rear 3/4 view.
	_show_all(false)
	for view in 3:
		var tile := Vector2i(480, 270)
		var sheet := Image.create(tile.x * 5, tile.y * 4, false, Image.FORMAT_RGBA8)
		for i in models.size():
			var m := models[i]
			m.visible = true
			var b: Dictionary = bombs[i]
			hud.text = "%d %s" % [i + 1, String(b.get("id", ""))]
			var box: AABB = m.get_meta("aabb")
			var ctr := m.position + box.get_center()
			var rad := box.size.length() * 0.5
			var dir := Vector3(0.0, 0.22, 1.0)
			if view == 1:
				dir = Vector3(-0.75, 0.45, 0.6)
			elif view == 2:
				dir = Vector3(0.7, 0.35, 0.65)
			dir = dir.normalized()
			var fov := 30.0
			var dist := rad / sin(deg_to_rad(fov * 0.5)) * 0.72
			if view == 0:
				var tv := tan(deg_to_rad(fov * 0.5))
				var th := tv * 16.0 / 9.0
				dist = maxf(box.size.x * 0.5 / th * 1.12, box.size.y * 0.5 / tv * 1.25) + box.size.z * 0.5
			_set_view(ctr + dir * dist, ctr, fov)
			var img := await _snap("")
			img.convert(Image.FORMAT_RGBA8)
			img.resize(tile.x, tile.y, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, tile), Vector2i((i % 5) * tile.x, (i / 5) * tile.y))
			m.visible = false
		var names := ["sheet_side.png", "sheet_rear34.png", "sheet_front34.png"]
		var path := out_dir.path_join(names[view])
		print("SHOT ", path, " err=", sheet.save_png(path))
	hud.text = ""
	_finish()
