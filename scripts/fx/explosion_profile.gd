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
var conventional := false    # HE (Kingery-Bulmash blast scaling)
var surface := false         # fireball touches the ground (surface/tower/contact)
var humid_site := false      # Pacific/tropical test site (higher cloud tops)
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
var rise_tau := 100.0
var fb_formula_max := 1.0     # formula R_max for this burst geometry
var fb_scale := 1.0           # measured / formula size ratio applied over the whole growth
var dusty := false           # burst low enough to raise heavy dust
var fb_duration := 0.0       # conventional fireball lifetime
var wilson_r := 0.0
var wilson_t := 0.0
var wilson_t0 := 0.0
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
	conventional = not nuclear
	surface = kind in [Kind.NUCLEAR_SURFACE, Kind.NUCLEAR_TOWER, Kind.CONVENTIONAL_SURFACE, Kind.CONVENTIONAL_BURIED, Kind.NUCLEAR_BURIED, Kind.NUCLEAR_UNDERWATER]
	humid_site = bool(art.get("humid_site", false))
	_derive()


func a(key: String, def: Variant) -> Variant:
	return art.get(key, def)


func _derive() -> void:
	tmin = BlastPhysics.t_min(w_kt)
	t2 = BlastPhysics.t_second_max(w_kt)
	t_fb_max = BlastPhysics.t_fireball_max(w_kt)
	if nuclear:
		var r_air := BlastPhysics.fireball_r_max(w_kt, false)
		var r_con := BlastPhysics.fireball_r_max(w_kt, true)
		if surface:
			r_fb_max = r_con
		elif hob < r_air:
			# fireball touching the ground: interpolate between contact and free-air sizes
			r_fb_max = lerpf(r_con, r_air, clampf(hob / r_air, 0.0, 1.0))
		else:
			r_fb_max = r_air
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
	fb_formula_max = r_fb_max
	r_fb_max *= float(a("fireball_scale", 1.0))
	if art.has("fireball_r_m") and float(art["fireball_r_m"]) > 0.0:
		r_fb_max = float(art["fireball_r_m"])
	fb_scale = r_fb_max / maxf(fb_formula_max, 1e-3)
	cloud_top = float(a("cloud_top_m", BlastPhysics.cloud_top(w_kt, humid_site)))
	cap_r = float(a("cap_radius_m", BlastPhysics.cloud_cap_radius(w_kt)))
	cap_half = float(a("cap_half_m", clampf(cloud_top * 0.2, 12.0, 14000.0)))
	t_stab = float(a("t_stab_s", BlastPhysics.cloud_stabilization_time(w_kt)))
	rise_tau = float(a("rise_tau_s", t_stab / 3.0))
	stem_r = float(a("stem_radius_m", BlastPhysics.stem_radius(w_kt) * (cap_r / BlastPhysics.cloud_cap_radius(w_kt))))
	dusty = hob < BlastPhysics.dust_height_threshold(w_kt) * 1.3
	if nuclear:
		crater_r = BlastPhysics.crater_radius_nuclear(w_kt) * float(a("crater_scale", 1.0))
		crater_depth = BlastPhysics.crater_depth_nuclear(w_kt) * float(a("crater_scale", 1.0))
	else:
		crater_r = BlastPhysics.crater_diameter_conventional(w_kt * 1000.0) * 0.5 * float(a("crater_scale", 1.0))
		crater_depth = crater_r * 0.6
	if art.has("crater_r_m"):
		crater_r = float(art["crater_r_m"])
	if art.has("crater_depth_m"):
		crater_depth = float(art["crater_depth_m"])
	wilson_r = BlastPhysics.wilson_radius(w_kt)
	wilson_t = BlastPhysics.wilson_duration(w_kt)
	wilson_t0 = BlastPhysics.wilson_time(w_kt)
	emission_scale = float(a("emission", 1600.0 if nuclear else 160.0))


# ------------------------------------------------------------------ fireball

## Returns {center_y, radius, temp, opacity, emis, mottle, squash, skin}
func fireball_state(t: float) -> Dictionary:
	var st := {"center_y": hob, "radius": 0.0, "temp": 0.0, "opacity": 0.0, "emis": 0.0, "mottle": 0.0, "squash": 1.0, "skin": 0.0}
	if t <= 0.0:
		return st
	if kind == Kind.NUCLEAR_UNDERWATER or kind == Kind.NUCLEAR_BURIED or kind == Kind.CONVENTIONAL_BURIED:
		return _hidden_fireball(t)
	if not nuclear:
		return _conventional_fireball(t)
	var r := BlastPhysics.fireball_radius(w_kt, t, surface or hob < fb_formula_max) * fb_scale
	r = minf(r, r_fb_max)
	var temp := BlastPhysics.fireball_temperature(w_kt, t, surface)
	st["radius"] = r
	st["temp"] = temp
	# the ball IS the base of the rising head (same centre): no stacked "egg" of two spheres.
	# Surface bursts start as a hemisphere centred on the ground and lift off later.
	st["center_y"] = head_center_y(t)
	# opacity: cools below ~2100 K, and in any case dissolves into the cloud between 4 and 12 t_max
	var fade_temp := clampf((temp - 1250.0) / 900.0, 0.0, 1.0)
	var fade_time := 1.0 - smoothstep(4.0 * t_fb_max, 12.0 * t_fb_max, t)
	st["opacity"] = minf(fade_temp, fade_time)
	st["emis"] = emission_scale * float(a("fireball_brightness", 1.0))
	st["mottle"] = clampf(1.0 - t / maxf(t2 * float(a("mottle_t2", 2.5)), 1e-4), 0.0, 1.0)
	# smoke skin forms as the ball cools (dark patches, NOx brown), ~8..40 t2
	st["skin"] = clampf((t / t2 - 8.0) / 32.0, 0.0, 1.0) * float(a("skin", 1.0))
	# a rising fireball flattens slightly (onset of the vortex)
	var tf := clampf((t - t_fb_max) / maxf(t_stab * 0.08, 0.5), 0.0, 1.0)
	st["squash"] = lerpf(1.0, 0.82, tf)
	if t > t_fb_max:
		st["radius"] = r_fb_max * (1.0 + 0.15 * tf)
	var sq := float(a("fireball_squash", 1.0))
	if sq != 1.0:
		st["squash"] = float(st["squash"]) * sq
	return st


## Height (local y) below which the fireball is cut flat by the reflected shock (-1e9 = none).
func fireball_cut_y(t: float) -> float:
	var tr := float(a("reflect_cut_t", 0.0))
	if tr <= 0.0 or t < tr:
		return -1e9
	var fs := fireball_state(t)
	return float(fs["center_y"]) - float(fs["radius"]) * lerpf(1.0, 0.72, clampf((t - tr) / (tr * 2.0), 0.0, 1.0))


func conventional_fb_duration() -> float:
	return float(a("fb_duration_s", fb_duration))


func _conventional_fireball(t: float) -> Dictionary:
	var st := {"center_y": maxf(hob, 0.0), "radius": 0.0, "temp": 0.0, "opacity": 0.0, "emis": 0.0, "mottle": 0.0, "squash": 1.0, "skin": 0.0}
	var dur := conventional_fb_duration()
	var t_grow := minf(t_fb_max, dur * 0.3)
	var x := t / maxf(t_grow, 1e-4)
	var grow := 1.0 - exp(-x * 2.5)
	st["radius"] = r_fb_max * (0.25 + 0.75 * grow) * (1.0 + 0.12 * clampf((t - t_grow) / maxf(dur, 0.01), 0.0, 1.5))
	var life := clampf(t / maxf(dur, 1e-3), 0.0, 1.6)
	var t_peak := float(a("fb_temp_peak", 3000.0 if kind != Kind.THERMOBARIC else 2600.0))
	if String(a("explosive", "tnt")) == "aluminized" and not art.has("fb_temp_peak"):
		t_peak = 3300.0
	# stays yellow-orange (>2200 K) for most of the burn, then dull red flame remnants
	st["temp"] = lerpf(t_peak, 1300.0, smoothstep(0.35, 1.25, life))
	st["opacity"] = clampf(1.0 - (life - 0.9) / 0.5, 0.0, 1.0)
	st["emis"] = emission_scale * float(a("fireball_brightness", 1.0))
	st["mottle"] = 0.0
	st["skin"] = clampf((life - 0.2) / 0.6, 0.0, 1.0) * float(a("skin", 1.0))
	var base_y := maxf(hob, 0.0) + r_fb_max * 0.55 * (0.4 + 0.6 * grow)
	# the burning ball rises with (and into) the smoke head
	st["center_y"] = lerpf(base_y, head_center_y(t), smoothstep(0.0, 1.0, life * 0.7))
	st["squash"] = float(a("fireball_squash", 0.85 if kind != Kind.THERMOBARIC else 0.75))
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
	return float(fs2["opacity"]) * pow(tt / 3300.0, 4.0)


