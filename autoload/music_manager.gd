extends Node
## MusicManager (Nusa Vale)
## Mengatur background music (BGM) bernuansa cozy mirip Stardew Valley & Harvest Moon.
## Mendukung dual-player crossfade halus, pergantian siang/malam dinamis, dan integrasi bus 'Music'.

signal track_changed(track_name: String)

const BUS_NAME := &"Music"
const DEFAULT_FADE := 1.2

const TRACK_DAY_FARM := "res://assets/audio/music/spring_cozy_farm.wav"
const TRACK_NIGHT_FARM := "res://assets/audio/music/night_cozy_serenade.wav"
const TRACK_TOWN := "res://assets/audio/music/town_friendly_breeze.wav"
const TRACK_DEEP_FOREST := "res://assets/audio/music/deep_forest_enchanted.wav"
const TRACK_SHOP := "res://assets/audio/music/cozy_shop_warung.wav"
const TRACK_RAIN := "res://assets/audio/music/rainy_day_solitude.wav"
const TRACK_MIDNIGHT_HORROR := "res://assets/audio/music/midnight_horror_nightmare.wav"
const TRACK_BOSS_ORCHESTRA := "res://assets/audio/music/boss_exclusive_orchestra.wav"

var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active_player: AudioStreamPlayer

var _current_path: String = ""
var _target_volume_db: float = -6.0
var _fade_tween: Tween
var _stream_cache: Dictionary = {}
var _warned_paths: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_players()
	_connect_events()
	# Tunggu 1 frame agar scene tree selesai terload sebelum cek scene awal
	await get_tree().process_frame
	_initial_scene_check()


func _setup_audio_players() -> void:
	_ensure_music_bus()
	_player_a = AudioStreamPlayer.new()
	_player_a.name = "MusicPlayerA"
	_player_a.bus = BUS_NAME
	_player_a.volume_db = -80.0
	add_child(_player_a)

	_player_b = AudioStreamPlayer.new()
	_player_b.name = "MusicPlayerB"
	_player_b.bus = BUS_NAME
	_player_b.volume_db = -80.0
	add_child(_player_b)

	_active_player = _player_a


## Bus "Music" biasanya dari default_bus_layout.tres. Kalau hilang (layout tertimpa),
## buat ulang agar pemutar tidak jatuh diam-diam ke bus yang salah.
func _ensure_music_bus() -> void:
	if AudioServer.get_bus_index(BUS_NAME) >= 0:
		return
	push_warning("[MusicManager] Bus 'Music' tidak ada di layout audio, dibuat ulang.")
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, BUS_NAME)
	AudioServer.set_bus_send(idx, &"Master")


func _connect_events() -> void:
	# Dengarkan pergantian scene
	get_tree().root.child_entered_tree.connect(_on_root_child_entered)
	
	# Dengarkan siklus waktu dari DayCycle
	if DayCycle.has_signal("time_tick"):
		DayCycle.time_tick.connect(_on_time_tick)


func _initial_scene_check() -> void:
	var current_scene = get_tree().current_scene
	if current_scene:
		print("[MusicManager] Scene awal terdeteksi: ", current_scene.name, " (", current_scene.scene_file_path, ")")
		_adapt_to_scene(current_scene)
	else:
		print("[MusicManager] WARNING: current_scene null saat _initial_scene_check!")


func _on_root_child_entered(node: Node) -> void:
	# Jika node baru yang masuk adalah scene utama (anak langsung dari root)
	if node.get_parent() == get_tree().root and node != self:
		call_deferred("_adapt_to_current_scene", node)


func _adapt_to_current_scene(node: Node) -> void:
	# Overlay/CanvasLayer yang ditambahkan ke root bukan scene utama; abaikan.
	if is_instance_valid(node) and node == get_tree().current_scene:
		_adapt_to_scene(node)


func _adapt_to_scene(scene: Node) -> void:
	if not scene or not is_instance_valid(scene):
		return
		
	var path: String = scene.scene_file_path.to_lower()
	var s_name: String = scene.name.to_lower()

	if "main_menu" in path or "main_menu" in s_name:
		play_menu()
	elif "cave" in path or "combat" in path:
		play_midnight_horror()
	elif "cookware_shop" in path or "blacksmith" in path or "warung" in path or "shop" in path:
		play_shop()
	elif "deepforest" in path or "deep_forest" in path or "forest" in path:
		play_forest()
	elif "town" in path or "balai" in path or "school" in path or "clinic" in path or "university" in path:
		play_town()
	elif "interior_house" in path or "home" in path or "interior" in path:
		play_interior()
	elif "farm" in path or "world" in path or "exterior" in path:
		play_farm_current_time()


func _on_time_tick(h: int, _m: int) -> void:
	# Update musik jika sedang explore di luar ruangan (farm / exterior)
	var cur_scene = get_tree().current_scene
	if not cur_scene:
		return
	var path: String = cur_scene.scene_file_path.to_lower()
	if "farm" in path or "exterior" in path or "world" in path:
		var desired_track := TRACK_DAY_FARM
		if h >= 0 and h < 6:
			# Tengah malam (00:00 - 05:59): kabut tebal & nightmare haunted!
			desired_track = TRACK_MIDNIGHT_HORROR
		elif h >= 18:
			# Malam santai (18:00 - 23:59)
			desired_track = TRACK_NIGHT_FARM
		else:
			# Siang hari (06:00 - 17:59)
			desired_track = TRACK_DAY_FARM

		if _current_path != desired_track:
			play_track(desired_track, 2.5, _target_volume_db)


