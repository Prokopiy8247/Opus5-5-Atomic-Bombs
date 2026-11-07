class_name BlastPhysics
extends RefCounted
## Explosion physics: closed-form fits from Glasstone & Dolan, Sublette's Nuclear Weapons FAQ,
## Sedov-Taylor, and conventional-explosive scaling (see docs/02_PHYSICS_REFERENCE.md and
## docs/RESEARCH_NOTES.md). W is the yield in KILOTONS of TNT unless stated otherwise.
## Distances in metres, times in seconds, pressure in psi.

const FT := 0.3048
const KT_J := 4.184e12
const RHO_AIR := 1.2
const C0 := 343.0
const P0_PSI := 14.7
const SEISMIC_V := 1800.0     # m/s, P-wave in alluvium (fast enough to arrive before the air wave)


# ---------------------------------------------------------------- fireball

## Glasstone correction above 1 Mt (formula over-predicts by ~15-20% for multi-megaton yields).
static func megaton_factor(w_kt: float) -> float:
	if w_kt <= 1000.0:
		return 1.0
	var t := clampf(log(w_kt / 1000.0) / log(15.0), 0.0, 1.0)
	return lerpf(1.0, 0.85, t)


## Maximum luminous fireball radius (m). surface=true for contact/surface/tower bursts.
static func fireball_r_max(w_kt: float, surface: bool) -> float:
	var k := 290.0 if surface else 200.0
	return k * pow(w_kt, 0.4) * FT * megaton_factor(w_kt)


static func fireball_r_breakaway(w_kt: float, surface: bool) -> float:
	var k := 145.0 if surface else 100.0
	return k * pow(w_kt, 0.4) * FT * megaton_factor(w_kt)


static func t_min(w_kt: float) -> float:
	return 0.0022 * pow(w_kt, 0.5)


static func t_second_max(w_kt: float) -> float:
	return 0.039 * pow(w_kt, 0.45)


static func t_breakaway(w_kt: float) -> float:
	return 1.5 * t_min(w_kt)


static func t_fireball_max(w_kt: float) -> float:
	return 0.25 * pow(w_kt, 0.5)


## Sedov-Taylor blast radius with the full yield (fits Trinity's measured 138 m at 25 ms).
static func sedov_taylor_r(w_kt: float, t: float) -> float:
	if t <= 0.0:
		return 0.0
	var e := w_kt * KT_J
	return 1.033 * pow(e * t * t / RHO_AIR, 0.2)


## Luminous fireball radius vs time: Sedov-Taylor early, smoothly limited by R_max.
static func fireball_radius(w_kt: float, t: float, surface: bool) -> float:
	if t <= 0.0:
		return 0.0
	var rst := sedov_taylor_r(w_kt, t)
	var rmax := fireball_r_max(w_kt, surface)
	var n := 4.0
	return pow(pow(rst, -n) + pow(rmax, -n), -1.0 / n)


## Apparent (brightness) temperature of the fireball surface in kelvin.
static func fireball_temperature(w_kt: float, t: float) -> float:
	if t <= 0.0:
		return 100000.0
	var tm := t_min(w_kt)
	var t2 := t_second_max(w_kt)
	if t < tm:
		# from >1e5 K at the first microseconds down to the opaque shock front at ~3300 K
		var x := clampf(log(t / (tm * 0.01)) / log(100.0), 0.0, 1.0)
		return exp(lerpf(log(60000.0), log(3300.0), x))
	if t < t2:
		var x2 := clampf(log(t / tm) / log(t2 / tm), 0.0, 1.0)
		return lerpf(3300.0, 8000.0, x2 * x2 * (3.0 - 2.0 * x2))
	# after the second maximum: table in units of t2
	var xs := [1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 120.0, 400.0]
	var ts := [8000.0, 6500.0, 4500.0, 3000.0, 2000.0, 1500.0, 1100.0, 700.0]
	return _interp_log(t / t2, xs, ts)


## Normalised thermal power (0..~1, 1 at the second maximum) including the first pulse.
static func thermal_power(w_kt: float, t: float) -> float:
	if t <= 0.0:
		return 0.0
	var tm := t_min(w_kt)
	var t2 := t_second_max(w_kt)
	var x := t / t2
	var p2 := 2.0 * x * x / (1.0 + x * x * x * x)
	var tau := tm / 6.0
	var y := t / tau
	var p1 := 0.9 * y * exp(1.0 - y)
	return p1 + p2


## Fraction of the thermal energy radiated by time t (integral of p2 normalised).
static func thermal_fraction(w_kt: float, t: float) -> float:
	var x := t / t_second_max(w_kt)
	# closed-form integral of 2x^2/(1+x^4) normalised by pi/sqrt(2)
	var s2 := sqrt(2.0)
	var a := log((x * x - s2 * x + 1.0) / (x * x + s2 * x + 1.0)) / (2.0 * s2)
	var b := (atan(s2 * x + 1.0) + atan(s2 * x - 1.0)) / s2
	var integral := a + b
	return clampf(integral / (PI / s2), 0.0, 1.0)


# ---------------------------------------------------------------- blast wave

## Peak overpressure (psi) at slant distance r (m). surface=true scales radii by 0.8.
static func overpressure(w_kt: float, r: float, surface := false) -> float:
	var rr := r / (0.8 if surface else 1.0)
	rr = maxf(rr, 1.0)
	var k := 2200.0 * pow(w_kt, 1.0 / 3.0)
	var x := k / rr
	if x >= 1.0:
		return pow(x, 1.5)
	return x


## Radius (m) at which the given overpressure is reached.
static func radius_for_pressure(w_kt: float, p_psi: float, surface := false) -> float:
	var k := 2200.0 * pow(w_kt, 1.0 / 3.0)
	var r := 0.0
	if p_psi >= 1.0:
		r = k * pow(p_psi, -2.0 / 3.0)
	else:
		r = k / p_psi
	return r * (0.8 if surface else 1.0)


static func shock_speed(p_psi: float) -> float:
	return C0 * sqrt(1.0 + 6.0 * p_psi / (7.0 * P0_PSI))


static func dynamic_pressure(p_psi: float) -> float:
	return 2.5 * p_psi * p_psi / (7.0 * P0_PSI + p_psi)


static func reflected_pressure(p_psi: float) -> float:
	return 2.0 * p_psi * (7.0 * P0_PSI + 4.0 * p_psi) / (7.0 * P0_PSI + p_psi)


## Peak wind speed behind the front (m/s), Rankine-Hugoniot.
static func peak_wind(p_psi: float) -> float:
	return 5.0 * p_psi / (7.0 * P0_PSI) * C0 / sqrt(1.0 + 6.0 * p_psi / (7.0 * P0_PSI))


## Shock arrival time at slant distance r: integral of dR / U(p(R)).
static func arrival_time(w_kt: float, r: float, surface := false) -> float:
	if r <= 0.0:
		return 0.0
	var r0 := minf(fireball_r_breakaway(w_kt, surface) * 0.3, r)
	# early phase: Sedov-Taylor inverse for the first segment
	var e := w_kt * KT_J
	var t := pow(r0 / 1.033, 2.5) * sqrt(RHO_AIR / e)
	var steps := 200
	var lr0 := log(r0)
	var lr1 := log(r)
	var prev_r := r0
	for i in range(1, steps + 1):
		var rr := exp(lerpf(lr0, lr1, float(i) / steps))
		var rm := 0.5 * (rr + prev_r)
		t += (rr - prev_r) / shock_speed(overpressure(w_kt, rm, surface))
		prev_r = rr
	return t


static func positive_phase(w_kt: float, p_psi: float) -> float:
	var ps := [1.0, 2.5, 5.0, 10.0, 20.0, 50.0, 100.0]
	var cs := [0.55, 0.52, 0.40, 0.30, 0.22, 0.14, 0.10]
	var c := _interp_log(clampf(p_psi, 1.0, 100.0), ps, cs)
	return c * pow(w_kt, 1.0 / 3.0)


static func sound_delay(d: float) -> float:
	return d / C0


static func seismic_delay(d: float) -> float:
	return d / SEISMIC_V


# ---------------------------------------------------------------- thermal

## Atmospheric transmittance for the thermal/light pulse.
static func transmittance(d_m: float, humidity: float = 0.5) -> float:
	var lam := lerpf(35000.0, 18000.0, clampf(humidity, 0.0, 1.0))
	return exp(-d_m / lam)


## Thermal fluence (cal/cm^2) at slant distance d (m).
static func thermal_fluence(w_kt: float, d: float, humidity := 0.5, fraction := 0.35) -> float:
	var dcm := maxf(d, 1.0) * 100.0
	return fraction * w_kt * 1e12 * transmittance(d, humidity) / (4.0 * PI * dcm * dcm)


## Burn ranges (m) for 1st/2nd/3rd degree (Glasstone fits, 1 kt - 20 Mt).
static func burn_radius(w_kt: float, degree: int) -> float:
	match degree:
		1:
			return 1200.0 * pow(w_kt, 0.38)
		2:
			return 870.0 * pow(w_kt, 0.40)
		_:
			return 670.0 * pow(w_kt, 0.41)


## Ignition threshold (cal/cm^2) for a material class, interpolated in log(W) between
## the 35 kt / 1.4 Mt / 20 Mt columns of Glasstone table 7.40.
static func ignition_threshold(w_kt: float, material: String) -> float:
	var tbl := {
		"paper": [4.0, 6.0, 11.0], "leaves": [4.0, 6.0, 8.0], "grass": [5.0, 8.0, 10.0],
		"cotton": [12.0, 18.0, 28.0], "wood": [10.0, 15.0, 20.0],
	}
	var v: Array = tbl.get(material, tbl["grass"])
	return _interp_log(clampf(w_kt, 35.0, 20000.0), [35.0, 1400.0, 20000.0], v)


## Relative illuminance of the flash at the observer in multiples of the noon sun.
## Calibrated: 1 Mt at 10 km ~ 450x sun, at 50 km ~ 4x (docs/02 section 4).
static func flash_illuminance(w_kt: float, t: float, d: float, humidity := 0.5) -> float:
	var p := thermal_power(w_kt, t)
	return 1.5e9 * pow(w_kt, 0.55) * p * transmittance(d, humidity) / maxf(d * d, 1.0)


# ---------------------------------------------------------------- cloud

## Cloud top (m above the burst point for small yields; above ground for large),
## log-log interpolation of docs/02 section 3 (Glasstone fig. 2.16 / Sublette).
static func cloud_top(w_kt: float) -> float:
	var ws := [0.00001, 0.001, 0.01, 0.1, 1.0, 10.0, 15.0, 100.0, 1000.0, 10000.0, 15000.0, 50000.0]
	var hs := [60.0, 260.0, 600.0, 1300.0, 3100.0, 5800.0, 7300.0, 14600.0, 23500.0, 35000.0, 40000.0, 65000.0]
	return _interp_loglog(w_kt, ws, hs)


static func cloud_cap_radius(w_kt: float) -> float:
	var ws := [0.00001, 0.001, 0.01, 0.1, 1.0, 10.0, 100.0, 1000.0, 10000.0, 15000.0, 50000.0]
	var rs := [25.0, 100.0, 230.0, 420.0, 700.0, 1500.0, 5000.0, 15000.0, 50000.0, 52000.0, 47500.0]
	return _interp_loglog(w_kt, ws, rs)


static func cloud_stabilization_time(w_kt: float) -> float:
	var ws := [0.00001, 0.001, 0.1, 1.0, 10.0, 100.0, 1000.0, 15000.0, 50000.0]
	var ts := [15.0, 40.0, 150.0, 240.0, 300.0, 480.0, 600.0, 660.0, 600.0]
	return _interp_log(w_kt, ws, ts)


## Normalised cloud-top rise z/H vs t/t_stab (1 Mt reference curve, docs/02 section 3).
static func cloud_rise_fraction(t_norm: float) -> float:
	var xs := [0.0, 0.03, 0.07, 0.11, 0.25, 0.38, 0.6, 0.8, 1.0, 1.4]
	var ys := [0.0, 0.13, 0.27, 0.40, 0.67, 0.80, 0.92, 0.98, 1.0, 1.0]
	return _interp_lin(t_norm, xs, ys)


## Height of burst below which the fireball raises heavy dust (docs/02 sec. 3): 180 W^0.4 ft.
static func dust_height_threshold(w_kt: float) -> float:
	return 180.0 * pow(w_kt, 0.4) * FT


# ---------------------------------------------------------------- craters, conventional

static func crater_radius_nuclear(w_kt: float) -> float:
	return 18.3 * pow(w_kt, 0.3)


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


static func wilson_radius(w_kt: float) -> float:
	return 200.0 * pow(w_kt, 1.0 / 3.0)


static func wilson_duration(w_kt: float) -> float:
	return 1.5 * pow(maxf(w_kt, 0.0001) / 23.0, 1.0 / 3.0)


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
	# log in x, linear in y
	var lx := log(maxf(x, 1e-12))
	if x <= xs[0]:
		return ys[0]
	for i in range(1, xs.size()):
		if x <= xs[i]:
			var t: float = (lx - log(xs[i - 1])) / (log(xs[i]) - log(xs[i - 1]))
			return lerpf(ys[i - 1], ys[i], t)
	return ys[ys.size() - 1]


static func _interp_loglog(x: float, xs: Array, ys: Array) -> float:
	var lx := log(maxf(x, 1e-12))
	if x <= xs[0]:
		return ys[0]
	for i in range(1, xs.size()):
		if x <= xs[i]:
			var t: float = (lx - log(xs[i - 1])) / (log(xs[i]) - log(xs[i - 1]))
			return exp(lerpf(log(ys[i - 1]), log(ys[i]), t))
	return ys[ys.size() - 1]


static func is_finite_num(v: float) -> bool:
	return not (is_nan(v) or is_inf(v))