# ------------------------------------------------------------------ cloud head

func rise_norm(t: float) -> float:
	return tanh(maxf(t, 0.0) / maxf(rise_tau, 1.0))


func head_center_final() -> float:
	return cloud_top - cap_half


func head_center_y(t: float) -> float:
	var start := maxf(hob, 0.0)
	if surface and nuclear:
		start = 0.0
	elif not nuclear:
		start = maxf(hob, 0.0) + r_fb_max * 0.5
	var target := head_center_final()
	var rk := float(a("rise_k", 0.0))
	if rk > 0.0:
		# buoyant thermal from a conventional charge: z ~ k sqrt(t) (Church 1969 TNT analogues)
		var te := maxf(t - float(a("rise_delay", 0.0)), 0.0)
		return minf(start + rk * sqrt(te), target + cap_half * 0.3)
	var f := rise_norm(t)
	var y := lerpf(start, target, f)
	# overshoot and settling for megaton clouds (research A5.3)
	var ov := float(a("overshoot", 0.0 if w_kt < 200.0 else 0.06))
	if ov > 0.0:
		y += target * ov * exp(-pow((t - 2.0 * rise_tau) / rise_tau, 2.0))
	return y


## Returns {center_y, radius, half, torus, density, roll, col_mix, heat_temp, heat_glow}
func head_state(t: float) -> Dictionary:
	var st := {"center_y": -1e6, "radius": 0.0, "half": 1.0, "torus": 0.0, "density": 0.0, "roll": 0.0,
		"col_mix": 0.0, "heat_temp": 0.0, "heat_glow": 0.0}
	if t <= 0.0:
		return st
	if is_column_kind():
		return _column_head(t, st)
	var x := t / maxf(t_stab, 1.0)
	var appear := 0.0
	var r_now := r_fb_max
	if nuclear:
		appear = clampf((t / t2 - 10.0) / 30.0, 0.0, 1.0)
		r_now = minf(BlastPhysics.fireball_radius(w_kt, t, surface or hob < fb_formula_max) * fb_scale, r_fb_max) * 1.04
	else:
		var dur := conventional_fb_duration()
		appear = clampf((t - dur * 0.15) / maxf(dur * 0.5, 0.05), 0.0, 1.0)
		r_now = r_fb_max * 1.05
	# lateral growth: power law in time (King: ~3.4 km at 60 s of a 13.5 km final cap)
	var g := clampf(pow(x, 0.8), 0.0, 1.0)
	var r := lerpf(r_now, cap_r, g)
	if x > 1.0:
		r *= 1.0 + float(a("late_spread", 0.12)) * minf(x - 1.0, 3.0)
	if art.has("cap_d_keys"):
		# measured cap diameters (dossier), log-time interpolation
		r = maxf(r_now, _keys_log(art["cap_d_keys"], t) * 0.5)
	var h_final := minf(cap_half, cap_r * float(a("cap_aspect_max", 0.75)))
	var h := lerpf(r_now * 0.95, h_final, g)
	if art.has("cap_d_keys"):
		h = minf(h, r * float(a("cap_aspect_max", 0.75)))
	st["center_y"] = head_center_y(t)
	if art.has("top_keys") and t > t_fb_max:
		st["center_y"] = maxf(_keys_log(art["top_keys"], t) - h, float(st["center_y"]) * 0.5)
	st["radius"] = r
	st["half"] = h
	st["torus"] = clampf((x - 0.008) / 0.06, 0.0, 1.0) * float(a("torus", 1.0))
	st["density"] = appear * float(a("head_density", 1.0)) * (1.0 - clampf((x - float(a("dissipate_at", 6.0))) / 3.0, 0.0, 0.85))
	st["roll"] = float(a("roll", 2.2)) * (1.0 - exp(-x / 0.25))
	st["col_mix"] = clampf((x - 0.04) / float(a("whiten_time", 0.5)), 0.0, 1.0)
	if nuclear and kind != Kind.NUCLEAR_UNDERWATER and kind != Kind.NUCLEAR_BURIED:
		# the vortex core stays incandescent longer than the fireball surface (absolute time scale)
		var tt := BlastPhysics.fireball_temperature(w_kt, t, surface)
		var cool := float(a("core_cool_s", 2.5 * pow(w_kt, 0.35)))
		var core_t := lerpf(2300.0, 950.0, smoothstep(0.0, 1.0, t / cool))
		var tc := maxf(tt, core_t)
		st["heat_temp"] = tc
		st["heat_glow"] = emission_scale * 0.9 * clampf((tc - 950.0) / 500.0, 0.0, 1.0) * float(a("core_glow", 0.7))
	elif not nuclear and kind != Kind.CONVENTIONAL_BURIED:
		var fs := fireball_state(t)
		st["heat_temp"] = maxf(float(fs["temp"]), 900.0)
		st["heat_glow"] = emission_scale * 0.4 * float(fs["opacity"])
	return st


