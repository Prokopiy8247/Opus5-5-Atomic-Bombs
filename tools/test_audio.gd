extends SceneTree
## Audio module test (scripts/audio/*): generation timing, per-sound peak/RMS, WAV export,
## spectrogram PNGs, bus layout, scheduled soundtrack timelines, pause / backward scrubbing,
## UI / rocket / whistle / ambience smoke test. Prints READY when everything passed.
##
## Modes (user args after --):
##   (default)            headless logic test
##   --movie              scripted ~100 s soundtrack driven by real frames (run windowed with
##                        --write-movie <dir>/mix.png --fixed-fps 30 to render the real mix)
##   --analyze <wav>      peak / RMS / envelope + spectrogram PNG of a rendered WAV
##   --soak               repeated create/setup/free cycles and 20 launches with real playback:
##                        buses/effects must not multiply, nodes/objects must not grow (run it
##                        windowed too: headless uses the dummy audio driver)
##   --out <dir>          output folder (default user://audio_test)
##   --nospec             skip spectrogram PNGs

const SoundManager = preload("res://scripts/audio/sound_manager.gd")
const AudioSynth = preload("res://scripts/audio/audio_synth.gd")
const SPEC_NAMES := ["crack", "thump", "infra", "rumble", "roar", "wind", "thunder_a", "tremor",
		"rocket_ignite", "rocket_loop", "whistle", "vent", "hum", "debris", "glass_shatter", "ui_launch"]

var out_dir := ""
var fails := 0
var sm: SoundManager


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = OS.get_user_data_dir().path_join("audio_test")
	var mode := "test"
	var wav_path := ""
	var spec := true
	var i := 0
	while i < args.size():
		match args[i]:
			"--out":
				out_dir = args[i + 1]
				i += 1
			"--movie":
				mode = "movie"
			"--analyze":
				mode = "analyze"
				wav_path = args[i + 1]
				i += 1
			"--nospec":
				spec = false
			"--soak":
				mode = "soak"
		i += 1
	DirAccess.make_dir_recursive_absolute(out_dir)
	if mode == "movie":
		await _movie()
		return
	if mode == "soak":
		await _soak()
		print("RESULT fails=%d" % fails)
		print("READY" if fails == 0 else "FAIL")
		quit()
		return
	if mode == "analyze":
		_analyze(wav_path)
		print("READY" if fails == 0 else "FAIL")
		quit()
		return
	await _test(spec)
	print("RESULT fails=%d" % fails)
	print("READY" if fails == 0 else "FAIL")
	quit()


func _check(ok: bool, what: String) -> void:
	if ok:
		print("CHECK ok   ", what)
	else:
		fails += 1
		print("CHECK FAIL ", what)


# =============================================================================== main test

