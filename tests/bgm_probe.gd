extends Node
## Probe diagnostik BGM: cetak status bus audio dan pemutar MusicManager,
## lalu uji putar WAV musik langsung (loop asli vs loop dimatikan).

const TEST_PATH := "res://assets/audio/music/town_friendly_breeze.wav"


func _ready() -> void:
	await get_tree().process_frame
	MusicManager.play_town()
	await get_tree().create_timer(2.0).timeout
	for i in AudioServer.bus_count:
		print("[BGMProbe] bus ", i, " ", AudioServer.get_bus_name(i), " vol=", AudioServer.get_bus_volume_db(i), " mute=", AudioServer.is_bus_mute(i))
	for p in MusicManager.get_children():
		if p is AudioStreamPlayer:
			print("[BGMProbe] ", p.name, " playing=", p.playing, " vol=", p.volume_db, " pos=", p.get_playback_position(), " stream=", p.stream)
	var wav := load(TEST_PATH) as AudioStreamWAV
	print("[BGMProbe] wav format=", wav.format, " stereo=", wav.stereo, " rate=", wav.mix_rate, " loop_mode=", wav.loop_mode, " loop_begin=", wav.loop_begin, " loop_end=", wav.loop_end, " length=", wav.get_length(), " data_bytes=", wav.data.size())
	MusicManager.fade_out(0.1)
	await get_tree().create_timer(0.3).timeout
	var fresh := ResourceLoader.load(TEST_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as AudioStreamWAV
	print("[BGMProbe] fresh import loop_mode=", fresh.loop_mode, " loop_begin=", fresh.loop_begin, " loop_end=", fresh.loop_end)
	await _try("fresh", fresh)
	var no_loop := fresh.duplicate() as AudioStreamWAV
	no_loop.loop_mode = AudioStreamWAV.LOOP_DISABLED
	await _try("no_loop", no_loop)
	var fixed := fresh.duplicate() as AudioStreamWAV
	fixed.loop_mode = AudioStreamWAV.LOOP_FORWARD
	fixed.loop_begin = 0
	fixed.loop_end = int(fixed.get_length() * fixed.mix_rate)
	await _try("loop_end_fixed(%d)" % fixed.loop_end, fixed)
	print("[BGMProbe] selesai")


func _try(label: String, stream: AudioStream) -> void:
	var p := AudioStreamPlayer.new()
	p.bus = &"Music"
	p.stream = stream
	add_child(p)
	p.play()
	await get_tree().create_timer(1.0).timeout
	print("[BGMProbe] test ", label, ": playing=", p.playing, " pos=", p.get_playback_position(), " peak Music=", AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index(&"Music"), 0))
	p.queue_free()