# ------------------------------------------------------------------ stem

## Returns {bottom, top, radius, density, flare, waist, hollow, rise}
func stem_state(t: float) -> Dictionary:
	var st := {"bottom": 0.0, "top": 0.0, "radius": 0.0, "density": 0.0, "flare": 2.0, "waist": 0.25, "hollow": 0.0, "rise": 0.0}
	if t <= 0.0:
		return st
	if is_column_kind():
		return _column_stem(t, st)
	var dens := float(a("stem_density", 0.9 if (surface or dusty) else 0.35))
	if dens <= 0.0:
		return st
	var hs := head_state(t)
	var head_bottom: float = float(hs["center_y"]) - float(hs["half"]) * 0.5
	var t_start := float(a("stem_delay", 0.0))
	if t_start <= 0.0:
		if surface or dusty:
			t_start = t_fb_max * 0.5
		else:
			# dust starts rising after the shock reflects from the ground
			t_start = BlastPhysics.arrival_time(w_kt, maxf(hob, 1.0), false, conventional) + t_fb_max
	if t < t_start:
		return st
	var v := float(a("stem_speed_rel", 0.75))
	var avg_speed := head_center_final() / maxf(t_stab * 0.35, 1.0)
	var rising := (t - t_start) * avg_speed * v + r_fb_max * 0.3
	var top := minf(head_bottom + float(hs["half"]) * 0.45, rising)
	if bool(a("stem_detached", false)):
		top = minf(rising, head_bottom * float(a("stem_detached_frac", 0.6)))
	var rx := clampf(t / maxf(t_stab * 0.4, 1.0), 0.0, 1.0)
	st["bottom"] = -5.0
	st["top"] = maxf(top, 0.0)
	st["radius"] = lerpf(maxf(r_fb_max * 0.35, stem_r * 0.35), stem_r, sqrt(rx))
	st["density"] = dens * clampf((t - t_start) / maxf(t_fb_max * 2.0, 0.5), 0.0, 1.0) * (1.0 - clampf((t / t_stab - 2.0) / 3.0, 0.0, 0.8))
	st["flare"] = float(a("stem_flare", 1.6 if (surface or dusty) else 1.3))
	st["waist"] = float(a("stem_waist", 0.3))
	st["rise"] = avg_speed * 0.4
	return st


# ------------------------------------------------------------------ ground skirt / dust