func play_farm_current_time(fade_time: float = DEFAULT_FADE) -> void:
	var h: int = DayCycle.hour
	var track := TRACK_DAY_FARM
	if h >= 0 and h < 6:
		track = TRACK_MIDNIGHT_HORROR
	elif h >= 18:
		track = TRACK_NIGHT_FARM
	else:
		track = TRACK_DAY_FARM
	play_track(track, fade_time, -6.0)


func play_menu(fade_time: float = DEFAULT_FADE) -> void:
	play_track(TRACK_DAY_FARM, fade_time, -8.0)


func play_interior(fade_time: float = DEFAULT_FADE) -> void:
	# Dalam rumah aman & hangat dari teror luar
	play_track(TRACK_NIGHT_FARM, fade_time, -7.0)


func play_town(fade_time: float = DEFAULT_FADE) -> void:
	play_track(TRACK_TOWN, fade_time, -6.0)


func play_forest(fade_time: float = DEFAULT_FADE) -> void:
	play_track(TRACK_DEEP_FOREST, fade_time, -6.0)


func play_shop(fade_time: float = DEFAULT_FADE) -> void:
	play_track(TRACK_SHOP, fade_time, -6.5)


func play_rain(fade_time: float = DEFAULT_FADE) -> void:
	play_track(TRACK_RAIN, fade_time, -6.0)


func play_midnight_horror(fade_time: float = DEFAULT_FADE) -> void:
	play_track(TRACK_MIDNIGHT_HORROR, fade_time, -5.5)


func play_boss_orchestra(fade_time: float = 0.8) -> void:
	play_track(TRACK_BOSS_ORCHESTRA, fade_time, -5.0)


func play_track(track_path: String, fade_time: float = DEFAULT_FADE, target_volume_db: float = -6.0) -> void:
	if _current_path == track_path and (_active_player and _active_player.playing):
		return
	# Headless (tes/CI) tidak bersuara. Thread audio melepas playback secara tertunda, jadi
	# memutar musik di sini kadang meninggalkan stream saat proses keluar
	# ("resources still in use at exit") dan menggagalkan smoke test verify_mvp.
	if DisplayServer.get_name() == "headless":
		_current_path = track_path
		return

	var stream := _get_stream(track_path)
	if not stream:
		if not _warned_paths.has(track_path):
			_warned_paths[track_path] = true
			push_error("[MusicManager] Musik belum bisa dimuat: %s. Jika file .wav baru ditambahkan, buka editor Godot sekali agar ter-import (muncul file .import), lalu jalankan ulang." % track_path)
		return

	_current_path = track_path
	_target_volume_db = target_volume_db
	print("[MusicManager] ▶ Memutar: ", track_path.get_file())
	track_changed.emit(track_path.get_file().get_basename())

	# Crossfade dual-player
	var next_player: AudioStreamPlayer = _player_b if _active_player == _player_a else _player_a
	var prev_player: AudioStreamPlayer = _active_player

	next_player.stream = stream
	next_player.volume_db = -80.0
	next_player.play()

	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.set_trans(Tween.TRANS_SINE)
	_fade_tween.set_ease(Tween.EASE_IN_OUT)

	# Fade in player baru
	_fade_tween.tween_property(next_player, "volume_db", _target_volume_db, fade_time)

	# Fade out player lama
	if prev_player and prev_player.playing:
		_fade_tween.tween_property(prev_player, "volume_db", -80.0, fade_time)
		_fade_tween.chain().tween_callback(prev_player.stop)

	_active_player = next_player


func fade_out(fade_time: float = 1.0) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	if _active_player and _active_player.playing:
		_fade_tween = create_tween()
		_fade_tween.set_trans(Tween.TRANS_SINE)
		_fade_tween.set_ease(Tween.EASE_IN_OUT)
		_fade_tween.tween_property(_active_player, "volume_db", -80.0, fade_time)
		_fade_tween.tween_callback(func():
			_active_player.stop()
			_current_path = ""
		)


func fade_in(fade_time: float = 1.0) -> void:
	if _active_player and _active_player.stream:
		if not _active_player.playing:
			_active_player.play()
		if _fade_tween and _fade_tween.is_valid():
			_fade_tween.kill()
		_fade_tween = create_tween()
		_fade_tween.set_trans(Tween.TRANS_SINE)
		_fade_tween.set_ease(Tween.EASE_IN_OUT)
		_fade_tween.tween_property(_active_player, "volume_db", _target_volume_db, fade_time)


func _get_stream(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path]

	if not ResourceLoader.exists(path):
		return null

	var stream: AudioStream = load(path)
	# Pastikan stream berulang terus (loop)
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		# Import WAV default-nya tanpa loop sehingga loop_end = 0. Memaksa LOOP_FORWARD
		# dengan loop_end 0 membuat pemutar langsung berhenti (musik tidak terdengar),
		# jadi titik akhir loop diisi panjang lagu (dalam frame).
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED or wav.loop_end <= wav.loop_begin:
			wav.loop_begin = 0
			wav.loop_end = int(round(wav.get_length() * wav.mix_rate))
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true

	_stream_cache[path] = stream
	return stream
