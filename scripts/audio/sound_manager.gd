extends Node
## SoundManager: procedural audio for the whole game (task section 8).
##
## setup() builds the bus layout and synthesizes every stream (AudioSynth, threaded on the
## WorkerThreadPool). The explosion soundtrack is driven entirely by the explosion's AGE in game
## seconds (update_age), so slow motion, pause, jumps and --write-movie stay deterministic:
##   t_seismic            ground tremor (+ rattle) on the Bunker bus
##   t_shock              crack (+ second report for high bursts), thump, infrasonic thump
##                        (megatons), rumble tail with terrain echoes, bunker debris/glass
##   t_shock + ...        fireball roar (close only), distant thunder rolls, cloud afterwind
##   p_psi > 2            "ringing in the ears": the Ears bus is low-passed and ducked for a few
##                        seconds while a 4 kHz tinnitus tone fades in and out (Master direct)
## Bus layout:  Master [HardLimiter -0.3 dB]  <-  Ears [LowPass, muffling]  <-  Blast [LowPass by
## distance + Reverb], World (rocket, whistle), Bunker (ambience, tremor, debris);  UI -> Master.
## Blast layers use non-positional AudioStreamPlayer (the sound is the observer's), the rocket
## uses AudioStreamPlayer3D. One-shot events never retrigger on backward scrubbing or at
## time_scale 0; a forward jump starts a layer at the matching offset or skips it if it is over.

const AudioSynth = preload("res://scripts/audio/audio_synth.gd")
const BlastSynth = preload("res://scripts/audio/blast_synth.gd")

const SOUND_SPEED := 343.0
const LN10 := 2.302585092994046
# bunker ambience sits at ~-34 LUFS (measured in a --write-movie mix), well under the faintest
# blasts at their recommended distance (Mk 82 at 2 km peaks around -21 dBFS)
const VENT_DB := -24.0
const HUM_DB := -33.0
const ROCKET_DB := 16.0          # +6 dB vs the old loop: the crackling roar has a crest factor of ~12 (was ~4)
const WHISTLE_DB := -9.0
## The falling-bomb whistle keeps its full level up to this distance, then falls off as 1/r
## (floored at WHISTLE_MIN_DB so it stays a faint cue at long range).
const WHISTLE_REF_M := 1500.0
const WHISTLE_MIN_DB := -24.0
const UI_DB := -10.0
const UI_KINDS := ["click", "select", "launch", "warn", "error"]
const MAX_THUNDER := 7
const EXIT_DRAIN_MS := 60
## One player per thunder roll: reusing a playing player would cut its tail (set_stream stops it).
const BLAST_IDS := ["crack", "crack2", "thump", "infra", "rumble", "thunder0", "thunder1",
		"thunder2", "thunder3", "thunder4", "thunder5", "thunder6", "roar", "wind",
		"blast_front", "blast_tail"]
## Generic layers replaced by the per-event synthesis (BlastSynth) when it is ready in time.
const GENERIC_IDS := ["crack", "crack2", "thump", "rumble", "thunder0", "thunder1", "thunder2",
		"thunder3", "thunder4", "thunder5", "thunder6"]
const BUNKER_IDS := ["tremor", "debris", "glass"]
const LOOP_STREAM := {"roar": "roar", "wind": "wind"}

## Generated streams {name: AudioStreamWAV} (see AudioSynth.NAMES).
var sounds: Dictionary = {}
## Wall-clock generation time of setup() in milliseconds.
var gen_ms := 0.0
var is_setup := false
## Generate on the WorkerThreadPool (falls back to the main thread for anything missing).
var use_threads := true
## Every fired one-shot event: [age, id, stream, volume_db, pitch, late_s] (for tests/debug).
var event_log: Array = []
var log_events := false

var bus_ears := -1
var bus_blast := -1
var bus_world := -1
var bus_bunker := -1
var bus_ui := -1
var limiter: AudioEffectHardLimiter
var lp_blast: AudioEffectLowPassFilter
var reverb_blast: AudioEffectReverb
var lp_ears: AudioEffectLowPassFilter

var _p: Dictionary = {}            # layer id -> AudioStreamPlayer
var _base_pitch: Dictionary = {}   # layer id -> pitch before the slow-motion factor
var _ui: Dictionary = {}
var _vent: AudioStreamPlayer
var _hum: AudioStreamPlayer
var _whistle: AudioStreamPlayer
var _tinnitus: AudioStreamPlayer
var _rocket_ign: AudioStreamPlayer3D
var _rocket_loop: AudioStreamPlayer3D

var _own_limiter := false
var _gen_names: Array = []
var _gen_out: Dictionary = {}
var _gen_mutex: Mutex

# explosion state
var _active := false
var _events: Array = []            # {t, id, stream, db, pitch, fired}
var _loops: Dictionary = {}        # id -> {t0, dur, att, shape, db, pitch}
var _last_age := -1.0e9
var _slow := 1.0
var _pause_age := false
var _pause_game := false
var _paused := false
var _w := 1.0
var _d := 1000.0
var _psi := 0.0
var _kind := ""
var _t_shock := 0.0
var _lvl := 0.0
var _mf_on := false
# per-event blast synthesis (BlastSynth on the WorkerThreadPool, started at launch)
var _syn_key := ""                 # key of the prepared event (bomb + distance)
var _syn_task := -1
var _syn_res: Dictionary = {}
var _syn_res_key := ""
var _syn_mutex := Mutex.new()
var _syn_pending: Array[int] = []  # finished-or-running task ids still to be waited for
var _mode := ""                    # "", "synth" or "generic" (decided when the blast arrives)
var _syn_stream: Dictionary = {}   # id -> AudioStreamWAV for the synthesized layers
var _mf_rec := 4.0
var _mf_min := 1000.0
var _mf_dip := -6.0
var _tin_db := -18.0
var _tin_tau := 4.0
var _muffle := 0.0

