class_name ExplosionProfile
extends RefCounted
## Derives every size/time of an explosion from BlastPhysics (yield + burst type) and exposes
## the state of each visual layer as a pure function of the explosion's age (seconds).
## Art parameters (colours, noise, special features) come from the bomb's "profile" in bombs.json.

enum Kind {
	CONVENTIONAL_SURFACE, CONVENTIONAL_BURIED, THERMOBARIC,
	NUCLEAR_AIR, NUCLEAR_LOW_AIR, NUCLEAR_TOWER, NUCLEAR_SURFACE,
	NUCLEAR_BURIED, NUCLEAR_UNDERWATER, NUCLEAR_HIGH_AIR,
}

var bomb: Dictionary
var art: Dictionary          # bomb["profile"]
var kind: int
var w_kt := 1.0
var hob := 0.0               # height of burst (m), negative = depth
var nuclear := true
var surface := false         # fireball touches the ground (surface/tower/contact)
var charge_kg := 0.0

# derived physics
var r_fb_max := 0.0
var t_fb_max := 0.0
var t2 := 0.0
var tmin := 0.0
var cloud_top := 0.0         # m above ground zero
var cap_r := 0.0             # final cap radius
var cap_half := 0.0          # final cap half thickness
var t_stab := 0.0
var stem_r := 0.0
var crater_r := 0.0
var crater_depth := 0.0
var dusty := false           # burst low enough to raise heavy dust
var fb_duration := 0.0       # conventional fireball lifetime
var wilson_r := 0.0
var wilson_t := 0.0
var emission_scale := 3000.0


static func kind_from_string(s: String) -> int:
	var k: int = Kind.get(s, -1)
	return k if k >= 0 else Kind.NUCLEAR_AIR


func _init(b: Dictionary) -> void:
	bomb = b
	art = b.get("profile", {})
	kind = kind_from_string(String(b.get("burst_type", "NUCLEAR_AIR")))
	w_kt = float(b.get("yield_kt", 1.0))
	hob = float(b.get("burst_height_m", 0.0))
	charge_kg = float(b.get("charge_kg", 0.0))
	nuclear = kind >= Kind.NUCLEAR_AIR
	surface = kind in [Kind.NUCLEAR_SURFACE, Kind.NUCLEAR_TOWER, Kind.CONVENTIONAL_SURFACE]
	_derive()


func a(key: String, def: Variant) -> Variant:
	return art.get(key, def)


func _derive() -> void:
	tmin = BlastPhysics.t_min(w_kt)
	t2 = BlastPhysics.t_second_max(w_kt)
	t_fb_max = BlastPhysics.t_fireball_max(w_kt)
	if nuclear:
		r_fb_max = BlastPhysics.fireball_r_max(w_kt, surface or kind == Kind.NUCLEAR_LOW_AIR and hob < BlastPhysics.fireball_r_max(w_kt, false))
	else:
		var w_t := w_kt * 1000.0
		var m := charge_kg if charge_kg > 0.0 else w_t * 1000.0
		r_fb_max = BlastPhysics.conventional_fireball_radius(m)
		fb_duration = BlastPhysics.conventional_fireball_duration(m)
		t_fb_max = fb_duration * 0.35
		if kind == Kind.THERMOBARIC:
			r_fb_max = BlastPhysics.thermobaric_cloud_diameter(m) * 0.5
			fb_duration = BlastPhysics.thermobaric_duration(m)
			t_fb_max = fb_duration * 0.3
	r_fb_max *= float(a("fireball_scale", 1.0))
	cloud_top = float(a("cloud_top_m", BlastPhysics.cloud_top(w_kt) + (maxf(hob, 0.0) if w_kt < 15.0 else 0.0)))
	cap_r = float(a("cap_radius_m", BlastPhysics.cloud_cap_radius(w_kt)))
	cap_half = float(a("cap_half_m", clampf(cloud_top * 0.22, 15.0, 13000.0)))
	t_stab = float(a("t_stab_s", BlastPhysics.cloud_stabilization_time(w_kt)))
	var stem_frac := 0.45 if w_kt < 20.0 else lerpf(0.45, 0.14, clampf(log(w_kt / 20.0) / log(2500.0), 0.0, 1.0))
	stem_r = float(a("stem_radius_m", cap_r * stem_frac))
	dusty = hob < BlastPhysics.dust_height_threshold(w_kt) * 1.3
	if nuclear:
		crater_r = BlastPhysics.crater_radius_nuclear(w_kt) * float(a("crater_scale", 1.0))
		crater_depth = crater_r * 0.5
	else:
		crater_r = BlastPhysics.crater_diameter_conventional(w_kt * 1000.0) * 0.5 * float(a("crater_scale", 1.0))
		crater_depth = crater_r * 0.6
	if crater_r > 300.0:
		crater_depth = crater_r * 0.12 * float(a("crater_depth_scale", 1.0))
	wilson_r = BlastPhysics.wilson_radius(w_kt)
	wilson_t = BlastPhysics.wilson_duration(w_kt)
	emission_scale = float(a("emission", 3000.0 if nuclear else 160.0))


