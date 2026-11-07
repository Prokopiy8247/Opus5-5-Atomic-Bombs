extends RefCounted
## AudioSynth: deterministic procedural sound synthesis (all functions are static).
##
## Every sound is assembled in PackedFloat32Array buffers from LCG white noise, sines and cheap
## IIR filters (one-pole, RBJ biquad, Chamberlin state-variable, damped resonators) and is then
## packed into 16-bit PCM AudioStreamWAV (mono or interleaved stereo). Long low-frequency sounds
## use low mix rates (8000-11025 Hz) and every sustained sound is a seamless loop (equal-power
## crossfade of the tail into the head), so the whole set generates in a fraction of a second.
##
## Usage (no class_name on purpose):
##   const AudioSynth = preload("res://scripts/audio/audio_synth.gd")
##   var s: AudioStreamWAV = AudioSynth.make("crack")
##   var all: Dictionary = AudioSynth.generate_all()
## Packed arrays are passed by reference in Godot 4: the helpers below modify their input in
## place and return it for convenience.

## All sound names, heaviest first (helps the threaded generator balance its workers).
const NAMES := [
	"rumble", "wind", "roar", "vent", "infra", "thunder_a", "thunder_b", "tremor", "debris",
	"glass_shatter", "rocket_loop", "crack", "thump", "rocket_ignite", "whistle", "glass_crack",
	"hum", "tinnitus", "ui_launch", "ui_warn", "ui_error", "ui_select", "ui_click",
]

const BQ_LP := 0
const BQ_HP := 1
const BQ_BP := 2
const INV_2_30 := 9.313225746154785e-10     # 2 / 2^31: maps a 31-bit LCG state to [0, 2)
const INV_2_31 := 4.656612873077393e-10     # 1 / 2^31: maps a 31-bit LCG state to [0, 1)


## Builds one sound by name (see NAMES). Returns null for an unknown name.
static func make(sound_name: String) -> AudioStreamWAV:
	match sound_name:
		"crack":
			return make_crack()
		"thump":
			return make_thump()
		"infra":
			return make_infra()
		"rumble":
			return make_rumble()
		"roar":
			return make_roar()
		"wind":
			return make_wind()
		"thunder_a":
			return make_thunder(5101)
		"thunder_b":
			return make_thunder(5202)
		"tremor":
			return make_tremor()
		"rocket_ignite":
			return make_rocket_ignite()
		"rocket_loop":
			return make_rocket_loop()
		"whistle":
			return make_whistle()
		"vent":
			return make_vent()
		"hum":
			return make_hum()
		"tinnitus":
			return make_tinnitus()
		"debris":
			return make_debris()
		"glass_crack":
			return make_glass_crack()
		"glass_shatter":
			return make_glass_shatter()
		"ui_click":
			return make_ui_click()
		"ui_select":
			return make_ui_select()
		"ui_launch":
			return make_ui_launch()
		"ui_warn":
			return make_ui_warn()
		"ui_error":
			return make_ui_error()
	push_error("AudioSynth: unknown sound '%s'" % sound_name)
	return null


## Single-threaded generation of every sound: {name: AudioStreamWAV}.
static func generate_all() -> Dictionary:
	var out := {}
	for n: String in NAMES:
		out[n] = make(n)
	return out


# =============================================================================== blast layers

## Sharp N-wave front with its ground reflection, crackle and a short low "boom" body.
static func make_crack() -> AudioStreamWAV:
	var rate := 44100.0
	var n := int(1.6 * rate)
	var out := _buf(n)
	var o := int(0.002 * rate)
	# direct N-wave plus the ground-reflected one a few ms later (the classic double report)
	nwave(out, o, rate, 0.009, 1.0, 0.00012)
	nwave(out, o + int(0.0047 * rate), rate, 0.012, 0.5, 0.0005)
	# broadband crackle right behind the front
	var cr := noise(n, 101)
	hp1(cr, 900.0, rate)
	env_ad(cr, rate, 0.0003, 0.028)
	add(out, normalize(cr, 1.0), o, 0.5)
	# low "boom" body
	var bd := noise(n, 102)
	lp1(bd, 240.0, rate)
	lp1(bd, 240.0, rate)
	env_ad(bd, rate, 0.004, 0.24)
	add(out, normalize(bd, 1.0), o, 0.85)
	# sizzle of the decaying front: sparse crackles
	var sz := impulses(n, 0.004, 103, false)
	env_ad(sz, rate, 0.01, 0.32)
	biquad(sz, BQ_BP, 2600.0, 0.8, rate)
	add(out, normalize(sz, 1.0), o, 0.2)
	lp1(out, 11000.0, rate)
	normalize(out, 0.97)
	fade_out(out, rate, 0.35)
	return to_wav(out, int(rate), false)


## Low-frequency thump: slow pressure pulse + 42->16 Hz drop (subsonic-ish) + 85->50 Hz body
## so it stays audible on ordinary speakers, softly saturated for harmonics.
static func make_thump() -> AudioStreamWAV:
	var rate := 11025.0
	var n := int(5.0 * rate)
	var out := _buf(n)
	nwave(out, 0, rate, 0.13, 0.75, 0.003)
	add(out, sweep(n, rate, 42.0, 16.0, 0.7, 0.012, 1.1), 0, 0.9)
	add(out, sweep(n, rate, 85.0, 50.0, 0.25, 0.004, 0.42), 0, 0.8)
	var nb := noise(n, 201)
	lp1(nb, 110.0, rate)
	lp1(nb, 110.0, rate)
	env_ad(nb, rate, 0.006, 0.65)
	add(out, normalize(nb, 1.0), 0, 0.55)
	hp1(out, 4.0, rate)
	normalize(out, 1.0)
	soft_clip(out, 1.7)
	normalize(out, 0.95)
	fade_out(out, rate, 0.5)
	return to_wav(out, int(rate), false)


