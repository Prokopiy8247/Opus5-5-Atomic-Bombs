extends SceneTree
## Test for scripts/world/range_objects.gd + shaders/destructible.gdshader.
##
## Logic check:  godot --headless --path . -s res://tools/test_range.gd
## Visual check: godot --path . --resolution 1600x900 -s res://tools/test_range.gd -- --out C:/abs/dir
##   [--only a|b] [--night 0|1] [--scrub 0|1]
##
## Scenario A: 15 kt air burst at 580 m (Little Boy), ground zero 12 km north of the bunker.
## Scenario B: 1.2 Mt surface burst (B83), ground zero 45 km north.
## For each scenario the global uniform g_blast_age is set to -1, 1, 3, 6, 10, 20 s and an
## overview plus close-ups of the stations at several pressure rings are captured, together
## with contact sheets (row-major in time order). Prints READY at the end.

const RO = preload("res://scripts/world/range_objects.gd")
const TIMES := [-1.0, 1.0, 3.0, 6.0, 10.0, 20.0]

var out_dir := ""
var only := ""
var do_night := true
var do_scrub := true
var fails := 0
var ro: Node3D
var cam: Camera3D
var env_ctl: Node3D
var terrain: Node3D
var game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			out_dir = args[i + 1]
		elif args[i] == "--only" and i + 1 < args.size():
			only = args[i + 1]
		elif args[i] == "--night" and i + 1 < args.size():
			do_night = args[i + 1] != "0"
		elif args[i] == "--scrub" and i + 1 < args.size():
			do_scrub = args[i + 1] != "0"
	if out_dir == "":
		out_dir = OS.get_user_data_dir().path_join("test_range")
	DirAccess.make_dir_recursive_absolute(out_dir)
	game = root.get_node_or_null("Game")
	print("test_range: Game autoload present: ", game != null, " display: ", DisplayServer.get_name())
	_logic_tests()
	_run.call_deferred()


func _run() -> void:
	await _leak_test()
	if DisplayServer.get_name() == "headless":
		_finish()
	else:
		await _visual()


func _finish() -> void:
	if fails == 0:
		print("ALL RANGE CHECKS PASSED")
	else:
		print("RANGE CHECK FAILURES: ", fails)
	print("READY")
	quit()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		print("  FAIL ", msg)
		fails += 1


# =================================================================== logic

func _frac_destroyed(t: int, psi: float) -> float:
	var n := 400
	var k := 0
	for i in n:
		if RO.state_for(t, psi, (i + 0.5) / n) >= 2:
			k += 1
	return float(k) / n


func _p50(t: int) -> float:
	# overpressure at which half of the objects of a type are destroyed
	var lo := 0.1
	var hi := 1000.0
	for i in 40:
		var mid := sqrt(lo * hi)
		if _frac_destroyed(t, mid) < 0.5:
			lo = mid
		else:
			hi = mid
	return hi


