extends RefCounted
## BlastSynth: per-event, physically parameterised synthesis of what the observer in the bunker
## hears from ONE explosion at ONE distance (built on a WorkerThreadPool task while the booster
## flies, so it is ready when the blast wave arrives; deterministic for a given input).
##
## Two streams are produced, both starting at the blast arrival (t = 0):
##   "front" (32 kHz stereo, a few s): the shock front and its immediate aftermath. The pressure
##           waveform is a Friedlander pulse (far field: an N-wave with a rear shock) with the
##           observer's positive-phase duration t+ (DNA / Kingery-Bulmash scaling) and a rise time
##           set by the shock strength (molecular relaxation, ~ 1/dp) and by turbulence; then the
##           scattered "rattle" of the front by turbulence, the burst-type signature (thermobaric
##           dispersal pop + slow whoomph, buried muffled heave, underwater water-hammer), and a
##           1st-order loudspeaker high-pass. Only weak (linear) components are ISO 9613-1 absorbed:
##           the shock front itself stays steep because nonlinear steepening balances absorption.
##   "tail"  (8 kHz stereo, up to ~2 min): the rolling rumble - echoes of the blast from the
##           mountains and ridges around the range (sparse reflector field: delay = extra path / c,
##           amplitude ~ 1/(r1 r2), each echo the pulse absorbed over its own path, panned by the
##           reflector's bearing), the diffuse late reverberation, eruption / water-column roar of
##           buried and underwater shots, and the long low roar of the rising fireball of big yields.
##
## Usage (no class_name on purpose):
##   const BlastSynth = preload("res://scripts/audio/blast_synth.gd")
##   var r: Dictionary = BlastSynth.make_event(params)   # {"front": AudioStreamWAV, "tail": ..., ...}

const BlastDSP = preload("res://scripts/audio/blast_dsp.gd")
const AudioSynth = preload("res://scripts/audio/audio_synth.gd")

const C0 := 343.0
const PA_PER_PSI := 6894.76
const FRONT_RATE := 32000.0
const TAIL_RATE := 8000.0
## The front stream starts this long before the blast arrival (room for zero-phase filtering).
const FRONT_PRE := 0.06


