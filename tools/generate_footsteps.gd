@tool
extends SceneTree

# Generates 20 high quality CC0 footstep audio samples:
# - footstep_grass_walk_000..004.wav
# - footstep_grass_run_000..004.wav
# - footstep_dirt_walk_000..004.wav
# - footstep_dirt_run_000..004.wav
#
# Dedicated organic acoustic models:
# Grass: soft ground compression thud + multi-burst leaf blade crunch/scuff
# Dirt: punchy low-frequency soil thump + granular earth/grit dispersion

const SAMPLE_RATE := 44100
const OUTPUT_DIR := "res://assets/audio/sfx/footsteps/"

func _init() -> void:
	print("Starting CC0 Footstep SFX Generator...")
	var dir := DirAccess.open("res://")
	if not dir.dir_exists("assets/audio/sfx/footsteps"):
		dir.make_dir_recursive("assets/audio/sfx/footsteps")

	generate_set("grass", false, 5)
	generate_set("grass", true, 5)
	generate_set("dirt", false, 5)
	generate_set("dirt", true, 5)

	write_license_files()
	print("All CC0 footstep SFX generated successfully.")
	quit()

func generate_set(surface: String, running: bool, count: int) -> void:
	var mode_name := "run" if running else "walk"
	for i in range(count):
		var filename := "footstep_%s_%s_%03d.wav" % [surface, mode_name, i]
		var path := OUTPUT_DIR + filename
		var samples: PackedFloat32Array
		var seed_val := (surface.hash() * 31 + (100 if running else 0) + i * 77) & 0x7FFFFFFF
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_val

		if surface == "grass":
			samples = synth_grass(running, rng)
		else:
			samples = synth_dirt(running, rng)

		save_wav(path, samples)
		print("Generated: %s (%d samples)" % [filename, samples.size()])