func _test(spec: bool) -> void:
	# 1) every sound, single-threaded, with its own timing and level stats
	var total := 0.0
	var all := {}
	for nm: String in AudioSynth.NAMES:
		var t0 := Time.get_ticks_usec()
		var s: AudioStreamWAV = AudioSynth.make(nm)
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		total += ms
		if s == null:
			_check(false, "sound %s generated" % nm)
			continue
		var st := _stats(s)
		print("SOUND %-14s %5d Hz %s %6.2f s loop=%-5s gen %6.1f ms  peak %.3f  rms %.4f  bytes %d" % [
				nm, s.mix_rate, "st" if s.stereo else "mo", s.get_length(),
				str(s.loop_mode != AudioStreamWAV.LOOP_DISABLED), ms, st.x, st.y, s.data.size()])
		_check(st.x > 0.0 and st.y > 0.0 and st.x <= 1.0, "%s not silent, peak<=1 (peak %.3f rms %.4f)" % [nm, st.x, st.y])
		if s.loop_mode != AudioStreamWAV.LOOP_DISABLED:
			var seam := _loop_seam(s)
			_check(seam < 0.25, "%s loop seam jump %.3f" % [nm, seam])
		var err := s.save_to_wav(out_dir.path_join(nm + ".wav"))
		_check(err == OK, "save %s.wav" % nm)
		all[nm] = s
	print("GEN single-thread total %.1f ms for %d sounds" % [total, all.size()])
	_check(total < 2500.0, "single-thread generation < 2500 ms")
	# determinism
	var a: AudioStreamWAV = AudioSynth.make("thunder_a")
	_check(a.data == (all["thunder_a"] as AudioStreamWAV).data, "deterministic synthesis (thunder_a twice)")
	if spec:
		for nm: String in SPEC_NAMES:
			_spectrogram_stream(all[nm], out_dir.path_join("spec_%s.png" % nm))

	# 2) the manager
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	sm = SoundManager.new()
	sm.name = "SoundManager"
	root.add_child(sm)
	sm.setup()
	print("SETUP gen_ms=%.1f" % sm.gen_ms)
	_check(sm.gen_ms < 2500.0, "setup() generation < 2500 ms (%.1f)" % sm.gen_ms)
	_check(sm.sounds.size() == AudioSynth.NAMES.size(), "all sounds present after threaded setup")
	_check((sm.sounds["rumble"] as AudioStreamWAV).data == (all["rumble"] as AudioStreamWAV).data,
			"threaded result identical to single-thread")
	_print_buses()
	_check(AudioServer.get_bus_index("Blast") > 0 and AudioServer.get_bus_index("World") > 0
			and AudioServer.get_bus_index("Bunker") > 0 and AudioServer.get_bus_index("UI") > 0, "buses exist")
	_check(sm.limiter != null and sm.limiter.ceiling_db <= -0.3 + 1e-4, "master hard limiter <= -0.3 dB")
	sm.log_events = false

	# 3) 15 kt at 20 km, 0..t_shock+45 s
	var d1 := 20000.0
	var p1 := _params(15.0, d1, "NUCLEAR_AIR", 580.0)
	_start(p1)
	await _advance(0.0, float(p1["t_shock"]) + 45.0, 1.0 / 30.0, 1.0)
	_dump_log("15kt@20km")
	_check(_fired("tremor") and _fired("crack") and _fired("thump") and _fired("rumble"), "15kt@20km core layers fired")
	_check(_fired_at("tremor") < _fired_at("crack"), "tremor arrives before the air blast")
	_check(absf(_fired_at("crack") - float(p1["t_shock"])) < 0.05, "crack at t_shock (%.2f)" % float(p1["t_shock"]))
	_check(not _fired("infra"), "no infrasonic thump for 15 kt")
	_check(_count("thunder") >= 2, "thunder rolls fired")
	_check(sm.lp_blast.cutoff_hz < 1200.0 and sm.lp_blast.cutoff_hz > 600.0, "20 km low-pass %.0f Hz" % sm.lp_blast.cutoff_hz)

	# 4) 50 Mt at 150 km: the first 60 s, then a jump to just before the seismic arrival
	var d2 := 150000.0
	var p2 := _params(50000.0, d2, "NUCLEAR_HIGH_AIR", 4000.0)
	_start(p2)
	await _advance(0.0, 60.0, 1.0 / 30.0, 1.0)
	_check(sm.event_log.size() == 0, "50Mt@150km: nothing audible in the first 60 s")
	await _advance(float(p2["t_seismic"]) - 2.0, float(p2["t_shock"]) + 45.0, 1.0 / 30.0, 1.0)
	_dump_log("50Mt@150km")
	_check(_fired("tremor") and _fired("crack") and _fired("crack2") and _fired("thump") and _fired("infra")
			and _fired("rumble"), "50Mt core layers incl. infrasonic thump and second report")
	_check(_count("thunder") >= 5, "megaton thunder rolls (%d)" % _count("thunder"))
	var seen := {}
	var dup := false
	for e: Array in sm.event_log:
		dup = dup or seen.has(e[1])
		seen[e[1]] = true
	_check(not dup, "every fired layer has its own player (a reused player would cut its tail)")
	_check(is_equal_approx(sm.lp_blast.cutoff_hz, 250.0), "150 km low-pass 250 Hz")
	_check(not sm._mf_on, "no ear ringing at 150 km")

	# 5) a forward jump past everything: one-shots must be skipped, not stacked
	_start(p1)
	await _advance(float(p1["t_shock"]) + 200.0, float(p1["t_shock"]) + 201.0, 1.0 / 30.0, 1.0)
	_check(sm.event_log.size() == 0, "jump far past the events skips them (%d fired)" % sm.event_log.size())

	# 6) close 15 kt at 2.5 km: ringing in the ears, pause, backward scrubbing
	var p3 := _params(15.0, 2500.0, "NUCLEAR_AIR", 580.0)
	_start(p3)
	print(sm.describe())
	var ts3 := float(p3["t_shock"])
	await _advance(0.0, ts3 + 1.0, 1.0 / 30.0, 1.0)
	_check(sm._muffle > 0.3, "ears muffled after a %.1f psi blast (muffle %.2f, cutoff %.0f Hz)" % [
			float(p3["p_psi"]), sm._muffle, sm.lp_ears.cutoff_hz])
	_check(sm._tinnitus.playing, "tinnitus playing")
	_check((sm._p["roar"] as AudioStreamPlayer).playing, "fireball roar audible at 2.5 km")
	_check(AudioServer.is_bus_effect_enabled(sm.bus_ears, 0), "Ears low-pass enabled while muffled")
	# pause (time_scale 0)
	sm.update_age(ts3 + 1.0, 0.0)
	_check((sm._p["rumble"] as AudioStreamPlayer).stream_paused and sm._tinnitus.stream_paused, "paused at time_scale 0")
	var n_before := sm.event_log.size()
	sm.update_age(ts3 + 30.0, 0.0)
	_check(sm.event_log.size() == n_before, "no events while paused")
	sm.update_age(ts3 + 1.0, 1.0)
	_check(not (sm._p["rumble"] as AudioStreamPlayer).stream_paused, "resumed")
	# backward scrub then forward again: nothing retriggers
	await _advance(ts3 + 1.0, ts3 + 6.0, 1.0 / 30.0, 1.0)
	var n_mid := sm.event_log.size()
	sm.update_age(ts3 - 5.0, 1.0)
	await _advance(ts3 - 5.0, ts3 + 6.0, 1.0 / 30.0, 1.0)
	_check(sm.event_log.size() == n_mid, "backward scrub does not retrigger (%d -> %d)" % [n_mid, sm.event_log.size()])
	# slow motion lowers the pitch
	sm.update_age(ts3 + 6.1, 0.25)
	var pl_r := sm._p["rumble"] as AudioStreamPlayer
	_check(pl_r.pitch_scale < float(sm._base_pitch["rumble"]), "slow motion lowers pitch (%.2f)" % pl_r.pitch_scale)
	await _advance(ts3 + 6.1, ts3 + sm._mf_rec + 2.0, 1.0 / 30.0, 1.0)
	_check(sm._muffle == 0.0 and not AudioServer.is_bus_effect_enabled(sm.bus_ears, 0), "ears recovered")
	_dump_log("15kt@2.5km")

	# 7) all burst kinds schedule without errors
	var kinds := ["CONVENTIONAL_SURFACE", "CONVENTIONAL_BURIED", "THERMOBARIC", "NUCLEAR_AIR",
			"NUCLEAR_LOW_AIR", "NUCLEAR_TOWER", "NUCLEAR_SURFACE", "NUCLEAR_BURIED", "NUCLEAR_UNDERWATER",
			"NUCLEAR_HIGH_AIR"]
	var yields := [0.0001, 0.0066, 0.044, 0.3, 15.0, 21.0, 1200.0, 104.0, 23.0, 24200.0]
	for k in kinds.size():
		for dk: float in [500.0, 5000.0, 60000.0]:
			var pk := _params(float(yields[k]), dk, kinds[k], 0.0)
			_start(pk)
			await _advance(0.0, float(pk["t_shock"]) + 3.0, 0.25, 1.0)
			var ok := sm.event_log.size() >= 3
			for e: Array in sm.event_log:
				if is_nan(float(e[3])) or is_inf(float(e[3])):
					ok = false
			_check(ok, "%s %s kt @ %.1f km: %d events, %.2f psi" % [kinds[k], str(yields[k]), dk / 1000.0,
					sm.event_log.size(), float(pk["p_psi"])])
	# the bunker-destroying case: glass shatter, power loss
	var p4 := _params(1200.0, 2000.0, "NUCLEAR_SURFACE", 0.0)
	_start(p4)
	await _advance(0.0, float(p4["t_shock"]) + 5.0, 1.0 / 30.0, 1.0)
	_check(_fired("glass") and String(sm.event_log.filter(func(e: Array) -> bool: return e[1] == "glass")[0][2]) == "glass_shatter"
			and sm._vent_pitch < 1.0, "%.0f psi: glass shatter + fan spin-down" % float(p4["p_psi"]))
	# 12 psi: the window cracks but holds
	var p5 := _params(1200.0, 3000.0, "NUCLEAR_SURFACE", 0.0)
	_start(p5)
	await _advance(0.0, float(p5["t_shock"]) + 2.0, 1.0 / 30.0, 1.0)
	_check(_fired("glass") and String(sm.event_log.filter(func(e: Array) -> bool: return e[1] == "glass")[0][2]) == "glass_crack",
			"%.0f psi: glass crack" % float(p5["p_psi"]))
	# missing / NaN / infinite parameters fall back to defaults: no NaN volume, no error
	var bad_cases: Array[Dictionary] = [{},
			{"yield_kt": NAN, "distance_m": INF, "t_shock": NAN, "t_seismic": -INF, "p_psi": NAN, "kind": ""},
			{"yield_kt": 0.0, "distance_m": 0.0, "p_psi": INF, "hob_m": NAN, "kind": "NUCLEAR_SURFACE"}]
	for bad: Dictionary in bad_cases:
		_start(bad)
		await _advance(0.0, sm._t_shock + 3.0, 0.25, 1.0)
		var ok_bad := sm.event_log.size() >= 2 and is_finite(sm._lvl) and is_finite(sm._psi) \
				and is_finite(sm._t_shock) and is_finite(sm.lp_blast.cutoff_hz)
		for e: Array in sm.event_log:
			ok_bad = ok_bad and is_finite(float(e[3])) and is_finite(float(e[4]))
		_check(ok_bad, "robust params %s: %d events, lvl %.1f dB" % [str(bad), sm.event_log.size(), sm._lvl])
	sm.stop_all()

	# 8) UI, rocket, whistle, ambience
	sm.set_ambience(true)
	for kind: String in ["click", "select", "launch", "warn", "error", "unknown"]:
		sm.play_ui(kind)
		await process_frame
	sm.rocket_start(Vector3(-350.0, -15.0, -500.0))
	var tt := 0.0
	while tt < 4.0:
		tt += 1.0 / 30.0
		sm.rocket_update(Vector3(-350.0, -15.0 + 15.0 * tt * tt, -500.0 - 5.0 * tt * tt))
		sm._process(1.0 / 30.0)
		await process_frame
	_check(sm._rocket_loop.playing and sm._rk_state == 2, "rocket loop running after the sound delay")
	sm.rocket_stop()
	sm.whistle_start()
	for f in 60:
		sm._process(1.0 / 30.0)
		await process_frame
	_check(sm._whistle.playing and sm._whistle.pitch_scale < 1.3, "whistle playing, pitch sliding (%.2f)" % sm._whistle.pitch_scale)
	sm.whistle_stop()
	for f in 30:
		sm._process(1.0 / 30.0)
		await process_frame
	_check(not sm._whistle.playing and not sm._rocket_loop.playing, "rocket and whistle stopped")
	# a bomb falling 30 km away: the whistle is only a faint cue (1/r beyond 1.5 km, floored)
	sm.rocket_update(Vector3(0.0, 300.0, -30000.0))
	sm.whistle_start()
	for f in 90:
		sm._process(1.0 / 30.0)
		await process_frame
	_check(sm._whistle.playing and sm._whistle.volume_db < SoundManager.WHISTLE_DB - 20.0,
			"whistle 30 km away attenuated (%.1f dB)" % sm._whistle.volume_db)
	sm.stop_all()
	_check(not sm._whistle.playing, "stop_all stops the whistle")
	_check(sm._vent.playing and sm._hum.playing, "ambience playing")
	sm.set_ambience(false)
	for f in 60:
		sm._process(1.0 / 30.0)
		await process_frame
	_check(not sm._vent.playing, "ambience faded out")
	sm.stop_all()
	# 9) per-event blast synthesis: prepared at launch on a worker thread, used when the blast arrives
	var ps := _params(15.0, 20000.0, "NUCLEAR_AIR", 580.0)
	var bp := {"yield_kt": 15.0, "kind": "NUCLEAR_AIR", "nuclear": true, "distance_m": ps["distance_m"],
			"hob_m": 580.0, "p_psi": ps["p_psi"], "t_plus": 0.5, "humidity": 0.35, "seed": 77,
			"tod": "noon", "key": "test_15kt"}
	var t_syn := Time.get_ticks_msec()
	sm.prepare_blast(bp)
	while sm._synth_ready("test_15kt").is_empty() and Time.get_ticks_msec() - t_syn < 90000:
		await process_frame
	var syn := sm._synth_ready("test_15kt")
	_check(not syn.is_empty() and syn.get("front") != null and syn.get("tail") != null,
			"blast event synthesized on a worker thread (%d ms)" % (Time.get_ticks_msec() - t_syn))
	ps["synth_key"] = "test_15kt"
	_start(ps)
	var cut0 := sm.lp_blast.cutoff_hz
	await _advance(0.0, float(ps["t_shock"]) + 2.0, 0.25, 1.0)
	_check((sm._p["blast_front"] as AudioStreamPlayer).bus == "BlastSyn" and is_equal_approx(sm.lp_blast.cutoff_hz, cut0),
			"synth layers on their own bus, Blast-bus distance low-pass untouched (%.0f Hz)" % sm.lp_blast.cutoff_hz)
	_check(sm._mode == "synth" and _fired("blast_front") and _fired("blast_tail") and not _fired("crack")
			and not _fired("rumble"), "synthesized front + tail replace the generic layers (mode %s)" % sm._mode)
	var pf := sm._p["blast_front"] as AudioStreamPlayer
	_check(pf.stream == syn["front"] and is_equal_approx(pf.volume_db, float(syn["front_db"])),
			"front plays the synthesized stream at its SPL-mapped level (%.1f dB)" % pf.volume_db)
	_check(_fired_at("blast_front") < _fired_at("blast_tail") and _fired("tremor"), "front pre-roll before the tail, tremor kept")
	# a different key (not prepared) falls back to the generic layers
	ps["synth_key"] = "other"
	_start(ps)
	await _advance(0.0, float(ps["t_shock"]) + 2.0, 0.25, 1.0)
	_check(sm._mode == "generic" and _fired("crack") and not _fired("blast_front"), "unprepared event falls back to generic layers")
	# a relaunch while a synthesis is running: only the newest request may store its result
	var bp2 := bp.duplicate()
	bp2["key"] = "test_a"
	bp2["distance_m"] = 90000.0
	var bp3 := bp.duplicate()
	bp3["key"] = "test_b"
	bp3["distance_m"] = 3000.0
	sm.prepare_blast(bp2)
	sm.prepare_blast(bp3)
	var t_r := Time.get_ticks_msec()
	while not sm._syn_pending.is_empty() and Time.get_ticks_msec() - t_r < 90000:
		sm._process(1.0 / 30.0)
		await process_frame
	_check(not sm._synth_ready("test_b").is_empty() and sm._syn_res_key == "test_b",
			"relaunch: the newest synthesis wins even if an older task finishes later")
	sm.stop_all()
	# no node growth over repeated launches
	var nodes0 := sm.get_child_count()
	for r in 20:
		_start(p1)
		sm.update_age(float(p1["t_shock"]) + 1.0, 1.0)
		sm.stop_all()
	_check(sm.get_child_count() == nodes0, "no node growth over 20 launches")


# =============================================================================== helpers

func _params(w: float, d: float, kind: String, hob: float) -> Dictionary:
	var surface := kind.contains("SURFACE") or kind.contains("TOWER") or kind.contains("BURIED") or kind.contains("UNDERWATER")
	var slant := sqrt(d * d + hob * hob)
	var t_shock := BlastPhysics.arrival_time(w, slant, surface)
	return {"yield_kt": w, "distance_m": slant, "t_seismic": BlastPhysics.seismic_delay(d),
			"t_shock": t_shock, "p_psi": BlastPhysics.overpressure(w, slant, surface),
			"nuclear": w >= 0.01, "kind": kind, "megaton": w >= 1000.0, "hob_m": hob}


func _start(p: Dictionary) -> void:
	sm.stop_all()
	sm.on_detonation(p)


func _advance(t_from: float, t_to: float, dt: float, ts: float) -> void:
	var t := t_from
	var steps := 0
	var max_us := 0
	while t <= t_to:
		var t0 := Time.get_ticks_usec()
		sm.update_age(t, ts)
		max_us = maxi(max_us, Time.get_ticks_usec() - t0)
		steps += 1
		if steps % 8 == 0:
			await process_frame
		t += dt
	if max_us > 1500:
		print("WARN slow update_age: %d us" % max_us)


func _fired(id: String) -> bool:
	for e: Array in sm.event_log:
		if String(e[1]) == id:
			return true
	return false


func _fired_at(id: String) -> float:
	for e: Array in sm.event_log:
		if String(e[1]) == id:
			return float(e[0]) - float(e[5])
	return -1.0


func _count(prefix: String) -> int:
	var c := 0
	for e: Array in sm.event_log:
		if String(e[1]).begins_with(prefix):
			c += 1
	return c


func _dump_log(label: String) -> void:
	print(sm.describe())
	print("FIRED %s: %d events" % [label, sm.event_log.size()])
	for e: Array in sm.event_log:
		print("  t=%8.2f  %-9s %-13s %6.1f dB  pitch %.2f  late %.3f" % [e[0], e[1], e[2], e[3], e[4], e[5]])


func _print_buses() -> void:
	for b in AudioServer.bus_count:
		var fx := []
		for e in AudioServer.get_bus_effect_count(b):
			fx.append(AudioServer.get_bus_effect(b, e).get_class())
		print("BUS %d %-7s send=%-7s fx=%s" % [b, AudioServer.get_bus_name(b), AudioServer.get_bus_send(b), str(fx)])


## (peak, rms) of a 16-bit AudioStreamWAV, normalised to 1.0 = full scale.
func _stats(s: AudioStreamWAV) -> Vector2:
	var d := s.data
	var pk := 0.0
	var acc := 0.0
	var n := d.size() / 2
	for i in n:
		var v := float(d.decode_s16(i * 2)) / 32767.0
		pk = maxf(pk, absf(v))
		acc += v * v
	return Vector2(pk, sqrt(acc / maxf(float(n), 1.0)))


## Sample jump across the loop point (last -> first) in excess of the largest adjacent-sample
## step found in the last 2000 frames, relative to the stream peak (0 = seamless).
func _loop_seam(s: AudioStreamWAV) -> float:
	var d := s.data
	var ch := 2 if s.stereo else 1
	var frames := d.size() / (2 * ch)
	var st := _stats(s)
	var worst := 0.0
	for c in ch:
		var max_step := 0.0
		var prev := float(d.decode_s16(((frames - 2000) * ch + c) * 2)) / 32767.0
		for i in range(frames - 1999, frames):
			var v := float(d.decode_s16((i * ch + c) * 2)) / 32767.0
			max_step = maxf(max_step, absf(v - prev))
			prev = v
		var first := float(d.decode_s16(c * 2)) / 32767.0
		worst = maxf(worst, (absf(first - prev) - max_step) / maxf(st.x, 1e-6))
	return maxf(worst, 0.0)


func _mono_samples(s: AudioStreamWAV) -> PackedFloat32Array:
	var d := s.data
	var ch := 2 if s.stereo else 1
	var frames := d.size() / (2 * ch)
	var out := PackedFloat32Array()
	out.resize(frames)
	for i in frames:
		var v := 0.0
		for c in ch:
			v += float(d.decode_s16((i * ch + c) * 2))
		out[i] = v / (32767.0 * ch)
	return out


func _spectrogram_stream(s: AudioStreamWAV, path: String) -> void:
	_spectrogram(_mono_samples(s), float(s.mix_rate), path)


## Waveform strip (top) + log-frequency spectrogram. Grid: 50/500/5000 Hz bright, 20/100/200/
## 1000/2000/10000 Hz dim; vertical lines every second (every 10 s for long signals).
func _spectrogram(x: PackedFloat32Array, rate: float, path: String) -> void:
	var cols := 360
	var rows := 200
	var wave_h := 80
	var nfft := 1024
	var img := Image.create(cols, rows + wave_h, false, Image.FORMAT_RGB8)
	img.fill(Color(0.03, 0.03, 0.05))
	var n := x.size()
	var per := maxf(1.0, float(n) / cols)
	for c in cols:
		var a := int(c * per)
		var b := mini(n, int((c + 1) * per) + 1)
		var mn := 0.0
		var mx := 0.0
		for i in range(a, b):
			mn = minf(mn, x[i])
			mx = maxf(mx, x[i])
		var y0 := int((1.0 - (mx * 0.5 + 0.5)) * (wave_h - 1))
		var y1 := int((1.0 - (mn * 0.5 + 0.5)) * (wave_h - 1))
		for y in range(clampi(y0, 0, wave_h - 1), clampi(y1, 0, wave_h - 1) + 1):
			img.set_pixel(c, y, Color(0.5, 0.85, 1.0))
	var win := PackedFloat32Array()
	win.resize(nfft)
	for i in nfft:
		win[i] = 0.5 - 0.5 * cos(TAU * i / (nfft - 1))
	var fmin := 10.0
	var fmax := rate * 0.5
	var row_bin := PackedInt32Array()
	row_bin.resize(rows)
	for r in rows:
		var f := fmin * pow(fmax / fmin, float(r) / float(rows - 1))
		row_bin[r] = clampi(int(round(f / rate * nfft)), 1, nfft / 2 - 1)
	var re := PackedFloat32Array()
	var im := PackedFloat32Array()
	re.resize(nfft)
	im.resize(nfft)
	var hop := maxf(1.0, float(n - nfft) / cols)
	for c in cols:
		var st := int(c * hop)
		for i in nfft:
			var j := st + i
			re[i] = (x[j] if j < n else 0.0) * win[i]
			im[i] = 0.0
		_fft(re, im)
		for r in rows:
			var k := row_bin[r]
			var mag := sqrt(re[k] * re[k] + im[k] * im[k]) / (nfft * 0.25)
			var db := 20.0 * log(maxf(mag, 1e-9)) / log(10.0)
			var v := clampf((db + 72.0) / 66.0, 0.0, 1.0)
			img.set_pixel(c, wave_h + rows - 1 - r, Color(clampf(v * 3.0, 0, 1), clampf(v * 3.0 - 1.0, 0, 1), clampf(v * 3.0 - 2.0, 0, 1) * 0.9 + 0.08))
	for fg: float in [20.0, 50.0, 100.0, 200.0, 500.0, 1000.0, 2000.0, 5000.0, 10000.0]:
		if fg >= fmax:
			continue
		var r := int(round(log(fg / fmin) / log(fmax / fmin) * (rows - 1)))
		var bright := fg == 50.0 or fg == 500.0 or fg == 5000.0
		for c in range(0, cols, 2 if bright else 4):
			img.set_pixel(c, wave_h + rows - 1 - r, Color(0.9, 0.9, 0.9) if bright else Color(0.45, 0.45, 0.45))
	var dur := float(n) / rate
	var step := 1.0 if dur <= 12.0 else 10.0
	var t := step
	while t < dur:
		var c := int(t / dur * cols)
		for y in range(0, rows + wave_h, 3):
			img.set_pixel(c, y, Color(0.35, 0.35, 0.4))
		t += step
	var err := img.save_png(path)
	print("SPEC %s err=%d (%.1f s @ %d Hz)" % [path, err, dur, int(rate)])


func _fft(re: PackedFloat32Array, im: PackedFloat32Array) -> void:
	var n := re.size()
	var j := 0
	for i in range(1, n):
		var bit := n >> 1
		while j & bit:
			j ^= bit
			bit >>= 1
		j ^= bit
		if i < j:
			var tr := re[i]
			re[i] = re[j]
			re[j] = tr
			var ti := im[i]
			im[i] = im[j]
			im[j] = ti
	var ln := 2
	while ln <= n:
		var ang := -TAU / ln
		var wr := cos(ang)
		var wi := sin(ang)
		var half := ln >> 1
		var i := 0
		while i < n:
			var cr := 1.0
			var ci := 0.0
			for k in half:
				var a := i + k
				var b := a + half
				var tr := re[b] * cr - im[b] * ci
				var ti := re[b] * ci + im[b] * cr
				re[b] = re[a] - tr
				im[b] = im[a] - ti
				re[a] += tr
				im[a] += ti
				var ncr := cr * wr - ci * wi
				ci = cr * wi + ci * wr
				cr = ncr
			i += ln
		ln <<= 1


# =============================================================================== soak mode

