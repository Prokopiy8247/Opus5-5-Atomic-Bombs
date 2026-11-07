extends RefCounted
## BlastParams: the BlastSynth input of a bomb (bombs.json entry) seen from the bunker at a ground
## range, from the same physics as the explosion (ExplosionProfile / BlastPhysics). Kept apart
## from blast_synth.gd so the synthesizer itself has no dependency on the Game autoload.
## Usage: const BlastParams = preload("res://scripts/audio/blast_params.gd")

## The synthesis parameters of a bomb (bombs.json entry) seen from the bunker at a ground range
## (m): used by the game at launch time and by tools/audio_preview.gd.
static func params_for(b: Dictionary, ground_m: float, humidity: float, tod: String = "noon") -> Dictionary:
	var prof := ExplosionProfile.new(b)
	var hob := maxf(prof.hob, 0.0)
	var slant := sqrt(ground_m * ground_m + hob * hob)
	var wb := prof.blast_yield()
	var psi := BlastPhysics.overpressure(wb, slant, prof.surface, prof.conventional)
	# positive phase at the bunker: DNA table down to 1 psi, then the slow far-field growth
	var tp := BlastPhysics.positive_phase(wb, maxf(psi, 1.0), prof.surface)
	if psi < 1.0:
		var r1 := BlastPhysics.radius_for_pressure(wb, 1.0, prof.surface, prof.conventional)
		tp *= 1.0 + 0.3 * log(maxf(slant / maxf(r1, 1.0), 1.0)) / log(10.0)
	if prof.conventional:
		tp *= 0.8
	return {"yield_kt": prof.w_kt, "kind": String(b.get("burst_type", "")), "nuclear": prof.nuclear,
		"distance_m": slant, "hob_m": hob, "p_psi": psi, "t_plus": tp, "humidity": humidity,
		"seed": int(b.get("num", 1)) * 7919 + int(ground_m), "tod": String(prof.a("sound_atmos", tod)),
		"over_water": bool(prof.art.get("humid_site", false)) and prof.nuclear,
		# same default as the visuals (ExplosionProfile reads fae_delay with 0.0): the cloud detonation
		# is heard when the fireball is seen
		"thermobaric_delay_s": float(prof.a("fae_delay", 0.0)),
		"r1psi_m": BlastPhysics.radius_for_pressure(wb, 1.0, prof.surface, prof.conventional),
		"eruption_s": float(prof.a("col_delay", 0.6)),
		"eruption_dur_s": float(prof.a("col_rise", 5.0)) + float(prof.a("col_fall_time", 5.0))}