## Returns {radius, height, density, inner}
func skirt_state(t: float, shock_r: float) -> Dictionary:
	var st := {"radius": 0.0, "height": 0.0, "density": 0.0, "inner": 0.0}
	if is_column_kind():
		return _base_surge(t, st)
	var amt := float(a("skirt", 1.0 if (surface or dusty) else 0.25))
	if t <= 0.0 or amt <= 0.0:
		return st
	var rmax := float(a("skirt_max_r", BlastPhysics.radius_for_pressure(w_kt, 3.0, surface, conventional) * 0.9))
	var r := minf(shock_r, rmax)
	if r <= 0.0:
		return st
	var t_hit := BlastPhysics.arrival_time(w_kt, maxf(hob, 1.0), false, conventional)
	if not bool(a("skirt_early", false)):
		t_hit = maxf(t_hit, t_fb_max * 0.5)
	if t < t_hit:
		return st
	var grow := clampf(r / maxf(rmax, 1.0), 0.0, 1.0)
	st["radius"] = r + minf(t - t_hit, 40.0) * 1.0
	var hk := 1.0 if (surface or dusty) else 0.45
	st["height"] = maxf(r * 0.05, r_fb_max * 0.1) * float(a("skirt_height", 1.0)) * hk * (0.55 + 0.45 * grow) + minf(t, 6.0) * 0.6
	var fade := 1.0 - smoothstep(0.3 * t_stab, 1.6 * t_stab, t)
	st["density"] = amt * fade * clampf((t - t_hit) / maxf(t_fb_max, 0.2), 0.0, 1.0)
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
	# DNA time of arrival on the slant radii 10 * 1.06^k
	var tbl := PackedFloat64Array()
	var r := 10.0
	while r < 420000.0:
		tbl.append(BlastPhysics.arrival_time(w_kt, r, surface, conventional))
		r *= 1.06
	return tbl


# ------------------------------------------------------------------ columns (buried / underwater)

func is_column_kind() -> bool:
	return kind in [Kind.CONVENTIONAL_BURIED, Kind.NUCLEAR_BURIED, Kind.NUCLEAR_UNDERWATER] or art.has("col_height")


## Height of the ejecta / water column at time t: fast rise, then (optionally) collapse.
func column_height(t: float) -> float:
	var hmax := float(a("col_height", 100.0))
	var t0 := float(a("col_delay", 0.05))
	var tr := float(a("col_rise", 2.0))
	if t < t0:
		return 0.0
	var x := (t - t0) / tr
	var h := hmax * (1.0 - exp(-3.0 * x)) / (1.0 - exp(-3.0))
	h = minf(h, hmax * (1.0 + 0.04 * maxf(x - 1.0, 0.0)))
	var tf := float(a("col_fall", 0.0))
	if tf > 0.0 and t > tf:
		var y := (t - tf) / float(a("col_fall_time", 6.0))
		h *= clampf(1.0 - 0.75 * y * y, 0.25, 1.0)
	return h


func _column_stem(t: float, st: Dictionary) -> Dictionary:
	var h := column_height(t)
	if h <= 1.0:
		return st
	var r := float(a("col_radius", 20.0))
	var spread := 1.0 + float(a("col_spread", 0.3)) * clampf(t / maxf(float(a("col_rise", 2.0)) * 4.0, 0.1), 0.0, 2.0)
	st["bottom"] = -5.0
	st["top"] = h
	st["radius"] = r * spread
	var dens := float(a("col_density", 1.0))
	var tf := float(a("col_fall", 0.0))
	if tf > 0.0 and t > tf:
		dens *= clampf(1.0 - (t - tf) / (float(a("col_fall_time", 6.0)) * 2.5), 0.15, 1.0)
	var fade_at := float(a("col_fade", 1e9))
	if t > fade_at:
		dens *= clampf(1.0 - (t - fade_at) / maxf(fade_at, 1.0), 0.0, 1.0)
	st["density"] = dens
	st["flare"] = float(a("col_flare", 1.5))
	st["waist"] = float(a("col_waist", -0.2))
	st["hollow"] = float(a("col_wall", 0.0))
	st["rise"] = h / maxf(float(a("col_rise", 2.0)), 0.5) * 0.3
	return st


