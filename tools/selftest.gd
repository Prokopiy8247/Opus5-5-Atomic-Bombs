extends Node
## Automated quantitative checks. Prints PASS/FAIL lines and finally READY (all passed) or FAIL.
## Run: godot --path . res://scenes/selftest.tscn  (or --headless)

var fails := 0
var checks := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	checks += 1
	if ok:
		print("PASS  ", name, "  ", detail)
	else:
		fails += 1
		print("FAIL  ", name, "  ", detail)


func near(name: String, value: float, ref: float, tol: float) -> void:
	var err := absf(value - ref) / maxf(absf(ref), 1e-9)
	check(name, err <= tol and BlastPhysics.is_finite_num(value), "value=%.4f ref=%.4f err=%.1f pct tol=%d pct" % [value, ref, err * 100.0, int(tol * 100.0)])


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("SELFTEST start")
	_fireball()
	_cloud()
	_blast()
	_thermal()
	_bombs()
	await _leaks()
	print("SELFTEST checks=%d failures=%d" % [checks, fails])
	print("READY" if fails == 0 else "FAIL")
	get_tree().quit()


func _fireball() -> void:
	# Trinity measured fireball radius (Mack/Taylor): 138 m at 25 ms, 200 m at 53 ms, 218 m at 90 ms (21 kt tower)
	near("fireball Trinity 25 ms", BlastPhysics.fireball_radius(21.0, 0.025, true), 138.0, 0.15)
	near("fireball Trinity 53 ms", BlastPhysics.fireball_radius(21.0, 0.053, true), 200.0, 0.15)
	near("fireball Trinity 90 ms", BlastPhysics.fireball_radius(21.0, 0.090, true), 218.0, 0.15)
	near("fireball Trinity ~2 s (600 m diameter)", BlastPhysics.fireball_radius(21.0, 2.0, true), 300.0, 0.15)
	# research A10 / G&D: R_max air 1 kt 61 m; contact 15 Mt ~3.41 km (6.8 km measured ~7 km for Bravo)
	near("R_max air 1 kt", BlastPhysics.fireball_r_max(1.0, false), 61.0, 0.03)
	near("R_max air 15 kt (Little Boy ~200 m)", BlastPhysics.fireball_r_max(15.0, false), 180.0, 0.15)
	near("R_max air 1 Mt", BlastPhysics.fireball_r_max(1000.0, false), 966.0, 0.15)
	near("R_max contact 15 Mt (Bravo)", BlastPhysics.fireball_r_max(15000.0, true), 3410.0, 0.10)
	near("R_max Tsar Bomba (measured ~8 km diameter)", BlastPhysics.fireball_r_max(50000.0, false), 4000.0, 0.15)
	near("t2 1 Mt", BlastPhysics.t_second_max(1000.0), 0.871, 0.02)
	near("t_min 20 kt", BlastPhysics.t_min(20.0), 0.0116, 0.20)
	# pulse shape cumulative: F(2) = 0.46, F(5) = 0.73 (+-0.03 absolute)
	var w := 20.0
	var t2 := BlastPhysics.t_second_max(w)
	check("thermal pulse F(2 t2) = 0.46 +- 0.03", absf(BlastPhysics.thermal_fraction(w, 2.0 * t2) - 0.46) <= 0.03, "%.3f" % BlastPhysics.thermal_fraction(w, 2.0 * t2))
	check("thermal pulse F(5 t2) = 0.73 +- 0.03", absf(BlastPhysics.thermal_fraction(w, 5.0 * t2) - 0.73) <= 0.03, "%.3f" % BlastPhysics.thermal_fraction(w, 5.0 * t2))
	var pmin := BlastPhysics.thermal_power(w, BlastPhysics.t_min(w))
	var pmax := BlastPhysics.thermal_power(w, t2)
	var p1 := BlastPhysics.thermal_power(w, BlastPhysics.t_min(w) / 6.0)
	check("double thermal pulse: first spike > dip at t_min < second maximum", p1 > pmin * 3.0 and pmax > pmin * 5.0 and pmin < 0.12, "p1=%.3f dip=%.3f p2=%.3f" % [p1, pmin, pmax])
	near("fireball temperature at t2 ~8000 K", BlastPhysics.fireball_temperature(w, t2), 8000.0, 0.05)
	near("fireball temperature at 5 t2 ~3800-4000 K", BlastPhysics.fireball_temperature(w, 5.0 * t2), 3900.0, 0.15)