# ambience
var _amb_on := false
var _amb_gain := 0.0
var _amb_mod_vent := 1.0
var _amb_mod_hum := 1.0
var _vent_pitch := 1.0

# rocket / whistle
var _rk_state := 0                 # 0 off, 1 waiting for the sound to arrive, 2 on, 3 fading
var _rk_delay := 0.0
var _rk_gain := 0.0
var _wh_state := 0                 # 0 off, 1 falling, 2 fading
var _wh_t := 0.0
var _wh_gain := 0.0
var _src_pos := Vector3.ZERO       # last rocket_start/rocket_update position (the flying payload)
var _src_known := false


# =============================================================================== public API

## Creates the buses (Master limiter, Ears, Blast, World, Bunker, UI) and generates all sounds.
func setup() -> void:
	if is_setup:
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_generate()
	_make_players()
	is_setup = true


## Bunker ventilation + electrical hum (fades in/out over ~1.5 s).
func set_ambience(on: bool) -> void:
	_amb_on = on


## Terminal sounds: "click", "select", "launch", "warn", "error".
func play_ui(kind: String) -> void:
	if not is_setup:
		return
	var p: AudioStreamPlayer = _ui.get(kind, _ui.get("click"))
	if p:
		p.play()


## Starts the booster sound at world_pos; it is heard after distance / 343 m/s (game time).
func rocket_start(world_pos: Vector3) -> void:
	if not is_setup:
		return
	_rocket_ign.stop()
	_rocket_loop.stop()
	_rk_delay = 0.0
	_src_known = _finite3(world_pos)
	if _src_known:
		_rocket_ign.position = world_pos
		_rocket_loop.position = world_pos
		_src_pos = world_pos
		_rk_delay = world_pos.distance_to(_listener_pos()) / SOUND_SPEED
	_rk_state = 1
	_rk_gain = 0.0


## Moves the booster sound; also the source position of the falling-bomb whistle.
func rocket_update(world_pos: Vector3) -> void:
	if not is_setup or not _finite3(world_pos):
		return
	_rocket_ign.position = world_pos
	_rocket_loop.position = world_pos
	_src_pos = world_pos
	_src_known = true


func rocket_stop() -> void:
	if _rk_state == 1:
		_rk_state = 0
	elif _rk_state == 2:
		_rk_state = 3


## Falling-bomb whistle: a looped tone whose pitch slides down while it plays.
func whistle_start() -> void:
	if not is_setup:
		return
	_wh_state = 1
	_wh_t = 0.0
	_wh_gain = 0.0
	_whistle.volume_db = -80.0
	_whistle.stream_paused = false
	_whistle.play()


func whistle_stop() -> void:
	if _wh_state == 1:
		_wh_state = 2


## Starts synthesizing the blast heard at the bunker for the coming detonation (call at launch;
## params from BlastSynth.params_for plus "key"). Runs on the WorkerThreadPool while the booster
## flies; on_detonation() with the same "synth_key" uses it if it is ready when the blast arrives.
func prepare_blast(params: Dictionary) -> void:
	if not is_setup:
		return
	_syn_key = String(params.get("key", ""))
	if not use_threads:
		_synth_job(params, _syn_key)
		return
	_syn_task = WorkerThreadPool.add_task(_synth_job.bind(params, _syn_key), false, "BlastSynth")
	_syn_pending.append(_syn_task)


func _synth_job(params: Dictionary, key: String) -> void:
	var r := BlastSynth.make_event(params)
	_syn_mutex.lock()
	_syn_res = r
	_syn_res_key = key
	_syn_mutex.unlock()


## The synthesized event for `key`, or {} if it is not finished (never blocks).
func _synth_ready(key: String) -> Dictionary:
	if key == "" or key != _syn_key:
		return {}
	_syn_mutex.lock()
	var r := _syn_res if _syn_res_key == key else {}
	_syn_mutex.unlock()
	return r