# ------------------------------------------------------------------ fireball

## Returns {center_y, radius, temp, opacity, emis, mottle, squash}
func fireball_state(t: float) -> Dictionary:
	var st := {"center_y": hob, "radius": 0.0, "temp": 0.0, "opacity": 0.0, "emis": 0.0, "mottle": 0.0, "squash": 1.0, "skin": 0.0}
	if t <= 0.0:
		return st
	if kind == Kind.NUCLEAR_UNDERWATER or kind == Kind.NUCLEAR_BURIED or kind == Kind.CONVENTIONAL_BURIED:
		return _hidden_fireball(t)
	if not nuclear:
		return _conventional_fireball(t)
	var r := BlastPhysics.fireball_radius(w_kt, t, surface)
	r = minf(r, r_fb_max) if t > t_fb_max * 0.5 else r * float(a("fireball_scale", 1.0))
	var temp := BlastPhysics.fireball_temperature(w_kt, t)
	var rise := head_center_y(t) - hob
	st["radius"] = r
	st["temp"] = temp
	st["center_y"] = hob + rise * 0.92
	if surface:
		st["center_y"] = maxf(hob * 0.5, 0.0) + rise * 0.92
	# opacity: opaque until it cools below ~1800 K, then dissolves into the head
	var fade := clampf((temp - 1250.0) / 900.0, 0.0, 1.0)
	st["opacity"] = fade
	st["emis"] = emission_scale * float(a("fireball_brightness", 1.0))
	st["mottle"] = clampf(1.0 - t / maxf(t2 * 1.5, 1e-4), 0.0, 1.0)
	# smoke skin forms as the ball cools (dark patches, NOx brown), ~8..40 t2
	st["skin"] = clampf((t / t2 - 8.0) / 32.0, 0.0, 1.0) * float(a("skin", 1.0))
	# a rising fireball flattens slightly (onset of the vortex)
	var tf := clampf((t - t_fb_max) / maxf(t_stab * 0.08, 0.5), 0.0, 1.0)
	st["squash"] = lerpf(1.0, 0.82, tf)
	if t > t_fb_max:
		st["radius"] = r_fb_max * (1.0 + 0.15 * tf)
	return st


func _conventional_fireball(t: float) -> Dictionary:
	var st := {"center_y": maxf(hob, 0.0), "radius": 0.0, "temp": 0.0, "opacity": 0.0, "emis": 0.0, "mottle": 0.0, "squash": 1.0, "skin": 0.0}
	var x := t / maxf(t_fb_max, 1e-4)
	var grow := 1.0 - exp(-x * 2.5)
	st["radius"] = r_fb_max * (0.25 + 0.75 * grow) * (1.0 + 0.1 * maxf(t - t_fb_max, 0.0) / maxf(fb_duration, 0.01))
	var life := clampf(t / maxf(fb_duration, 1e-3), 0.0, 1.5)
	var t_peak := 4200.0 if kind != Kind.THERMOBARIC else 2600.0
	if String(a("explosive", "tnt")) == "aluminized":
		t_peak = 5200.0
	st["temp"] = lerpf(t_peak, 1300.0, smoothstep(0.0, 1.0, life))
	st["opacity"] = clampf(1.0 - (life - 0.85) / 0.4, 0.0, 1.0)
	st["emis"] = emission_scale * float(a("fireball_brightness", 1.0))
	st["mottle"] = 0.0
	st["skin"] = clampf((life - 0.25) / 0.6, 0.0, 1.0) * float(a("skin", 1.0))
	st["center_y"] = maxf(hob, 0.0) + r_fb_max * 0.55 * (0.4 + 0.6 * grow) + (t * r_fb_max * 0.15 if kind == Kind.THERMOBARIC else 0.0)
	st["squash"] = 0.85 if kind != Kind.THERMOBARIC else 0.75
	return st


func _hidden_fireball(t: float) -> Dictionary:
	# buried / underwater: a brief glow venting (Sedan, Grand Slam), otherwise nothing
	var st := {"center_y": 0.0, "radius": 0.0, "temp": 0.0, "opacity": 0.0, "emis": 0.0, "mottle": 0.0, "squash": 1.0, "skin": 0.0}
	var vent := float(a("vent_glow", 0.0))
	if vent <= 0.0:
		return st
	var t0 := float(a("vent_time", 0.5))
	var dur := float(a("vent_duration", 0.6))
	var x := (t - t0) / dur
	if x < 0.0 or x > 1.0:
		return st
	st["radius"] = float(a("vent_radius", 30.0)) * (0.5 + 0.5 * x)
	st["center_y"] = float(a("vent_height", 20.0)) * (0.3 + 0.7 * x)
	st["temp"] = lerpf(3200.0, 1400.0, x)
	st["opacity"] = vent * (1.0 - x)
	st["emis"] = emission_scale
	st["squash"] = 0.6
	return st


