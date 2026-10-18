class_name SfxSynth
extends RefCounted

## Suara combat yang dibuat langsung dari kode (AudioStreamWAV 16-bit mono), tanpa file aset:
## tali busur berderit, dengung tongkat sihir, denting bidikan penuh, desau tembakan, dan
## dentuman bass tier Obsidian, dan genderang perang arena boss. Dibuat sekali lalu disimpan di cache.

const RATE := 22050

static var _cache: Dictionary = {}

## Derit tali busur yang ditarik (loop). Klik kayu kecil dengan jarak acak.
static func bow_creak() -> AudioStreamWAV:
	return _cached(&"bow_creak", func() -> Array:
		var n := int(RATE * 0.5)
		var out := PackedFloat32Array()
		out.resize(n)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var next_click := 0
		while next_click < n:
			var freq := rng.randf_range(700.0, 1100.0)
			var amp := rng.randf_range(0.35, 0.8)
			for i in int(RATE * 0.006):
				var at := next_click + i
				if at >= n:
					break
				var t := float(i) / RATE
				out[at] += amp * sin(TAU * freq * t) * exp(-t * 900.0)
			next_click += int(RATE / rng.randf_range(32.0, 55.0))
		# Desis tali tipis di bawah klik.
		for i in n:
			out[i] += rng.randf_range(-0.04, 0.04)
		return [out, true])

## Dengung energi tongkat sihir (loop 1 detik; semua frekuensi bulat agar sambungan mulus).
static func staff_hum() -> AudioStreamWAV:
	return _cached(&"staff_hum", func() -> Array:
		var n := RATE
		var out := PackedFloat32Array()
		out.resize(n)
		for i in n:
			var t := float(i) / RATE
			var wobble := 0.6 * sin(TAU * 6.0 * t)
			var tone := 0.45 * sin(TAU * 220.0 * t + wobble) + 0.3 * sin(TAU * 330.0 * t + wobble * 1.5)
			var shimmer := 0.15 * sin(TAU * 880.0 * t) * (0.5 + 0.5 * sin(TAU * 8.0 * t))
			out[i] = tone + shimmer
		return [out, true])

## Denting lonceng kecil (bidikan penuh, kilau tier). Nada diatur lewat semitone Juice.sfx.
static func chime() -> AudioStreamWAV:
	return _cached(&"chime", func() -> Array:
		var n := int(RATE * 0.6)
		var out := PackedFloat32Array()
		out.resize(n)
		for i in n:
			var t := float(i) / RATE
			var env := exp(-t * 7.0) * minf(1.0, t * 400.0)
			out[i] = env * (0.6 * sin(TAU * 1320.0 * t) + 0.25 * sin(TAU * 1320.0 * 2.76 * t) * exp(-t * 12.0) + 0.12 * sin(TAU * 1320.0 * 5.4 * t) * exp(-t * 20.0))
		return [out, false])

## Desau udara saat anak panah/bola sihir dilepas atau pedang diayun.
static func whoosh() -> AudioStreamWAV:
	return _cached(&"whoosh", func() -> Array:
		var n := int(RATE * 0.28)
		var out := PackedFloat32Array()
		out.resize(n)
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var low := 0.0
		for i in n:
			var p := float(i) / n
			# Saringan low-pass yang menutup: desis terang lalu meredup.
			var cutoff := lerpf(0.55, 0.05, p)
			low += cutoff * (rng.randf_range(-1.0, 1.0) - low)
			var env := minf(1.0, p * 14.0) * pow(1.0 - p, 2.0)
			out[i] = low * env * 2.2
		return [out, false])

## Dentuman bass (Obsidian): nada turun dengan klik di awal.
static func boom() -> AudioStreamWAV:
	return _cached(&"boom", func() -> Array:
		var n := int(RATE * 0.6)
		var out := PackedFloat32Array()
		out.resize(n)
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		var phase := 0.0
		for i in n:
			var t := float(i) / RATE
			phase += TAU * lerpf(70.0, 32.0, minf(1.0, t / 0.45)) / RATE
			var click := rng.randf_range(-1.0, 1.0) * exp(-t * 80.0) * 0.5
			out[i] = (sin(phase) * 0.95 + click) * exp(-t * 5.5) * minf(1.0, t * 600.0)
		return [out, false])

## Genderang perang arena boss (loop 2 detik, pola taiko). Tempo naik lewat pitch_scale per fase.
static func war_drum() -> AudioStreamWAV:
	return _cached(&"war_drum", func() -> Array:
		var n := RATE * 2
		var out := PackedFloat32Array()
		out.resize(n)
		var rng := RandomNumberGenerator.new()
		rng.seed = 21
		# [detik, kekuatan, nada dasar]
		var hits := [[0.0, 1.0, 62.0], [0.5, 0.55, 70.0], [0.75, 0.6, 70.0], [1.0, 0.95, 58.0], [1.375, 0.5, 74.0], [1.5, 0.8, 62.0], [1.75, 0.45, 80.0]]
		for hit: Array in hits:
			var start := int(float(hit[0]) * RATE)
			var phase := 0.0
			for i in int(RATE * 0.45):
				var at := start + i
				if at >= n:
					break
				var t := float(i) / RATE
				phase += TAU * float(hit[2]) * (1.0 + 0.6 * exp(-t * 30.0)) / RATE
				var slap := rng.randf_range(-1.0, 1.0) * exp(-t * 60.0) * 0.35
				out[at] += float(hit[1]) * (sin(phase) * exp(-t * 7.0) + slap)
		return [out, true])

static func _cached(key: StringName, build: Callable) -> AudioStreamWAV:
	if _cache.has(key):
		return _cache[key]
	var made: Array = build.call()
	var stream := to_wav(made[0], made[1])
	_cache[key] = stream
	return stream

## Ubah sampel -1..1 menjadi AudioStreamWAV. Puncak dinormalkan ke 0.9 supaya tidak pecah.
static func to_wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var peak := 0.001
	for s in samples:
		peak = maxf(peak, absf(s))
	var gain := 0.9 / peak
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, clampi(int(samples[i] * gain * 32767.0), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav
