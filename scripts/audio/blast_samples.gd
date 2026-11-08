extends RefCounted
## BlastSamples: the recorded blast of every bomb (ElevenLabs sound effects generated from
## docs/ELEVENLABS_PROMPTS.md, cut and measured by tools/process_samples.py) and how it is adapted to
## the event the player sets up. Each recording is the blast heard at the bomb's recommended
## distance (rec_km) under its historical time of day and site humidity (the REFERENCE event); the
## game plays it for any distance, time of day and humidity by changing, against that reference:
##   - level: a loudness map of the effective peak SPL at the bunker (overpressure from the game's
##     blast physics, minus the daytime shadow zone), compressive for loud events, steeper towards
##     the threshold of hearing (a 100 kg bomb 15 km away by day is a faint thud, 50 km away silence);
##   - spectrum: ISO 9613-1 air absorption of the extra (or missing) path at the site humidity and the
##     high-frequency loss of the shadow zone, as six EQ bands (32 Hz .. 10 kHz) on the sample bus;
##   - direct-to-rumble balance: the recording is split into FRONT (the report) and TAIL (the rolling
##     rumble); far away the rumble is relatively stronger (research: about -25 dB within 2 km,
##     -9..-15 dB beyond 20 km);
##   - extra arrivals: a ground inversion (dawn, pre-dawn, night) beyond 3 km adds a later, duller
##     arrival when the reference had none;
##   - the long megaton rumble past the 30 s recordings (a looped bed), the bunker window rattle
##     below the debris threshold, and a slight pan towards the burst's bearing.
## All functions are static and pure (plan() can run on any thread once meta() is loaded).
## Usage (no class_name on purpose): const BlastSamples = preload("res://scripts/audio/blast_samples.gd")

const BlastParams = preload("res://scripts/audio/blast_params.gd")
const BlastSynth = preload("res://scripts/audio/blast_synth.gd")
const BlastDSP = preload("res://scripts/audio/blast_dsp.gd")

const MANIFEST := "res://assets/audio/samples/samples.json"
## Centre frequencies of AudioEffectEQ6 (the sample bus).
const EQ_BANDS: Array[float] = [32.0, 100.0, 320.0, 1000.0, 3200.0, 10000.0]
const PA_PER_PSI := 6894.76
## Loudness map: effective peak SPL at the bunker (dB) -> max momentary loudness of the event (LUFS,
## ITU-R BS.1770, 400 ms). 164 dB = Tsar Bomba / Test 219 at their recommended 120-150 km; 137 dB =
## Mk 82 at 2 km (about -21.8 LUFS, ~18 dB over the bunker ambience); 110 dB = a dull thud at the
## ambience level; 95 dB and below fades out.
const MAP_SPL: Array[float] = [80.0, 95.0, 110.0, 130.0, 164.0, 185.0]
const MAP_LUFS: Array[float] = [-80.0, -54.6, -36.6, -24.6, -11.0, -8.0]
## Never louder than this momentary loudness (headroom for the EQ and the ears' muffling).
const MAX_LUFS := -8.0
## K-weighting (ITU-R BS.1770) at the six EQ bands, dB: to keep the loudness of a brightened
## (closer) event on target. The band energies of each recording are in samples.json.
const K_WEIGHT_DB: Array[float] = [-5.0, -0.5, 0.0, 0.5, 3.5, 4.0]
const BAND_KEYS: Array[String] = ["20-60", "60-150", "150-500", "500-2000", "2000-6000", "6000-20000"]
## Shadow zone (research: excess attenuation 5-15 dB below ~100 Hz, 20-30 dB above a few hundred Hz):
## a broadband part on the level, the rest as a high-frequency shelf on the EQ.
const SHADOW_BROAD_DB := 12.0
const SHADOW_LF_DB := 8.0
const SHADOW_HF_DB := 26.0

static var _meta: Dictionary = {}


## The parsed samples.json (loaded once; call from the main thread first).
static func meta() -> Dictionary:
	if _meta.is_empty() and FileAccess.file_exists(MANIFEST):
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		if v is Dictionary:
			_meta = v
	return _meta


static func entry(bomb_id: String) -> Dictionary:
	var bombs: Dictionary = meta().get("bombs", {})
	return bombs.get(bomb_id, {})


static func extra(name: String) -> Dictionary:
	var ex: Dictionary = meta().get("extra", {})
	return ex.get(name, {})


static func has_sample(bomb_id: String) -> bool:
	var e := entry(bomb_id)
	return not e.is_empty() and ResourceLoader.exists(String(e.get("front", ""))) \
			and ResourceLoader.exists(String(e.get("tail", "")))


