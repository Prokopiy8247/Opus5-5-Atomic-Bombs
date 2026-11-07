class_name BlastPhysics
extends RefCounted
## Explosion physics: closed-form fits from Glasstone & Dolan (1962/1977), Fletcher 1963,
## the DNA 1-kt standard, Miller 1963 (cloud, as coded in NUKEMAP), Sublette's Nuclear Weapons
## FAQ, Sedov-Taylor and Kingery-Bulmash for conventional HE. Sources and the resolution of
## disputed values: docs/RESEARCH_NOTES.md and docs/research_parts/techniques_and_physics.md.
## W is the yield in KILOTONS of TNT. Distances in metres, times in seconds, pressure in psi.

const FT := 0.3048
const KT_J := 4.184e12
const RHO_AIR := 1.2
const C0 := 343.0
const P0_PSI := 14.7
const PSI_PA := 6894.76
const SEISMIC_V := 1800.0     # m/s, P-wave in alluvium (arrives before the air wave)
const HE_RADIUS_FACTOR := 0.82  # Kingery-Bulmash HE radii vs the nuclear optimum-HOB fit (181 m vs 220 m at 1 t, 1 psi)

static var _pulse_cdf := PackedFloat64Array()


# ---------------------------------------------------------------- fireball

## Roll-off above 1 Mt: min(1, (W/1000)^-0.03) (Bravo 6.8 km, Tsar 8.2 km diameters).
static func megaton_factor(w_kt: float) -> float:
	return minf(1.0, pow(maxf(w_kt, 1e-9) / 1000.0, -0.03))


## Maximum luminous fireball radius (m): 61 m W^0.4 in free air, 79 m W^0.4 for contact bursts.
static func fireball_r_max(w_kt: float, surface: bool) -> float:
	return (79.0 if surface else 61.0) * pow(w_kt, 0.4) * megaton_factor(w_kt)


## Radius at shock breakaway: 33.5 / 44.2 m W^0.4.
static func fireball_r_breakaway(w_kt: float, surface: bool) -> float:
	return (44.2 if surface else 33.5) * pow(w_kt, 0.4) * megaton_factor(w_kt)


## First thermal minimum: 3.5 W^0.4 ms (G&D 2.125; 11 ms at 20 kt).
static func t_min(w_kt: float) -> float:
	return 0.0035 * pow(w_kt, 0.4)


## Second thermal maximum: 0.0417 W^0.44 s (G&D eq. 7.85.1).
static func t_second_max(w_kt: float) -> float:
	return 0.0417 * pow(w_kt, 0.44)


static func t_breakaway(w_kt: float) -> float:
	return 1.36 * t_min(w_kt)


## Time to the maximum luminous size ~ 10 t2.
static func t_fireball_max(w_kt: float) -> float:
	return 10.0 * t_second_max(w_kt)


## Sedov-Taylor blast radius. Free air uses E = 0.5 W (hydrodynamic share); a surface/tower
## hemisphere behaves like a sphere of ~E = W (Trinity's measured 138 m at 25 ms).
static func sedov_taylor_r(w_kt: float, t: float, surface := false) -> float:
	if t <= 0.0:
		return 0.0
	var e := w_kt * KT_J * (1.0 if surface else 0.5)
	return 1.033 * pow(e * t * t / RHO_AIR, 0.2)


## Luminous fireball radius vs time: Sedov-Taylor early, smoothly limited by R_max.
static func fireball_radius(w_kt: float, t: float, surface: bool) -> float:
	if t <= 0.0:
		return 0.0
	var rst := sedov_taylor_r(w_kt, t, surface)
	var rmax := fireball_r_max(w_kt, surface)
	var n := 4.0
	return pow(pow(rst, -n) + pow(rmax, -n), -1.0 / n)


## Normalised thermal power of the main pulse, P/Pmax = (15/7) tau^2 / (1 + (8/7) tau^3.75).
static func pulse_shape(tau: float) -> float:
	if tau <= 0.0:
		return 0.0
	return (15.0 / 7.0) * tau * tau / (1.0 + (8.0 / 7.0) * pow(tau, 3.75))


## Normalised thermal power (1 at the second maximum) including the first (UV) pulse spike.
static func thermal_power(w_kt: float, t: float) -> float:
	if t <= 0.0:
		return 0.0
	var tm := t_min(w_kt)
	var p2 := pulse_shape(t / t_second_max(w_kt))
	var y := t / (tm / 6.0)
	var p1 := 0.9 * y * exp(1.0 - y)
	return p1 + p2