## Schedules the explosion soundtrack. Keys: yield_kt, distance_m (slant), t_seismic, t_shock,
## p_psi, nuclear, kind, megaton; optional hob_m (burst height, adds the second report of high
## bursts). Missing keys get physical defaults. Call update_age() every frame afterwards.
func on_detonation(p: Dictionary) -> void:
	if not is_setup:
		setup()
	_stop_layers()
	whistle_stop()
	event_log.clear()
	# NaN / inf / missing values fall back to physical defaults (never reach a volume or a timer)
	_w = maxf(_num(p, "yield_kt", 1.0), 1.0e-6)
	_d = maxf(_num(p, "distance_m", 10000.0), 1.0)
	_kind = String(p.get("kind", "NUCLEAR_AIR"))
	var surface := _kind.contains("SURFACE") or _kind.contains("TOWER") or _kind.contains("BURIED") \
			or _kind.contains("UNDERWATER")
	_t_shock = maxf(_num(p, "t_shock", _d / SOUND_SPEED), 0.0)
	var t_seis := maxf(_num(p, "t_seismic", _d / BlastPhysics.SEISMIC_V), 0.0)
	_psi = _num(p, "p_psi", -1.0)
	if _psi < 0.0:
		_psi = BlastPhysics.overpressure(_w, _d, surface)
	if is_nan(_psi) or is_inf(_psi):
		_psi = 0.0
	var nuclear := bool(p.get("nuclear", _w >= 0.01))
	var mega := bool(p.get("megaton", _w >= 1000.0))
	var hob := _num(p, "hob_m", 0.0)
	var lw := _log10(_w / 15.0)
	var mods := _kind_mods(_kind)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(int(_w * 1000.0), int(_d)))

	# overall level from the peak overpressure (log), the limiter keeps the mix <= -0.3 dBFS
	_lvl = clampf(-8.0 + 9.0 * _log10(maxf(_psi, 1.0e-6)), -38.0, 3.0)
	# air absorption: 8 kHz at 1 km down to 250 Hz at 100+ km
	var cut := clampf(8000.0 * pow(_d / 1000.0, -0.7526), 250.0, 16000.0) * float(mods["cut"])
	lp_blast.cutoff_hz = maxf(cut, 180.0)
	reverb_blast.wet = clampf(0.1 + 0.08 * _log10(_d / 1000.0), 0.08, 0.3)
	reverb_blast.room_size = clampf(0.7 + 0.06 * _log10(_d / 1000.0), 0.6, 0.9)

	var pc := clampf(pow(_w / 15.0, -0.045), 0.7, 1.35)
	var pt := clampf(pow(_w / 15.0, -0.07), 0.6, 1.5)
	var pr := clampf(pow(_w / 15.0, -0.05) * pow(_d / 20000.0, -0.04), 0.6, 1.25)
	_events.clear()
	_loops.clear()

	# ground tremor arrives first (P-wave), stronger for coupled bursts
	var tdb := -14.0 + 6.0 * _log10(_w) - 10.0 * _log10(maxf(_d, 300.0) / 1000.0) + float(mods["couple"])
	if tdb > -40.0:
		_add_ev(t_seis, "tremor", "tremor", minf(tdb, 0.0), clampf(pow(_w / 15.0, -0.04), 0.7, 1.3))
	# the air blast
	# (a layer pitched down by p lasts 1/p longer: 10*log10(p) keeps its energy comparable)
	_add_ev(_t_shock, "crack", "crack", _lvl + float(mods["crack"]) + _e_comp(pc), pc)
	if hob >= 1000.0 or _kind == "NUCLEAR_HIGH_AIR":
		_add_ev(_t_shock + 0.35 + maxf(hob, 1500.0) / 4000.0, "crack2", "crack",
				_lvl + float(mods["crack"]) - 5.0 + _e_comp(pc), pc * 0.92)
	_add_ev(_t_shock + 0.004, "thump", "thump",
			_lvl + float(mods["thump"]) + (0.0 if nuclear else -2.0) + _e_comp(pt), pt)
	if mega or _w >= 500.0:
		var pi := clampf(pow(_w / 1000.0, -0.05), 0.75, 1.1)
		_add_ev(_t_shock + 0.01, "infra", "infra", _lvl - (1.0 if mega else 3.0) + _e_comp(pi), pi)
	_add_ev(_t_shock + 0.03, "rumble", "rumble",
			_lvl + clampf(-2.0 + 1.5 * lw, -9.0, 2.0) + float(mods["rumble"]) + _e_comp(pr), pr)
	# bunker reaction
	if _psi >= 0.15:
		_add_ev(_t_shock + 0.04, "debris", "debris", clampf(-18.0 + 9.0 * _log10(_psi / 0.15), -24.0, 0.0), 1.0)
	if _psi >= 25.0:
		_add_ev(_t_shock, "glass", "glass_shatter", 0.0, 1.0)
	elif _psi >= 10.0:
		_add_ev(_t_shock + 0.01, "glass", "glass_crack", -2.0, 1.0)
	# distant thunder rolls / echoes from the ranges
	var n_th := 0
	if nuclear:
		n_th = clampi(2 + int(1.3 * _log10(maxf(_w, 1.0))), 2, MAX_THUNDER)
	else:
		n_th = 1 if _w < 0.005 else 2
	var tt := _t_shock + rng.randf_range(2.5, 4.0)
	for k in n_th:
		var tdb2 := _lvl - 5.0 - 2.2 * k + (2.0 if mega else 0.0) - (4.0 if not nuclear else 0.0)
		_add_ev(tt, "thunder%d" % k, "thunder_a" if k % 2 == 0 else "thunder_b", tdb2,
				clampf(pt * rng.randf_range(0.85, 1.12), 0.5, 1.5))
		tt += rng.randf_range(1.6, 4.5) * (1.0 + 0.12 * _log10(maxf(_w, 1.0)))

	# fireball roar: only close, fades with distance (reference distance grows with the fireball)
	var d_ref := 700.0 * maxf(1.0, pow(_w / 15.0, 0.3))
	var roar_dur := clampf(4.0 * pow(_w, 0.3), 3.0, 90.0)
	if not nuclear:
		d_ref = 300.0 * pow(maxf(_w * 1.0e6 / 100.0, 1.0), 0.25)
		roar_dur = maxf(0.8, 3.0 * BlastPhysics.conventional_fireball_duration(_w * 1.0e6))
	if float(mods["roar_dur"]) > 0.0:
		roar_dur = float(mods["roar_dur"])
	var g := pow(clampf(1.0 - _log10(maxf(_d, 1.0) / d_ref) / _log10(30.0), 0.0, 1.0), 1.5)
	if g > 0.01:
		_loops["roar"] = {"t0": _t_shock + 0.15, "dur": roar_dur, "att": 0.4, "shape": 1.6,
				"db": _lvl - 3.0 + float(mods["roar"]) + linear_to_db(g),
				"pitch": clampf(pow(_w / 15.0, -0.06), 0.6, 1.4)}
	# afterwind of the rising cloud
	if nuclear and _w >= 0.05:
		var wdb := clampf(-12.0 + 2.0 * lw - 8.0 * _log10(maxf(_d, 2000.0) / 5000.0), -34.0, -5.0)
		_loops["wind"] = {"t0": _t_shock + 1.5,
				"dur": clampf(BlastPhysics.cloud_stabilization_time(_w) * 0.5, 20.0, 180.0),
				"att": 8.0, "shape": 0.7, "db": wdb, "pitch": clampf(pow(_w / 15.0, -0.04), 0.75, 1.15)}
	# per-event synthesis: front just before the arrival (zero-phase pre-roll), tail at the arrival
	_mode = ""
	_syn_stream.clear()
	var skey := String(p.get("synth_key", ""))
	if skey != "" and skey == _syn_key:
		_add_ev(_t_shock - BlastSynth.FRONT_PRE, "blast_front", "", _lvl + 2.0, 1.0)
		_add_ev(_t_shock, "blast_tail", "", _lvl + 2.0, 1.0)
		if mega:
			# keep a felt, saturated infrasonic thump under the synthesized front for megatons
			for ev: Dictionary in _events:
				if ev["id"] == "infra":
					ev["db"] = float(ev["db"]) - 5.0
	else:
		_mode = "generic"
	for id: String in _loops:
		var st: AudioStreamWAV = sounds[LOOP_STREAM[id]]
		(_p[id] as AudioStreamPlayer).stream = st
		_base_pitch[id] = float(_loops[id]["pitch"])

	# ringing in the ears
	_mf_on = _psi > 2.0
	if _mf_on:
		var m := clampf(_log10(_psi / 2.0), 0.0, 1.0)
		_mf_rec = 3.0 + 7.0 * m
		_mf_min = exp(lerpf(log(1800.0), log(320.0), m))
		_mf_dip = -3.0 - 9.0 * m
		_tin_db = -18.0 + 8.0 * m
		_tin_tau = 3.0 + 5.0 * m
	_active = true
	_last_age = -1.0e9
	_pause_age = false
	_refresh_pause()