## Max momentary loudness (LUFS) of an event with this effective peak SPL (piecewise linear).
static func target_lufs(spl_eff: float) -> float:
	if spl_eff <= MAP_SPL[0]:
		return MAP_LUFS[0]
	for i in range(1, MAP_SPL.size()):
		if spl_eff <= MAP_SPL[i]:
			return minf(lerpf(MAP_LUFS[i - 1], MAP_LUFS[i], (spl_eff - MAP_SPL[i - 1]) / (MAP_SPL[i] - MAP_SPL[i - 1])), MAX_LUFS)
	return MAX_LUFS


static func spl_db(psi: float) -> float:
	return 20.0 * log(maxf(psi * PA_PER_PSI, 1.0e-6) / 2.0e-5) / log(10.0)


## Rumble relative to the direct report (dB) at distance d (research; as BlastSynth's local echoes).
static func rumble_db(d: float) -> float:
	return clampf(-25.0 + 12.0 * log(maxf(d / 2000.0, 1.0)) / log(10.0), -25.0, -9.0)


## Air absorption (dB, positive) at frequency f over d metres (ISO 9613-1, 15 C, rh %). A strong
## shock (peak > ~150 Pa) stays steep - nonlinear steepening keeps re-creating the high frequencies
## that absorption takes - so its absorption is capped at 6 dB, as in BlastSynth; a front diffracted
## into the shadow zone (s01 -> 1) gets the full absorption.
static func absorption_db(f: float, d: float, rh: float, dp_pa: float, s01: float) -> float:
	var att := BlastDSP.iso9613_db_per_m(f, 15.0, rh) * d
	var floor_g := db_to_linear(-6.0) * smoothstep(100.0, 150.0, dp_pa) * (1.0 - clampf(s01, 0.0, 1.0))
	# capped in dB (a linear floor would saturate both terms of a difference at ~180 dB)
	return minf(att, -linear_to_db(floor_g)) if floor_g > 0.0 else att


## Shadow-zone attenuation (dB, positive) at frequency f for shadow depth s01 (0..1), beyond the
## broadband part already taken off the level.
static func shadow_eq_db(f: float, s01: float) -> float:
	var hf := smoothstep(log(80.0), log(400.0), log(f))
	return s01 * (SHADOW_LF_DB + SHADOW_HF_DB * hf - SHADOW_BROAD_DB)