## params: yield_kt, kind (burst type string), nuclear, distance_m (slant, burst -> bunker),
## hob_m, p_psi (peak overpressure at the bunker), t_plus (s, positive phase at the bunker),
## humidity (0..1), seed. Optional: thermobaric_delay_s, eruption_s, eruption_dur_s.
static func make_event(p: Dictionary) -> Dictionary:
	var w := maxf(float(p.get("yield_kt", 1.0)), 1.0e-6)
	var kind := String(p.get("kind", "NUCLEAR_AIR"))
	var nuclear := bool(p.get("nuclear", w >= 0.01))
	var d := maxf(float(p.get("distance_m", 10000.0)), 50.0)
	var psi := maxf(float(p.get("p_psi", 0.1)), 1.0e-5)
	var tp := clampf(float(p.get("t_plus", 0.1)), 0.004, 30.0)
	var hum := clampf(float(p.get("humidity", 0.4)), 0.05, 1.0)
	var rh := hum * 100.0
	var sd := int(p.get("seed", 1))
	var rng := BlastDSP.Rng.new(sd)
	var buried := kind.contains("BURIED")
	var underwater := kind.contains("UNDERWATER")
	var thermobaric := kind == "THERMOBARIC"
	var dp := psi * PA_PER_PSI
	var hob := maxf(float(p.get("hob_m", 0.0)), 0.0)
	var dg := maxf(sqrt(maxf(d * d - hob * hob, 1.0)), 50.0)
	# Atmosphere preset from the time of day: noon = lapse (sound bends up: beyond the geometric
	# shadow onset x_s = sqrt(2 * 86 km * H) + 0.6 km only diffracted, duller sound arrives);
	# dawn / pre-dawn / night = ground inversion (no shadow, extra 'reflected' arrivals, as at
	# Trinity and RDS-37); dusk = neutral.
	var tod := String(p.get("tod", "noon"))
	var inversion := tod in ["dawn", "predawn", "night"]
	var shadow := 0.0
	if tod == "noon":
		# the shock is not a point source: until it decays to ~1 psi it runs as a nonlinear
		# hemisphere hundreds of metres to kilometres tall, so the effective source height is a
		# quarter of the 1-psi radius (megatons are heard loud at 50-100 km by day); over the sea
		# the lapse is weak (marine layer) and the shadow shallower
		var h_eff := maxf(hob, 0.25 * float(p.get("r1psi_m", 0.0)))
		var xs := sqrt(2.0 * 86000.0 * maxf(h_eff, 2.0)) + 600.0
		shadow = smoothstep(xs, 3.0 * xs, dg) * 0.6 * (0.5 if bool(p.get("over_water", false)) else 1.0)

	# ------------------------------------------------------------------ the front (32 kHz)
	var front_dur := clampf(1.2 + 1.2 * minf(tp, 1.0) + d / 60000.0, 1.4, 3.0)
	if thermobaric:
		front_dur += 0.6
	var nf := int(front_dur * FRONT_RATE)
	var press := PackedFloat32Array()
	press.resize(nf)
	var t0 := int(FRONT_PRE * FRONT_RATE)
	# Rise time (research: sonic-boom and explosion data): tau = tau0 (100 Pa / dp) F_turb, with
	# tau0 = 0.5 ms in humid air .. 1.5 ms in dry air (molecular relaxation) and F_turb 1-4
	# (turbulence), clamped to 20 us .. 15 ms. tau sets the 'crack' corner f ~ 1 / (pi tau).
	var f_turb := 1.0 + 2.0 * rng.f() * clampf(d / 5000.0, 0.3, 1.0)
	var rise := lerpf(1.5e-3, 0.5e-3, hum) * (100.0 / maxf(dp, 1.0)) * f_turb
	rise = clampf(rise * (1.0 + 6.0 * shadow), 2.0e-5, 0.03)
	var tpp := tp
	if buried:
		# camouflet: the ground heave pushes the air - a slow, muffled pulse (tau 5-20 ms, t+ x2.5)
		rise = maxf(rise, 0.012)
		tpp = tp * 2.5
	elif underwater:
		rise = maxf(rise, 0.008)
		tpp = tp * 1.6
	elif thermobaric:
		tpp = tp * 1.7
	# Pulse shape morphs with the scaled distance Z = R / W^(1/3) (m/kg^1/3): Friedlander below
	# Z ~ 100, a rounded N-wave (negative lobe ~45 % for ~1.2 t+) beyond Z ~ 500
	var zs := d / pow(w * 1.0e6, 1.0 / 3.0)
	var nwave_k := smoothstep(log(100.0), log(500.0), log(maxf(zs, 1.0))) if not (buried or underwater) else 0.0
	if thermobaric:
		# FAE: a faint dispersal pop (-30 dB), then the cloud detonation (fae_delay later, as in the
		# visuals) whose onset is smeared over ~0.1 s (cloud size / c): a 'whoomph' with a long
		# positive phase
		var dly := maxf(float(p.get("thermobaric_delay_s", 0.0)), 0.0)
		_add_pulse(press, t0, FRONT_RATE, tp * 0.2, 0.032, rise, 0.0)
		_add_pulse(press, t0 + int(dly * FRONT_RATE), FRONT_RATE, tpp, 1.0, maxf(rise, 0.03), nwave_k * 0.5)
	else:
		_add_pulse(press, t0, FRONT_RATE, tpp, 1.0, rise, nwave_k)
	if buried:
		# gas venting through the crater: a second, weaker and slower pulse ~0.5 s later
		_add_pulse(press, t0 + int(0.5 * FRONT_RATE), FRONT_RATE, tpp * 1.4, 0.45, 0.02, 0.0)
	# loudspeaker/headphone band: below ~16 Hz nothing moves; keep it as a 1st-order roll-off.
	# Air absorption of the front: a strong shock stays steep (nonlinear steepening balances
	# absorption), so the absorbing path is shortened for strong fronts (to ~15 % above ~700 Pa).
	# (research: apply absorption fully to weak fronts, cap it at ~6 dB while dp > 150 Pa; a
	# shadowed, diffracted front gets the full absorption)
	var floor_g := db_to_linear(-6.0) * smoothstep(100.0, 150.0, dp) * (1.0 - shadow / 0.6)
	var direct := BlastDSP.absorb(press, FRONT_RATE, d, rh, 15.0, 0.0, 0.0, floor_g)
	# the loudspeaker roll-off is causal: a zero-phase 16 Hz high-pass would put a large acausal
	# pre-swing before the shock (a DC step at the start of the stream)
	AudioSynth.hp1(direct, 16.0, FRONT_RATE)
	if nuclear and not (buried or underwater):
		# the heavy 'body' of a nuclear report on loudspeakers: a 55 -> 32 Hz thump that lasts about
		# min(t+, 0.5 s), riding on the front (research: designed 30-60 Hz burst for nuclear)
		var th := AudioSynth.sweep(nf - t0, FRONT_RATE, 55.0, 32.0, minf(tpp, 0.5), 0.004, minf(tpp, 0.5) * 0.45)
		AudioSynth.add(direct, th, t0, 0.32 * AudioSynth.peak(direct))
	# scattered copies of the front (turbulence, terrain diffraction): a dense, decaying rattle
	# right behind the bang that grows with range
	var scat := PackedFloat32Array()
	scat.resize(nf)
	var spread := clampf(0.06 + 0.35 * pow(d / 10000.0, 0.7), 0.05, 2.5)
	var n_sc := int(clampf(40.0 + 30.0 * d / 10000.0, 40.0, 220.0))
	# two precomputed step kernels (sharper / softer scattered fronts), added as scaled copies
	var sk_dec := clampf(tp * 0.3, 0.004, 0.08)
	var sk_a := _step_kernel(FRONT_RATE, rise * 2.0, sk_dec)
	var sk_b := _step_kernel(FRONT_RATE, rise * 6.0, sk_dec * 1.6)
	for k in n_sc:
		var dt := -spread * log(1.0 - 0.999 * rng.f()) * 0.6
		var a := rng.range(0.03, 0.16) * exp(-dt / (spread * 1.5)) * (1.0 if rng.f() > 0.3 else -0.6)
		AudioSynth.add(scat, sk_a if rng.f() < 0.5 else sk_b, t0 + int(dt * FRONT_RATE), a)
	scat = BlastDSP.absorb(scat, FRONT_RATE, d * 1.05, rh, 15.0, 0.0)
	AudioSynth.hp1(scat, 30.0, FRONT_RATE)
	var fl := direct.duplicate()
	var fr := direct.duplicate()
	var sg := 0.55 + 0.25 * clampf(d / 50000.0, 0.0, 1.0)
	for i in nf:
		var s := scat[i] * sg
		fl[i] += s
		fr[i] += s * 0.82
	# decorrelate L/R of the rattle a little (a few ms)
	var sh := int(0.0037 * FRONT_RATE)
	for i in range(nf - 1, sh, -1):
		fr[i] += scat[i - sh] * sg * 0.35 - scat[i] * sg * 0.17
	# body: the long positive phase of big yields is felt as a push; on speakers it becomes the
	# low roar of everything that rattles plus the harmonics of the pressure pulse
	var body_k := clampf((tp - 0.25) / 1.0, 0.0, 1.0) * 0.35
	if body_k > 0.0:
		var bn := AudioSynth.noise(nf, sd + 11)
		AudioSynth.lp1(bn, 70.0, FRONT_RATE)
		AudioSynth.lp1(bn, 70.0, FRONT_RATE)
		AudioSynth.hp1(bn, 18.0, FRONT_RATE)
		AudioSynth.normalize(bn, 1.0)
		var att := exp(-1.0 / (0.01 * FRONT_RATE))
		var dec := exp(-1.0 / (minf(tp * 1.4, 4.0) * FRONT_RATE))
		var ea := 1.0
		var ed := 1.0
		for i in range(t0, nf):
			var e := (1.0 - ea) * ed * 0.32 * body_k
			fl[i] += bn[i] * e
			fr[i] += bn[i] * e * 0.9
			ea *= att
			ed *= dec
	# the stream starts from silence (the absorption filter's short pre-response is faded in)
	_taper(fl, FRONT_RATE, 0.02, 0.0)
	_taper(fr, FRONT_RATE, 0.02, 0.0)
	_fade(fl, FRONT_RATE, 0.25)
	_fade(fr, FRONT_RATE, 0.25)
	var pk := maxf(AudioSynth.peak(fl), AudioSynth.peak(fr))
	var front := AudioSynth.to_wav_stereo(fl, fr, int(FRONT_RATE), false, 0.95 / maxf(pk, 1e-9))

	# ------------------------------------------------------------------ the tail (8 kHz)
	# rolling-rumble decay (research: ~0.5 s at 1 km, ~2 s at 3 km, 4-6 s at 10-15 km for bombs;
	# tens of seconds for kiloton-class events in hilly terrain)
	var tau_tail := clampf(0.55 * pow(d / 1000.0, 0.9) * (1.0 + 0.5 * log(1.0 + w) / log(10.0)), 0.4, 25.0)
	var tail_dur := clampf(maxf(14.0 + 9.0 * log(1.0 + w) / log(10.0) + d / 4000.0, 6.0 * tau_tail), 10.0, 130.0)
	var nt := int(tail_dur * TAIL_RATE)
	var tl := PackedFloat32Array()
	tl.resize(nt)
	var tr := PackedFloat32Array()
	tr.resize(nt)
	# echo kernels: the pulse absorbed over three representative echo path lengths
	var kn := int(clampf(2.2 * tp + 0.5, 0.5, 1.4) * TAIL_RATE)
	var kpre := int(0.25 * TAIL_RATE)
	kn += kpre
	var kpulse := PackedFloat32Array()
	kpulse.resize(kn)
	var krise := maxf(rise * 8.0, 0.004)
	_add_pulse(kpulse, kpre, TAIL_RATE, tpp, 1.0, krise, nwave_k * 0.6)
	_fade(kpulse, TAIL_RATE, kn / TAIL_RATE * 0.35)
	var kernels: Array[PackedFloat32Array] = []
	var kpaths := [d + 6000.0, d + 25000.0, d + 70000.0]
	for kp: float in kpaths:
		var ker := BlastDSP.absorb(kpulse, TAIL_RATE, kp, rh, 15.0, 18.0, 900.0)
		# the zero-phase absorption filter spreads the pulse both ways: taper the truncated edges
		# (an abrupt end would click in every echo)
		_taper(ker, TAIL_RATE, 0.12, 0.15)
		kernels.append(ker)
	# Echo field in the bunker frame (observer at the origin facing +x, ground zero at dg):
	#  - LOCAL scatterers (hills, gullies, outcrops, structures within a few km of the source and
	#    the observer) give the dense rolling rumble of the first seconds;
	#  - RIDGES and mountain ranges 8-70 km away give the discrete late echoes.
	# Each population is built separately and scaled to a target level relative to the direct
	# pulse (energy ratio), so the balance does not depend on how many reflectors happen to land
	# where; amplitude ~ 1/(r1 r2) only shapes the distribution inside a population.
	var d_ref_rms := _rms(kernels[0], kpre, mini(kernels[0].size(), kpre + int(maxf(tp, 0.05) * TAIL_RATE))) + 1e-9
	var lg := log(1.0 + w) / log(10.0)
	var dkm := log(maxf(d / 1000.0, 0.5)) / log(10.0)
	var loc_l := PackedFloat32Array()
	loc_l.resize(nt)
	var loc_r := PackedFloat32Array()
	loc_r.resize(nt)
	var r_loc := 0.6 * dg + 3000.0
	var n_loc := 180
	for k in n_loc:
		var u := sqrt(rng.f()) * r_loc
		var th := rng.f() * TAU
		var rx := dg * 0.5 + u * cos(th)
		var ry := u * sin(th)
		var r1 := maxf(sqrt((rx - dg) * (rx - dg) + ry * ry), 50.0)
		var r2 := maxf(sqrt(rx * rx + ry * ry), 50.0)
		var dly := (r1 + r2 - dg) / C0
		if dly > tail_dur - 1.0 or dly < 0.05:
			continue
		var a := dg / (r1 * r2) * 1000.0 * rng.range(0.3, 1.0) * (1.0 if rng.f() > 0.25 else -0.7) * exp(-dly / tau_tail)
		var pan := clampf(ry / r2, -1.0, 1.0)
		var kidx := 0 if dly < 8.0 else 1
		_add_scaled(loc_l, loc_r, kernels[kidx], int(dly * TAIL_RATE) - kpre, a * sqrt(0.5 * (1.0 + pan)), a * sqrt(0.5 * (1.0 - pan)))
	# rumble level: scattering grows with range (more terrain in between, refraction), and big
	# yields roll longer (the source itself is kilometres wide)
	# direct-to-rumble ratio (research): about -25 dB within 2 km, -6..-15 dB beyond 20 km
	var loc_db := clampf(-25.0 + 12.0 * log(maxf(d / 2000.0, 1.0)) / log(10.0), -25.0, -9.0)
	loc_db += 2.0 * clampf(log(maxf(w, 1.0)) / log(10.0) / 4.7, 0.0, 1.0) + 4.0 * shadow + float(p.get("rumble_db", 0.0))
	# no single echo may be louder than half the (absorbed) direct pulse
	var echo_cap := 0.5 * AudioSynth.peak(kernels[0])
	_mix_scaled(tl, tr, loc_l, loc_r, d_ref_rms * db_to_linear(loc_db), TAIL_RATE, 0.2, 4.0, echo_cap)
	var rid_l := PackedFloat32Array()
	rid_l.resize(nt)
	var rid_r := PackedFloat32Array()
	rid_r.resize(nt)
	var n_ref := int(clampf(90.0 + 30.0 * lg, 90.0, 220.0))
	# smear kernel: low-passed (500 Hz) noise with a 0.6 s exponential decay (-36 dB at its end, plus
	# a taper: no audible cut-off), energy-matched to the echo kernel
	var smear_k := AudioSynth.noise(int(2.5 * TAIL_RATE), sd + 51)
	AudioSynth.lp1(smear_k, 500.0, TAIL_RATE)
	AudioSynth.lp1(smear_k, 500.0, TAIL_RATE)
	AudioSynth.env_ad(smear_k, TAIL_RATE, 0.05, 0.6)
	_fade(smear_k, TAIL_RATE, 0.8)
	# the smeared energy travelled as far as the echo itself: same air absorption (a 30-70 km echo
	# keeps almost nothing above ~150 Hz)
	var smears: Array[PackedFloat32Array] = [smear_k]
	var smear_gs: Array[float] = [0.0]
	for kk in [1, 2]:
		var sk := BlastDSP.absorb(smear_k, TAIL_RATE, kpaths[kk], rh, 15.0, 18.0, 900.0)
		_taper(sk, TAIL_RATE, 0.02, 0.3)
		smears.append(sk)
		smear_gs.append(_rms(kernels[kk], kpre, kpre + int(maxf(tp, 0.05) * TAIL_RATE)) / maxf(_rms(sk, 0, int(0.8 * TAIL_RATE)), 1e-9) * 0.5)
	var got := 0
	var t_first := 1.0e9
	var t_last := 0.0
	for k in n_ref:
		var rr := 8000.0 + 62000.0 * pow(rng.f(), 0.8)
		var th := rng.f() * TAU
		var rx := rr * cos(th)
		var ry := rr * sin(th)
		var r1 := sqrt((rx - dg) * (rx - dg) + ry * ry)
		var extra := r1 + rr - dg
		var dly := extra / C0
		if dly > tail_dur - 1.0:
			continue
		got += 1
		t_first = minf(t_first, dly)
		t_last = maxf(t_last, dly)
		# a ridge right next to ground zero is not a point mirror 1 m away: bound the geometry (a
		# ridge is kilometres long), otherwise 1 / r1 makes one echo louder than the blast
		var a := dg / (maxf(r1, maxf(2000.0, 0.1 * rr)) * rr) * 1.0e4 * rng.range(0.4, 1.2)
		var kidx := 1 if extra < 50000.0 else 2
		var pan := clampf(ry / rr, -1.0, 1.0)
		_add_scaled(rid_l, rid_r, kernels[kidx], int(dly * TAIL_RATE) - kpre, a * 0.6 * sqrt(0.5 * (1.0 + pan)), a * 0.6 * sqrt(0.5 * (1.0 - pan)))
		# a mountainside reflects diffusely: the echo is smeared over ~0.5-2 s
		var smg: float = smear_gs[kidx]
		_add_scaled(rid_l, rid_r, smears[kidx], int(dly * TAIL_RATE), a * sqrt(0.5 * (1.0 + pan)) * smg, a * sqrt(0.5 * (1.0 - pan)) * smg)
	if got > 0:
		var rid_db := clampf(-21.0 + 3.0 * dkm + 1.5 * lg, -26.0, -10.0) + float(p.get("echo_db", 0.0))
		# level set over the span the echoes actually occupy (a fixed 20-90 s window was empty for
		# short tails: its tiny residue blew the gain up by 1e5), capped like the local echoes
		var w0 := maxf(t_first, 0.0)
		var w1 := clampf(t_last + 2.5, w0 + 1.0, tail_dur)
		_mix_scaled(tl, tr, rid_l, rid_r, d_ref_rms * db_to_linear(rid_db), TAIL_RATE, w0, w1, echo_cap)
	# diffuse late reverberation: noise whose envelope follows the echo energy, darker with time
	var env_l := _envelope(tl, TAIL_RATE, 2.5)
	var env_r := _envelope(tr, TAIL_RATE, 2.5)
	# continuous coda bed under the echoes (research: T60 = 3 + 2 log10(W + 1) + R_km / 20 s, capped
	# at 40 s, starting ~10 dB under the front): no silent gaps between mountain echoes
	var t60 := clampf(3.0 + 2.0 * lg + d / 20000.0, 3.0, 40.0)
	var bed0 := d_ref_rms * db_to_linear(-14.0 + 3.0 * clampf(dkm, 0.0, 2.0))
	var kb := exp(-6.9 / (t60 * TAIL_RATE))
	var eb := bed0
	# the reverberant field between distant echoes decays slowly (release ~2.5 s close, up to 8 s far
	# away): echoes ride on a continuous rumble instead of starting from silence
	var rel := exp(-1.0 / (clampf(1.5 + d / 5000.0, 2.5, 8.0) * TAIL_RATE))
	var hl := 0.0
	var hr := 0.0
	for i in nt:
		hl = maxf(env_l[i], hl * rel)
		hr = maxf(env_r[i], hr * rel)
		env_l[i] = maxf(hl, eb)
		env_r[i] = maxf(hr, eb)
		eb *= kb
	var dn := AudioSynth.noise(nt, sd + 21)
	var dn2 := AudioSynth.noise(nt, sd + 22)
	var c1 := 0.0
	var c2 := 0.0
	var c3 := 0.0
	var c4 := 0.0
	var al := 0.0
	var roll := AudioSynth.smooth_noise(nt, sd + 23, 2.5, TAIL_RATE)
	for i in nt:
		if i & 255 == 0:
			var tt := float(i) / TAIL_RATE
			al = 1.0 - exp(-TAU * (380.0 / (1.0 + tt / 12.0)) / TAIL_RATE)
		c1 += al * (dn[i] - c1)
		c2 += al * (c1 - c2)
		c3 += al * (dn2[i] - c3)
		c4 += al * (c3 - c4)
		var rm := 0.75 + 0.25 * roll[i]
		tl[i] += c2 * env_l[i] * 3.2 * rm
		tr[i] += c4 * env_r[i] * 3.2 * rm
	# burst-type extras
	if buried or underwater:
		# eruption / water column and the debris or water falling back: a long low roar
		var e0 := float(p.get("eruption_s", 0.6))
		var ed := float(p.get("eruption_dur_s", 8.0 if underwater else 5.0))
		_add_roar(tl, tr, TAIL_RATE, e0, ed, 0.45, 220.0 if underwater else 140.0, sd + 31, rng)
	if inversion and d > 3000.0 and not buried:
		# ground inversion: 1-2 further arrivals 1.5-6 s after the first, nearly as strong and a
		# little duller ('knocked off our feet by a reflected shock wave', RDS-37 at 32 km)
		var n_inv := 1 if d < 15000.0 else 2
		for k in n_inv:
			var dl := rng.range(1.5, 3.5) + 2.2 * k
			var g := rng.range(0.5, 0.9) * (0.8 if k > 0 else 1.0)
			_add_scaled(tl, tr, kernels[0], int(dl * TAIL_RATE) - kpre, g * rng.range(0.85, 1.0), g * rng.range(0.85, 1.0))
	if w >= 1000.0 and (underwater or bool(p.get("over_water", false)) or d > 80000.0):
		# megatons over water / far away: an 'avalanche' of several bangs (atmospheric multipath)
		var n_sub := 3 + int(rng.f() * 5.0)
		for k in n_sub:
			var dl := rng.range(1.0, 15.0)
			var g := rng.range(0.25, 0.6) * exp(-dl / 20.0)
			_add_scaled(tl, tr, kernels[1], int(dl * TAIL_RATE) - kpre, g * rng.range(0.7, 1.0), g * rng.range(0.7, 1.0))
	# blast wind: the air behind the front moves at u = dp / (rho c) ~ dp / 412 m/s; above ~3 m/s it
	# is heard as a gust/roar for the positive phase (Farrell at 9 km: 'the strong, sustained, awesome
	# roar'), reversing in the suction phase
	var u := dp / 412.0
	if u > 1.5 and not buried:
		var wn := AudioSynth.noise(nt, sd + 61)
		AudioSynth.lp1(wn, 380.0, TAIL_RATE)
		AudioSynth.lp1(wn, 380.0, TAIL_RATE)
		AudioSynth.hp1(wn, 25.0, TAIL_RATE)
		AudioSynth.normalize(wn, 1.0)
		var wg := clampf(u * u / 225.0, 0.02, 1.0) * d_ref_rms * 2.2
		var gust := AudioSynth.smooth_noise(nt, sd + 62, 3.0, TAIL_RATE)
		for i in mini(nt, int(3.5 * tpp * TAIL_RATE)):
			var x := float(i) / TAIL_RATE / tpp
			var pv := (1.0 - x) * exp(-x)
			var e := pv * pv * (1.0 - exp(-x * 40.0)) * (0.75 + 0.25 * gust[i])
			tl[i] += wn[i] * e * wg
			tr[i] += wn[(i + 997) % nt] * e * wg
	AudioSynth.hp1(tl, 16.0, TAIL_RATE)
	AudioSynth.hp1(tr, 16.0, TAIL_RATE)
	_fade(tl, TAIL_RATE, 3.0)
	_fade(tr, TAIL_RATE, 3.0)
	var pt := maxf(AudioSynth.peak(tl), AudioSynth.peak(tr))
	var tail := AudioSynth.to_wav_stereo(tl, tr, int(TAIL_RATE), false, 0.95 / maxf(pt, 1e-9))
	var spl := 20.0 * log(maxf(dp, 1e-3) / 2.0e-5) / log(10.0)
	var front_db := _map_spl(spl) - 12.0 * shadow
	# both streams are normalised to the same peak: playing the tail at tail_gain_db relative to the
	# front restores their physical ratio
	return {"front": front, "tail": tail, "front_dur": front_dur, "tail_dur": tail_dur, "tau_tail": tau_tail,
		"front_db": front_db, "spl_db": spl, "shadow": shadow,
		"front_peak": pk, "tail_peak": pt, "tail_gain_db": linear_to_db(maxf(pt, 1e-9) / maxf(pk, 1e-9)),
		"rise_s": rise, "t_plus": tp}