## Megaton infrasonic thump: a 0.45 s pressure pulse (1-2 Hz), 32->13 Hz and 56->33 Hz drops,
## very low noise, driven into saturation so the harmonics carry it on normal speakers.
static func make_infra() -> AudioStreamWAV:
	var rate := 6000.0
	var n := int(9.0 * rate)
	var out := _buf(n)
	nwave(out, 0, rate, 0.45, 1.0, 0.012)
	add(out, sweep(n, rate, 32.0, 13.0, 1.5, 0.06, 2.8), 0, 0.9)
	add(out, sweep(n, rate, 56.0, 33.0, 0.6, 0.02, 1.5), 0, 0.7)
	var nb := noise(n, 301)
	lp1(nb, 55.0, rate)
	lp1(nb, 55.0, rate)
	env_ad(nb, rate, 0.05, 2.6)
	add(out, normalize(nb, 1.0), 0, 0.6)
	hp1(out, 2.0, rate)
	normalize(out, 1.0)
	soft_clip(out, 2.3)
	normalize(out, 0.95)
	fade_out(out, rate, 1.2)
	return to_wav(out, int(rate), false)


## 26 s stereo rumble: rolling brown noise tail plus ten delayed, progressively darker and
## panned terrain/mountain reflections. 6 kHz mix rate (content < 400 Hz).
static func make_rumble() -> AudioStreamWAV:
	var rate := 6000.0
	var n := int(26.0 * rate)
	var w := _buf(n)
	var m := _buf(n)
	var s1 := _seed(401)
	var s2 := _seed(402)
	var leak := exp(-TAU * 4.0 / rate)
	var hpa := 1.0 - exp(-TAU * 18.0 / rate)
	var lpa := 1.0 - exp(-TAU * 380.0 / rate)
	var ma := 1.0 - exp(-TAU * 1.3 / rate)
	var b := 0.0
	var hy := 0.0
	var ly := 0.0
	var m1 := 0.0
	var m2 := 0.0
	var pw := 1.0e-9
	var pm := 1.0e-9
	# brown noise (leaky integrator) band-limited 18-380 Hz + a slow "rolling" modulation
	for i in n:
		s1 = (s1 * 1103515245 + 12345) & 0x7FFFFFFF
		b = b * leak + (float(s1) * INV_2_30 - 1.0) * 0.05
		hy += hpa * (b - hy)
		ly += lpa * (b - hy - ly)
		w[i] = ly
		if ly > pw:
			pw = ly
		elif -ly > pw:
			pw = -ly
		s2 = (s2 * 1103515245 + 12345) & 0x7FFFFFFF
		m1 += ma * (float(s2) * INV_2_30 - 1.0 - m1)
		m2 += ma * (m1 - m2)
		m[i] = m2
		if m2 > pm:
			pm = m2
		elif -m2 > pm:
			pm = -m2
	# envelope; the strong first 5 s also feed two darker echo sources
	var gw := 1.0 / pw
	var gm := 0.45 / pm
	var ka := exp(-1.0 / (0.06 * rate))
	var kd1 := exp(-1.0 / (5.0 * rate))
	var kd2 := exp(-1.0 / (14.0 * rate))
	var ea := 1.0
	var ed1 := 1.0
	var ed2 := 1.0
	var src_n := mini(n, int(5.0 * rate))
	var e1 := _buf(src_n)
	var e2 := _buf(src_n)
	var a1 := 1.0 - exp(-TAU * 240.0 / rate)
	var a2 := 1.0 - exp(-TAU * 120.0 / rate)
	var u1 := 0.0
	var u2 := 0.0
	var v1 := 0.0
	var v2 := 0.0
	var pe1 := 1.0e-9
	var pe2 := 1.0e-9
	for i in src_n:
		var x := w[i] * gw * (1.0 - ea) * (ed1 + 0.18 * ed2) * (0.55 + gm * m[i])
		w[i] = x
		ea *= ka
		ed1 *= kd1
		ed2 *= kd2
		u1 += a1 * (x - u1)
		u2 += a1 * (u1 - u2)
		e1[i] = u2
		v1 += a2 * (u2 - v1)
		v2 += a2 * (v1 - v2)
		e2[i] = v2
		if absf(u2) > pe1:
			pe1 = absf(u2)
		if absf(v2) > pe2:
			pe2 = absf(v2)
	for i in range(src_n, n):
		w[i] *= gw * (1.0 - ea) * (ed1 + 0.18 * ed2) * (0.55 + gm * m[i])
		ea *= ka
		ed1 *= kd1
		ed2 *= kd2
	var l := w.duplicate()
	var r := w.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = 403
	var delays := [0.7, 1.6, 2.5, 3.6, 4.9, 6.5, 8.4, 10.8, 13.7, 17.1]
	var gains := [0.5, 0.46, 0.42, 0.38, 0.33, 0.29, 0.25, 0.2, 0.15, 0.11]
	for k in delays.size():
		var dl: float = float(delays[k]) * rng.randf_range(0.9, 1.1)
		var g: float = float(gains[k]) / (pe1 if k < 4 else pe2)
		var th := (rng.randf_range(-0.85, 0.85) + 1.0) * PI * 0.25
		var gl := g * cos(th) * 1.41
		var gr := g * sin(th) * 1.41
		var src: PackedFloat32Array = e1 if k < 4 else e2
		var d := int(dl * rate)
		var cnt := mini(src_n, n - d)
		for i in cnt:
			var v := src[i]
			l[d + i] += gl * v
			r[d + i] += gr * v
	fade_out(l, rate, 3.0)
	fade_out(r, rate, 3.0)
	return to_wav_stereo(l, r, int(rate), false, 0.9 / maxf(peak(l), peak(r)))