func _logic_tests() -> void:
	print("--- threshold order (docs/02 section 6)")
	var p := {}
	for t in [RO.T_WOOD, RO.T_BRICK, RO.T_TREE, RO.T_JUNIPER, RO.T_CAR, RO.T_TRUCK, RO.T_TANK, RO.T_TOWER,
			RO.T_MAST, RO.T_POLE, RO.T_BRIDGE, RO.T_BUNKER, RO.T_HANGAR, RO.T_AIRCRAFT, RO.T_RAILCAR]:
		p[t] = _p50(t)
		print("  p50 %-12s %7.2f psi" % [RO.TYPE_NAMES[t], p[t]])
	_check(p[RO.T_AIRCRAFT] < p[RO.T_WOOD], "parked aircraft thrown before wooden houses are blown away")
	_check(p[RO.T_HANGAR] < p[RO.T_BRICK], "steel-frame hangar (3.1 psi) before brick houses (5 psi)")
	_check(p[RO.T_TREE] < p[RO.T_CAR], "trees toppled before cars tumble")
	_check(p[RO.T_WOOD] < p[RO.T_BRICK], "wooden houses before brick houses")
	_check(p[RO.T_CAR] < p[RO.T_RAILCAR], "cars before rail cars")
	_check(p[RO.T_RAILCAR] < p[RO.T_BRIDGE], "rail cars before bridge spans")
	_check(p[RO.T_BRIDGE] < p[RO.T_TANK], "bridge spans before tanks")
	_check(p[RO.T_TANK] < p[RO.T_BUNKER], "tanks before concrete bunkers")
	_check(absf(p[RO.T_TOWER] - 5.0) < 0.8 and absf(p[RO.T_MAST] - 5.0) < 0.8, "towers / 120 ft masts fail at ~5 psi")
	_check(p[RO.T_BUNKER] > 100.0, "concrete bunkers survive below 100 psi")
	var f3 := _frac_destroyed(RO.T_TREE, 3.0)
	var f45 := _frac_destroyed(RO.T_TREE, 4.5)
	print("  trees toppled: %.0f%% at 3 psi, %.0f%% at 4.5 psi" % [f3 * 100.0, f45 * 100.0])
	_check(absf(f3 - 0.3) < 0.1 and absf(f45 - 0.9) < 0.08, "tree toppling 30% at 3 psi, 90% at 4.5 psi")
	_check(_frac_destroyed(RO.T_WOOD, 1.7) == 0.0 and _frac_destroyed(RO.T_WOOD, 6.0) == 1.0, "wood house stands at 1.7 psi, gone at 6 psi")
	_check(_frac_destroyed(RO.T_TANK, 25.0) == 0.0, "tanks unaffected below ~30 psi")
	_check(RO.state_for(RO.T_BRICK, 4.0, 0.5) == 1 and _frac_destroyed(RO.T_BRICK, 4.9) == 0.0, "brick house damaged (not destroyed) at 3-5 psi")

	print("--- scenario A: 15 kt air burst, HOB 580 m, ground zero 12 km")
	ro = RO.new()
	root.add_child(ro)
	_scenario_logic(Vector3(0, TerrainMath.height(0, -12000), -12000), 15.0, 580.0, false, {})
	print("--- scenario B: 1.2 Mt surface burst, ground zero 45 km")
	_scenario_logic(Vector3(1500, TerrainMath.height(1500, -45000), -45000), 1200.0, 2.0, true, {})
	print("--- scenario C: Mk 82 (0.1 t) conventional surface burst at 2 km")
	_scenario_logic(Vector3(0, TerrainMath.height(0, -2000), -2000), 0.0001, 1.0, true, {"nuclear": false})
	print("--- scenario D: Tsar Bomba 50 Mt at 4 km, ground zero 150 km")
	_scenario_logic(Vector3(0, TerrainMath.height(0, -150000), -150000), 50000.0, 4000.0, false, {})
	print("--- scenario E: Sedan-like buried burst, blast_scale 0.08 (as main.gd passes it)")
	var gz_e := Vector3(0, TerrainMath.height(0, -9000), -9000)
	ro.setup(gz_e, 104.0, -194.0, true, 0.55, {"nuclear": true, "blast_scale": 0.08, "crater_r": 190.0})
	var worst_p := 0.0
	var worst_a := 0.0
	for s: float in [300.0, 800.0, 2000.0, 5000.0]:
		var b := BlastPhysics.overpressure(104.0 * 0.08, s, true, false)
		worst_p = maxf(worst_p, absf(ro.psi_at(s) - b) / b)
		worst_a = maxf(worst_a, absf(ro.arrival_at(s) - BlastPhysics.arrival_time(104.0, s, true, false)))
	_check(worst_p < 0.02, "coupled overpressure = BlastPhysics.overpressure(w * blast_scale) (worst %.2f%%)" % (worst_p * 100.0))
	_check(worst_a < 1e-6, "arrival uses the full yield, like explosion.gd's shock ring and bunker shock")
	_check(ro.instance_total() > 40, "objects placed around a buried burst (%d)" % ro.instance_total())
	var inside := 0
	for key: String in ro._buckets:
		for xf: Transform3D in ro._buckets[key]["xf"]:
			if Vector2(xf.origin.x - gz_e.x, xf.origin.z - gz_e.z).length() < 190.0 * 1.6 * 0.9:
				inside += 1
	_check(inside == 0, "nothing placed inside the crater keep-out")
	print("--- scenario F: exclude_r keeps the lagoon empty (Baker-style)")
	var gz_f := Vector3(0, TerrainMath.height(0, -8000), -8000)
	ro.setup(gz_f, 23.0, -27.0, true, 0.9, {"nuclear": true, "blast_scale": 0.3, "exclude_r": 2500.0})
	var wet := 0
	for key: String in ro._buckets:
		for xf: Transform3D in ro._buckets[key]["xf"]:
			if Vector2(xf.origin.x - gz_f.x, xf.origin.z - gz_f.z).length() < 2500.0 * 0.9:
				wet += 1
	_check(wet == 0, "no object inside exclude_r (%d objects outside)" % ro.instance_total())
	print("--- setup() before the node enters the tree, double clear(), empty queries")
	var r2: Node3D = RO.new()
	r2.setup(Vector3(0, TerrainMath.height(0, -5000), -5000), 0.3, 150.0, false, 0.5)
	var n2: int = r2.instance_total()
	root.add_child(r2)
	r2.clear()
	r2.clear()
	_check(n2 > 0 and r2.instance_total() == 0 and r2.damage_summary(5.0).is_empty() and r2.rings().is_empty(), "out-of-tree setup works (%d objects), clear() empties it" % n2)
	r2.queue_free()
	print("--- repeated setup does not leak instances")
	var counts: Array = []
	for i in 3:
		ro.setup(Vector3(0, TerrainMath.height(0, -12000), -12000), 15.0, 580.0, false, 0.55)
		counts.append(ro.instance_total())
	_check(counts[0] == counts[1] and counts[1] == counts[2], "same layout each time (%s)" % str(counts))