func synth_grass(running: bool, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var duration := rng.randf_range(0.14, 0.17) if running else rng.randf_range(0.11, 0.14)
	var total_samples := int(duration * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(total_samples)
	buf.fill(0.0)

	# 1. Thud component (soft damp sub-surface ground)
	var thud_freq_start := rng.randf_range(130.0, 160.0) if running else rng.randf_range(110.0, 130.0)
	var thud_freq_end := rng.randf_range(60.0, 75.0)
	var thud_decay := rng.randf_range(35.0, 48.0) if running else rng.randf_range(42.0, 56.0)
	var thud_phase := 0.0

	# 2. Multi-burst grass blade crunches (sol melindas bilah-bilah rumput bertahap)
	var burst_count := rng.randi_range(3, 5) if running else rng.randi_range(2, 3)
	var burst_times: Array[float] = []
	var burst_strengths: Array[float] = []
	for b in range(burst_count):
		burst_times.append(rng.randf_range(0.003, 0.045 if running else 0.035))
		burst_strengths.append(rng.randf_range(0.6, 1.0))

	# Simple bandpass state variables for grass noise (1.2 kHz - 4.2 kHz)
	var hp_y := 0.0
	var hp_x_prev := 0.0
	var lp_y := 0.0
	var alpha_hp := 0.85 # Cut off sub-mids
	var alpha_lp := 0.28 # Soften harsh high fizz

	for n in range(total_samples):
		var t := float(n) / SAMPLE_RATE

		# Thud calculation
		var thud_progress := minf(t * 15.0, 1.0)
		var cur_freq := lerpf(thud_freq_start, thud_freq_end, thud_progress)
		thud_phase += 2.0 * PI * cur_freq / SAMPLE_RATE
		var thud_env := exp(-t * thud_decay) * (1.0 - exp(-t * 800.0))
		# Subtle pitch saturation
		var thud_sample := sin(thud_phase) * thud_env * (0.45 if running else 0.32)

		# Grass blade noise crunch calculation
		var noise_raw := rng.randf_range(-1.0, 1.0)
		# High pass
		hp_y = alpha_hp * (hp_y + noise_raw - hp_x_prev)
		hp_x_prev = noise_raw
		# Low pass
		lp_y += alpha_lp * (hp_y - lp_y)

		# Accumulate burst envelopes
		var crunch_env := 0.0
		for b in range(burst_count):
			var dt := t - burst_times[b]
			if dt >= 0.0:
				var decay_rate := rng.randf_range(50.0, 75.0)
				crunch_env += burst_strengths[b] * exp(-dt * decay_rate) * (1.0 - exp(-dt * 600.0))

		# Tail blade rustle as foot lifts/settles
		var rustle_decay := 22.0 if running else 30.0
		var rustle_env := exp(-t * rustle_decay) * (1.0 - exp(-t * 200.0)) * (0.35 if running else 0.25)
		var total_crunch := lp_y * (crunch_env * 0.55 + rustle_env)

		# Combine
		var mixed := thud_sample + total_crunch
		# Soft tape saturation
		buf[n] = tanh(mixed * 1.3) * 0.92

	return buf

func synth_dirt(running: bool, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var duration := rng.randf_range(0.14, 0.17) if running else rng.randf_range(0.10, 0.13)
	var total_samples := int(duration * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(total_samples)
	buf.fill(0.0)

	# 1. Earthy heel impact (solid grounded thump)
	var thud_freq_start := rng.randf_range(110.0, 140.0) if running else rng.randf_range(95.0, 115.0)
	var thud_freq_end := rng.randf_range(48.0, 60.0)
	var thud_decay := rng.randf_range(30.0, 42.0) if running else rng.randf_range(38.0, 50.0)
	var thud_phase := 0.0

	# 2. Granular soil scuff / micro-grit (pasir, debu padat, butiran tanah)
	# Bandpass ~350 Hz - 2.4 kHz
	var hp_y := 0.0
	var hp_x_prev := 0.0
	var lp_y := 0.0
	var alpha_hp := 0.92 # Filter sub rumble from noise
	var alpha_lp := 0.18 # Heavy damp on highs so it sounds like dry gritty earth, not metal or plastic

	# Scuff timing
	var scuff_start := rng.randf_range(0.005, 0.02)
	var kickup_start := rng.randf_range(0.045, 0.07) if running else 0.0

	for n in range(total_samples):
		var t := float(n) / SAMPLE_RATE

		# Earth thud with asymmetric warmth
		var cur_freq := lerpf(thud_freq_start, thud_freq_end, minf(t * 18.0, 1.0))
		thud_phase += 2.0 * PI * cur_freq / SAMPLE_RATE
		var thud_env := exp(-t * thud_decay) * (1.0 - exp(-t * 900.0))
		# Triangle-like harmonics for leather shoe on compacted dirt
		var thud_wave := sin(thud_phase) + 0.25 * sin(thud_phase * 2.0)
		var thud_sample := thud_wave * thud_env * (0.55 if running else 0.42)

		# Granular dirt noise
		var noise_raw := rng.randf_range(-1.0, 1.0)
		hp_y = alpha_hp * (hp_y + noise_raw - hp_x_prev)
		hp_x_prev = noise_raw
		lp_y += alpha_lp * (hp_y - lp_y)

		# Scuff envelope
		var scuff_env := 0.0
		var dt := t - scuff_start
		if dt >= 0.0:
			var scuff_decay := 35.0 if running else 45.0
			scuff_env += exp(-dt * scuff_decay) * (1.0 - exp(-dt * 450.0)) * 0.45

		# Run has kickup dirt dispersion at the end
		if running:
			var dt_kick := t - kickup_start
			if dt_kick >= 0.0:
				scuff_env += exp(-dt_kick * 30.0) * (1.0 - exp(-dt_kick * 300.0)) * 0.35

		var dirt_grit := lp_y * scuff_env

		var mixed := thud_sample + dirt_grit
		buf[n] = tanh(mixed * 1.4) * 0.94

	return buf

func save_wav(file_path: String, samples: PackedFloat32Array) -> void:
	var f := FileAccess.open(file_path, FileAccess.WRITE)
	if f == null:
		push_error("Failed to open file for writing: %s" % file_path)
		return

	var num_samples := samples.size()
	var byte_rate := SAMPLE_RATE * 2 # 16-bit mono
	var data_chunk_size := num_samples * 2
	var total_chunk_size := 36 + data_chunk_size

	# RIFF Header
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(total_chunk_size)
	f.store_buffer("WAVE".to_ascii_buffer())

	# fmt subchunk
	f.store_buffer("fmt ".to_ascii_buffer())
	f.store_32(16) # Subchunk1Size (16 for PCM)
	f.store_16(1)  # AudioFormat (1 = PCM)
	f.store_16(1)  # NumChannels (1 = Mono)
	f.store_32(SAMPLE_RATE)
	f.store_32(byte_rate)
	f.store_16(2)  # BlockAlign
	f.store_16(16) # BitsPerSample

	# data subchunk
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(data_chunk_size)

	# Samples (16-bit signed PCM)
	for s in samples:
		var clamped := clampf(s, -1.0, 1.0)
		var sample_i16 := int(round(clamped * 32767.0))
		f.store_16(sample_i16)

	f.close()

func write_license_files() -> void:
	var license_text := """CC0 1.0 Universal (CC0 1.0) Public Domain Dedication

The person who associated a work with this deed has dedicated the work to the
public domain by waiving all of his or her rights to the work worldwide under
copyright law, including all related and neighboring rights, to the extent
allowed by law.

You can copy, modify, distribute and perform the work, even for commercial
purposes, all without asking permission.

Official deed: https://creativecommons.org/publicdomain/zero/1.0/
"""

	var sources_text := """# Footstep Audio Assets (CC0 1.0 Universal)

All footstep audio files in this directory are procedurally synthesized and released under **Creative Commons Zero 1.0 Universal (CC0 1.0)**:

- `footstep_grass_walk_000.wav` - `footstep_grass_walk_004.wav`
- `footstep_grass_run_000.wav` - `footstep_grass_run_004.wav`
- `footstep_dirt_walk_000.wav` - `footstep_dirt_walk_004.wav`
- `footstep_dirt_run_000.wav` - `footstep_dirt_run_004.wav`

## Characteristics
- **Grass Footsteps**: Organic composite of soft turf soil impact dampening coupled with crisp leafy micro-burst crunch and dry blade rustle. Separated into dedicated walking and running velocities.
- **Dirt Footsteps**: Compacted earthy footfall thud paired with granular soil displacement, dry sand grit, and trailing kickup scuff.
- **License**: CC0 1.0 Universal (Public Domain) - Free for commercial, personal, and modification use without attribution required.
"""

	var f_lic := FileAccess.open(OUTPUT_DIR + "LICENSE.txt", FileAccess.WRITE)
	if f_lic != null:
		f_lic.store_string(license_text)
		f_lic.close()

	var f_src := FileAccess.open(OUTPUT_DIR + "SOURCES.md", FileAccess.WRITE)
	if f_src != null:
		f_src.store_string(sources_text)
		f_src.close()
