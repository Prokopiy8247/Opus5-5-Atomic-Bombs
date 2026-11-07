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

	# ------------------------------------------------------------------ the front (32 kHz)
	var front_dur := clampf(1.2 + 1.2 * minf(tp, 1.0) + d / 60000.0, 1.4, 3.0)
	if thermobaric:
		front_dur += 0.6
	var nf := int(front_dur * FRONT_RATE)
	var press := PackedFloat32Array()
	press.resize(nf)
	var t0 := int(FRONT_PRE * FRONT_RATE)
	# rise time: molecular relaxation (~0.15 Pa*s / dp, sonic-boom data ~3 ms at 48 Pa) plus
	# turbulence, which grows with range; buried / underwater pulses rise slowly (heave, water)
	var rise := 0.15 / maxf(dp, 1.0) + 2.0e-4 * sqrt(d / 1000.0)
	if buried:
		rise = maxf(rise, 0.25 * tp)
	elif underwater:
		rise = maxf(rise, 0.12 * tp)
	rise = clampf(rise, 3.0e-5, 0.5)
	# far field (< ~1 psi) the Friedlander pulse has evolved into an N-wave with a rear shock
	var nwave_k := clampf((1.0 - psi) / 0.8, 0.0, 1.0) if not (buried or underwater) else 0.0
	_add_pulse(press, t0, FRONT_RATE, tp, 1.0, rise, nwave_k)
	if thermobaric:
		# FAE: dispersal charge (small sharp pop) ~0.15 s before the main, slower 'whoomph'
		var dly := float(p.get("thermobaric_delay_s", 0.15))
		var main := PackedFloat32Array()
		main.resize(nf)
		_add_pulse(main, t0, FRONT_RATE, tp * 1.6, 1.0, maxf(rise, 0.004), 0.0)
		press.fill(0.0)
		_add_pulse(press, t0, FRONT_RATE, tp * 0.25, 0.12, rise, 0.0)
		AudioSynth.add(press, main, int(dly * FRONT_RATE), 1.0)
	# loudspeaker/headphone band: below ~16 Hz nothing moves; keep it as a 1st-order roll-off
	var direct := AudioSynth.hp1(press.duplicate(), 16.0, FRONT_RATE)
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
	scat = BlastDSP.absorb(scat, FRONT_RATE, d * 1.05, rh, 15.0, 30.0)
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
	var body_k := clampf((tp - 0.25) / 1.0, 0.0, 1.0) * 0.6
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
	_fade(fl, FRONT_RATE, 0.25)
	_fade(fr, FRONT_RATE, 0.25)
	var pk := maxf(AudioSynth.peak(fl), AudioSynth.peak(fr))
	var front := AudioSynth.to_wav_stereo(fl, fr, int(FRONT_RATE), false, 0.95 / maxf(pk, 1e-9))

	# ------------------------------------------------------------------ the tail (8 kHz)
	var tail_dur := clampf(14.0 + 9.0 * log(1.0 + w) / log(10.0) + d / 4000.0, 10.0, 130.0)
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
	_add_pulse(kpulse, kpre, TAIL_RATE, tp * (1.6 if thermobaric else 1.0), 1.0, krise, nwave_k * 0.6)
	_fade(kpulse, TAIL_RATE, kn / TAIL_RATE * 0.35)
	var kernels: Array[PackedFloat32Array] = []
	var kpaths := [d + 6000.0, d + 25000.0, d + 70000.0]
	for kp: float in kpaths:
		kernels.append(BlastDSP.absorb(kpulse, TAIL_RATE, kp, rh, 15.0, 18.0, 900.0))
	# Echo field in the bunker frame (observer at the origin facing +x, ground zero at dg):
	#  - LOCAL scatterers (hills, gullies, outcrops, structures within a few km of the source and
	#    the observer) give the dense rolling rumble of the first seconds;
	#  - RIDGES and mountain ranges 8-70 km away give the discrete late echoes.
	# Each population is built separately and scaled to a target level relative to the direct
	# pulse (energy ratio), so the balance does not depend on how many reflectors happen to land
	# where; amplitude ~ 1/(r1 r2) only shapes the distribution inside a population.
	var dg := maxf(sqrt(maxf(d * d - float(p.get("hob_m", 0.0)) ** 2, 1.0)), 50.0)
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
		var a := dg / (r1 * r2) * 1000.0 * rng.range(0.3, 1.0) * (1.0 if rng.f() > 0.25 else -0.7)
		var pan := clampf(ry / r2, -1.0, 1.0)
		var kidx := 0 if dly < 8.0 else 1
		_add_scaled(loc_l, loc_r, kernels[kidx], int(dly * TAIL_RATE) - kpre, a * sqrt(0.5 * (1.0 + pan)), a * sqrt(0.5 * (1.0 - pan)))
	# rumble level: scattering grows with range (more terrain in between, refraction), and big
	# yields roll longer (the source itself is kilometres wide)
	var loc_db := clampf(-15.0 + 5.0 * dkm + 1.0 * lg, -18.0, -5.0) + float(p.get("rumble_db", 0.0))
	_mix_scaled(tl, tr, loc_l, loc_r, d_ref_rms * db_to_linear(loc_db), TAIL_RATE, 0.2, 4.0)
	var rid_l := PackedFloat32Array()
	rid_l.resize(nt)
	var rid_r := PackedFloat32Array()
	rid_r.resize(nt)
	var n_ref := int(clampf(90.0 + 30.0 * lg, 90.0, 220.0))
	var got := 0
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
		var a := dg / maxf(r1 * rr, 1.0) * 1.0e4 * rng.range(0.4, 1.2)
		var kidx := 1 if extra < 50000.0 else 2
		var pan := clampf(ry / rr, -1.0, 1.0)
		_add_scaled(rid_l, rid_r, kernels[kidx], int(dly * TAIL_RATE) - kpre, a * sqrt(0.5 * (1.0 + pan)), a * sqrt(0.5 * (1.0 - pan)))
	if got > 0:
		var rid_db := clampf(-21.0 + 3.0 * dkm + 1.5 * lg, -26.0, -10.0) + float(p.get("echo_db", 0.0))
		_mix_scaled(tl, tr, rid_l, rid_r, d_ref_rms * db_to_linear(rid_db), TAIL_RATE, 20.0, 90.0)
	# diffuse late reverberation: noise whose envelope follows the echo energy, darker with time
	var env_l := _envelope(tl, TAIL_RATE, 0.9)
	var env_r := _envelope(tr, TAIL_RATE, 0.9)
	var dn := AudioSynth.noise(nt, sd + 21)
	var dn2 := AudioSynth.noise(nt, sd + 22)
	var c1 := 0.0
	var c2 := 0.0
	var c3 := 0.0
	var c4 := 0.0
	var al := 0.0
	for i in nt:
		if i & 255 == 0:
			var tt := float(i) / TAIL_RATE
			al = 1.0 - exp(-TAU * (380.0 / (1.0 + tt / 12.0)) / TAIL_RATE)
		c1 += al * (dn[i] - c1)
		c2 += al * (c1 - c2)
		c3 += al * (dn2[i] - c3)
		c4 += al * (c3 - c4)
		tl[i] += c2 * env_l[i] * 3.2
		tr[i] += c4 * env_r[i] * 3.2
	# burst-type extras
	if buried or underwater:
		# eruption / water column and the debris or water falling back: a long low roar
		var e0 := float(p.get("eruption_s", 0.6))
		var ed := float(p.get("eruption_dur_s", 8.0 if underwater else 5.0))
		_add_roar(tl, tr, TAIL_RATE, e0, ed, 0.45, 220.0 if underwater else 140.0, sd + 31, rng)
	if nuclear and w >= 1.0 and d < 60000.0:
		# the rising fireball's turbulent roar (heard close, minutes for megatons)
		var rd := clampf(6.0 * pow(w, 0.25), 6.0, 60.0)
		var rg := 0.22 * clampf(1.0 - log(d / 3000.0) / log(30.0), 0.0, 1.0)
		if rg > 0.0:
			_add_roar(tl, tr, TAIL_RATE, 0.5, rd, rg, 120.0, sd + 41, rng)
	AudioSynth.hp1(tl, 16.0, TAIL_RATE)
	AudioSynth.hp1(tr, 16.0, TAIL_RATE)
	_fade(tl, TAIL_RATE, 3.0)
	_fade(tr, TAIL_RATE, 3.0)
	var pt := maxf(AudioSynth.peak(tl), AudioSynth.peak(tr))
	var tail := AudioSynth.to_wav_stereo(tl, tr, int(TAIL_RATE), false, 0.95 / maxf(pt, 1e-9))
	# both streams are normalised to the same peak: playing the tail at tail_gain_db relative to the
	# front restores their physical ratio
	return {"front": front, "tail": tail, "front_dur": front_dur, "tail_dur": tail_dur,
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
		# N-wave: linear fall to -1 at 2 t+, then the rear shock back to 0 within ~ the rise time
		var nw := 1.0 - x if x < 2.0 else -exp(-(t - 2.0 * tp) / (tr * 0.45))
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


## Adds (sl, sr) to (l, r) scaled so that its RMS over [t0, t1] equals target_rms.
static func _mix_scaled(l: PackedFloat32Array, r: PackedFloat32Array, sl: PackedFloat32Array, sr: PackedFloat32Array, target_rms: float, rate: float, t0: float, t1: float) -> void:
	var a := int(t0 * rate)
	var b := mini(int(t1 * rate), sl.size())
	var cur := maxf(_rms(sl, a, b), _rms(sr, a, b))
	if cur <= 1e-12:
		return
	var g := target_rms / cur
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