static func _ensure_cdf() -> void:
	if _pulse_cdf.size() > 0:
		return
	# cumulative integral of pulse_shape on a log grid tau = 10^(-3..3), 256 entries
	var n := 256
	_pulse_cdf.resize(n)
	var acc := 0.0
	var prev_tau := 0.0
	var prev_p := 0.0
	for i in n:
		var tau := pow(10.0, -3.0 + 6.0 * float(i) / (n - 1))
		var p := pulse_shape(tau)
		acc += 0.5 * (p + prev_p) * (tau - prev_tau)
		_pulse_cdf[i] = acc
		prev_tau = tau
		prev_p = p
	# analytic tail beyond tau = 1000: ~ (15/8) tau^-1.75 -> integral (15/8)/0.75 tau^-0.75
	var tail := (15.0 / 8.0) / 0.75 * pow(1000.0, -0.75)
	var total := acc + tail
	for i in n:
		_pulse_cdf[i] /= total


## Fraction of the thermal energy radiated by time t.
static func thermal_fraction(w_kt: float, t: float) -> float:
	if t <= 0.0:
		return 0.0
	_ensure_cdf()
	var tau := t / t_second_max(w_kt)
	var x := (log(tau) / log(10.0) + 3.0) / 6.0 * 255.0
	if x <= 0.0:
		return 0.0
	if x >= 255.0:
		return _pulse_cdf[255]
	var i := int(x)
	return lerpf(_pulse_cdf[i], _pulse_cdf[i + 1], x - i)


## Apparent (brightness) temperature: Stefan-Boltzmann with P = 4 pi sigma T^4 R^2 anchored
## to 8000 K at the second maximum; early shock-front temperatures before t_min.
static func fireball_temperature(w_kt: float, t: float, surface := false) -> float:
	if t <= 0.0:
		return 100000.0
	var tm := t_min(w_kt)
	var t2 := t_second_max(w_kt)
	if t < tm:
		var x := clampf(log(t / (tm * 0.01)) / log(100.0), 0.0, 1.0)
		return exp(lerpf(log(60000.0), log(3300.0), x))
	if t < t2:
		var x2 := clampf(log(t / tm) / log(t2 / tm), 0.0, 1.0)
		return lerpf(3300.0, 8000.0, x2 * x2 * (3.0 - 2.0 * x2))
	var r2 := fireball_radius(w_kt, t2, surface)
	var r := fireball_radius(w_kt, t, surface)
	var temp := 8000.0 * pow(pulse_shape(t / t2), 0.25) * sqrt(r2 / maxf(r, 1e-3))
	return maxf(temp, 600.0)


# ---------------------------------------------------------------- blast wave

## Optimum-HOB airburst radius for a pressure (Sublette/G&D: 2.2, 1.0, 0.71, 0.45, 0.28 km W^1/3).
static func _r_opt(w_kt: float, p_psi: float) -> float:
	var k := 2200.0 * pow(w_kt, 1.0 / 3.0)
	if p_psi >= 1.0:
		return k * pow(p_psi, -2.0 / 3.0)
	# far field: DNA free-air shape spliced at 1 psi (falls as 1/(R sqrt(ln R)))
	var lo := k
	# (bracket up to 1e5 k: with 2000 k the search saturated for small HE charges beyond ~170 km and
	# overpressure() fell to its 1e-5 psi floor - a 25 dB step)
	var hi := k * 1.0e5
	for i in 70:
		var mid := sqrt(lo * hi)
		if _far_field(w_kt, mid) > p_psi:
			lo = mid
		else:
			hi = mid
	return sqrt(lo * hi)


static func _dna_free_air_pa(r_scaled: float) -> float:
	var r := maxf(r_scaled, 1.0)
	var a := r / 445.42
	return 3.04e11 / (r * r * r) + 1.13e9 / (r * r) + 7.9e6 / (r * sqrt(log(a + 3.0 * exp(-sqrt(a) / 3.0))))