func _column_head(t: float, st: Dictionary) -> Dictionary:
	var h := column_height(t)
	if h <= 1.0:
		return st
	var cap := float(a("col_cap_r", float(a("col_radius", 20.0)) * 1.6))
	var grow := clampf(h / maxf(float(a("col_height", 100.0)), 1.0), 0.0, 1.0)
	var late := sqrt(clampf((t - float(a("col_rise", 2.0))) / maxf(float(a("cap_grow_time", 20.0)), 1.0), 0.0, 1.0))
	var r := cap * (0.35 + 0.65 * grow) * (1.0 + float(a("cap_late_grow", 0.6)) * late)
	var rise_extra := float(a("cap_rise", 0.0)) * late
	# the cloud keeps the height the ejecta reached (it does not sink with the collapsing column)
	var h_ref := float(a("col_height", 100.0)) * clampf(grow * 3.0, 0.0, 1.0) if bool(a("cap_hold_peak", false)) else h
	st["center_y"] = maxf(h, h_ref) * 0.92 + rise_extra
	st["radius"] = r
	st["half"] = r * float(a("cap_aspect", 0.55))
	st["torus"] = float(a("torus", 0.0)) * late
	var dens := float(a("head_density", 1.0)) * clampf(grow * 1.5, 0.0, 1.0)
	var fade_at := float(a("cap_fade", 1e9))
	if t > fade_at:
		dens *= clampf(1.0 - (t - fade_at) / maxf(fade_at, 1.0), 0.05, 1.0)
	st["density"] = dens
	st["roll"] = float(a("roll", 0.6)) * late
	st["col_mix"] = clampf(t / maxf(float(a("whiten_s", 60.0)), 1.0), 0.0, 1.0)
	st["heat_temp"] = 0.0
	st["heat_glow"] = 0.0
	var vent := float(a("vent_glow", 0.0))
	if vent > 0.0:
		var fs := fireball_state(t)
		st["heat_temp"] = maxf(float(fs["temp"]), 900.0)
		st["heat_glow"] = emission_scale * 0.3 * float(fs["opacity"])
	return st


func _base_surge(t: float, st: Dictionary) -> Dictionary:
	var t0 := float(a("surge_start", 1e9))
	if t < t0:
		return st
	var tau := float(a("surge_tau", 60.0))
	var rmax := float(a("surge_r", 1000.0))
	var x := t - t0
	var r := rmax * (1.0 - exp(-x / tau)) + float(a("col_radius", 20.0))
	st["radius"] = r
	st["height"] = lerpf(float(a("surge_h0", 50.0)), float(a("surge_h1", 150.0)), clampf(x / (tau * 3.0), 0.0, 1.0))
	st["density"] = float(a("surge_density", 0.9)) * clampf(x / 3.0, 0.0, 1.0) * clampf(1.0 - (x - tau * 4.0) / (tau * 4.0), 0.1, 1.0)
	st["inner"] = float(a("surge_inner", 0.0)) * clampf(x / (tau * 2.0), 0.0, 1.0)
	return st


## Ground heave (Sedan dome, camouflet bulge): Vector4(radius, height, 0, 0) for g_dome.
func dome_state(t: float) -> Vector4:
	var dr := float(a("dome_r", 0.0))
	if dr <= 0.0 or t <= 0.0:
		return Vector4.ZERO
	var dh := float(a("dome_h", 0.0))
	var trise := float(a("dome_time", 1.0))
	var tburst := float(a("dome_burst", trise))
	var x := clampf(t / trise, 0.0, 1.0)
	var h := dh * x * (2.0 - x)
	if t > tburst:
		h *= clampf(1.0 - (t - tburst) / 1.5, 0.0, 1.0)
	return Vector4(dr, h, 0, 0)


# ------------------------------------------------------------------ megaton condensation features