## Drive the soundtrack with the explosion age (game seconds) every frame.
## time_scale 0 (or Game.paused) pauses every explosion/flight player.
func update_age(age: float, time_scale: float) -> void:
	if not _active:
		return
	_pause_age = time_scale <= 0.0
	_refresh_pause()
	if _paused:
		return
	_slow = _slow_factor(time_scale)
	var backwards := age < _last_age - 1.0e-4
	if not backwards:
		for ev: Dictionary in _events:
			if not ev["fired"] and age >= float(ev["t"]):
				var id: String = ev["id"]
				var grp := "synth" if id.begins_with("blast_") else ("generic" if id in GENERIC_IDS else "")
				if grp != "" and _mode == "":
					_resolve_mode()
				ev["fired"] = true
				if grp != "" and grp != _mode:
					continue
				_fire(ev, age - float(ev["t"]), age)
	_update_loops(age, not backwards)
	_update_ears(age)
	_update_amb_mod(age)
	for id: String in _p:
		var pl: AudioStreamPlayer = _p[id]
		if pl.playing:
			pl.pitch_scale = float(_base_pitch.get(id, 1.0)) * _slow
	_last_age = age


## Silences everything explosion/flight related and resets the state between launches.
## The ambience keeps its on/off state.
func stop_all() -> void:
	_active = false
	_events.clear()
	_loops.clear()
	_stop_layers()
	if is_setup:
		_rocket_ign.stop()
		_rocket_loop.stop()
		_whistle.stop()
		_rocket_ign.stream_paused = false
		_rocket_loop.stream_paused = false
		_whistle.stream_paused = false
	_rk_state = 0
	_wh_state = 0
	_src_known = false
	_pause_age = false
	_paused = false
	_slow = 1.0
	_amb_mod_vent = 1.0
	_amb_mod_hum = 1.0
	_vent_pitch = 1.0
	_last_age = -1.0e9


# =============================================================================== setup

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_release_effects()


func _exit_tree() -> void:
	# stop every voice so the AudioServer drops its playbacks before the engine shuts down
	if not is_setup:
		return
	for tid in _syn_pending:
		WorkerThreadPool.wait_for_task_completion(tid)
	_syn_pending.clear()
	stop_all()
	for c in get_children():
		if c is AudioStreamPlayer:
			(c as AudioStreamPlayer).stop()
		elif c is AudioStreamPlayer3D:
			(c as AudioStreamPlayer3D).stop()
	# The AudioServer frees stopped playbacks on its mix thread one or two periods later; quitting
	# right away reports them (and their streams) as leaked ObjectDB instances. Give the mix thread
	# that time once here. (--write-movie mixes on the main thread per frame: waiting cannot help.)
	if Engine.get_write_movie_path().is_empty():
		OS.delay_msec(EXIT_DRAIN_MS)