## Overpressure below 1 psi: DNA curve stretched so that 1 psi falls at the optimum-HOB radius.
static func _far_field(w_kt: float, r: float) -> float:
	var k := 2200.0 * pow(w_kt, 1.0 / 3.0)
	var stretch := 1129.0 / 2200.0            # DNA free-air 1 psi radius / optimum fit radius (1 kt)
	var rs := r / pow(w_kt, 1.0 / 3.0) * stretch
	var r1 := k / pow(w_kt, 1.0 / 3.0) * stretch
	return _dna_free_air_pa(rs) / _dna_free_air_pa(r1)


## Contact-surface / optimum-HOB radius ratio, pressure dependent (Fletcher eq. 2.5 / G&D 1962).
static func surface_factor(p_psi: float) -> float:
	var ps := [1.0, 3.0, 5.0, 10.0, 20.0, 50.0, 100.0]
	var fs := [0.55, 0.60, 0.64, 0.70, 0.77, 0.85, 0.90]
	return _interp_log(clampf(p_psi, 1.0, 100.0), ps, fs)


## Radius (m) at which the given peak overpressure is reached.
static func radius_for_pressure(w_kt: float, p_psi: float, surface := false, conventional := false) -> float:
	var r := _r_opt(w_kt, p_psi)
	if conventional:
		# Kingery-Bulmash hemispherical (surface) HE charges: 18.2 m M^(1/3) at 1 psi
		return r * HE_RADIUS_FACTOR
	if surface:
		r *= surface_factor(p_psi)
	return r


## Peak overpressure (psi) at slant distance r (m).
static func overpressure(w_kt: float, r: float, surface := false, conventional := false) -> float:
	if r <= 1.0:
		r = 1.0
	if not surface and not conventional:
		var k := 2200.0 * pow(w_kt, 1.0 / 3.0)
		if r <= k:
			return pow(k / r, 1.5)
		return _far_field(w_kt, r)
	# invert radius_for_pressure (monotonic) in log space
	var lo := log(1e-5)
	var hi := log(1e5)
	for i in 50:
		var mid := 0.5 * (lo + hi)
		if radius_for_pressure(w_kt, exp(mid), surface, conventional) > r:
			lo = mid
		else:
			hi = mid
	return exp(0.5 * (lo + hi))


static func shock_speed(p_psi: float) -> float:
	return C0 * sqrt(1.0 + 6.0 * p_psi / (7.0 * P0_PSI))


static func dynamic_pressure(p_psi: float) -> float:
	return 2.5 * p_psi * p_psi / (7.0 * P0_PSI + p_psi)


static func reflected_pressure(p_psi: float) -> float:
	return 2.0 * p_psi * (7.0 * P0_PSI + 4.0 * p_psi) / (7.0 * P0_PSI + p_psi)


## Peak wind speed behind the front (m/s), Rankine-Hugoniot.
static func peak_wind(p_psi: float) -> float:
	return 5.0 * p_psi / (7.0 * P0_PSI) * C0 / sqrt(1.0 + 6.0 * p_psi / (7.0 * P0_PSI))


## DNA 1-kt time of arrival t1(r) for scaled distance r (m).
static func _dna_t1(r: float) -> float:
	return r * r * (6.7 + r) / (7.12e6 + 7.32e4 * r + 340.5 * r * r)


## Shock arrival time (s) at slant distance r. Free air W; ideal surface burst 2W (G&D checks:
## 20 kt 3.1 s at 1 mi, 1 Mt 4.5 s at 2 mi).
static func arrival_time(w_kt: float, r: float, surface := false, conventional := false) -> float:
	if r <= 0.0:
		return 0.0
	var we := w_kt * (2.0 if surface else 1.0)
	if conventional:
		we = w_kt * pow(HE_RADIUS_FACTOR, 3.0) * (2.0 if surface else 1.0)
	var s := pow(we, 1.0 / 3.0)
	return s * _dna_t1(r / s)


## Inverse of arrival_time: shock (slant) radius at time t.
static func shock_radius(w_kt: float, t: float, surface := false, conventional := false) -> float:
	if t <= 0.0:
		return 0.0
	var lo := 0.01
	var hi := 2.0e6
	for i in 60:
		var mid := sqrt(lo * hi)
		if arrival_time(w_kt, mid, surface, conventional) < t:
			lo = mid
		else:
			hi = mid
	return sqrt(lo * hi)


## Positive-phase duration (Fletcher 2.68 optimum HOB; surface 0.569 p^-0.381).
static func positive_phase(w_kt: float, p_psi: float, surface := false) -> float:
	if surface:
		return 0.569 * pow(clampf(p_psi, 2.5, 90.0), -0.381) * pow(w_kt, 1.0 / 3.0)
	var ps := [1.0, 2.5, 5.0, 10.0, 20.0, 50.0, 100.0]
	var cs := [0.505, 0.401, 0.331, 0.267, 0.208, 0.139, 0.097]
	return _interp_log(clampf(p_psi, 1.0, 100.0), ps, cs) * pow(w_kt, 1.0 / 3.0)


## Mach stem formation ground range (DNA): x_m = h^2.5/5822 + 2.09 h^0.75 (scaled metres).
static func mach_stem_range(w_kt: float, hob: float) -> float:
	var s := pow(w_kt, 1.0 / 3.0)
	var h := maxf(hob, 0.0) / s
	return (pow(h, 2.5) / 5822.0 + 2.09 * pow(h, 0.75)) * s


static func sound_delay(d: float) -> float:
	return d / C0


static func seismic_delay(d: float) -> float:
	return d / SEISMIC_V


# ---------------------------------------------------------------- thermal

## Atmospheric transmittance tau = exp(-k d_km^0.44); k = 0.14 very clear .. 0.22 typical.
static func transmittance(d_m: float, humidity: float = 0.5) -> float:
	var k := lerpf(0.14, 0.24, clampf(humidity, 0.0, 1.0))
	return exp(-k * pow(maxf(d_m, 0.0) / 1000.0, 0.44))


## Thermal fluence (cal/cm^2) at slant distance d (m): Q = 0.35 W 10^12 tau / (4 pi d^2).
static func thermal_fluence(w_kt: float, d: float, humidity := 0.5, fraction := 0.35) -> float:
	var dcm := maxf(d, 1.0) * 100.0
	return fraction * w_kt * 1e12 * transmittance(d, humidity) / (4.0 * PI * dcm * dcm)


## Burn ranges (m), clear air (NUKEMAP-consistent): R3 = 0.65 W^0.44, R2 = 0.79 W^0.44, R1 = 1.12 W^0.43 km.
static func burn_radius(w_kt: float, degree: int) -> float:
	match degree:
		1:
			return 1120.0 * pow(w_kt, 0.43)
		2:
			return 790.0 * pow(w_kt, 0.44)
		_:
			return 650.0 * pow(w_kt, 0.44)


## Ignition threshold (cal/cm^2), log-interpolated between the 35 kt / 1.4 Mt / 20 Mt columns of G&D table 7.40.
static func ignition_threshold(w_kt: float, material: String) -> float:
	var tbl := {
		"paper": [4.0, 6.0, 11.0], "leaves": [4.0, 6.0, 8.0], "grass": [5.0, 8.0, 10.0],
		"cotton": [12.0, 18.0, 28.0], "wood": [10.0, 15.0, 20.0],
	}
	var v: Array = tbl.get(material, tbl["grass"])
	return _interp_log(clampf(w_kt, 35.0, 20000.0), [35.0, 1400.0, 20000.0], v)


## Peak thermal power Pmax = 3.18 W^0.56 kt/s (G&D eq. 7.85.2).
static func peak_thermal_power_w(w_kt: float) -> float:
	return 3.18 * pow(w_kt, 0.56) * KT_J


## Irradiance of the flash at the observer in multiples of the noon sun (1000 W/m^2).
## 1 Mt at 10 km peaks at ~300x (research A4.4).
static func flash_illuminance(w_kt: float, t: float, d: float, humidity := 0.5) -> float:
	var p := thermal_power(w_kt, t)
	return peak_thermal_power_w(w_kt) * p * transmittance(d, humidity) / (4.0 * PI * maxf(d * d, 1.0)) / 1000.0


# ---------------------------------------------------------------- cloud

## Cloud top (m above ground) : Miller 1963 (NUKEMAP) up to 1 Mt, 24.3 km (W/1 Mt)^0.2 above,
## 2.44 km W^0.3 below 1 kt; x0.82 for dry mid-latitude sites. Measured per-bomb overrides
## live in the bomb profiles.
static func cloud_top(w_kt: float, humid := false) -> float:
	var h := 0.0
	if w_kt <= 1.0:
		h = 2440.0 * pow(maxf(w_kt, 1e-6), 0.3)
	elif w_kt <= 1000.0:
		var hc := 2010.0 * pow(w_kt, 0.445) if w_kt <= 28.0 else 5120.0 * pow(w_kt, 0.164)
		h = hc + 427.0 * pow(w_kt, 0.431)
	else:
		h = 24300.0 * pow(w_kt / 1000.0, 0.2)
	return h * (1.0 if humid else 0.82)