## 20 consecutive setup() calls over four bomb sizes with frames in between: the node, object
## and resource counts after the 5th round equal those after the 2nd round (no leaks), and
## clear() leaves no children behind.
func _leak_test() -> void:
	print("--- 20 setup() cycles: nodes / objects / resources do not grow")
	var sc := [[Vector3(0, 0, -12000), 15.0, 580.0, false], [Vector3(1500, 0, -45000), 1200.0, 2.0, true],
		[Vector3(0, 0, -2000), 0.0001, 1.0, true], [Vector3(0, 0, -150000), 50000.0, 4000.0, false]]
	var snap := {}
	var setup_ms := 0.0
	for i in 20:
		var e: Array = sc[i % 4]
		var gz: Vector3 = e[0]
		gz.y = TerrainMath.height(gz.x, gz.z)
		var t0 := Time.get_ticks_usec()
		ro.setup(gz, e[1], e[2], e[3], 0.55, {"nuclear": float(e[1]) >= 0.05})
		setup_ms = maxf(setup_ms, (Time.get_ticks_usec() - t0) / 1000.0)
		for f in 3:
			await process_frame
		var m := [ro.get_child_count(), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			int(Performance.get_monitor(Performance.OBJECT_COUNT)), int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
			int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))]
		if i >= 4 and i < 8:
			snap[i % 4] = m
		elif i >= 16:
			var a: Array = snap[i % 4]
			print("  scenario %d: children %d->%d nodes %d->%d objects %d->%d resources %d->%d orphans %d->%d" % [i % 4,
				a[0], m[0], a[1], m[1], a[2], m[2], a[3], m[3], a[4], m[4]])
			_check(m[0] == a[0] and m[1] == a[1] and m[4] == a[4], "scenario %d: node counts stable over 12 more setups" % (i % 4))
			_check(m[2] - a[2] <= 8 and m[3] - a[3] <= 8, "scenario %d: object / resource counts stable" % (i % 4))
	print("  slowest setup(): %.0f ms" % setup_ms)
	_check(setup_ms < 400.0, "setup() stays well under half a second")
	ro.clear()
	for f in 3:
		await process_frame
	_check(ro.get_child_count() == 0, "clear() frees every MultiMesh node")