func _cloud() -> void:
	# research A5.1: G&D mid-latitude (dry) and Miller (humid) tops
	near("cloud top 10 kt (dry, G&D 5.8 km)", BlastPhysics.cloud_top(10.0), 5800.0, 0.2)
	near("cloud top 100 kt (dry, G&D 11.8 km)", BlastPhysics.cloud_top(100.0), 11800.0, 0.2)
	near("cloud top 1 Mt (humid, Miller 24.3 km)", BlastPhysics.cloud_top(1000.0, true), 24300.0, 0.05)
	near("cloud top 1 Mt (dry, G&D 19.8 km)", BlastPhysics.cloud_top(1000.0), 19800.0, 0.2)
	near("cap radius 1 Mt (Miller 14.0 km)", BlastPhysics.cloud_cap_radius(1000.0), 14000.0, 0.05)
	near("cloud rise 1 Mt at 66 s (G&D z/H 0.465)", BlastPhysics.cloud_rise_fraction(66.0, 1000.0), 0.465, 0.2)
	near("crater radius 100 kt (73 m)", BlastPhysics.crater_radius_nuclear(100.0), 72.9, 0.03)


func _blast() -> void:
	near("R(1 psi) opt 1 Mt (21.7 km)", BlastPhysics.radius_for_pressure(1000.0, 1.0), 21700.0, 0.05)
	near("R(5 psi) opt 1 kt (0.70 km)", BlastPhysics.radius_for_pressure(1.0, 5.0), 696.0, 0.10)
	near("R(20 psi) opt 1 kt (0.28 km)", BlastPhysics.radius_for_pressure(1.0, 20.0), 280.0, 0.10)
	near("p contact 1 kt @ 1191 m = 1 psi", BlastPhysics.overpressure(1.0, 1191.0, true), 1.0, 0.05)
	near("KB HE R(1 psi) 1 t (181 m)", BlastPhysics.radius_for_pressure(0.001, 1.0, true, true), 181.0, 0.05)
	# DNA arrival times (research A3.6, free air W): +-5 %
	near("arrival 1 kt @ 1 km", BlastPhysics.arrival_time(1.0, 1000.0), 2.39, 0.05)
	near("arrival 15 kt @ 2 km", BlastPhysics.arrival_time(15.0, 2000.0), 4.57, 0.05)
	near("arrival 1 Mt @ 10 km", BlastPhysics.arrival_time(1000.0, 10000.0), 23.9, 0.05)
	near("arrival 15 Mt @ 20 km", BlastPhysics.arrival_time(15000.0, 20000.0), 45.7, 0.05)
	near("arrival 50 Mt @ 50 km", BlastPhysics.arrival_time(50000.0, 50000.0), 126.2, 0.05)
	near("arrival 1 Mt @ 100 km", BlastPhysics.arrival_time(1000.0, 100000.0), 287.6, 0.05)
	# Glasstone surface checks (2W): 20 kt @ 1 mi 3.1 s, 1 Mt @ 2 mi 4.5 s
	near("Glasstone 20 kt @ 1 mi (surface)", BlastPhysics.arrival_time(20.0, 1609.0, true), 3.1, 0.05)
	near("Glasstone 1 Mt @ 2 mi (surface)", BlastPhysics.arrival_time(1000.0, 3219.0, true), 4.5, 0.05)
	near("shock radius 1 kt free air @ 1 s (506 m)", BlastPhysics.shock_radius(1.0, 1.0), 506.0, 0.02)
	near("peak wind 5 psi (163 mph = 73 m/s)", BlastPhysics.peak_wind(5.0), 72.8, 0.05)
	near("peak wind 20 psi (502 mph = 224 m/s)", BlastPhysics.peak_wind(20.0), 224.4, 0.12)
	# the profile's arrival table agrees with the closed form (+-5 %)
	var b: Dictionary = Game.bomb(8)
	var prof := ExplosionProfile.new(b)
	var tbl := prof.build_arrival_table()
	var r := 10.0
	var k := 0
	while r < 20000.0:
		r *= 1.06
		k += 1
	near("arrival table vs DNA formula (bomb 9 @ ~20 km)", tbl[k], BlastPhysics.arrival_time(prof.w_kt, r, prof.surface, prof.conventional), 0.05)