## Takes our effects off the AudioServer buses (they would otherwise outlive the scene tree
## and be reported as leaked ObjectDB instances at exit).
func _release_effects() -> void:
	for fx: AudioEffect in [limiter, lp_ears, lp_blast, reverb_blast]:
		if fx == null or (fx == limiter and not _own_limiter):
			continue
		for b in AudioServer.bus_count:
			for i in range(AudioServer.get_bus_effect_count(b) - 1, -1, -1):
				if AudioServer.get_bus_effect(b, i) == fx:
					AudioServer.remove_bus_effect(b, i)
	bus_ears = -1


func _setup_buses() -> void:
	limiter = null
	for i in AudioServer.get_bus_effect_count(0):
		var fx := AudioServer.get_bus_effect(0, i)
		if fx is AudioEffectHardLimiter:
			limiter = fx as AudioEffectHardLimiter
	if limiter == null:
		limiter = AudioEffectHardLimiter.new()
		AudioServer.add_bus_effect(0, limiter)
		_own_limiter = true
	limiter.ceiling_db = -0.3
	limiter.pre_gain_db = 0.0
	limiter.release = 0.15
	_make_bus("Ears", "Master")
	_make_bus("Blast", "Ears")
	_make_bus("World", "Ears")
	_make_bus("Bunker", "Ears")
	_make_bus("UI", "Master")
	bus_ears = AudioServer.get_bus_index("Ears")
	bus_blast = AudioServer.get_bus_index("Blast")
	bus_world = AudioServer.get_bus_index("World")
	bus_bunker = AudioServer.get_bus_index("Bunker")
	bus_ui = AudioServer.get_bus_index("UI")
	lp_ears = AudioEffectLowPassFilter.new()
	lp_ears.cutoff_hz = 20000.0
	lp_ears.resonance = 0.5
	lp_ears.db = AudioEffectFilter.FILTER_12DB
	AudioServer.add_bus_effect(bus_ears, lp_ears)
	AudioServer.set_bus_effect_enabled(bus_ears, 0, false)
	lp_blast = AudioEffectLowPassFilter.new()
	lp_blast.cutoff_hz = 8000.0
	lp_blast.resonance = 0.5
	lp_blast.db = AudioEffectFilter.FILTER_12DB
	AudioServer.add_bus_effect(bus_blast, lp_blast)
	reverb_blast = AudioEffectReverb.new()
	reverb_blast.room_size = 0.75
	reverb_blast.damping = 0.55
	reverb_blast.spread = 1.0
	reverb_blast.hipass = 0.0
	reverb_blast.dry = 1.0
	reverb_blast.wet = 0.15
	reverb_blast.predelay_msec = 120.0
	reverb_blast.predelay_feedback = 0.35
	AudioServer.add_bus_effect(bus_blast, reverb_blast)


## Creates (or reuses) a bus that sends to `send`; a bus can only send to a lower index.
func _make_bus(bus_name: String, send: String) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1 and idx <= AudioServer.get_bus_index(send):
		AudioServer.remove_bus(idx)
		idx = -1
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
	while AudioServer.get_bus_effect_count(idx) > 0:
		AudioServer.remove_bus_effect(idx, 0)
	AudioServer.set_bus_send(idx, send)
	AudioServer.set_bus_volume_db(idx, 0.0)
	AudioServer.set_bus_mute(idx, false)


func _generate() -> void:
	var t0 := Time.get_ticks_usec()
	_gen_names = AudioSynth.NAMES.duplicate()
	_gen_out = {}
	var threaded := use_threads and OS.get_processor_count() > 1
	if threaded:
		_gen_mutex = Mutex.new()
		var gid := WorkerThreadPool.add_group_task(_gen_job, _gen_names.size(), -1, true, "AudioSynth")
		WorkerThreadPool.wait_for_group_task_completion(gid)
	for nm: String in _gen_names:
		if _gen_out.get(nm) == null:
			_gen_out[nm] = AudioSynth.make(nm)
	sounds = _gen_out
	gen_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	print("AUDIO generated %d sounds in %.1f ms (%s)" % [sounds.size(), gen_ms,
			"threaded" if threaded else "single thread"])


func _gen_job(i: int) -> void:
	var nm: String = _gen_names[i]
	var s: AudioStreamWAV = AudioSynth.make(nm)
	_gen_mutex.lock()
	_gen_out[nm] = s
	_gen_mutex.unlock()


func _make_players() -> void:
	for id: String in BLAST_IDS:
		_p[id] = _player("L_" + id, "Blast", 1)
	for id: String in BUNKER_IDS:
		_p[id] = _player("L_" + id, "Bunker", 1)
	_tinnitus = _player("Tinnitus", "Master", 1)
	_tinnitus.stream = sounds["tinnitus"]
	_vent = _player("Vent", "Bunker", 1)
	_vent.stream = sounds["vent"]
	_hum = _player("Hum", "Bunker", 1)
	_hum.stream = sounds["hum"]
	_whistle = _player("Whistle", "World", 1)
	_whistle.stream = sounds["whistle"]
	for kind: String in UI_KINDS:
		var u := _player("UI_" + kind, "UI", 3)
		u.stream = sounds["ui_" + kind]
		u.volume_db = UI_DB
		_ui[kind] = u
	_rocket_ign = _player3d("RocketIgnite", sounds["rocket_ignite"])
	_rocket_loop = _player3d("RocketLoop", sounds["rocket_loop"])