func _scenario_logic(gz: Vector3, w: float, hob: float, surface: bool, opts: Dictionary) -> void:
	var t0 := Time.get_ticks_msec()
	ro.setup(gz, w, hob, surface, 0.55, opts)
	var ms := Time.get_ticks_msec() - t0
	var n: int = ro.instance_total()
	print("  setup %d ms, %d objects, %d smoke columns, %d multimeshes" % [ms, n, ro._smoke_list.size(), ro._buckets.size()])
	_check(n > 40 and n < 6000, "instance count is modest (%d)" % n)
	var rings: Array = ro.rings()
	var prev_r := 0.0
	var prev_t := -1.0
	var mono := true
	for rg: Dictionary in rings:
		print("  ring %6.1f psi  r = %8.0f m  arrival %7.2f s" % [rg["psi"], rg["r"], rg["arrival"]])
		if float(rg["r"]) <= prev_r or float(rg["arrival"]) <= prev_t:
			mono = false
		prev_r = rg["r"]
		prev_t = rg["arrival"]
	_check(rings.size() >= 3, "at least 3 pressure rings placed (%d)" % rings.size())
	_check(mono, "ring radii and arrival times increase outward")
	# per-instance pressure table vs BlastPhysics.overpressure, arrival = BlastPhysics.arrival_time
	var conv := not bool(opts.get("nuclear", w >= 0.05))
	var worst := 0.0
	var worst_t := 0.0
	for s: float in [20.0, 80.0, 300.0, 1000.0, 3000.0, 10000.0, 40000.0]:
		var a: float = ro.psi_at(s)
		var b := BlastPhysics.overpressure(w, s, surface, conv)
		if b > 0.01 and b < 50000.0:
			worst = maxf(worst, absf(a - b) / maxf(b, 1e-6))
		worst_t = maxf(worst_t, absf(ro.arrival_at(s) - BlastPhysics.arrival_time(w, s, surface, conv)))
	_check(worst < 0.02, "psi table matches BlastPhysics.overpressure (worst %.2f%%)" % (worst * 100.0))
	_check(worst_t < 1e-6, "arrival times are BlastPhysics.arrival_time")
	# placement rules: nothing near the bunker, nothing on the line of sight, sitting on terrain
	var near_bunker := 0
	var on_los := 0
	var bad := 0
	var off_ground := 0
	var gz2 := Vector2(gz.x, gz.z)
	for key: String in ro._buckets:
		var b: Dictionary = ro._buckets[key]
		var type: int = b["type"]
		for i in (b["xf"] as Array).size():
			var xf: Transform3D = b["xf"][i]
			var cu: Color = b["cu"][i]
			var o := Vector2(xf.origin.x, xf.origin.z)
			if type != RO.T_WIRE and o.length() < 300.0:
				near_bunker += 1
			var t := o.dot(gz2) / gz2.length_squared()
			if type != RO.T_WIRE and t > 0.0 and t < 1.0 and (o - gz2 * t).length() < 20.0:
				on_los += 1
			for c in 4:
				if is_nan(cu[c]) or is_inf(cu[c]):
					bad += 1
			if absf(xf.origin.y - TerrainMath.height(xf.origin.x, xf.origin.z)) > 0.01:
				off_ground += 1
	_check(near_bunker == 0, "no object within 300 m of the bunker")
	_check(on_los == 0, "no object on the line of sight bunker -> ground zero")
	_check(bad == 0, "no NaN/inf in instance data")
	_check(off_ground == 0, "every instance sits on TerrainMath.height")
	# destruction progresses monotonically with time and in psi order
	var prev := -1
	var mono_t := true
	for t: float in [0.5, 1.0, 2.0, 3.0, 6.0, 10.0, 20.0, 40.0, 90.0]:
		var sm: Dictionary = ro.damage_summary(t)
		var dsum := 0
		var line := ""
		for nm: String in sm:
			var d: Dictionary = sm[nm]
			dsum += int(d["destroyed"])
			if nm in ["wood_house", "brick_house", "tree", "car", "tank", "bunker"]:
				line += " %s %d/%d" % [nm, d["destroyed"], d["total"]]
		print("  t=%5.1f s destroyed %4d |%s" % [t, dsum, line])
		if dsum < prev:
			mono_t = false
		prev = dsum
	_check(mono_t, "destroyed count never decreases with time")
	# per-object psi order: whenever a sturdier type is destroyed at some psi, the weaker types at
	# that psi are destroyed too (wood < brick < tank < bunker by the doc thresholds)
	var order_ok := true
	for o: Array in ro._objects:
		var tt: int = o[0]
		var ps: float = o[1]
		if ps >= 999.0:
			continue
		if tt == RO.T_BRICK and RO.state_for(tt, ps, o[3]) == 2 and _frac_destroyed(RO.T_WOOD, ps) < 1.0:
			order_ok = false
		if tt == RO.T_TANK and RO.state_for(tt, ps, o[3]) == 2 and _frac_destroyed(RO.T_BRICK, ps) < 1.0:
			order_ok = false
	_check(order_ok, "no sturdier object fails where a weaker one survives")


# =================================================================== visual

func _visual() -> void:
	# world: the project's own environment + clipmap terrain if available
	if game != null:
		game.set("tod", 1)
		env_ctl = load("res://scripts/world/environment_ctl.gd").new()
		env_ctl.name = "Environment"
		root.add_child(env_ctl)
		env_ctl.call("set_humidity", 0.55)
	else:
		_simple_env()
	terrain = load("res://scripts/world/terrain.gd").new()
	terrain.name = "Terrain"
	root.add_child(terrain)
	cam = Camera3D.new()
	cam.near = 0.3
	cam.far = 300000.0
	cam.fov = 55.0
	root.add_child(cam)
	cam.current = true
	for i in 30:
		await process_frame
	if only == "" or only == "a":
		await _scenario_visual("a", Vector3(0, TerrainMath.height(0, -12000), -12000), 15.0, 580.0, false)
	if only == "" or only == "b":
		await _scenario_visual("b", Vector3(1500, TerrainMath.height(1500, -45000), -45000), 1200.0, 2.0, true)
	if only == "" or only == "c":
		await _scenario_visual("c", Vector3(0, TerrainMath.height(0, -2000), -2000), 0.0001, 1.0, true, {"nuclear": false})
	await _perf()
	RenderingServer.global_shader_parameter_set("g_blast_age", -1.0)
	_finish()


## Average frame time with the range objects shown / hidden (scenario A at age 10 s).
func _perf() -> void:
	var gz := Vector3(0, TerrainMath.height(0, -12000), -12000)
	ro.setup(gz, 15.0, 580.0, false, 0.55)
	_set_globals(10.0, gz, gz + Vector3(0, 580, 0), 15.0, false)
	for view: Array in [["bunker", Vector3(0, 0, 0), gz + Vector3(0, 30, 0), 70.0], ["close", gz + Vector3(1300, 240, 700), gz + Vector3(-150, 0, -300), 45.0]]:
		_aim(view[1], view[2], view[3])
		var res := []
		for vis: bool in [false, true]:
			ro.visible = vis
			for f in 30:
				await process_frame
			var t0 := Time.get_ticks_usec()
			for f in 120:
				await process_frame
			res.append((Time.get_ticks_usec() - t0) / 120000.0)
		print("PERF %s: frame %.2f ms without objects, %.2f ms with objects" % [view[0], res[0], res[1]])
	ro.visible = true