## Up to 4 condensation rings around the stem: Array of Vector4(y, radius, thickness, opacity).
func rings_state(t: float) -> Array[Vector4]:
	var out: Array[Vector4] = [Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO]
	var hum := clampf((Game.humidity - 0.3) / 0.5, 0.15, 1.0)
	if art.has("ring_list"):
		# explicit documented rings: [t_on, life, y, radius, half_thickness]
		var lst: Array = art["ring_list"]
		for i in mini(lst.size(), 4):
			var rg: Array = lst[i]
			var x0 := (t - float(rg[0])) / maxf(float(rg[1]), 1.0)
			if x0 < 0.0 or x0 > 1.6:
				continue
			var op0 := smoothstep(0.0, 0.12, x0) * (1.0 - smoothstep(0.7, 1.6, x0)) * maxf(hum, 0.6)
			out[i] = Vector4(float(rg[2]) + float(rg[2]) * 0.15 * x0, float(rg[3]) * (1.0 + 0.25 * x0), float(rg[4]), op0)
		return out
	var n := int(a("rings", 0))
	if n <= 0:
		return out
	var r_t0 := float(a("ring_t0", 0.03))
	var r_life := float(a("ring_life", 0.12))
	for i in mini(n, 4):
		var fr := 0.25 + 0.13 * i
		var t_on := t_stab * (r_t0 + 0.02 * i)
		var life := t_stab * r_life
		if t < t_on or t > t_on + life * 2.0:
			continue
		var x := (t - t_on) / life
		var op := smoothstep(0.0, 0.2, x) * (1.0 - smoothstep(0.8, 2.0, x)) * hum
		var y := cloud_top * fr * (0.6 + 0.4 * rise_norm(t))
		var ss := stem_state(t)
		var rr := maxf(float(ss["radius"]), stem_r * 0.5) * (2.2 + 0.4 * i) * (1.0 + 0.3 * x)
		out[i] = Vector4(y, rr, clampf(rr * 0.05, 60.0, 400.0), op)
	return out


## Ice cap / pileus shells. which = 0 (pileus over the head), 1 (second tier / bell skirt).
func ice_state(t: float, which: int) -> Vector4:
	var key := "ice_cap" if which == 0 else "tier2"
	var cfg: Dictionary = a(key, {})
	if cfg.is_empty():
		return Vector4.ZERO
	var t_on := float(cfg.get("t_on", 0.06)) * t_stab
	var dur := float(cfg.get("dur", 0.35)) * t_stab
	if t < t_on:
		return Vector4.ZERO
	var x := (t - t_on) / dur
	var op := smoothstep(0.0, 0.15, x) * (1.0 - smoothstep(0.7, 1.4, x)) * float(cfg.get("opacity", 0.8))
	if op <= 0.0:
		return Vector4.ZERO
	var hs := head_state(t)
	var top: float = float(hs["center_y"]) + float(hs["half"])
	if which == 0:
		var r: float = float(hs["radius"]) * float(cfg.get("r_rel", 1.1))
		var y: float = top + float(hs["half"]) * float(cfg.get("lift", 0.1)) - r * 0.25
		return Vector4(y, r, r * 0.3, op)
	var r2 := float(cfg.get("radius_m", cap_r * 1.4)) * clampf(0.3 + 0.7 * x, 0.0, 1.0)
	var y2 := cloud_top * float(cfg.get("height_rel", 0.7))
	return Vector4(y2, r2, float(cfg.get("half_m", 3000.0)), op)


## Yield driving the AIR blast: buried and underwater shots couple most energy into the ground/water.
func blast_yield() -> float:
	match kind:
		Kind.NUCLEAR_BURIED, Kind.CONVENTIONAL_BURIED:
			return w_kt * float(a("air_coupling", 0.08))
		Kind.NUCLEAR_UNDERWATER:
			return w_kt * float(a("air_coupling", 0.3))
	return w_kt


## Log-time interpolation of [[t_s, value], ...] keyframes (clamped at the ends).
func _keys_log(keys: Array, t: float) -> float:
	if keys.is_empty():
		return 0.0
	var tt := maxf(t, 0.001)
	if tt <= float(keys[0][0]):
		return float(keys[0][1]) * sqrt(tt / float(keys[0][0]))
	for i in range(1, keys.size()):
		var t1 := float(keys[i][0])
		if tt <= t1:
			var t0 := float(keys[i - 1][0])
			var f := (log(tt) - log(t0)) / maxf(log(t1) - log(t0), 1e-6)
			return lerpf(float(keys[i - 1][1]), float(keys[i][1]), f)
	return float(keys[keys.size() - 1][1])