# ------------------------------------------------------------------ building blocks

## Friedlander pulse (1 - t/t+) e^(-t/t+) with a finite rise; nk 0..1 morphs it into an N-wave
## (linear fall to -1 at 2 t+, then a rear shock back to 0 with the same rise time).
static func _add_pulse(buf: PackedFloat32Array, start: int, rate: float, tp: float, amp: float, rise: float, nk: float) -> void:
	var n := buf.size()
	var tr := maxf(rise, 1.0 / rate)
	var i := start
	while i < n:
		var t := float(i - start) / rate
		if t > 8.0 * tp + 10.0 * tr:
			break
		var x := t / tp
		var fr := (1.0 - x) * exp(-x)
		# rounded N-wave: linear fall to 0 at t+, a negative lobe of ~45 % over 1.2 t+, then back
		var nw := 1.0 - x if x < 1.0 else (-0.45 * sin(PI * (x - 1.0) / 1.2) if x < 2.2 else 0.0)
		var rf := 1.0 - exp(-t / (tr * 0.45))
		buf[i] += lerpf(fr, nw, nk) * rf * amp
		i += 1


## Precomputed scattered-front kernel: rise tr, then (1 - t/dec) e^(-t/dec).
static func _step_kernel(rate: float, tr: float, dec: float) -> PackedFloat32Array:
	var m := int((dec * 5.0 + tr * 6.0) * rate) + 1
	var k := PackedFloat32Array()
	k.resize(m)
	var kr := 1.0 / maxf(tr * 0.45 * rate, 1.0)
	var kd := 1.0 / maxf(dec * rate, 1.0)
	for j in m:
		var fj := float(j)
		k[j] = (1.0 - exp(-fj * kr)) * (1.0 - fj * kd) * exp(-fj * kd)
	return k