## Leak / growth check: 6 create -> setup -> play -> free cycles of the manager (buses and
## effects must not multiply), then 21 launches on one manager with every layer really playing
## (nodes must stay equal, objects must not grow). Run windowed for the real audio driver.
func _soak() -> void:
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	var real_driver := DisplayServer.get_name() != "headless"
	print("SOAK display=%s audio=%s mix %d Hz" % [DisplayServer.get_name(), AudioServer.get_driver_name(),
			int(AudioServer.get_mix_rate())])
	var near := _params(15.0, 2500.0, "NUCLEAR_AIR", 580.0)
	var sig0: Array = []
	var objs: Array[int] = []
	for cycle in 6:
		var t0 := Time.get_ticks_usec()
		sm = SoundManager.new()
		sm.name = "SoundManager"
		root.add_child(sm)
		sm.setup()
		var setup_ms := float(Time.get_ticks_usec() - t0) / 1000.0
		sm.set_ambience(true)
		sm.play_ui("click")
		sm.rocket_start(Vector3(-350.0, -15.0, -500.0))
		_start(near)
		await _play_real(float(near["t_shock"]) - 0.1, 30)
		sm.stop_all()
		var sig := _bus_signature()
		if cycle == 0:
			sig0 = sig
			print("SOAK buses ", str(sig))
		else:
			_check(sig == sig0, "cycle %d: same buses and effects after setup (%d buses)" % [cycle, AudioServer.bus_count])
		root.remove_child(sm)
		sm.free()
		sm = null
		for f in 30:
			await process_frame
		var fx_left := 0
		for b in AudioServer.bus_count:
			fx_left += AudioServer.get_bus_effect_count(b)
		objs.append(int(Performance.get_monitor(Performance.OBJECT_COUNT)))
		print("SOAK cycle %d: setup %.0f ms, buses %d, effects left after free %d, objects %d, nodes %d, static %.1f MB" % [
				cycle, setup_ms, AudioServer.bus_count, fx_left, objs[cycle],
				int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
				Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
		_check(fx_left == 0, "cycle %d: the freed manager took its effects off the buses" % cycle)
	var grow := objs[objs.size() - 1] - objs[1]
	if real_driver:
		_check(grow <= 4, "objects stable over create/free cycles (%s)" % str(objs))
	else:
		print("INFO headless dummy audio driver: object delta over cycles %d (%s)" % [grow, str(objs)])

	# 21 launches on one manager, every layer audible for a few frames
	sm = SoundManager.new()
	sm.name = "SoundManager"
	root.add_child(sm)
	sm.setup()
	sm.set_ambience(true)
	var cases: Array[Dictionary] = [near, _params(50000.0, 150000.0, "NUCLEAR_HIGH_AIR", 4000.0),
			_params(1200.0, 2000.0, "NUCLEAR_SURFACE", 0.0), _params(0.0054, 1200.0, "CONVENTIONAL_BURIED", 0.0)]
	var o_base := 0
	var n_base := 0
	var det_us := 0
	for r in 21:
		var pc: Dictionary = cases[r % cases.size()]
		sm.stop_all()
		sm.rocket_start(Vector3(-350.0, -15.0, -500.0))
		sm.whistle_start()
		for f in 3:
			sm.rocket_update(Vector3(-350.0, -15.0 + 40.0 * f, -500.0))
			await process_frame
		sm.rocket_stop()
		var t0 := Time.get_ticks_usec()
		sm.on_detonation(pc)
		det_us = maxi(det_us, Time.get_ticks_usec() - t0)
		await _play_real(float(pc["t_shock"]) - 0.05, 12)
		sm.stop_all()
		for f in 10:
			await process_frame
		if r == 0:
			o_base = int(Performance.get_monitor(Performance.OBJECT_COUNT))
			n_base = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for f in 30:
		await process_frame
	var o_end := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var n_end := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	print("SOAK 20 launches: objects %d -> %d, nodes %d -> %d, on_detonation max %d us" % [o_base, o_end, n_base, n_end, det_us])
	_check(n_end == n_base, "no node growth over 20 launches (%d -> %d)" % [n_base, n_end])
	if real_driver:
		_check(o_end - o_base <= 8, "no object growth over 20 launches (%d -> %d)" % [o_base, o_end])
	else:
		print("INFO headless dummy audio driver: object delta over 20 launches %d" % (o_end - o_base))
	_check(det_us < 5000, "on_detonation() < 5 ms (%d us)" % det_us)
	root.remove_child(sm)
	sm.free()
	sm = null
	await process_frame


## Drives the current manager with real frames from `age0` (60 game fps, time scale 1).
func _play_real(age0: float, frames: int) -> void:
	var age := age0
	for f in frames:
		sm.update_age(age, 1.0)
		age += 1.0 / 60.0
		await process_frame


func _bus_signature() -> Array:
	var sig := []
	for b in AudioServer.bus_count:
		var fx := []
		for e in AudioServer.get_bus_effect_count(b):
			fx.append(AudioServer.get_bus_effect(b, e).get_class())
		sig.append("%s>%s%s" % [AudioServer.get_bus_name(b), AudioServer.get_bus_send(b), str(fx)])
	return sig


# =============================================================================== movie mode

## Scripted soundtrack in real frames; with --write-movie the engine renders the real bus mix.
func _movie() -> void:
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	sm = SoundManager.new()
	root.add_child(sm)
	sm.setup()
	sm.log_events = true
	sm.set_ambience(true)
	var fps := 30.0
	var frame := 0
	var pa := _params(15.0, 2500.0, "NUCLEAR_AIR", 580.0)
	var pb := _params(50000.0, 150000.0, "NUCLEAR_HIGH_AIR", 4000.0)
	var pc := _params(0.0054, 1200.0, "CONVENTIONAL_BURIED", 0.0)
	var rk0 := Vector3(-350.0, -15.0, -500.0)
	var age := 0.0
	var phase := ""
	print("MOVIE timeline: 0 ui | 4 rocket | 10 whistle | 16 15kt@2.5km | 47 50Mt@150km (from t_shock-4) | 92 Tallboy@1.2km | 102 end")
	while true:
		var t := frame / fps
		var dt := 1.0 / fps
		if frame == int(1.0 * fps):
			sm.play_ui("click")
		elif frame == int(1.5 * fps):
			sm.play_ui("select")
		elif frame == int(2.0 * fps):
			sm.play_ui("launch")
		elif frame == int(2.6 * fps):
			sm.play_ui("warn")
		elif frame == int(3.4 * fps):
			sm.play_ui("error")
		elif frame == int(4.0 * fps):
			sm.rocket_start(rk0)
		elif frame == int(10.0 * fps):
			sm.whistle_start()
		elif frame == int(12.0 * fps):
			sm.rocket_stop()
		elif frame == int(16.0 * fps):
			sm.on_detonation(pa)
			print(sm.describe())
			phase = "A"
			age = 0.0
		elif frame == int(47.0 * fps):
			sm.stop_all()
			sm.on_detonation(pb)
			print(sm.describe())
			phase = "B"
			age = float(pb["t_shock"]) - 4.0
		elif frame == int(92.0 * fps):
			sm.stop_all()
			sm.on_detonation(pc)
			print(sm.describe())
			phase = "C"
			age = 0.0
		elif frame == int(102.0 * fps):
			break
		if t > 4.0 and t < 12.5:
			var tr := t - 4.0
			sm.rocket_update(rk0 + Vector3(0.0, 12.0 * tr * tr, -4.0 * tr * tr))
		if phase != "":
			# a 1 s pause in the middle of explosion A
			var ts := 0.0 if (phase == "A" and t >= 33.0 and t < 34.0) else 1.0
			sm.update_age(age, ts)
			age += dt * ts
		frame += 1
		await process_frame
	# free the manager while frames are still mixed, so the AudioServer releases its playbacks
	root.remove_child(sm)
	sm.free()
	sm = null
	for f in 4:
		await process_frame
	print("MOVIE done frames=%d" % frame)
	print("READY")
	quit()


# =============================================================================== analysis

func _analyze(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_check(false, "open " + path)
		return
	var bytes := f.get_buffer(f.get_length())
	var pos := 12
	var fmt_tag := 0
	var ch := 0
	var rate := 0
	var bits := 0
	var data_off := -1
	var data_len := 0
	while pos + 8 <= bytes.size():
		var id := bytes.slice(pos, pos + 4).get_string_from_ascii()
		var sz := bytes.decode_u32(pos + 4)
		if id == "fmt ":
			fmt_tag = bytes.decode_u16(pos + 8)
			ch = bytes.decode_u16(pos + 10)
			rate = bytes.decode_u32(pos + 12)
			bits = bytes.decode_u16(pos + 22)
		elif id == "data":
			data_off = pos + 8
			data_len = mini(sz, bytes.size() - data_off)
			break
		pos += 8 + sz + (sz & 1)
	print("WAV fmt=%d ch=%d rate=%d bits=%d data=%d bytes" % [fmt_tag, ch, rate, bits, data_len])
	if data_off < 0 or ch == 0:
		_check(false, "parse wav")
		return
	var bps := bits / 8
	var frames := data_len / (bps * ch)
	var mono := PackedFloat32Array()
	mono.resize(frames)
	var pk := 0.0
	var acc := 0.0
	for i in frames:
		var v := 0.0
		for c in ch:
			var o := data_off + (i * ch + c) * bps
			var s := 0.0
			if fmt_tag == 3:
				s = bytes.decode_float(o)
			elif bits == 16:
				s = bytes.decode_s16(o) / 32768.0
			elif bits == 32:
				s = bytes.decode_s32(o) / 2147483648.0
			elif bits == 24:
				var u := bytes[o] | (bytes[o + 1] << 8) | (bytes[o + 2] << 16)
				if u >= 0x800000:
					u -= 0x1000000
				s = u / 8388608.0
			pk = maxf(pk, absf(s))
			acc += s * s
			v += s
		mono[i] = v / ch
	var rms := sqrt(acc / maxf(1.0, float(frames * ch)))
	print("MIX duration %.1f s  peak %.4f (%.2f dBFS)  rms %.4f (%.1f dBFS)" % [float(frames) / rate, pk,
			20.0 * log(maxf(pk, 1e-9)) / log(10.0), rms, 20.0 * log(maxf(rms, 1e-9)) / log(10.0)])
	_check(pk > 0.01, "mix not silent")
	_check(pk <= 1.0, "mix peak <= 0 dBFS")
	# 0.5 s RMS envelope printout
	var win := int(rate * 0.5)
	var line := ""
	for w in frames / win:
		var a2 := 0.0
		for i in range(w * win, (w + 1) * win):
			a2 += mono[i] * mono[i]
		var db := 20.0 * log(maxf(sqrt(a2 / win), 1e-9)) / log(10.0)
		line += "%5.1f:%4.0f " % [w * 0.5, db]
		if w % 10 == 9:
			print("ENV ", line)
			line = ""
	if line != "":
		print("ENV ", line)
	_spectrogram(mono, float(rate), out_dir.path_join("mix_spec.png"))
	# zoomed slices of the scripted --movie timeline
	var dur := float(frames) / rate
	for sl: Array in [["flight", 3.0, 17.0], ["near", 21.0, 37.0], ["far", 50.0, 72.0], ["small", 92.0, 101.0]]:
		if float(sl[2]) <= dur:
			var part := mono.slice(int(float(sl[1]) * rate), int(float(sl[2]) * rate))
			_spectrogram(part, float(rate), out_dir.path_join("mix_spec_%s.png" % sl[0]))