func _player(pname: String, bus: String, poly: int) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = pname
	p.bus = bus
	p.max_polyphony = poly
	add_child(p)
	return p


func _player3d(pname: String, st: AudioStream) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = pname
	p.stream = st
	p.bus = "World"
	# physical 1/r spreading (Godot's ATTENUATION_LOGARITHMIC is -20*ln(d/u), far too steep for km)
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.unit_size = 60.0
	p.max_db = 10.0
	p.max_distance = 0.0
	p.volume_db = ROCKET_DB
	p.attenuation_filter_cutoff_hz = 7000.0
	p.attenuation_filter_db = -18.0
	p.panning_strength = 1.0
	add_child(p)
	return p


# =============================================================================== runtime

func _process(delta: float) -> void:
	if not is_setup:
		return
	var ts := 1.0
	_pause_game = false
	var g := get_node_or_null("/root/Game")
	if g:
		var v: Variant = g.get("time_scale")
		if v != null:
			ts = float(v)
		var pv: Variant = g.get("paused")
		if pv != null:
			_pause_game = bool(pv)
	_refresh_pause()
	var dt_game := 0.0 if _paused else delta * ts
	_update_ambience(delta)
	# reap finished synthesis tasks (WorkerThreadPool requires every task to be waited for)
	for i in range(_syn_pending.size() - 1, -1, -1):
		var tid := _syn_pending[i]
		if WorkerThreadPool.is_task_completed(tid):
			WorkerThreadPool.wait_for_task_completion(tid)
			_syn_pending.remove_at(i)
	_update_rocket(delta, dt_game, ts)
	_update_whistle(delta, dt_game, ts)


func _refresh_pause() -> void:
	var want := _pause_age or _pause_game
	if want == _paused:
		return
	_paused = want
	for id: String in _p:
		(_p[id] as AudioStreamPlayer).stream_paused = want
	if is_setup:
		_tinnitus.stream_paused = want
		_whistle.stream_paused = want
		_rocket_ign.stream_paused = want
		_rocket_loop.stream_paused = want


## Decides once per explosion (when the blast arrives) between the synthesized event and the
## generic layers; the synthesized one is used only if it finished in time.
func _resolve_mode() -> void:
	var r := _synth_ready(_syn_key)
	if r.is_empty() or r.get("front") == null:
		_mode = "generic"
		return
	_mode = "synth"
	_syn_stream["blast_front"] = r["front"]
	_syn_stream["blast_tail"] = r["tail"]
	# levels: the front's peak from the physical peak SPL (compressive map, BlastSynth._map_spl),
	# the tail at its physical ratio to the front
	var fdb := float(r.get("front_db", _lvl))
	for ev: Dictionary in _events:
		if ev["id"] == "blast_front":
			ev["db"] = fdb
		elif ev["id"] == "blast_tail":
			ev["db"] = fdb + float(r.get("tail_gain_db", -10.0))
	# the synthesized streams already carry the air absorption and the echoes
	lp_blast.cutoff_hz = 20000.0
	reverb_blast.wet = 0.04
	if log_events:
		print("AUDIO synth event used: tail %.1f dB, rise %.5f s" % [float(r.get("tail_gain_db", 0.0)), float(r.get("rise_s", 0.0))])


func _add_ev(t: float, id: String, stream: String, db: float, pitch: float) -> void:
	_events.append({"t": t, "id": id, "stream": stream, "db": db, "pitch": pitch, "fired": false})


func _fire(ev: Dictionary, late: float, age: float) -> void:
	var id: String = ev["id"]
	var pl: AudioStreamPlayer = _p[id]
	var st: AudioStreamWAV = _syn_stream.get(id) if id.begins_with("blast_") else sounds.get(String(ev["stream"]))
	if st == null:
		return
	var pitch: float = ev["pitch"]
	var pos := late * pitch
	if pos > st.get_length() * 0.9:
		return   # the layer would already be over (forward jump): skip it
	pl.stream = st
	_base_pitch[id] = pitch
	pl.pitch_scale = pitch * _slow
	pl.volume_db = float(ev["db"])
	pl.stream_paused = false
	pl.play(pos)
	event_log.append([age, id, ev["stream"], float(ev["db"]), pitch, late])
	if log_events:
		print("AUDIO ev t=%.2f %s (%s) %.1f dB pitch %.2f late %.3f" % [age, id, ev["stream"], float(ev["db"]), pitch, late])


func _update_loops(age: float, allow_start: bool) -> void:
	for id: String in _loops:
		var lp: Dictionary = _loops[id]
		var pl: AudioStreamPlayer = _p[id]
		var x := age - float(lp["t0"])
		var dur: float = lp["dur"]
		var env := 0.0
		if x >= 0.0 and x <= dur:
			env = smoothstep(0.0, float(lp["att"]), x) * pow(1.0 - x / dur, float(lp["shape"]))
		if env < 0.001:
			if pl.playing:
				pl.stop()
			continue
		pl.volume_db = float(lp["db"]) + linear_to_db(env)
		if not pl.playing and allow_start:
			pl.pitch_scale = float(lp["pitch"]) * _slow
			pl.stream_paused = false
			pl.play(fmod(x * float(lp["pitch"]), pl.stream.get_length()))