func _thermal() -> void:
	near("3rd-degree burns 1 Mt clear air (13.5 km)", BlastPhysics.burn_radius(1000.0, 3), 13500.0, 0.07)
	near("3rd-degree burns 20 kt clear air (2.45 km)", BlastPhysics.burn_radius(20.0, 3), 2450.0, 0.07)
	var e := BlastPhysics.flash_illuminance(1000.0, BlastPhysics.t_second_max(1000.0), 10000.0, 0.5)
	check("flash 1 Mt at 10 km ~280-350x sun", e > 230.0 and e < 400.0, "%.0f x" % e)
	var e2 := BlastPhysics.flash_illuminance(1000.0, BlastPhysics.t_second_max(1000.0), 50000.0, 0.0)
	check("flash 1 Mt at 50 km 6-9x sun (clear)", e2 > 4.5 and e2 < 11.0, "%.1f x" % e2)


func _bombs() -> void:
	var bombs: Array = Game.bombs
	check("20 bombs loaded", bombs.size() == 20, "n=%d" % bombs.size())
	var prev := -1.0
	var mono := true
	for b in bombs:
		var w := float(b.get("yield_kt", 0.0))
		if w <= prev:
			mono = false
		prev = w
	check("strictly ascending yields", mono)
	var ages := [0.0005, 0.002, 0.02, 0.1, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 40.0, 90.0, 180.0, 360.0, 900.0]
	for b in bombs:
		var prof := ExplosionProfile.new(b)
		var finite := true
		for t in ages:
			for st in [prof.fireball_state(t), prof.head_state(t), prof.stem_state(t), prof.skirt_state(t, 1000.0)]:
				for v in (st as Dictionary).values():
					if (v is float or v is int) and not BlastPhysics.is_finite_num(float(v)):
						finite = false
			if not BlastPhysics.is_finite_num(prof.light_power(t)):
				finite = false
		check("no NaN/inf in profile: %s" % b["id"], finite)
		var name := String(b["id"])
		if prof.nuclear and not prof.is_column_kind():
			# fireball at t_max matches the (art-scaled) formula radius
			var fs := prof.fireball_state(prof.t_fb_max * 1.2)
			near("fireball radius %s vs formula" % name, float(fs["radius"]), prof.r_fb_max, 0.15)
			# cloud reaches its stabilisation height (+-20 %)
			var hs := prof.head_state(prof.t_stab)
			var top := float(hs["center_y"]) + float(hs["half"])
			near("cloud top %s at t_stab" % name, top, prof.cloud_top, 0.2)
		# recommended distance: the bunker glass survives comfortably (< 2 psi with the real air-blast
		# coupling) and an observer behind the window would not get 2nd-degree burns
		var d_rec := float(b["rec_km"]) * 1000.0
		var p_rec := BlastPhysics.overpressure(prof.blast_yield(), d_rec, prof.surface, prof.conventional)
		check("recommended distance keeps the bunker < 2 psi: %s" % name, p_rec < 2.0, "p=%.3f psi" % p_rec)
		if prof.nuclear:
			var slant := sqrt(d_rec * d_rec + maxf(prof.hob, 0.0) * maxf(prof.hob, 0.0))
			check("recommended distance is beyond the 2nd-degree burn radius: %s" % name, slant > BlastPhysics.burn_radius(prof.w_kt, 2), "d=%.0f m r2=%.0f m" % [slant, BlastPhysics.burn_radius(prof.w_kt, 2)])


func _leaks() -> void:
	# 20 consecutive explosions: node count and static memory must not grow
	var root3d := Node3D.new()
	add_child(root3d)
	await get_tree().process_frame
	var nodes0 := 0
	var mem0 := 0.0
	for i in 20:
		var b: Dictionary = Game.bomb(i)
		var ex := Explosion.new()
		root3d.add_child(ex)
		ex.setup(b, Vector3(0, -22, -5000.0 - i * 1000.0), null, null, null)
		for t in [0.01, 1.0, 10.0, 60.0]:
			ex.set_age(t)
		ex.cleanup_globals()
		ex.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
		if i == 1:
			nodes0 = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			mem0 = Performance.get_monitor(Performance.MEMORY_STATIC)
	var nodes1 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var mem1 := Performance.get_monitor(Performance.MEMORY_STATIC)
	check("no node leak over 20 launches", nodes1 <= nodes0, "nodes %d -> %d" % [nodes0, nodes1])
	check("no memory growth over 20 launches (<8 MB)", mem1 - mem0 < 8.0 * 1024.0 * 1024.0, "static %.1f MB -> %.1f MB" % [mem0 / 1048576.0, mem1 / 1048576.0])
	root3d.queue_free()