## Cap radius at ~10 min: a = 0.713 km W^0.431 (Miller, DELFIC-checked), sub-kt continuation.
static func cloud_cap_radius(w_kt: float) -> float:
	return 713.0 * pow(maxf(w_kt, 1e-6), 0.431)


## Rise time constant tau_r = 165 s (W/1 Mt)^0.1 clamped to [60, 250] s (fit to G&D table 2.12).
static func cloud_rise_tau(w_kt: float) -> float:
	return clampf(165.0 * pow(maxf(w_kt, 1e-6) / 1000.0, 0.1), 60.0, 250.0)


## Normalised cloud-top rise z/H: tanh(t / tau_r).
static func cloud_rise_fraction(t: float, w_kt: float) -> float:
	return tanh(maxf(t, 0.0) / cloud_rise_tau(w_kt))


static func cloud_stabilization_time(w_kt: float) -> float:
	return 3.0 * cloud_rise_tau(w_kt)


## Stem radius: a clamp(0.5 - 0.2 log10(W/20), 0.1, 0.5).
static func stem_radius(w_kt: float) -> float:
	return cloud_cap_radius(w_kt) * clampf(0.5 - 0.2 * log(maxf(w_kt, 1e-6) / 20.0) / log(10.0), 0.1, 0.5)


## Height of burst below which the fireball raises a heavy dust stem: 55 m W^0.4 (+-30%).
static func dust_height_threshold(w_kt: float) -> float:
	return 55.0 * pow(w_kt, 0.4)


# ---------------------------------------------------------------- craters, conventional

## Dry-soil contact-burst crater: R = 18.3 m W^0.3, depth D = 9.1 m W^0.3 (G&D 6.09).
static func crater_radius_nuclear(w_kt: float) -> float:
	return 18.3 * pow(w_kt, 0.3)


static func crater_depth_nuclear(w_kt: float) -> float:
	return 9.1 * pow(w_kt, 0.3)


static func crater_diameter_conventional(w_t: float) -> float:
	return 9.5 * pow(w_t, 1.0 / 3.0)


static func conventional_fireball_radius(charge_kg: float) -> float:
	return 1.0 * pow(charge_kg, 1.0 / 3.0)


static func conventional_fireball_duration(charge_kg: float) -> float:
	return 0.04 * pow(charge_kg, 1.0 / 3.0)


static func thermobaric_cloud_diameter(fuel_kg: float) -> float:
	return 5.8 * pow(fuel_kg, 1.0 / 3.0)


static func thermobaric_duration(fuel_kg: float) -> float:
	return 0.45 * pow(fuel_kg, 1.0 / 3.0)


## Wilson cloud (G&D 2.48-2.50, game model): appears at (W/20)^(1/3) s, lasts 1.5 (W/20)^(1/3) s.
static func wilson_time(w_kt: float) -> float:
	return pow(maxf(w_kt, 1e-6) / 20.0, 1.0 / 3.0)


static func wilson_duration(w_kt: float) -> float:
	return 1.5 * pow(maxf(w_kt, 1e-6) / 20.0, 1.0 / 3.0)


static func wilson_radius(w_kt: float) -> float:
	return 0.85 * shock_radius(w_kt, wilson_time(w_kt))


# ---------------------------------------------------------------- helpers

static func _interp_lin(x: float, xs: Array, ys: Array) -> float:
	if x <= xs[0]:
		return ys[0]
	for i in range(1, xs.size()):
		if x <= xs[i]:
			var t: float = (x - xs[i - 1]) / (xs[i] - xs[i - 1])
			return lerpf(ys[i - 1], ys[i], t)
	return ys[ys.size() - 1]


static func _interp_log(x: float, xs: Array, ys: Array) -> float:
	var lx := log(maxf(x, 1e-12))
	if x <= xs[0]:
		return ys[0]
	for i in range(1, xs.size()):
		if x <= xs[i]:
			var t: float = (lx - log(xs[i - 1])) / (log(xs[i]) - log(xs[i - 1]))
			return lerpf(ys[i - 1], ys[i], t)
	return ys[ys.size() - 1]


static func is_finite_num(v: float) -> bool:
	return not (is_nan(v) or is_inf(v))