## Fireball roar/hiss loop (stereo, 6 s): boiling low roar, mid turbulence, hiss and crackle.
static func make_roar() -> AudioStreamWAV:
	var rate := 11025.0
	var ln := int(6.0 * rate)
	var xn := int(0.6 * rate)
	var n := ln + xn
	var ch: Array[PackedFloat32Array] = []
	var ks := 1.0 - exp(-TAU * 2.0 / rate)
	var kf := 1.0 - exp(-TAU * 9.0 / rate)
	var f1 := 2.0 * sin(PI * 330.0 / rate)
	var f2 := 2.0 * sin(PI * 850.0 / rate)
	# crackle band-pass (RBJ BP 1700 Hz, Q 1.4; b1 = 0, b2 = -b0)
	var w0 := TAU * 1700.0 / rate
	var al := sin(w0) / 2.8
	var cb0 := al / (1.0 + al)
	var ca1 := -2.0 * cos(w0) / (1.0 + al)
	var ca2 := (1.0 - al) / (1.0 + al)
	for c in 2:
		var slow := _buf(n)
		var fast := _buf(n)
		var crk := _buf(n)
		var s1 := _seed(1401 + c * 17)
		var s2 := _seed(1402 + c * 17)
		var s3 := _seed(1403 + c * 17)
		var y1 := 0.0
		var y2 := 0.0
		var z1 := 0.0
		var z2 := 0.0
		var cx1 := 0.0
		var cx2 := 0.0
		var cy1 := 0.0
		var cy2 := 0.0
		var ps := 1.0e-9
		var pf := 1.0e-9
		var pc := 1.0e-9
		for i in n:
			s1 = (s1 * 1103515245 + 12345) & 0x7FFFFFFF
			y1 += ks * (float(s1) * INV_2_30 - 1.0 - y1)
			y2 += ks * (y1 - y2)
			slow[i] = y2
			s2 = (s2 * 1103515245 + 12345) & 0x7FFFFFFF
			z1 += kf * (float(s2) * INV_2_30 - 1.0 - z1)
			z2 += kf * (z1 - z2)
			fast[i] = z2
			s3 = (s3 * 1103515245 + 12345) & 0x7FFFFFFF
			var imp := 0.0
			if float(s3) * INV_2_31 < 0.006:
				s3 = (s3 * 1103515245 + 12345) & 0x7FFFFFFF
				imp = float(s3) * INV_2_31
				imp *= imp
				if (s3 & 0x400000) != 0:
					imp = -imp
			var cy := cb0 * (imp - cx2) - ca1 * cy1 - ca2 * cy2
			cx2 = cx1
			cx1 = imp
			cy2 = cy1
			cy1 = cy
			crk[i] = cy
			if absf(y2) > ps:
				ps = absf(y2)
			if absf(z2) > pf:
				pf = absf(z2)
			if absf(cy) > pc:
				pc = absf(cy)
		var gs := 0.4 / ps
		var gf := 0.25 / pf
		var gc := 0.35 / pc
		var out := _buf(n)
		var s4 := _seed(1404 + c * 17)
		var lo1 := 0.0
		var bd1 := 0.0
		var lo2 := 0.0
		var bd2 := 0.0
		for i in n:
			s4 = (s4 * 1103515245 + 12345) & 0x7FFFFFFF
			var x := float(s4) * INV_2_30 - 1.0
			lo1 += f1 * bd1
			bd1 += f1 * (x - lo1 - 1.2 * bd1)
			lo2 += f2 * bd2
			var hi2 := x - lo2 - 1.6 * bd2
			bd2 += f2 * hi2
			var mf := 0.75 + gf * fast[i]
			# -bd2: the 330 Hz low-pass lags ~-135 deg where the 850 Hz band-pass leads ~+45 deg;
			# flipping the band keeps the two in phase (no notch around 500 Hz)
			out[i] = lo1 * 1.6 * (0.6 + gs * slow[i]) + (crk[i] * gc - bd2 * 0.8) * mf + hi2 * 0.1
		ch.append(loopify(out, xn))
	return _stereo_norm(ch[0], ch[1], 0.9, int(rate), true)


## Rising-cloud airflow wind loop (stereo, 8 s): band-passed noise with a wandering centre
## (140-770 Hz) and slow gusts. 8 kHz mix rate.
static func make_wind() -> AudioStreamWAV:
	var rate := 8000.0
	var ln := int(8.0 * rate)
	var xn := int(1.0 * rate)
	var n := ln + xn
	var ch: Array[PackedFloat32Array] = []
	var kl := 1.0 - exp(-TAU * 0.22 / rate)
	var kg := 1.0 - exp(-TAU * 0.5 / rate)
	var k := TAU * 330.0 / rate
	for c in 2:
		var lfo := _buf(n)
		var gust := _buf(n)
		var s1 := _seed(1502 + c * 13)
		var s2 := _seed(1503 + c * 13)
		var y1 := 0.0
		var y2 := 0.0
		var z1 := 0.0
		var z2 := 0.0
		var pl := 1.0e-9
		var pg := 1.0e-9
		for i in n:
			s1 = (s1 * 1103515245 + 12345) & 0x7FFFFFFF
			y1 += kl * (float(s1) * INV_2_30 - 1.0 - y1)
			y2 += kl * (y1 - y2)
			lfo[i] = y2
			s2 = (s2 * 1103515245 + 12345) & 0x7FFFFFFF
			z1 += kg * (float(s2) * INV_2_30 - 1.0 - z1)
			z2 += kg * (z1 - z2)
			gust[i] = z2
			if absf(y2) > pl:
				pl = absf(y2)
			if absf(z2) > pg:
				pg = absf(z2)
		var gl := 0.85 / pl
		var gg := 0.45 / pg
		var out := _buf(n)
		var s3 := _seed(1501 + c * 13)
		var lo := 0.0
		var bd := 0.0
		for i in n:
			s3 = (s3 * 1103515245 + 12345) & 0x7FFFFFFF
			var f := k * exp(gl * lfo[i])
			lo += f * bd
			bd += f * (float(s3) * INV_2_30 - 1.0 - lo - 1.25 * bd)
			var g := 0.55 + gg * gust[i]
			out[i] = (bd + lo * 0.6) * g * g
		ch.append(loopify(out, xn))
	return _stereo_norm(ch[0], ch[1], 0.9, int(rate), true)


