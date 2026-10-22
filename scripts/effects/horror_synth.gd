class_name HorrorSynth
extends RefCounted

## Suara horor malam yang dibuat lewat kode (tanpa file aset).
## Setiap HorrorEvent boleh mengganti suaranya lewat properti `sound`.

const RATE := 22050

static var _cache: Dictionary = {}

static func get_stream(key: StringName) -> AudioStreamWAV:
	if _cache.has(key):
		return _cache[key]
	var stream: AudioStreamWAV
	match key:
		&"heartbeat": stream = _heartbeat()
		&"whisper": stream = _whisper()
		&"footstep": stream = _footstep()
		&"caw": stream = _caw()
		&"flicker": stream = _flicker()
		&"sting": stream = _sting()
		&"ambience": stream = _ambience()
		&"giggle": stream = _giggle()
		&"scream": stream = _scream()
		&"presence": stream = _presence()
	if stream != null:
		_cache[key] = stream
	return stream


static func _to_stream(buffer: PackedFloat32Array, rate: int = RATE, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buffer.size() * 2)
	for i in buffer.size():
		bytes.encode_s16(i * 2, int(clampf(buffer[i], -1.0, 1.0) * 30000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = buffer.size()
	return stream


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## "Lub-dub": dua dentum rendah berdekatan.
static func _heartbeat() -> AudioStreamWAV:
	var length := int(RATE * 0.42)
	var out := PackedFloat32Array()
	out.resize(length)
	for i in length:
		var t := float(i) / RATE
		var s := 0.0
		for hit in [[0.0, 1.0, 58.0], [0.17, 0.7, 50.0]]:
			var dt: float = t - float(hit[0])
			if dt >= 0.0:
				var freq: float = float(hit[2]) * (1.0 + 0.6 * exp(-dt * 40.0))
				s += sin(TAU * freq * dt) * exp(-dt * 22.0) * float(hit[1])
		out[i] = s * 0.95
	return _to_stream(out)


## Bisikan: derau yang disaring jadi berdesis dengan suku kata naik-turun.
static func _whisper() -> AudioStreamWAV:
	var rng := _rng(4471)
	var length := int(RATE * 1.8)
	var out := PackedFloat32Array()
	out.resize(length)
	var low := 0.0
	var high := 0.0
	var syllables: Array[Vector2] = []
	var start := 0.08
	while start < 1.6:
		syllables.append(Vector2(start, rng.randf_range(0.08, 0.2)))
		start += rng.randf_range(0.14, 0.3)
	for i in length:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low += (noise - low) * 0.35
		high += (noise - high) * 0.08
		var band := low - high
		var env := 0.0
		for syl in syllables:
			var d := (t - syl.x) / syl.y
			env += exp(-d * d * 3.0)
		var breath := 0.18 * (0.5 + 0.5 * sin(TAU * 0.6 * t))
		var fade := minf(1.0, t * 8.0) * minf(1.0, (1.8 - t) * 4.0)
		out[i] = band * (minf(env, 1.0) + breath) * fade * 1.6
	return _to_stream(out)


## Langkah di tanah: dentum pendek + gesekan.
static func _footstep() -> AudioStreamWAV:
	var rng := _rng(907)
	var length := int(RATE * 0.2)
	var out := PackedFloat32Array()
	out.resize(length)
	var low := 0.0
	for i in length:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low += (noise - low) * 0.12
		var thud := sin(TAU * 70.0 * t) * exp(-t * 35.0)
		out[i] = (thud * 0.8 + low * 1.4 * exp(-t * 25.0))
	return _to_stream(out)


## Koak gagak: gelombang kasar turun nada, dua kali.
static func _caw() -> AudioStreamWAV:
	var rng := _rng(1313)
	var length := int(RATE * 0.75)
	var out := PackedFloat32Array()
	out.resize(length)
	var phase := 0.0
	for i in length:
		var t := float(i) / RATE
		var s := 0.0
		for start in [0.0, 0.38]:
			var dt: float = t - float(start)
			if dt >= 0.0 and dt < 0.3:
				var freq: float = lerpf(820.0, 520.0, dt / 0.3)
				phase += freq / RATE
				var saw := fmod(phase, 1.0) * 2.0 - 1.0
				var env := sin(PI * dt / 0.3)
				s += (saw * 0.6 + rng.randf_range(-0.4, 0.4)) * env
		out[i] = s * 0.55
	return _to_stream(out)


## Dengung listrik / api yang tersendat.
static func _flicker() -> AudioStreamWAV:
	var rng := _rng(77)
	var length := int(RATE * 0.9)
	var out := PackedFloat32Array()
	out.resize(length)
	var gate := 1.0
	for i in length:
		var t := float(i) / RATE
		if i % 600 == 0:
			gate = 1.0 if rng.randf() < 0.55 else 0.0
		var hum := sin(TAU * 100.0 * t) * 0.5 + sin(TAU * 200.0 * t) * 0.25
		out[i] = (hum + rng.randf_range(-0.3, 0.3)) * gate * 0.5 * minf(1.0, (0.9 - t) * 6.0)
	return _to_stream(out)


## Dengung rendah sumbang untuk glitch.
static func _sting() -> AudioStreamWAV:
	var rng := _rng(666)
	var length := int(RATE * 1.4)
	var out := PackedFloat32Array()
	out.resize(length)
	for i in length:
		var t := float(i) / RATE
		var env := minf(1.0, t * 12.0) * exp(-t * 2.2)
		var s := sin(TAU * 55.0 * t) + sin(TAU * 58.3 * t) * 0.8 + sin(TAU * 82.4 * t) * 0.5
		s += rng.randf_range(-0.5, 0.5) * exp(-t * 9.0)
		out[i] = s * env * 0.35
	return _to_stream(out)


## Angin/drone malam yang bisa diulang tanpa sambungan (efek lama).
static func _ambience() -> AudioStreamWAV:
	const AMB_RATE := 11025
	const SECONDS := 8
	var out := PackedFloat32Array()
	out.resize(AMB_RATE * SECONDS)
	for i in out.size():
		var t := float(i) / AMB_RATE
		var wind := sin(TAU * 63.0 * t + sin(TAU * 0.25 * t) * 2.0) * 0.24
		wind += sin(TAU * 91.0 * t) * (0.12 + 0.08 * sin(TAU * 0.125 * t))
		wind += sin(TAU * 177.0 * t + sin(TAU * 0.5 * t)) * 0.06
		out[i] = wind * 0.53
	return _to_stream(out, AMB_RATE, true)


## Tawa melengking "hi-hi-hi" (Kuntilanak).
static func _giggle() -> AudioStreamWAV:
	var rng := _rng(2024)
	var length := int(RATE * 1.6)
	var out := PackedFloat32Array()
	out.resize(length)
	var phase := 0.0
	var notes: Array[Vector2] = []
	var start := 0.0
	var pitch := 1250.0
	while start < 1.35:
		notes.append(Vector2(start, pitch))
		start += rng.randf_range(0.13, 0.19)
		pitch *= rng.randf_range(0.93, 0.99)
	for i in length:
		var t := float(i) / RATE
		var s := 0.0
		for n in notes:
			var dt := t - n.x
			if dt >= 0.0 and dt < 0.12:
				var freq := n.y * (1.0 + 0.04 * sin(TAU * 28.0 * dt)) * (1.0 - dt * 0.6)
				phase += freq / RATE
				var env := sin(PI * dt / 0.12)
				s += (sin(TAU * phase) * 0.6 + sin(TAU * phase * 2.01) * 0.25 + rng.randf_range(-0.25, 0.25)) * env
		out[i] = s * 0.5 * (1.0 - t / 1.6 * 0.4)
	return _to_stream(out)


## Jeritan jumpscare: lengkingan kasar turun nada + derau.
static func _scream() -> AudioStreamWAV:
	var rng := _rng(13)
	var length := int(RATE * 1.0)
	var out := PackedFloat32Array()
	out.resize(length)
	var phase := 0.0
	var phase2 := 0.0
	for i in length:
		var t := float(i) / RATE
		var freq := lerpf(1500.0, 420.0, pow(t, 0.7)) * (1.0 + 0.06 * sin(TAU * 31.0 * t))
		phase += freq / RATE
		phase2 += freq * 1.5 / RATE
		var saw := fmod(phase, 1.0) * 2.0 - 1.0
		var saw2 := fmod(phase2, 1.0) * 2.0 - 1.0
		var env := minf(1.0, t * 60.0) * exp(-t * 2.4)
		var s := (saw * 0.5 + saw2 * 0.3 + rng.randf_range(-0.6, 0.6)) * env
		s += sin(TAU * 45.0 * t) * exp(-t * 6.0) * 0.8
		out[i] = clampf(s * 1.6, -1.0, 1.0) * 0.85
	return _to_stream(out)


## Dengung kehadiran makhluk (diulang): denyut rendah + desis.
static func _presence() -> AudioStreamWAV:
	var rng := _rng(31)
	var seconds := 4.0
	var length := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(length)
	var low := 0.0
	for i in length:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low += (noise - low) * 0.05
		var drone := sin(TAU * 41.0 * t) * 0.5 + sin(TAU * 43.5 * t) * 0.4 + sin(TAU * 61.5 * t) * 0.2
		var pulse := 0.6 + 0.4 * sin(TAU * 0.5 * t)
		out[i] = (drone * pulse + low * 1.2) * 0.45
	return _to_stream(out, RATE, true)
