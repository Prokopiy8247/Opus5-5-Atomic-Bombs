extends RefCounted
## BlastDSP: offline DSP helpers for the per-event blast synthesis (static, thread-safe):
## an iterative radix-2 FFT, ISO 9613-1 atmospheric absorption, frequency-domain filtering and a
## deterministic random generator. Used by blast_synth.gd on a WorkerThreadPool task.
##
## Usage (no class_name on purpose):  const BlastDSP = preload("res://scripts/audio/blast_dsp.gd")


## In-place complex FFT of (re, im), length a power of two. inverse = true includes the 1/N.
static func fft(re: PackedFloat64Array, im: PackedFloat64Array, inverse: bool) -> void:
	var n := re.size()
	# bit-reversal permutation
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
	var length := 2
	var sgn := 1.0 if inverse else -1.0
	while length <= n:
		var ang := sgn * TAU / float(length)
		var wr := cos(ang)
		var wi := sin(ang)
		var half := length >> 1
		var i0 := 0
		while i0 < n:
			var cr := 1.0
			var ci := 0.0
			for k in half:
				var a := i0 + k
				var b := a + half
				var xr := re[b] * cr - im[b] * ci
				var xi := re[b] * ci + im[b] * cr
				re[b] = re[a] - xr
				im[b] = im[a] - xi
				re[a] += xr
				im[a] += xi
				var ncr := cr * wr - ci * wi
				ci = cr * wi + ci * wr
				cr = ncr
			i0 += length
		length <<= 1
	if inverse:
		var inv := 1.0 / float(n)
		for i in n:
			re[i] *= inv
			im[i] *= inv


static func next_pow2(n: int) -> int:
	var p := 1
	while p < n:
		p <<= 1
	return p


## ISO 9613-1 pure-tone atmospheric absorption coefficient in dB per metre.
## f Hz, temperature C, relative humidity %, pressure kPa.
static func iso9613_db_per_m(f: float, temp_c: float = 20.0, rh: float = 50.0, p_kpa: float = 101.325) -> float:
	var t := temp_c + 273.15
	var t0 := 293.15
	var t01 := 273.16
	var pr := 101.325
	var pa := p_kpa
	var psat_pr := pow(10.0, -6.8346 * pow(t01 / t, 1.261) + 4.6151)
	var h := rh * psat_pr * (pr / pa)                       # molar concentration of water vapour, %
	var fro := (pa / pr) * (24.0 + 4.04e4 * h * (0.02 + h) / (0.391 + h))
	var frn := (pa / pr) * pow(t / t0, -0.5) * (9.0 + 280.0 * h * exp(-4.170 * (pow(t / t0, -1.0 / 3.0) - 1.0)))
	var f2 := f * f
	var a := 8.686 * f2 * (1.84e-11 * (pr / pa) * pow(t / t0, 0.5) + pow(t / t0, -2.5) * (
			0.01275 * exp(-2239.1 / t) / (fro + f2 / fro) + 0.1068 * exp(-3352.0 / t) / (frn + f2 / frn)))
	return a


## Applies exp(-alpha(f) * dist) (ISO 9613-1) plus an optional 1st-order high-pass (hp_hz, the
## sub-audio part a loudspeaker cannot move) to a real signal, in place, via one FFT.
## The buffer is zero-padded to a power of two internally; returns the filtered signal (same length).
static func absorb(x: PackedFloat32Array, rate: float, dist_m: float, rh: float, temp_c: float, hp_hz: float, extra_lp_hz: float = 0.0, floor_gain: float = 0.0) -> PackedFloat32Array:
	var n0 := x.size()
	# at least 2x zero padding: the filter's impulse response must not wrap around (circular
	# convolution would smear the end of the buffer back onto the start)
	var n := next_pow2(n0 * 2)
	var re := PackedFloat64Array()
	re.resize(n)
	var im := PackedFloat64Array()
	im.resize(n)
	for i in n0:
		re[i] = x[i]
	fft(re, im, false)
	# tabulate the gain on a log-frequency grid (the ISO formula is costly) and interpolate
	var grid := 96
	var gf := PackedFloat64Array()
	var gg := PackedFloat64Array()
	for k in grid:
		var f := 5.0 * pow(rate * 0.5 / 5.0, float(k) / float(grid - 1))
		gf.append(f)
		var db := iso9613_db_per_m(f, temp_c, rh) * dist_m
		var g := maxf(pow(10.0, -db / 20.0), floor_gain)
		if hp_hz > 0.0:
			var r := f / hp_hz
			g *= r / sqrt(1.0 + r * r)
		if extra_lp_hz > 0.0:
			var q := f / extra_lp_hz
			g /= sqrt(1.0 + q * q * q * q)
		gg.append(g)
	var half := n >> 1
	var kk := 0
	for i in range(0, half + 1):
		var f := float(i) * rate / float(n)
		var g := 0.0
		if f <= gf[0]:
			g = gg[0] * (f / gf[0] if hp_hz > 0.0 else 1.0)
		else:
			while kk < grid - 2 and gf[kk + 1] < f:
				kk += 1
			var u := clampf((log(f) - log(gf[kk])) / (log(gf[kk + 1]) - log(gf[kk])), 0.0, 1.0)
			g = lerpf(gg[kk], gg[kk + 1], u)
		re[i] *= g
		im[i] *= g
		if i > 0 and i < half:
			re[n - i] *= g
			im[n - i] *= g
	fft(re, im, true)
	var out := PackedFloat32Array()
	out.resize(n0)
	for i in n0:
		out[i] = re[i]
	return out


## Frequency (Hz) above which air absorption over dist_m exceeds `db` (the audible "cut-off").
static func absorption_cutoff(dist_m: float, db: float, rh: float = 50.0, temp_c: float = 20.0) -> float:
	var lo := 5.0
	var hi := 20000.0
	for i in 40:
		var mid := sqrt(lo * hi)
		if iso9613_db_per_m(mid, temp_c, rh) * dist_m > db:
			hi = mid
		else:
			lo = mid
	return lo


## Deterministic xorshift random generator (independent of the global RNG, safe in threads).
class Rng:
	var s := 2463534242

	func _init(seed_val: int) -> void:
		s = (seed_val * 2654435761 + 12345) & 0xFFFFFFFF
		if s == 0:
			s = 2463534242
		for i in 4:
			next_u()

	func next_u() -> int:
		s ^= (s << 13) & 0xFFFFFFFF
		s ^= s >> 17
		s ^= (s << 5) & 0xFFFFFFFF
		s &= 0xFFFFFFFF
		return s

	## uniform [0, 1)
	func f() -> float:
		return float(next_u()) / 4294967296.0

	## uniform [-1, 1)
	func s1() -> float:
		return float(next_u()) / 2147483648.0 - 1.0

	func range(a: float, b: float) -> float:
		return a + (b - a) * f()

	## approximately normal (sum of 4 uniforms)
	func gauss() -> float:
		return (f() + f() + f() + f() - 2.0) * 1.7320508