func _simple_env() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.65, 0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.65)
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.basis = Basis.looking_at(Vector3(-0.4, -0.8, -0.3).normalized(), Vector3.UP)
	sun.shadow_enabled = true
	root.add_child(sun)


func _scenario_visual(tag: String, gz: Vector3, w: float, hob: float, surface: bool, opts: Dictionary = {}) -> void:
	# high-resolution terrain patch around ground zero, exactly as main.gd sets it up
	var crater := BlastPhysics.crater_radius_nuclear(w) if (surface and w >= 0.05) else 0.0
	var ext := clampf(maxf(crater * 4.0, BlastPhysics.radius_for_pressure(w, 5.0, surface) * 1.2), 250.0, 6000.0)
	terrain.call("set_patch", gz, ext)
	ro.setup(gz, w, hob, surface, 0.55, opts)
	var burst := gz + Vector3(0, maxf(hob, 0.0), 0)
	print("visual %s: %d objects" % [tag, ro.instance_total()])
	var gz2 := Vector2(gz.x, gz.z)
	var views: Array = []
	# what the player sees from the bunker window (default FOV and the binocular zoom)
	views.append(["bunker", Vector3(0, 0, 0), gz + Vector3(0, 30, 0), 70.0])
	views.append(["binocular", Vector3(0, 0, 0), gz + Vector3(900, 0, 0), 6.0])
	# overview: elevated, ~1.5 km (A) / 6 km (B) from ground zero, from the east side
	if tag == "a":
		views.append(["overview", gz + Vector3(1300, 240, 700), gz + Vector3(-150, 0, -300), 45.0])
	elif tag == "c":
		views.append(["overview", gz + Vector3(120, 45, 90), gz + Vector3(-10, 0, -20), 55.0])
	else:
		views.append(["overview", gz + Vector3(5200, 900, 3200), gz + Vector3(-600, 0, -1500), 62.0])
	for target: float in ([10.0, 5.0, 3.0, 2.0] if tag == "a" else [20.0, 10.0, 5.0, 3.0]):
		var v := _closeup(RO.T_WOOD, target, gz2, 55.0, 17.0, "p%s" % str(target))
		if not v.is_empty():
			views.append(v)
	# the special test structures
	for e: Array in [[RO.T_BRIDGE, 14.0, 150.0, 40.0, "bridge"], [RO.T_HANGAR, 2.5, 140.0, 45.0, "airfield"],
			[RO.T_RAILCAR, 7.5, 90.0, 26.0, "rail"], [RO.T_TOWER, 5.0, 120.0, 30.0, "tower"], [RO.T_MAST, 7.0, 100.0, 25.0, "mast"],
			[RO.T_TANK, 40.0, 45.0, 14.0, "tank"], [RO.T_BUNKER, 60.0, 45.0, 14.0, "cbunker"]]:
		var v := _closeup(e[0], e[1], gz2, e[2], e[3], e[4])
		if not v.is_empty():
			views.append(v)
	var shots := {}
	for t: float in TIMES:
		_set_globals(t, gz, burst, w, surface)
		for v: Array in views:
			_aim(v[1], v[2], v[3])
			for f in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			var path := out_dir.path_join("%s_%s_t%s.png" % [tag, v[0], _tstr(t)])
			var err := img.save_png(path)
			print("SHOT ", path, " err=", err)
			if not shots.has(v[0]):
				shots[v[0]] = []
			(shots[v[0]] as Array).append(img)
	for k: String in shots:
		_sheet(shots[k], 3, out_dir.path_join("%s_%s_sheet.png" % [tag, k]))
	# fine time scrub through the passage of the front at one station (continuity: nothing pops)
	var closeups: Array = views.filter(func(x: Array) -> bool: return x.size() > 4 and String(x[0]).begins_with("p"))
	if do_scrub and closeups.size() > 1:
		var v: Array = closeups[1]
		var arr: float = v[4]
		var imgs: Array = []
		for i in 18:
			var t := arr - 0.25 + i * 0.25
			_set_globals(t, gz, burst, w, surface)
			_aim(v[1], v[2], v[3])
			for f in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			imgs.append(root.get_texture().get_image())
		_sheet(imgs, 6, out_dir.path_join("%s_scrub_%s_sheet.png" % [tag, v[0]]))
		print("SCRUB %s arrival %.2f s" % [v[0], arr])
	# night: fires and smoke columns
	if do_night and env_ctl != null:
		env_ctl.call("apply_tod", 3)
		for t: float in [6.0, 20.0]:
			_set_globals(t, gz, burst, w, surface)
			for v: Array in ([views[0], closeups[min(1, closeups.size() - 1)]] if closeups.size() > 0 else [views[0]]):
				_aim(v[1], v[2], v[3])
				for f in 4:
					await process_frame
				await RenderingServer.frame_post_draw
				var path := out_dir.path_join("%s_night_%s_t%s.png" % [tag, v[0], _tstr(t)])
				print("SHOT ", path, " err=", root.get_texture().get_image().save_png(path))
		env_ctl.call("apply_tod", 1)