func _update_ears(age: float) -> void:
	if not _mf_on:
		_set_muffle(0.0)
		return
	var x := age - (_t_shock + 0.1)
	var a := 0.0
	if x >= 0.0 and x < _mf_rec:
		a = clampf(x / 0.06, 0.0, 1.0) * (1.0 - smoothstep(0.0, 1.0, x / _mf_rec))
	_set_muffle(a)
	var xt := age - (_t_shock + 0.08)
	var gt := 0.0
	if xt >= 0.0:
		gt = clampf(xt / 0.35, 0.0, 1.0)
		if xt > 1.2:
			gt *= exp(-(xt - 1.2) / _tin_tau)
	if gt < 0.002:
		if _tinnitus.playing:
			_tinnitus.stop()
		return
	_tinnitus.volume_db = _tin_db + linear_to_db(gt)
	if not _tinnitus.playing:
		_tinnitus.stream_paused = false
		_tinnitus.play()


func _set_muffle(a: float) -> void:
	if bus_ears < 0:
		return
	if a <= 0.001:
		if _muffle > 0.0:
			AudioServer.set_bus_effect_enabled(bus_ears, 0, false)
			AudioServer.set_bus_volume_db(bus_ears, 0.0)
			lp_ears.cutoff_hz = 20000.0
		_muffle = 0.0
		return
	if _muffle <= 0.0:
		AudioServer.set_bus_effect_enabled(bus_ears, 0, true)
	_muffle = a
	lp_ears.cutoff_hz = exp(lerpf(log(20000.0), log(_mf_min), a))
	AudioServer.set_bus_volume_db(bus_ears, _mf_dip * a)


func _update_amb_mod(age: float) -> void:
	var x := age - _t_shock
	_amb_mod_vent = 1.0
	_amb_mod_hum = 1.0
	_vent_pitch = 1.0
	if x < 0.0:
		return
	if _psi >= 25.0:
		# bunker destroyed: power lost, the fan spins down
		var k := clampf(x / 4.0, 0.0, 1.0)
		_amb_mod_hum = 0.0 if x > 0.4 else (1.0 if sin(x * 61.0) > 0.0 else 0.1)
		_amb_mod_vent = 1.0 - k
		_vent_pitch = lerpf(1.0, 0.45, k)
	elif _psi >= 1.0 and x < 1.4:
		# the shock jolts the power: hum drops out with the flickering lights
		_amb_mod_hum = 0.15 if sin(x * 61.0) * sin(x * 23.0 + 1.3) > 0.25 else 1.0
		_amb_mod_vent = 0.85


func _update_ambience(delta: float) -> void:
	_amb_gain = move_toward(_amb_gain, 1.0 if _amb_on else 0.0, delta / 1.5)
	_set_loop(_vent, VENT_DB, _amb_gain * _amb_mod_vent)
	_set_loop(_hum, HUM_DB, _amb_gain * _amb_mod_hum)
	_vent.pitch_scale = _vent_pitch


func _set_loop(pl: AudioStreamPlayer, base_db: float, gain: float) -> void:
	if gain <= 0.0005:
		if pl.playing:
			pl.stop()
		return
	pl.volume_db = base_db + linear_to_db(gain)
	if not pl.playing:
		pl.play()


func _update_rocket(delta: float, dt_game: float, ts: float) -> void:
	match _rk_state:
		1:
			_rk_delay -= dt_game
			if _rk_delay <= 0.0:
				_rocket_ign.volume_db = ROCKET_DB
				_rocket_ign.stream_paused = false
				_rocket_ign.play()
				_rocket_loop.volume_db = -80.0
				_rocket_loop.stream_paused = false
				_rocket_loop.play()
				_rk_state = 2
		2:
			_rk_gain = move_toward(_rk_gain, 1.0, dt_game / 0.9)
		3:
			_rk_gain = move_toward(_rk_gain, 0.0, delta / 0.4)
			if _rk_gain <= 0.0:
				_rocket_loop.stop()
				_rocket_ign.stop()
				_rk_state = 0
	if _rk_state >= 2:
		_rocket_loop.volume_db = ROCKET_DB + linear_to_db(maxf(_rk_gain, 1.0e-4))
		var sf := _slow_factor(ts)
		_rocket_loop.pitch_scale = sf
		_rocket_ign.pitch_scale = sf


func _update_whistle(delta: float, dt_game: float, ts: float) -> void:
	if _wh_state == 0:
		return
	if _wh_state == 1:
		_wh_t += dt_game
		_wh_gain = move_toward(_wh_gain, 1.0, dt_game / 2.5)
	else:
		_wh_gain = move_toward(_wh_gain, 0.0, delta / 0.15)
		if _wh_gain <= 0.0:
			_whistle.stop()
			_wh_state = 0
			return
	_whistle.volume_db = WHISTLE_DB + _whistle_dist_db() + linear_to_db(maxf(_wh_gain, 1.0e-4))
	_whistle.pitch_scale = (0.7 + 0.62 * exp(-_wh_t / 5.0)) * _slow_factor(ts)


