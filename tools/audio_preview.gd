extends Node
## Renders the per-event blast sounds (BlastSynth) of selected bombs at their recommended distance
## (or --dist KM) to WAV files for listening and spectrogram review, with generation timings.
## Run: Godot_console --headless --path . res://tools/audio_preview.tscn -- --out DIR [--bombs 1,11,20] [--dist 10]
## Writes <out>/bNN_<id>_<km>km_front.wav / _tail.wav / _mix.wav (front + tail summed at 32 kHz) and
## prints one PREVIEW line per bomb.

const BlastSynth = preload("res://scripts/audio/blast_synth.gd")
const BlastParams = preload("res://scripts/audio/blast_params.gd")
const AudioSynth = preload("res://scripts/audio/audio_synth.gd")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := "user://audio_preview"
	var bombs: Array[int] = []
	var dist_km := -1.0
	var i := 0
	while i < args.size():
		match args[i]:
			"--out":
				out = args[i + 1]
				i += 1
			"--bombs":
				for s in args[i + 1].split(",", false):
					bombs.append(s.to_int())
				i += 1
			"--dist":
				dist_km = args[i + 1].to_float()
				i += 1
			"--synth":
				# export generic AudioSynth sounds by name (e.g. rocket_ignite,rocket_loop)
				DirAccess.make_dir_recursive_absolute(out)
				for nm in args[i + 1].split(",", false):
					var t1 := Time.get_ticks_msec()
					var st: AudioStreamWAV = AudioSynth.make(nm)
					st.save_to_wav(out.path_join(nm + ".wav"))
					print("SYNTH %s %.2f s gen=%d ms" % [nm, st.get_length(), Time.get_ticks_msec() - t1])
				bombs.append(-1)
				i += 1
		i += 1
	DirAccess.make_dir_recursive_absolute(out)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/bombs.json"))
	var list: Array = data["bombs"]
	if bombs.is_empty() and not args.has("--synth"):
		for k in list.size():
			bombs.append(k + 1)
	for n in bombs:
		if n < 1:
			continue
		var b: Dictionary = list[n - 1]
		var km := dist_km if dist_km > 0.0 else float(b.get("rec_km", 10.0))
		var hum := 0.35
		var prof := b.get("profile", {}) as Dictionary
		if prof.has("site_humidity"):
			hum = float(prof["site_humidity"])
		var p := BlastParams.params_for(b, km * 1000.0, hum)
		var t0 := Time.get_ticks_msec()
		var r := BlastSynth.make_event(p)
		var ms := Time.get_ticks_msec() - t0
		var base := out.path_join("b%02d_%s_%skm" % [n, b["id"], str(km)])
		(r["front"] as AudioStreamWAV).save_to_wav(base + "_front.wav")
		(r["tail"] as AudioStreamWAV).save_to_wav(base + "_tail.wav")
		print("PREVIEW b%02d %-14s d=%.1f km p=%.4f psi t+=%.3f s rise=%.5f s front=%.1f s tail=%.1f s tail_gain=%.1f dB gen=%d ms" % [
			n, b["id"], p["distance_m"] / 1000.0, p["p_psi"], p["t_plus"], r["rise_s"], r["front_dur"], r["tail_dur"], r["tail_gain_db"], ms])
	print("READY")
	get_tree().quit()