## A small step (scattered front): rise tr, decaying over `dec` seconds.
static func _add_step(buf: PackedFloat32Array, start: int, rate: float, amp: float, tr: float, dec: float) -> void:
	var n := buf.size()
	if start >= n or start < 0:
		return
	var m := mini(n - start, int((dec * 6.0 + tr * 8.0) * rate))
	var kr := 1.0 / maxf(tr * 0.45 * rate, 1.0)
	var kd := 1.0 / maxf(dec * rate, 1.0)
	for j in m:
		var fj := float(j)
		buf[start + j] += amp * (1.0 - exp(-fj * kr)) * (1.0 - fj * kd) * exp(-fj * kd)


static func _add_scaled(l: PackedFloat32Array, r: PackedFloat32Array, k: PackedFloat32Array, off: int, gl: float, gr: float) -> void:
	var n := l.size()
	if off >= n:
		return
	var m := mini(k.size(), n - off)
	for j in range(maxi(0, -off), m):
		var v := k[j]
		l[off + j] += v * gl
		r[off + j] += v * gr


## Output level (dBFS of the front's peak) for a physical peak SPL: a compressive map
## (research: 100 dB -> -30, 120 -> -18, 140 -> -10, 160 -> -4, >= 180 -> -1 dBFS).
static func _map_spl(spl: float) -> float:
	var xs := [80.0, 100.0, 120.0, 140.0, 160.0, 180.0]
	var ys := [-42.0, -30.0, -18.0, -10.0, -4.0, -1.0]
	if spl <= xs[0]:
		return ys[0]
	for i in range(1, xs.size()):
		if spl <= xs[i]:
			return lerpf(ys[i - 1], ys[i], (spl - xs[i - 1]) / (xs[i] - xs[i - 1]))
	return -1.0


