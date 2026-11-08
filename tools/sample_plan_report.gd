extends Node
## Prints the BlastSamples plan (level, EQ, rumble balance, echo, rattle, megaton bed) of every bomb
## at its recommended distance and over a distance / time-of-day / humidity sweep, and checks the
## basic invariants (monotonic level with distance, reference = recording, no clipping headroom
## violations). Run: Godot_console --headless --path . res://tools/sample_plan_report.tscn
## Prints READY when every check passed, FAIL otherwise.

const BlastSamples = preload("res://scripts/audio/blast_samples.gd")

var _fails := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("CHECK FAIL: ", what)


func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/bombs.json"))
	var bombs: Array = data["bombs"]
	print("REF  n  id             km   spl  eff  lufs  front  tail  shadow  eq(32..10k)                         echo rattle ext  played")
	for b: Dictionary in bombs:
		var prof: Dictionary = b.get("profile", {})
		var hum := float(prof.get("site_humidity", 0.35))
		var tod := String(prof.get("tod_hist", "noon"))
		var rec := float(b["rec_km"]) * 1000.0
		_check(BlastSamples.has_sample(String(b["id"])), "recording present for %s" % b["id"])
		var pl := BlastSamples.plan(b, rec, hum, tod)
		_check(not pl.is_empty(), "plan for %s" % b["id"])
		if pl.is_empty():
			continue
		var eq: Array = pl["eq_db"]
		var flat := true
		for g: float in eq:
			flat = flat and absf(g) < 0.01
		_check(flat, "%s: reference event has a flat EQ (%s)" % [b["id"], str(eq)])
		_check(absf(float(pl["tail_rel_db"])) < 0.01, "%s: reference rumble balance 0" % b["id"])
		_check(float(pl["cap_loss_db"]) < 1.0, "%s: reference level reachable without clipping (%.2f dB short)" % [b["id"], float(pl["cap_loss_db"])])
		_line("REF", b, pl)
		# distance sweep at the historical time of day: the level must fall with distance
		var last := 1.0e9
		for km: float in [0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0, 200.0]:
			var q := BlastSamples.plan(b, km * 1000.0, hum, tod)
			# loudness as played (front gain + recording loudness + EQ) never grows with distance
			var lv := float(q["play_lufs"])
			_check(lv <= last + 0.05, "%s: loudness falls with distance (%.1f km: %.1f > %.1f)" % [b["id"], km, lv, last])
			last = lv
			if km in [0.5, 5.0, 20.0, 100.0, 200.0]:
				_line("%5.1f" % km, b, q)
			# beyond the recording's distance at its time of day the spectrum only gets duller with
			# frequency above 320 Hz (absorption grows with frequency)
			if km * 1000.0 > rec * 1.05:
				var eqk: Array = q["eq_db"]
				_check(float(eqk[3]) <= float(eqk[2]) + 0.01 and float(eqk[4]) <= float(eqk[3]) + 0.01
						and float(eqk[5]) <= float(eqk[4]) + 0.01, "%s: duller with frequency beyond the reference at %.1f km (%s)" % [b["id"], km, str(eqk)])
		# time of day at the recommended distance; an inversion echo is never louder than the report
		for t: String in ["dawn", "noon", "dusk", "night"]:
			for k: float in [1.0, 2.0, 4.0]:
				var qt := BlastSamples.plan(b, rec * k, hum, t)
				var ec: Dictionary = qt["echo"]
				if not ec.is_empty():
					var e_m := float(BlastSamples.entry(String(b["id"]))["m_front"]) + float(ec["db"])
					_check(e_m <= float(qt["play_lufs"]) + 0.01, "%s %s x%.0f: echo (%.1f LUFS) not louder than the report (%.1f)" % [b["id"], t, k, e_m, float(qt["play_lufs"])])
			if t != tod:
				_line(t.substr(0, 4).to_upper(), b, BlastSamples.plan(b, rec, hum, t))
		# humidity: drier air absorbs more at high frequencies far away
		var dry := BlastSamples.plan(b, rec * 2.0, 0.1, tod)
		var wet := BlastSamples.plan(b, rec * 2.0, 0.9, tod)
		_check(float((dry["eq_db"] as Array)[5]) <= float((wet["eq_db"] as Array)[5]) + 0.01 or rec * 2.0 < 3000.0,
				"%s: 10 kHz absorbed more in dry air at 2x rec" % b["id"])
	# --json PATH: the plan grid (recommended distance x0.25..x4 and four times of day) for
	# offline mixing / metrics (tools/audio_metrics.py --plans)
	var args := OS.get_cmdline_user_args()
	var ji := args.find("--json")
	if ji >= 0 and ji + 1 < args.size():
		var grid: Array = []
		for b: Dictionary in bombs:
			var prof: Dictionary = b.get("profile", {})
			var rec := float(b["rec_km"]) * 1000.0
			for k: float in [0.25, 0.5, 1.0, 2.0, 4.0]:
				for t: String in ["dawn", "noon", "dusk", "night"]:
					var q := BlastSamples.plan(b, rec * k, float(prof.get("site_humidity", 0.35)), t)
					q["k"] = k
					q["ref_tod"] = String(prof.get("tod_hist", "noon"))
					grid.append(q)
		var f := FileAccess.open(args[ji + 1], FileAccess.WRITE)
		f.store_string(JSON.stringify(grid, " "))
		f.close()
		print("WROTE ", args[ji + 1], " ", grid.size(), " plans")
	print("READY" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit()


func _line(tag: String, b: Dictionary, pl: Dictionary) -> void:
	var eq: Array = pl["eq_db"]
	var eqs := ""
	for g: float in eq:
		eqs += "%6.1f" % g
	var ext: Dictionary = pl["ext"]
	print("%-4s %2d %-13s %6.1f %5.1f %5.1f %5.1f %6.1f %5.1f  %4.2f  %s  %s %s %s  %.1f" % [tag, int(b["num"]), b["id"],
		float(pl["distance_m"]) / 1000.0, float(pl["spl_db"]), float(pl["spl_eff_db"]), float(pl["lufs"]),
		float(pl["front_db"]), float(pl["tail_rel_db"]), float(pl["shadow"]), eqs,
		"%.1fs/%.1fdB" % [float(pl["echo"]["delay_s"]), float(pl["echo"]["db"])] if not (pl["echo"] as Dictionary).is_empty() else "-",
		"%.1f" % float(pl["rattle"]["db"]) if not (pl["rattle"] as Dictionary).is_empty() else "-",
		"%.0fs@%.0f/%.1fdB" % [float(ext["dur_s"]), float(ext["t0_s"]), float(ext["db"])] if not ext.is_empty() else "-",
		float(pl["play_lufs"])])