func _tstr(t: float) -> String:
	return ("m%d" % int(-t)) if t < 0.0 else ("%04.1f" % t)


## Camera looking at the object of a type whose peak overpressure is closest to the target psi,
## from the side (perpendicular to the blast direction) so the motion crosses the frame.
func _closeup(type: int, target: float, gz2: Vector2, dist: float, height: float, label: String) -> Array:
	var best := INF
	var pos := Vector3.ZERO
	var arr := 0.0
	var psi := 0.0
	for key: String in ro._buckets:
		var b: Dictionary = ro._buckets[key]
		if int(b["type"]) != type:
			continue
		for i in (b["xf"] as Array).size():
			var cu: Color = b["cu"][i]
			var d := absf(log(cu.g / target))
			if d < best:
				best = d
				pos = (b["xf"][i] as Transform3D).origin
				arr = cu.r
				psi = cu.g
	if best == INF:
		return []
	var o := Vector2(pos.x, pos.z)
	var u_r := (o - gz2).normalized()
	var u_t := Vector2(-u_r.y, u_r.x)
	# stand on the side away from the bunker's line of sight, a bit downwind
	var side := 1.0 if (o + u_t * 10.0).length() > o.length() else -1.0
	var c2 := o + u_t * side * dist + u_r * dist * 0.4
	if type == RO.T_RAILCAR:
		# broadside: look from the ground-zero side across the track
		c2 = o - u_r * dist + u_t * side * dist * 0.35
	var eye := Vector3(c2.x, TerrainMath.height(c2.x, c2.y) + height, c2.y)
	var look := pos + Vector3(u_r.x, 0, u_r.y) * dist * 0.33 + Vector3(0, 2.0 + (12.0 if type == RO.T_TOWER else 0.0), 0)
	print("VIEW %s: type %s psi %.2f arrival %.2f s" % [label, RO.TYPE_NAMES[type], psi, arr])
	return [label, eye, look, 50.0, arr]


func _aim(eye: Vector3, look: Vector3, fov: float) -> void:
	cam.global_transform = Transform3D(Basis.looking_at(look - eye, Vector3.UP), eye)
	cam.fov = fov