## Visible luminous power (relative, 0..~1) driving lights and exposure.
func light_power(t: float) -> float:
	if t <= 0.0:
		return 0.0
	if nuclear:
		if kind == Kind.NUCLEAR_UNDERWATER:
			return 0.02 * exp(-t / 0.2)
		if kind == Kind.NUCLEAR_BURIED:
			var fs := fireball_state(t)
			return 0.03 * float(fs["opacity"])
		return BlastPhysics.thermal_power(w_kt, t)
	var fs2 := fireball_state(t)
	if float(fs2["radius"]) <= 0.0:
		return 0.0
	var tt: float = fs2["temp"]
	return float(fs2["opacity"]) * pow(tt / 4200.0, 4.0)


# ------------------------------------------------------------------ cloud head

func rise_norm(t: float) -> float:
	return BlastPhysics.cloud_rise_fraction(t / maxf(t_stab, 1.0))


func head_center_final() -> float:
	return cloud_top - cap_half


func head_center_y(t: float) -> float:
	var start := maxf(hob, 0.0) if nuclear else maxf(hob, 0.0) + r_fb_max * 0.5
	if surface:
		start = r_fb_max * 0.5
	var f := rise_norm(t)
	var target := head_center_final()
	var y := lerpf(start, target, f)
	# overshoot and settling for megaton clouds
	var ov := float(a("overshoot", 0.0 if w_kt < 200.0 else 0.06))
	if ov > 0.0:
		var x := t / maxf(t_stab, 1.0)
		y += target * ov * exp(-pow((x - 0.9) / 0.35, 2.0))
	return y


## Returns {center_y, radius, half, torus, density, roll, col_mix, heat_temp, heat_glow}
func head_state(t: float) -> Dictionary:
	var st := {"center_y": -1e6, "radius": 0.0, "half": 1.0, "torus": 0.0, "density": 0.0, "roll": 0.0,
		"col_mix": 0.0, "heat_temp": 0.0, "heat_glow": 0.0}
	if t <= 0.0:
		return st
	var x := t / maxf(t_stab, 1.0)
	var f := rise_norm(t)
	var start_r := r_fb_max * 1.05
	var start_h := r_fb_max * 1.0
	var appear := 0.0
	if nuclear:
		appear = clampf((t / t2 - 10.0) / 30.0, 0.0, 1.0)
	else:
		appear = clampf((t - t_fb_max * 0.5) / maxf(fb_duration * 0.6, 0.05), 0.0, 1.0)
	var grow := clampf(f * 1.25, 0.0, 1.0)
	grow = 1.0 - pow(1.0 - grow, 1.6)
	var r := lerpf(start_r, cap_r, grow)
	if x > 1.0:
		r *= 1.0 + float(a("late_spread", 0.12)) * minf(x - 1.0, 3.0)
	var h := lerpf(start_h, cap_half, grow)
	st["center_y"] = head_center_y(t)
	st["radius"] = r
	st["half"] = h
	st["torus"] = clampf((x - 0.01) / 0.12, 0.0, 1.0) * float(a("torus", 1.0))
	st["density"] = appear * float(a("head_density", 1.0)) * (1.0 - clampf((x - float(a("dissipate_at", 6.0))) / 3.0, 0.0, 0.85))
	st["roll"] = float(a("roll", 2.2)) * (1.0 - exp(-x / 0.25))
	st["col_mix"] = clampf((x - 0.04) / float(a("whiten_time", 0.5)), 0.0, 1.0)
	if nuclear and kind != Kind.NUCLEAR_UNDERWATER and kind != Kind.NUCLEAR_BURIED:
		# the vortex core stays incandescent much longer than the fireball surface
		var tt := BlastPhysics.fireball_temperature(w_kt, t)
		var core_t := lerpf(2300.0, 950.0, smoothstep(0.0, 1.0, x / float(a("core_cool", 0.14))))
		var tc := maxf(tt, core_t)
		st["heat_temp"] = tc
		st["heat_glow"] = emission_scale * 0.9 * clampf((tc - 950.0) / 500.0, 0.0, 1.0) * float(a("core_glow", 1.0))
	elif not nuclear and kind != Kind.CONVENTIONAL_BURIED:
		var fs := fireball_state(t)
		st["heat_temp"] = maxf(float(fs["temp"]), 900.0)
		st["heat_glow"] = emission_scale * 0.5 * float(fs["opacity"])
	return st


# ------------------------------------------------------------------ stem