func _stop_layers() -> void:
	for id: String in _p:
		var pl: AudioStreamPlayer = _p[id]
		pl.stop()
		pl.stream_paused = false
	if is_setup:
		_tinnitus.stop()
		_tinnitus.stream_paused = false
	_mf_on = false
	_set_muffle(0.0)
	if bus_ears >= 0:
		AudioServer.set_bus_effect_enabled(bus_ears, 0, false)
		AudioServer.set_bus_volume_db(bus_ears, 0.0)


# =============================================================================== helpers

## Relative dB per layer, seismic coupling (dB), distance-filter scale, roar duration (<0 auto).
func _kind_mods(kind: String) -> Dictionary:
	var m := {"crack": 0.0, "thump": 0.0, "rumble": 0.0, "roar": 0.0, "roar_dur": -1.0,
			"couple": -6.0, "cut": 1.0}
	match kind:
		"NUCLEAR_HIGH_AIR":
			m["crack"] = -1.0
			m["thump"] = 1.0
			m["rumble"] = 1.0
			m["couple"] = -8.0
		"NUCLEAR_LOW_AIR":
			m["crack"] = 1.0
			m["couple"] = -2.0
		"NUCLEAR_TOWER":
			m["couple"] = 2.0
		"NUCLEAR_SURFACE":
			m["thump"] = 1.0
			m["rumble"] = 2.0
			m["couple"] = 5.0
		"NUCLEAR_BURIED":
			m["crack"] = -10.0
			m["thump"] = 3.0
			m["rumble"] = 2.0
			m["roar"] = -8.0
			m["roar_dur"] = 4.0
			m["couple"] = 12.0
			m["cut"] = 0.5
		"NUCLEAR_UNDERWATER":
			m["crack"] = -6.0
			m["thump"] = 2.0
			m["rumble"] = 1.0
			m["roar"] = -5.0
			m["roar_dur"] = 8.0
			m["couple"] = 6.0
			m["cut"] = 0.7
		"CONVENTIONAL_SURFACE":
			m["crack"] = 1.0
			m["thump"] = -2.0
			m["rumble"] = -4.0
			m["roar"] = -2.0
			m["couple"] = 2.0
		"CONVENTIONAL_BURIED":
			m["crack"] = -8.0
			m["thump"] = 2.0
			m["rumble"] = -2.0
			m["roar"] = -8.0
			m["roar_dur"] = 2.5
			m["couple"] = 10.0
			m["cut"] = 0.55
		"THERMOBARIC":
			m["crack"] = -1.0
			m["rumble"] = -1.0
			m["roar"] = 3.0
			m["roar_dur"] = 9.0
			m["couple"] = -4.0
	return m


## Slow motion lowers the pitch a little (cinematic, keeps the sound in step with the picture).
func _slow_factor(ts: float) -> float:
	return clampf(pow(maxf(ts, 1.0e-4), 0.3), 0.45, 1.3)


func _listener_pos() -> Vector3:
	if is_inside_tree():
		var cam := get_viewport().get_camera_3d()
		if cam:
			return cam.global_position
	return Vector3.ZERO


func _log10(x: float) -> float:
	return log(x) / LN10


## p[key] as a float; `def` when missing, NaN or infinite.
func _num(p: Dictionary, key: String, def: float) -> float:
	var v: Variant = p.get(key, def)
	if not (v is float or v is int):
		return def
	var f := float(v)
	return def if is_nan(f) or is_inf(f) else f


func _finite3(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)


## Distance attenuation (dB) of the falling-bomb whistle from the last known payload position.
func _whistle_dist_db() -> float:
	if not _src_known:
		return 0.0
	var d := _src_pos.distance_to(_listener_pos())
	# research: never louder than ~70-80 dB at 1 km and inaudible beyond ~3-5 km
	if d >= 5000.0:
		return -80.0
	var db := -20.0 * _log10(maxf(d, WHISTLE_REF_M) / WHISTLE_REF_M)
	return db + linear_to_db(maxf(1.0 - smoothstep(3000.0, 5000.0, d), 1.0e-4))


## Energy compensation for a pitched layer (it lasts 1/pitch longer).
func _e_comp(pitch: float) -> float:
	return 10.0 * _log10(pitch)


## Debug summary of the scheduled soundtrack (for tests and the lead's logs).
func describe() -> String:
	var s := "AUDIO plan W=%s kt d=%.0f m psi=%.4f lvl=%.1f dB cutoff=%.0f Hz t_shock=%.2f s" % [
			str(snappedf(_w, 0.0001)), _d, _psi, _lvl, lp_blast.cutoff_hz if lp_blast else 0.0, _t_shock]
	for ev: Dictionary in _events:
		s += "\n  ev %-8s %-13s t=%7.2f  %6.1f dB  pitch %.2f" % [ev["id"], ev["stream"], ev["t"], ev["db"], ev["pitch"]]
	for id: String in _loops:
		var lp: Dictionary = _loops[id]
		s += "\n  loop %-6s t0=%7.2f dur=%6.1f  %6.1f dB  pitch %.2f" % [id, lp["t0"], lp["dur"], lp["db"], lp["pitch"]]
	if _mf_on:
		s += "\n  ears: muffle to %.0f Hz %.1f dB for %.1f s, tinnitus %.1f dB tau %.1f s" % [_mf_min, _mf_dip, _mf_rec, _tin_db, _tin_tau]
	return s