## Adds (sl, sr) to (l, r) scaled so that its RMS over [t0, t1] equals target_rms; with
## max_peak > 0 the gain is also limited so that the added signal's peak stays <= max_peak.
static func _mix_scaled(l: PackedFloat32Array, r: PackedFloat32Array, sl: PackedFloat32Array, sr: PackedFloat32Array, target_rms: float, rate: float, t0: float, t1: float, max_peak: float = 0.0) -> void:
	var a := int(t0 * rate)
	var b := mini(int(t1 * rate), sl.size())
	var cur := maxf(_rms(sl, a, b), _rms(sr, a, b))
	if cur <= 1e-12:
		return
	var g := target_rms / cur
	if max_peak > 0.0:
		var sp := maxf(AudioSynth.peak(sl), AudioSynth.peak(sr))
		if sp > 1e-12:
			g = minf(g, max_peak / sp)
	for i in l.size():
		l[i] += sl[i] * g
		r[i] += sr[i] * g


## Smoothed absolute envelope (one-pole, time constant tau).
static func _envelope(x: PackedFloat32Array, rate: float, tau: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(x.size())
	var a := 1.0 - exp(-1.0 / (tau * rate))
	var e := 0.0
	for i in x.size():
		e += a * (absf(x[i]) - e)
		out[i] = e
	return out


## Low roar (band-limited noise) starting at t0, swelling and decaying over dur.
static func _add_roar(l: PackedFloat32Array, r: PackedFloat32Array, rate: float, t0: float, dur: float, gain: float, fc: float, sd: int, rng: BlastDSP.Rng) -> void:
	var n := l.size()
	var s0 := int(t0 * rate)
	if s0 >= n:
		return
	var m := mini(n - s0, int(dur * 1.6 * rate))
	var nl := AudioSynth.noise(m, sd)
	var nr := AudioSynth.noise(m, sd + 1)
	var mod := AudioSynth.smooth_noise(m, sd + 2, 1.2, rate)
	AudioSynth.lp1(nl, fc, rate)
	AudioSynth.lp1(nl, fc, rate)
	AudioSynth.lp1(nr, fc, rate)
	AudioSynth.lp1(nr, fc, rate)
	AudioSynth.hp1(nl, 22.0, rate)
	AudioSynth.hp1(nr, 22.0, rate)
	AudioSynth.normalize(nl, 1.0)
	AudioSynth.normalize(nr, 1.0)
	# reference level: the mean level of the existing tail around t0 (so the roar sits in the mix)
	var ref := 0.0
	var c := 0
	for j in range(maxi(s0 - int(0.5 * rate), 0), mini(s0 + int(2.0 * rate), n)):
		ref += absf(l[j])
		c += 1
	ref = maxf(ref / maxf(float(c), 1.0), 1e-4)
	for j in m:
		var t := float(j) / rate
		var e := (1.0 - exp(-t / (0.12 * dur))) * exp(-t / (0.55 * dur)) * (0.7 + 0.3 * mod[j])
		l[s0 + j] += nl[j] * e * gain * ref * 6.0
		r[s0 + j] += nr[j] * e * gain * ref * 6.0


## Raised-cosine fade-in over a_s and fade-out over b_s seconds, in place.
static func _taper(x: PackedFloat32Array, rate: float, a_s: float, b_s: float) -> void:
	var n := x.size()
	var ma := mini(n / 2, int(a_s * rate))
	var mb := mini(n / 2, int(b_s * rate))
	for j in ma:
		x[j] *= 0.5 - 0.5 * cos(PI * float(j) / float(ma))
	for j in mb:
		x[n - 1 - j] *= 0.5 - 0.5 * cos(PI * float(j) / float(mb))


static func _fade(x: PackedFloat32Array, rate: float, secs: float) -> void:
	var n := x.size()
	var m := mini(n, int(secs * rate))
	for j in m:
		x[n - 1 - j] *= float(j) / float(m)


static func _rms(x: PackedFloat32Array, a: int, b: int) -> float:
	var s := 0.0
	var c := 0
	for i in range(clampi(a, 0, x.size()), clampi(b, 0, x.size())):
		s += x[i] * x[i]
		c += 1
	return sqrt(s / maxf(float(c), 1.0))