## Returns {bottom, top, radius, density, flare, waist, hollow, rise}
func stem_state(t: float) -> Dictionary:
	var st := {"bottom": 0.0, "top": 0.0, "radius": 0.0, "density": 0.0, "flare": 2.0, "waist": 0.25, "hollow": 0.0, "rise": 0.0}
	if t <= 0.0:
		return st
	var hs := head_state(t)
	var head_bottom: float = float(hs["center_y"]) - float(hs["half"]) * 0.5
	var t_start := float(a("stem_delay", 0.0))
	if t_start <= 0.0:
		if surface or dusty:
			t_start = t_fb_max * 0.5
		else:
			# dust starts rising after the shock reflects from the ground
			t_start = BlastPhysics.arrival_time(w_kt, maxf(hob, 1.0)) + t_fb_max
	if t < t_start:
		return st
	var v := float(a("stem_speed_rel", 0.75))
	var avg_speed := head_center_final() / maxf(t_stab * 0.35, 1.0)
	var top := minf(head_bottom + float(hs["half"]) * 0.3, (t - t_start) * avg_speed * v + r_fb_max * 0.3)
	var rx := clampf(t / maxf(t_stab * 0.4, 1.0), 0.0, 1.0)
	st["bottom"] = -5.0
	st["top"] = maxf(top, 0.0)
	st["radius"] = lerpf(maxf(r_fb_max * 0.35, stem_r * 0.35), stem_r, sqrt(rx))
	var dens := float(a("stem_density", 0.9 if (surface or dusty) else 0.35))
	st["density"] = dens * clampf((t - t_start) / maxf(t_fb_max * 2.0, 0.5), 0.0, 1.0)
	st["flare"] = float(a("stem_flare", 1.6 if (surface or dusty) else 1.3))
	st["waist"] = float(a("stem_waist", 0.3))
	st["rise"] = avg_speed * 0.4
	return st


# ------------------------------------------------------------------ ground skirt / dust

## Returns {radius, height, density, inner}
func skirt_state(t: float, shock_r: float) -> Dictionary:
	var st := {"radius": 0.0, "height": 0.0, "density": 0.0, "inner": 0.0}
	var amt := float(a("skirt", 1.0 if (surface or dusty) else 0.25))
	if t <= 0.0 or amt <= 0.0:
		return st
	var rmax := float(a("skirt_max_r", BlastPhysics.radius_for_pressure(w_kt, 3.0, surface) * 0.9))
	var r := minf(shock_r, rmax)
	if r <= 0.0:
		return st
	var t_hit := BlastPhysics.arrival_time(w_kt, maxf(hob, 1.0))
	if t < t_hit:
		return st
	var grow := clampf(r / maxf(rmax, 1.0), 0.0, 1.0)
	st["radius"] = r + (t - t_hit) * 2.0
	var hk := 1.0 if (surface or dusty) else 0.45
	st["height"] = maxf(r * 0.06, r_fb_max * 0.12) * float(a("skirt_height", 1.0)) * hk * (0.6 + 0.4 * grow) + t * 0.8
	st["density"] = amt * (1.0 - clampf((t - t_stab * 0.5) / (t_stab * 0.6), 0.0, 0.9))
	st["inner"] = 0.0
	return st


# ------------------------------------------------------------------ shock wave

## Ground range of the shock front at time t (m).
func shock_ground_radius(t: float, table: PackedFloat64Array) -> float:
	# table: arrival times at radii R_k = 10 * 1.06^k (built by explosion.gd)
	if t <= 0.0:
		return 0.0
	var n := table.size()
	for k in n:
		if table[k] >= t:
			if k == 0:
				return 10.0 * t / maxf(table[0], 1e-6)
			var r0 := 10.0 * pow(1.06, k - 1)
			var r1 := 10.0 * pow(1.06, k)
			var f := (t - table[k - 1]) / maxf(table[k] - table[k - 1], 1e-9)
			var slant := lerpf(r0, r1, f)
			var h := maxf(hob, 0.0)
			return sqrt(maxf(slant * slant - h * h, 0.0))
	return 10.0 * pow(1.06, n - 1)


func build_arrival_table() -> PackedFloat64Array:
	# cumulative integration of dR / U(p(R)) on the radii 10 * 1.06^k (slant distance)
	var tbl := PackedFloat64Array()
	var r := 10.0
	var t := BlastPhysics.arrival_time(w_kt, r, surface)
	tbl.append(t)
	while r < 400000.0:
		var r1 := r * 1.06
		var sub := 4
		for i in sub:
			var ra := lerpf(r, r1, float(i) / sub)
			var rb := lerpf(r, r1, float(i + 1) / sub)
			t += (rb - ra) / BlastPhysics.shock_speed(BlastPhysics.overpressure(w_kt, 0.5 * (ra + rb), surface))
		tbl.append(t)
		r = r1
	return tbl