## Distant thunder roll (8 s): a cluster of low claps followed by a long tail.
static func make_thunder(sd: int) -> AudioStreamWAV:
	var rate := 6000.0
	var n := int(8.0 * rate)
	var e := _buf(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var claps := 6 + rng.randi() % 4
	for c in claps:
		var t0 := 0.0 if c == 0 else rng.randf_range(0.05, 2.4)
		var amp := 1.0 if c == 0 else rng.randf_range(0.35, 0.95)
		var att := rng.randf_range(0.02, 0.09)
		var tau := rng.randf_range(0.35, 1.1)
		var i0 := int(t0 * rate)
		var cnt := mini(n - i0, int((att + 5.0 * tau) * rate))
		var ka := exp(-1.0 / (att * rate))
		var kd := exp(-1.0 / (tau * rate))
		var ea := 1.0
		var ed := 1.0
		for j in cnt:
			e[i0 + j] += amp * (1.0 - ea) * ed
			ea *= ka
			ed *= kd
	# body (2-pole 330 Hz) + weight (2-pole 75 Hz), normalised separately
	var nz := _buf(n)
	var lo := _buf(n)
	var s1 := _seed(sd)
	var s2 := _seed(sd + 1)
	var a1 := 1.0 - exp(-TAU * 330.0 / rate)
	var a2 := 1.0 - exp(-TAU * 75.0 / rate)
	var y1 := 0.0
	var y2 := 0.0
	var z1 := 0.0
	var z2 := 0.0
	var py := 1.0e-9
	var pz := 1.0e-9
	for i in n:
		s1 = (s1 * 1103515245 + 12345) & 0x7FFFFFFF
		y1 += a1 * (float(s1) * INV_2_30 - 1.0 - y1)
		y2 += a1 * (y1 - y2)
		nz[i] = y2
		s2 = (s2 * 1103515245 + 12345) & 0x7FFFFFFF
		z1 += a2 * (float(s2) * INV_2_30 - 1.0 - z1)
		z2 += a2 * (z1 - z2)
		lo[i] = z2
		if absf(y2) > py:
			py = absf(y2)
		if absf(z2) > pz:
			pz = absf(z2)
	var gy := 1.0 / py
	var gz := 0.6 / pz
	var ka2 := exp(-1.0 / (0.3 * rate))
	var kd2 := exp(-1.0 / (2.8 * rate))
	var ea2 := 1.0
	var ed2 := 1.0
	var ha := 1.0 - exp(-TAU * 22.0 / rate)
	var hy := 0.0
	var out := _buf(n)
	for i in n:
		var x := (nz[i] * gy + lo[i] * gz) * (e[i] + 0.28 * (1.0 - ea2) * ed2)
		hy += ha * (x - hy)
		out[i] = x - hy
		ea2 *= ka2
		ed2 *= kd2
	fade_out(out, rate, 1.2)
	return to_wav(out, int(rate), false, 0.92 / peak(out))


## Seismic ground tremor (8 s): very low rumble (<40 Hz + 85 Hz body) with a faint rattle of
## loose objects in the bunker.
static func make_tremor() -> AudioStreamWAV:
	var rate := 11025.0
	var n := int(8.0 * rate)
	var lo := noise(n, 601)
	lp1(lo, 30.0, rate)
	lp1(lo, 30.0, rate)
	normalize(lo, 1.0)
	var mid := noise(n, 602)
	lp1(mid, 85.0, rate)
	lp1(mid, 85.0, rate)
	normalize(mid, 1.0)
	var e := _buf(n)
	var kd := exp(-1.0 / (2.4 * rate))
	var ed := 1.0
	for i in n:
		var t := float(i) / rate
		if t < 0.7:
			e[i] = smoothstep(0.0, 0.7, t)
		else:
			e[i] = ed
			ed *= kd
	var rat := impulses(n, 0.005, 603, false)
	for i in n:
		rat[i] *= e[i]
	biquad(rat, BQ_BP, 3300.0, 3.0, rate)
	normalize(rat, 1.0)
	var out := _buf(n)
	for i in n:
		out[i] = (lo[i] + 0.55 * mid[i]) * e[i] + 0.12 * rat[i]
	normalize(out, 1.0)
	soft_clip(out, 1.6)
	normalize(out, 0.9)
	fade_out(out, rate, 1.0)
	return to_wav(out, int(rate), false)


# =============================================================================== flight

## Rocket ignition (2.6 s): bang plus the roar building up (the loop takes over).
static func make_rocket_ignite() -> AudioStreamWAV:
	var rate := 22050.0
	var n := int(2.6 * rate)
	var out := sweep(n, rate, 95.0, 38.0, 0.12, 0.002, 0.22)
	scale(out, 0.9)
	var bn := noise(n, 701)
	lp1(bn, 520.0, rate)
	env_ad(bn, rate, 0.0008, 0.12)
	add(out, normalize(bn, 1.0), 0, 0.85)
	var core := noise(n, 702)
	lp1(core, 1600.0, rate)
	var cr := impulses(n, 0.004, 703, true)
	biquad(cr, BQ_BP, 2400.0, 0.9, rate)
	normalize(cr, 1.0)
	normalize(core, 1.0)
	var ka := exp(-1.0 / (0.28 * rate))
	var ea := 1.0
	for i in n:
		var t := float(i) / rate
		var e := (1.0 - ea) * (1.0 - smoothstep(1.3, 2.6, t))
		out[i] += (core[i] * 0.7 + cr[i] * 0.35) * e
		ea *= ka
	normalize(out, 0.95)
	fade_out(out, rate, 0.1)
	return to_wav(out, int(rate), false)


## Rocket motor roar loop (3 s, mono for AudioStreamPlayer3D): low roar, mid, hiss, crackle.
static func make_rocket_loop() -> AudioStreamWAV:
	var rate := 22050.0
	var ln := int(3.0 * rate)
	var xn := int(0.4 * rate)
	var n := ln + xn
	var nz := noise(n, 801)
	var fl := smooth_noise(n, 802, 13.0, rate)
	var cr := impulses(n, 0.0035, 803, true)
	hp1(cr, 400.0, rate)
	biquad(cr, BQ_BP, 2100.0, 0.8, rate)
	normalize(cr, 1.0)
	var out := _buf(n)
	var f1 := 2.0 * sin(PI * 260.0 / rate)
	var f2 := 2.0 * sin(PI * 1300.0 / rate)
	var lo1 := 0.0
	var bd1 := 0.0
	var lo2 := 0.0
	var bd2 := 0.0
	for i in n:
		var x := nz[i]
		lo1 += f1 * bd1
		var hi1 := x - lo1 - 1.0 * bd1
		bd1 += f1 * hi1
		lo2 += f2 * bd2
		var hi2 := x - lo2 - 1.2 * bd2
		bd2 += f2 * hi2
		out[i] = (lo1 * 2.0 + bd2 * 0.65 + hi2 * 0.14) * (0.85 + 0.15 * fl[i]) + cr[i] * 0.45
	out = loopify(out, xn)
	normalize(out, 0.9)
	return to_wav(out, int(rate), true)


## Falling-bomb whistle loop (2 s): a 1450 Hz tone with vibrato plus narrow-band air noise.
## The descending pitch is applied by the player (pitch_scale sweep).
static func make_whistle() -> AudioStreamWAV:
	var rate := 22050.0
	var ln := int(2.0 * rate)
	var xn := int(0.3 * rate)
	var n := ln + xn
	var air := noise(n, 901)
	biquad(air, BQ_BP, 1450.0, 6.0, rate)
	normalize(air, 0.4)
	var air2 := noise(n, 902)
	biquad(air2, BQ_BP, 3100.0, 1.2, rate)
	add(air, normalize(air2, 1.0), 0, 0.12)
	var out := loopify(air, xn)
	# periodic tone: 1450 Hz * 2 s, vibrato 5 Hz and AM 3 Hz are whole cycles -> seamless
	for i in ln:
		var t := float(i) / rate
		var ph := TAU * 1450.0 * t + 1.8 * sin(TAU * 5.0 * t)
		out[i] += (sin(ph) + 0.12 * sin(2.0 * ph)) * (0.9 + 0.1 * sin(TAU * 3.0 * t)) * 0.5
	normalize(out, 0.9)
	return to_wav(out, int(rate), true)


# =============================================================================== bunker

## Bunker ventilation loop (stereo, 6 s): duct air noise plus a 25 Hz fan with blade harmonics.
static func make_vent() -> AudioStreamWAV:
	var rate := 11025.0
	var ln := int(6.0 * rate)
	var xn := int(0.8 * rate)
	var n := ln + xn
	var motor := _buf(ln)
	for i in ln:
		var t := float(i) / rate
		var v := 0.12 * sin(TAU * 25.0 * t) + 0.1 * sin(TAU * 50.0 * t)
		v += 0.07 * sin(TAU * 87.5 * t) + 0.035 * sin(TAU * 175.0 * t)
		motor[i] = v * (0.92 + 0.08 * sin(TAU * 4.5 * t))
	var a1 := 1.0 - exp(-TAU * 650.0 / rate)
	var a2 := 1.0 - exp(-TAU * 1600.0 / rate)
	var af := 1.0 - exp(-TAU * 0.7 / rate)
	# duct resonance: RBJ BP 240 Hz, Q 1.1
	var w0 := TAU * 240.0 / rate
	var al := sin(w0) / 2.2
	var cb0 := al / (1.0 + al)
	var ca1 := -2.0 * cos(w0) / (1.0 + al)
	var ca2 := (1.0 - al) / (1.0 + al)
	var ch: Array[PackedFloat32Array] = []
	for c in 2:
		var air := _buf(n)
		var duct := _buf(n)
		var fl := _buf(n)
		var s1 := _seed(1001 + c * 5)
		var s2 := _seed(1002 + c * 5)
		var s3 := _seed(1003 + c * 5)
		var y1 := 0.0
		var y2 := 0.0
		var x1 := 0.0
		var x2 := 0.0
		var d1 := 0.0
		var d2 := 0.0
		var f1 := 0.0
		var f2 := 0.0
		var pa := 1.0e-9
		var pd := 1.0e-9
		var pf := 1.0e-9
		for i in n:
			s1 = (s1 * 1103515245 + 12345) & 0x7FFFFFFF
			y1 += a1 * (float(s1) * INV_2_30 - 1.0 - y1)
			y2 += a2 * (y1 - y2)
			air[i] = y2
			s2 = (s2 * 1103515245 + 12345) & 0x7FFFFFFF
			var xx := float(s2) * INV_2_30 - 1.0
			var dy := cb0 * (xx - x2) - ca1 * d1 - ca2 * d2
			x2 = x1
			x1 = xx
			d2 = d1
			d1 = dy
			duct[i] = dy
			s3 = (s3 * 1103515245 + 12345) & 0x7FFFFFFF
			f1 += af * (float(s3) * INV_2_30 - 1.0 - f1)
			f2 += af * (f1 - f2)
			fl[i] = f2
			if absf(y2) > pa:
				pa = absf(y2)
			if absf(dy) > pd:
				pd = absf(dy)
			if absf(f2) > pf:
				pf = absf(f2)
		var ga := 0.6 / pa
		var gd := 0.35 / pd
		var gf := 0.15 / pf
		for i in n:
			air[i] = (air[i] * ga + duct[i] * gd) * (0.85 + gf * fl[i])
		var lp := loopify(air, xn)
		add(lp, motor, 0, 1.0)
		ch.append(lp)
	return _stereo_norm(ch[0], ch[1], 0.85, int(rate), true)


## Light 50 Hz electrical hum loop (1 s, whole cycles of every harmonic).
static func make_hum() -> AudioStreamWAV:
	var rate := 22050.0
	var n := int(rate)
	var amps := [0.45, 0.6, 0.3, 0.18, 0.12, 0.08, 0.05, 0.04, 0.03, 0.025, 0.02, 0.015]
	var out := _buf(n)
	var w := TAU * 50.0 / rate
	for i in n:
		var ph := w * float(i)
		var v := 0.0
		for k in amps.size():
			v += float(amps[k]) * sin(float(k + 1) * ph)
		out[i] = v
	normalize(out, 0.8)
	return to_wav(out, int(rate), true)


## Tinnitus ring loop (1 s): pure 4 kHz with a faint 4006 Hz partner (slow 6 Hz beating).
static func make_tinnitus() -> AudioStreamWAV:
	var rate := 22050.0
	var n := int(rate)
	var out := _buf(n)
	for i in n:
		var t := float(i) / rate
		out[i] = 0.6 * sin(TAU * 4000.0 * t) + 0.22 * sin(TAU * 4006.0 * t + 0.7)
	normalize(out, 0.75)
	return to_wav(out, int(rate), true)


## Dust and grit falling from the bunker ceiling plus a short window/fitting rattle (4.5 s).
static func make_debris() -> AudioStreamWAV:
	var rate := 22050.0
	var n := int(4.5 * rate)
	var out := noise(n, 1201)
	hp1(out, 1800.0, rate)
	lp1(out, 6500.0, rate)
	env_ad(out, rate, 0.12, 1.4)
	normalize(out, 0.28)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1202
	for k in 80:
		var t := 4.0 * pow(rng.randf(), 1.8)
		var amp := rng.randf_range(0.15, 1.0) * (1.0 - t / 4.6)
		ring(out, int(t * rate), rate, rng.randf_range(1200.0, 5200.0), rng.randf_range(0.003, 0.018), amp)
	var rat := noise(n, 1203)
	biquad(rat, BQ_BP, 3600.0, 2.5, rate)
	normalize(rat, 1.0)
	var kd := exp(-1.0 / (0.22 * rate))
	var ed := 1.0
	var lim := mini(n, int(0.9 * rate))
	for i in lim:
		var t := float(i) / rate
		var sq := 1.0 if sin(TAU * 31.0 * t) > 0.0 else 0.25
		out[i] += rat[i] * sq * ed * 0.5
		ed *= kd
	normalize(out, 0.9)
	fade_out(out, rate, 0.5)
	return to_wav(out, int(rate), false)


## Window glass cracking (>10 psi): click, inharmonic glass partials and propagation ticks.
static func make_glass_crack() -> AudioStreamWAV:
	var rate := 32000.0
	var n := int(1.3 * rate)
	var out := noise(n, 1301)
	env_ad(out, rate, 0.00005, 0.0015)
	normalize(out, 1.0)
	var fr := [2150.0, 3320.0, 4870.0, 6230.0, 7410.0, 9050.0]
	var am := [1.0, 0.7, 0.55, 0.45, 0.3, 0.25]
	var ta := [0.35, 0.24, 0.17, 0.12, 0.09, 0.06]
	for k in fr.size():
		ring(out, 0, rate, float(fr[k]), float(ta[k]), float(am[k]) * 0.35)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1302
	var nz := noise(int(0.002 * rate), 1303)
	for k in 14:
		add(out, nz, int(rng.randf_range(0.01, 0.28) * rate), rng.randf_range(0.3, 0.8))
		ring(out, int(rng.randf_range(0.01, 0.3) * rate), rate, rng.randf_range(3000.0, 9000.0), 0.02, 0.2)
	normalize(out, 0.95)
	fade_out(out, rate, 0.2)
	return to_wav(out, int(rate), false)


## Window blown out (>25 psi): noise burst, low thud and a cascade of glass shards.
static func make_glass_shatter() -> AudioStreamWAV:
	var rate := 32000.0
	var n := int(2.6 * rate)
	var out := noise(n, 1401)
	hp1(out, 700.0, rate)
	env_ad(out, rate, 0.0004, 0.13)
	normalize(out, 1.0)
	add(out, sweep(n, rate, 130.0, 55.0, 0.08, 0.002, 0.14), 0, 0.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1402
	for k in 80:
		var t := 2.3 * pow(rng.randf(), 1.6)
		var f := rng.randf_range(2400.0, 9800.0)
		var tau := rng.randf_range(0.015, 0.1)
		var amp := rng.randf_range(0.2, 1.0) * (1.0 - t / 2.6) * 0.5
		var i0 := int(t * rate)
		ring(out, i0, rate, f, tau, amp)
		ring(out, i0, rate, f * 1.47, tau * 0.7, amp * 0.5)
	normalize(out, 0.95)
	fade_out(out, rate, 0.3)
	return to_wav(out, int(rate), false)


# =============================================================================== UI

static func make_ui_click() -> AudioStreamWAV:
	var rate := 44100.0
	var n := int(0.04 * rate)
	var out := noise(n, 2001)
	env_ad(out, rate, 0.00005, 0.0022)
	hp1(out, 1500.0, rate)
	normalize(out, 0.6)
	ring(out, 0, rate, 2300.0, 0.006, 0.6)
	normalize(out, 0.7)
	return to_wav(out, int(rate), false)


static func make_ui_select() -> AudioStreamWAV:
	var rate := 44100.0
	var out := _buf(int(0.14 * rate))
	tone(out, rate, 0.0, 0.05, 1200.0, 0.3, 0.003, 0.01, 0.5)
	tone(out, rate, 0.062, 0.06, 1800.0, 0.3, 0.003, 0.015, 0.5)
	normalize(out, 0.6)
	return to_wav(out, int(rate), false)


static func make_ui_launch() -> AudioStreamWAV:
	var rate := 44100.0
	var n := int(0.7 * rate)
	var out := _buf(n)
	var ph := 0.0
	var lr := log(1600.0 / 300.0)
	for i in int(0.55 * rate):
		var t := float(i) / rate
		var f := 300.0 * exp(lr * minf(t / 0.38, 1.0))
		ph += TAU * f / rate
		var e := minf(1.0, t / 0.01) * clampf((0.55 - t) / 0.15, 0.0, 1.0)
		out[i] = (sin(ph) + 0.2 * sin(3.0 * ph)) * e * 0.7
	add(out, sweep(n, rate, 95.0, 60.0, 0.05, 0.002, 0.08), 0, 0.6)
	normalize(out, 0.75)
	return to_wav(out, int(rate), false)


static func make_ui_warn() -> AudioStreamWAV:
	var rate := 44100.0
	var out := _buf(int(0.86 * rate))
	for k in 4:
		tone(out, rate, k * 0.21, 0.17, 880.0 if k % 2 == 0 else 620.0, 0.5, 0.005, 0.02, 0.5)
	normalize(out, 0.6)
	return to_wav(out, int(rate), false)


static func make_ui_error() -> AudioStreamWAV:
	var rate := 44100.0
	var out := _buf(int(0.36 * rate))
	for k in 2:
		tone(out, rate, k * 0.18, 0.13, 150.0, 1.0, 0.004, 0.02, 0.5)
		tone(out, rate, k * 0.18, 0.13, 300.0, 1.0, 0.004, 0.02, 0.2)
	normalize(out, 0.65)
	return to_wav(out, int(rate), false)


# =============================================================================== DSP helpers

static func _buf(n: int) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(n)
	b.fill(0.0)
	return b


## Scrambled 31-bit LCG start state for a seed.
static func _seed(sd: int) -> int:
	return (sd * 2654435761 + 1013904223) & 0x7FFFFFFF


## Uniform white noise in [-1, 1) from a 31-bit LCG (deterministic per seed).
static func noise(n: int, sd: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var s: int = (sd * 2654435761 + 1013904223) & 0x7FFFFFFF
	for i in n:
		s = (s * 1103515245 + 12345) & 0x7FFFFFFF
		out[i] = float(s) * INV_2_30 - 1.0
	return out


## Very slow random modulation in roughly [-1, 1]: two-pole low-passed noise, normalized.
static func smooth_noise(n: int, sd: int, fc: float, rate: float) -> PackedFloat32Array:
	var s := noise(n, sd)
	lp1(s, fc, rate)
	lp1(s, fc, rate)
	return normalize(s, 1.0)


## Sparse random impulses (probability `density` per sample), amplitudes skewed towards small.
static func impulses(n: int, density: float, sd: int, positive: bool) -> PackedFloat32Array:
	var out := _buf(n)
	var s: int = (sd * 2654435761 + 1013904223) & 0x7FFFFFFF
	for i in n:
		s = (s * 1103515245 + 12345) & 0x7FFFFFFF
		if float(s) * INV_2_31 < density:
			s = (s * 1103515245 + 12345) & 0x7FFFFFFF
			var a := float(s) * INV_2_31
			a *= a
			if not positive and (s & 0x400000) != 0:
				a = -a
			out[i] = a
	return out


## One-pole low-pass, in place.
static func lp1(buf: PackedFloat32Array, fc: float, rate: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * fc / rate)
	var y := 0.0
	for i in buf.size():
		y += a * (buf[i] - y)
		buf[i] = y
	return buf


## One-pole high-pass (input minus its low-pass), in place.
static func hp1(buf: PackedFloat32Array, fc: float, rate: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * fc / rate)
	var y := 0.0
	for i in buf.size():
		var x := buf[i]
		y += a * (x - y)
		buf[i] = x - y
	return buf


## RBJ biquad (BQ_LP, BQ_HP or BQ_BP with 0 dB peak), in place.
static func biquad(buf: PackedFloat32Array, kind: int, fc: float, q: float, rate: float) -> PackedFloat32Array:
	var w0 := TAU * fc / rate
	var cw := cos(w0)
	var alpha := sin(w0) / (2.0 * q)
	var b0 := alpha
	var b1 := 0.0
	var b2 := -alpha
	if kind == BQ_LP:
		b0 = (1.0 - cw) * 0.5
		b1 = 1.0 - cw
		b2 = b0
	elif kind == BQ_HP:
		b0 = (1.0 + cw) * 0.5
		b1 = -(1.0 + cw)
		b2 = b0
	var a0 := 1.0 + alpha
	var a1 := -2.0 * cw / a0
	var a2 := (1.0 - alpha) / a0
	b0 /= a0
	b1 /= a0
	b2 /= a0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in buf.size():
		var x := buf[i]
		var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		buf[i] = y
	return buf


## Attack/decay envelope (1 - e^-t/att) * e^-t/tau, in place.
static func env_ad(buf: PackedFloat32Array, rate: float, att: float, tau: float) -> PackedFloat32Array:
	var ka := exp(-1.0 / (maxf(att, 1.0e-5) * rate))
	var kd := exp(-1.0 / (tau * rate))
	var ea := 1.0
	var ed := 1.0
	for i in buf.size():
		buf[i] *= (1.0 - ea) * ed
		ea *= ka
		ed *= kd
	return buf


## Decaying sine sweep f0 -> f1 (time constant tau_f) with an attack/decay envelope.
static func sweep(n: int, rate: float, f0: float, f1: float, tau_f: float, att: float, tau: float) -> PackedFloat32Array:
	var out := _buf(n)
	var kf := exp(-1.0 / (tau_f * rate))
	var ka := exp(-1.0 / (att * rate))
	var kd := exp(-1.0 / (tau * rate))
	var ef := 1.0
	var ea := 1.0
	var ed := 1.0
	var w := TAU / rate
	var ph := 0.0
	for i in n:
		ph += w * (f1 + (f0 - f1) * ef)
		out[i] = sin(ph) * (1.0 - ea) * ed
		ef *= kf
		ea *= ka
		ed *= kd
	return out


## Adds an N-wave (fast rise, linear fall through zero, fast return) at sample `start`.
static func nwave(out: PackedFloat32Array, start: int, rate: float, dur: float, amp: float, rise: float) -> PackedFloat32Array:
	var n := out.size()
	var nr := maxi(1, int(rise * rate))
	var nd := maxi(2, int(dur * rate))
	var nb := maxi(1, int(rise * 2.0 * rate))
	for i in nr:
		var j := start + i
		if j < n:
			out[j] += amp * float(i + 1) / float(nr)
	for i in nd:
		var j := start + nr + i
		if j < n:
			out[j] += amp * (1.0 - 2.0 * float(i) / float(nd))
	for i in nb:
		var j := start + nr + nd + i
		if j < n:
			out[j] -= amp * (1.0 - float(i + 1) / float(nb))
	return out


## Adds an exponentially decaying sinusoid (damped two-pole resonator, no sin() per sample).
static func ring(out: PackedFloat32Array, start: int, rate: float, f: float, tau: float, amp: float) -> PackedFloat32Array:
	var n := out.size()
	if start >= n or f >= rate * 0.5:
		return out
	var w := TAU * f / rate
	var r := exp(-1.0 / (tau * rate))
	var c := 2.0 * r * cos(w)
	var r2 := r * r
	var y2 := 0.0
	var y1 := amp * sin(w)
	var cnt := mini(n - start, int(4.6 * tau * rate))
	for i in cnt:
		out[start + i] += y1
		var y := c * y1 - r2 * y2
		y2 = y1
		y1 = y
	return out


## Adds a tone with optional odd harmonics (`square` 0..1) and linear attack/release.
static func tone(out: PackedFloat32Array, rate: float, t0: float, dur: float, f: float, square: float, att: float, rel: float, amp: float) -> PackedFloat32Array:
	var i0 := int(t0 * rate)
	var cnt := mini(int(dur * rate), out.size() - i0)
	var w := TAU * f / rate
	for j in cnt:
		var t := float(j) / rate
		var e := minf(1.0, t / att) * minf(1.0, (dur - t) / rel)
		var ph := w * float(j)
		out[i0 + j] += amp * e * (sin(ph) + square * (sin(3.0 * ph) / 3.0 + sin(5.0 * ph) / 5.0))
	return out


static func add(dst: PackedFloat32Array, src: PackedFloat32Array, offset: int, gain: float) -> PackedFloat32Array:
	var cnt := mini(src.size(), dst.size() - offset)
	for i in cnt:
		dst[offset + i] += src[i] * gain
	return dst


static func scale(buf: PackedFloat32Array, g: float) -> PackedFloat32Array:
	for i in buf.size():
		buf[i] *= g
	return buf


static func peak(buf: PackedFloat32Array) -> float:
	var mx := 0.0
	for i in buf.size():
		var v := buf[i]
		if v > mx:
			mx = v
		elif -v > mx:
			mx = -v
	return mx


static func normalize(buf: PackedFloat32Array, target: float) -> PackedFloat32Array:
	var pk := peak(buf)
	if pk > 1.0e-12:
		scale(buf, target / pk)
	return buf


## tanh saturation normalised so that +-1 maps to +-1.
static func soft_clip(buf: PackedFloat32Array, drive: float) -> PackedFloat32Array:
	var inv := 1.0 / tanh(drive)
	for i in buf.size():
		buf[i] = tanh(drive * buf[i]) * inv
	return buf


static func fade_out(buf: PackedFloat32Array, rate: float, secs: float) -> PackedFloat32Array:
	var n := buf.size()
	var m := mini(n, int(secs * rate))
	for j in m:
		buf[n - m + j] *= 1.0 - float(j + 1) / float(m)
	return buf


## Seamless loop: the last `xn` samples are crossfaded (equal power) into the head.
## Input length L + xn, output length L.
static func loopify(buf: PackedFloat32Array, xn: int) -> PackedFloat32Array:
	var l := buf.size() - xn
	var out := buf.slice(0, l)
	for i in xn:
		var th := float(i) / float(xn) * PI * 0.5
		out[i] = buf[i] * sin(th) + buf[l + i] * cos(th)
	return out


static func _stereo_norm(l: PackedFloat32Array, r: PackedFloat32Array, target: float, rate: int, loop: bool) -> AudioStreamWAV:
	var pk := maxf(peak(l), peak(r))
	return to_wav_stereo(l, r, rate, loop, target / maxf(pk, 1.0e-12))


# =============================================================================== packing

## Mono float buffer -> 16-bit AudioStreamWAV. Two samples are packed per int32 and the whole
## buffer is converted with one to_byte_array() (little-endian, same bytes as encode_s16).
static func to_wav(buf: PackedFloat32Array, rate: int, loop: bool, gain := 1.0) -> AudioStreamWAV:
	var n := buf.size()
	var pairs := (n + 1) >> 1
	var ints := PackedInt32Array()
	ints.resize(pairs)
	var j := 0
	for i in pairs:
		var a := buf[j] * gain
		var b := 0.0
		if j + 1 < n:
			b = buf[j + 1] * gain
		if a > 1.0:
			a = 1.0
		elif a < -1.0:
			a = -1.0
		if b > 1.0:
			b = 1.0
		elif b < -1.0:
			b = -1.0
		ints[i] = int(b * 32767.0) * 65536 + (int(a * 32767.0) & 0xFFFF)
		j += 2
	var bytes := ints.to_byte_array()
	if n & 1:
		bytes.resize(n * 2)
	return _wav(bytes, rate, false, loop, n)


## Two float buffers (same length) -> interleaved 16-bit stereo AudioStreamWAV.
static func to_wav_stereo(l: PackedFloat32Array, r: PackedFloat32Array, rate: int, loop: bool, gain := 1.0) -> AudioStreamWAV:
	var n := mini(l.size(), r.size())
	var ints := PackedInt32Array()
	ints.resize(n)
	for i in n:
		var a := l[i] * gain
		var b := r[i] * gain
		if a > 1.0:
			a = 1.0
		elif a < -1.0:
			a = -1.0
		if b > 1.0:
			b = 1.0
		elif b < -1.0:
			b = -1.0
		ints[i] = int(b * 32767.0) * 65536 + (int(a * 32767.0) & 0xFFFF)
	return _wav(ints.to_byte_array(), rate, true, loop, n)


static func _wav(bytes: PackedByteArray, rate: int, stereo: bool, loop: bool, frames: int) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = stereo
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = frames
	return w