## Everything the sound manager needs to play bomb `b`'s recording for a burst at ground range
## ground_m (m) with the given humidity (0..1), time of day ("dawn", "noon", ...) and bearing
## (deg, 0 = straight out of the bunker window, positive = to the right). {} when there is no
## recording for this bomb.
static func plan(b: Dictionary, ground_m: float, humidity: float, tod: String, az_deg: float = 0.0) -> Dictionary:
	var id := String(b.get("id", ""))
	var e := entry(id)
	if e.is_empty():
		return {}
	var p := BlastParams.params_for(b, ground_m, humidity, tod)
	var prof: Dictionary = b.get("profile", {})
	var ref_hum := float(prof.get("site_humidity", 0.35))
	var ref_tod := String(prof.get("tod_hist", "noon"))
	var q := BlastParams.params_for(b, float(b.get("rec_km", 10.0)) * 1000.0, ref_hum, ref_tod)
	var s_p := BlastSynth.shadow_of(p) / 0.6
	var s_q := BlastSynth.shadow_of(q) / 0.6
	var spl_p := spl_db(float(p["p_psi"]))
	var spl_q := spl_db(float(q["p_psi"]))
	var eff_p := spl_p - SHADOW_BROAD_DB * s_p
	var eff_q := spl_q - SHADOW_BROAD_DB * s_q
	var lufs := target_lufs(eff_p)
	var d_p := float(p["distance_m"])
	var d_q := float(q["distance_m"])
	# rumble share: more rumble far away and in the shadow (the scattered energy is not shadowed)
	var tail_rel := clampf(0.6 * (rumble_db(d_p) - rumble_db(d_q)) + 3.0 * (s_p - s_q), -4.0, 4.0)
	# the loudest moment as played: the report, or a later blow inside the tail (RDS-37's focused
	# second blow, Castle Bravo's run of bangs, Sedan's venting) at the tail's gain
	var m_front := float(e.get("m_front", e.get("m_max", -10.0)))
	var m_tail := float(e.get("m_tail", -30.0))
	if m_tail > m_front - 3.0:
		# that later blow is a direct arrival, not rumble: closer it is not turned down
		tail_rel = maxf(tail_rel, 0.0)
	var m_play := maxf(m_front, m_tail + tail_rel)
	var gain := lufs - m_play
	# spectrum: air absorption of the path difference at each site humidity, shadow HF loss
	var eq: Array[float] = []
	var rh_p := clampf(float(p["humidity"]), 0.05, 1.0) * 100.0
	var rh_q := clampf(ref_hum, 0.05, 1.0) * 100.0
	var dp_p := float(p["p_psi"]) * PA_PER_PSI
	var dp_q := float(q["p_psi"]) * PA_PER_PSI
	for f: float in EQ_BANDS:
		var a := absorption_db(f, d_p, rh_p, dp_p, s_p) - absorption_db(f, d_q, rh_q, dp_q, s_q)
		var g := -a - shadow_eq_db(f, s_p) + shadow_eq_db(f, s_q)
		eq.append(clampf(g, -40.0, 6.0))
	# a brightened event (closer than the recording) keeps its loudness target: the boost changes
	# the timbre, the level map already made it louder (a duller one keeps its physical loss)
	var bands: Dictionary = e.get("bands_db", {})
	var e0 := 0.0
	var e1 := 0.0
	for i in EQ_BANDS.size():
		var be := db_to_linear(2.0 * (float(bands.get(BAND_KEYS[i], -30.0)) + K_WEIGHT_DB[i]))
		e0 += be
		e1 += be * db_to_linear(2.0 * eq[i])
	var eq_lufs := 10.0 * log(maxf(e1, 1.0e-12) / maxf(e0, 1.0e-12)) / log(10.0)
	if eq_lufs > 0.0:
		gain -= eq_lufs
	# the sample's peak (-0.5 dBFS) never goes over -0.5 dBFS before the EQ, in front or tail
	var cap := -float(e.get("peak_dbfs", -0.5)) - 0.5
	var cap_loss := maxf(gain + maxf(tail_rel, 0.0) - cap, 0.0)
	gain = minf(gain, cap - maxf(tail_rel, 0.0))
	var kind := String(p.get("kind", ""))
	var buried := kind.contains("BURIED")
	# ground inversion: a later, duller arrival (as BlastSynth: 1.5-3.5 s, 0.5-0.9 of the first)
	var inv := func(t: String) -> bool: return t in ["dawn", "predawn", "night"]
	var rng := BlastDSP.Rng.new(int(b.get("num", 1)) * 7919 + int(ground_m))
	var echo := {}
	if inv.call(String(p["tod"])) and not inv.call(String(q["tod"])) and d_p > 3000.0 and not buried:
		# relative to the report as played: the echo (Blast bus, low-passed only) must not keep the
		# loudness the direct path lost to absorption and the shadow zone
		echo = {"delay_s": rng.range(1.5, 3.5), "db": gain + minf(eq_lufs, 0.0) + linear_to_db(rng.range(0.5, 0.8)),
				"lp_hz": clampf(BlastDSP.absorption_cutoff(d_p * 2.0, 6.0, rh_p, 15.0), 250.0, 2500.0)}
	else:
		rng.f()
		rng.f()
	# megatons: the rumble goes on for minutes (RDS-37: ~3 min at 70 km); a looped bed takes over
	# before the recording ends
	var w := float(p["yield_kt"])
	var ext := {}
	var rl := extra("rumble_loop")
	if w >= 400.0 and not rl.is_empty():
		var t_end := float(e.get("dur_s", 20.0))
		ext = {"t0_s": maxf(t_end - 9.0, 4.0), "att_s": 6.0,
				"dur_s": clampf(30.0 + 18.0 * log(w / 400.0) / log(10.0), 30.0, 75.0),
				"db": gain + tail_rel + float(e.get("m_tail", -14.0)) - 9.0 - float(rl.get("m_mean", -22.0)),
				"pitch": clampf(1.04 - 0.06 * log(w / 400.0) / log(10.0), 0.85, 1.04)}
	# window and fittings rattle (about 125-145 dB): below the debris layer's threshold
	var rattle := {}
	var rt := extra("rattle")
	var psi := float(p["p_psi"])
	var spl_out := spl_p - SHADOW_BROAD_DB * s_p
	if psi < 0.15 and spl_out >= 125.0 and not rt.is_empty():
		var rdb := lufs - 18.0 + 0.6 * minf(spl_out - 125.0, 15.0) - (6.0 if buried else 0.0)
		rattle = {"db": rdb - float(rt.get("m_max", -14.0)), "delay_s": 0.012,
				"pitch": clampf(1.0 + 0.05 * rng.s1(), 0.9, 1.1)}
	return {"id": id, "num": int(b.get("num", 0)), "front": String(e["front"]), "tail": String(e["tail"]),
		"tail_offset_s": float(e.get("tail_offset_s", 0.5)), "front_db": gain, "tail_db": gain + tail_rel,
		"tail_rel_db": tail_rel, "eq_db": eq, "pan": clampf(sin(deg_to_rad(az_deg)) * 0.35, -0.35, 0.35),
		"lufs": lufs, "cap_loss_db": cap_loss, "eq_lufs_db": eq_lufs,
		"play_lufs": maxf(m_front + gain, m_tail + gain + tail_rel) + eq_lufs, "spl_db": spl_p, "spl_eff_db": eff_p, "ref_spl_eff_db": eff_q,
		"shadow": s_p, "ref_shadow": s_q, "distance_m": d_p, "ref_distance_m": d_q, "tod": String(p["tod"]),
		"echo": echo, "ext": ext, "rattle": rattle, "dur_s": float(e.get("dur_s", 10.0))}