func _set_globals(t: float, gz: Vector3, burst: Vector3, w: float, surface: bool) -> void:
	RenderingServer.global_shader_parameter_set("g_blast_center", gz)
	RenderingServer.global_shader_parameter_set("g_blast_age", t)
	ro.set_age(t)
	if t <= 0.0:
		RenderingServer.global_shader_parameter_set("g_fireball", Vector4(0, -10000, 0, 0))
		RenderingServer.global_shader_parameter_set("g_fireball_color", Vector4(0, 0, 0, 0))
		RenderingServer.global_shader_parameter_set("g_shock", Vector4(0, 0, 0, 0))
		RenderingServer.global_shader_parameter_set("g_crater", Vector4(0, 0, 0, 0))
		return
	if w < 0.05:
		# conventional charge: no nuclear fireball / thermal pulse in this test
		RenderingServer.global_shader_parameter_set("g_fireball_color", Vector4(0, 0, 0, 0))
		RenderingServer.global_shader_parameter_set("g_shock", Vector4(0, 0, 0, 0))
		return
	var R := BlastPhysics.fireball_radius(w, t, surface)
	var rise := 0.0 if t < 3.0 else 30.0 * (t - 3.0)
	var fpos := burst + Vector3(0, (R * 0.6 if surface else 0.0) + rise, 0)
	var temp := BlastPhysics.fireball_temperature(w, t)
	var col := _bb(maxf(temp, 1500.0))
	var inten := BlastPhysics.thermal_power(w, t) * pow(w, 0.33) * 40.0
	RenderingServer.global_shader_parameter_set("g_fireball", Vector4(fpos.x, fpos.y, fpos.z, R))
	RenderingServer.global_shader_parameter_set("g_fireball_color", Vector4(col.r, col.g, col.b, inten))
	# visible ground shock ring at the front (terrain shader), from the module's own arrival table
	var lo := 1.0
	var hi := 400000.0
	for i in 50:
		var mid := sqrt(lo * hi)
		if ro.arrival_at(mid) < t:
			lo = mid
		else:
			hi = mid
	var hb := maxf(burst.y - gz.y, 0.0)
	var rg := sqrt(maxf(lo * lo - hb * hb, 0.0))
	RenderingServer.global_shader_parameter_set("g_shock", Vector4(rg, 1.0, maxf(rg * 0.02, 5.0), 1.0))
	if surface:
		var cr := BlastPhysics.crater_radius_nuclear(w)
		RenderingServer.global_shader_parameter_set("g_crater", Vector4(cr, cr * 0.5, cr * 0.12, clampf(t / 2.0, 0.0, 1.0)))


func _bb(temp: float) -> Color:
	var t := clampf(temp, 1000.0, 40000.0) / 100.0
	var r := 1.0 if t <= 66.0 else clampf(1.29293618606 * pow(t - 60.0, -0.1332047592), 0.0, 1.0)
	var g := clampf(0.39008157876 * log(t) - 0.63184144378, 0.0, 1.0) if t <= 66.0 else clampf(1.12989086089 * pow(t - 60.0, -0.0755148492), 0.0, 1.0)
	var b := 1.0 if t >= 66.0 else (0.0 if t <= 19.0 else clampf(0.54320678911 * log(t - 10.0) - 1.19625408914, 0.0, 1.0))
	return Color(r, g, b)


func _sheet(imgs: Array, cols: int, path: String) -> void:
	if imgs.is_empty():
		return
	var first: Image = imgs[0]
	var tw := first.get_width() / 2
	var th := first.get_height() / 2
	var rows := int(ceil(float(imgs.size()) / cols))
	var sheet := Image.create(tw * cols, th * rows, false, Image.FORMAT_RGB8)
	for i in imgs.size():
		var im: Image = (imgs[i] as Image).duplicate()
		im.convert(Image.FORMAT_RGB8)
		im.resize(tw, th, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(im, Rect2i(0, 0, tw, th), Vector2i((i % cols) * tw, (i / cols) * th))
	print("SHEET ", path, " err=", sheet.save_png(path))
