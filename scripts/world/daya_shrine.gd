class_name DayaShrine
extends Area2D
## Akar Keramat (docs/BIJI_DAYA.md): tempat Biji Daya di dunia. Tata letak ada di
## scenes/world/exterior/object/daya_shrine.tscn; teks, syarat, dan efek diatur di Inspector.

## ID Biji Daya (PlayerData.DAYA_IDS): item yang diberikan = "biji_daya_<id>".
@export var daya_id := "forest"
## Flag WorldState yang harus aktif sebelum biji bisa diambil. Kosong = tanpa syarat.
@export var required_flag := "bridge_repaired"

@export_group("Teks")
@export var title := "Akar Keramat"
## Ditambahkan di belakang judul setelah biji diambil, mis. "Akar Keramat · Hening".
@export var found_suffix := "Hening"
@export_multiline var locked_message := "Akar ini menanti jalan pulau yang tersambung kembali."
@export_multiline var found_message := "Hangat akar keramat kini menetap bersamamu."
## Pesan saat masuk area selama biji belum diambil. Kosong = tanpa pesan.
@export_multiline var arrival_message := "Cahaya keemasan berdenyut di akar keramat dekat jalan hutan. Dekati dan berinteraksi."

@export_group("Tampilan")
## Frame Altar saat biji masih ada; berputar berurutan agar rune berdenyut.
@export var lit_frames: PackedInt32Array = [3, 4, 5, 4]
@export var lit_fps := 4.0
## Frame Altar setelah biji diambil (rune padam).
@export var dim_frame := 0
@export var found_tint := Color(0.85, 0.9, 0.84)
## Biji melayang naik-turun (piksel) dan kecepatannya.
@export var bob_height := 2.0
@export var bob_speed := 2.4
@export var aura_pulse := 0.12

@export_group("Efek ambil")
## Partikel, riak, guncangan dan suara saat biji lepas dari akar.
@export var release_feedback: ActionFeedback = preload("res://resources/feedback/daya_obtain.tres")
## Partikel saat biji tiba di atas kepala pemain.
@export var hold_feedback: ActionFeedback = preload("res://resources/feedback/sparkle.tres")
@export var rise_height := 18.0
@export var rise_time := 0.4
## Lama biji melengkung dari akar ke atas kepala pemain.
@export var arc_time := 0.35
@export var arc_height := 22.0
@export var head_offset := Vector2(0, -30)
## Biji diangkat di atas kepala sebelum terbang ke tas.
@export var hold_time := 0.7
@export var pop_scale := 1.6
@export var obtain_text := "Biji Daya!"
@export var obtain_text_color := Color(1, 0.89, 0.48)
@export_range(0.0, 0.3, 0.01) var zoom_punch := 0.1
## Nada lonceng berurutan (semitone) saat biji diangkat. Kosong = tanpa lonceng.
@export var chime_notes: PackedInt32Array = [0, 4, 7, 12]
@export var chime_volume_db := -9.0
@export var chime_interval := 0.09
## Kunci gerak pemain selama efek agar urutannya terbaca.
@export var lock_input := true

@onready var _altar: Sprite2D = $Altar
@onready var _seed: Sprite2D = $Seed
@onready var _aura: Sprite2D = $Aura
@onready var _sparkles: CPUParticles2D = $Sparkles
@onready var _hint: Label = $Hint

var _seed_base := Vector2.ZERO
var _aura_base := Vector2.ONE
var _time := 0.0
var _playing := false
var _actor: Player

func _ready() -> void:
	# Player.interact() hanya mengirim dirinya ke target bertanda ini.
	set_meta("player_interaction", true)
	_seed_base = _seed.position
	_aura_base = _aura.scale
	GameState.daya.state_changed.connect(_refresh)
	_refresh()
	if not _found() and not arrival_message.is_empty():
		Notify.say(arrival_message)

func _found() -> bool:
	return GameState.daya.obtained.has(daya_id)

func _process(delta: float) -> void:
	if _playing or _found():
		return
	_time += delta
	_seed.position = _seed_base + Vector2(0, sin(_time * bob_speed) * bob_height).round()
	_aura.scale = _aura_base * (1.0 + sin(_time * bob_speed) * aura_pulse)
	if not lit_frames.is_empty():
		_altar.frame = lit_frames[int(_time * lit_fps) % lit_frames.size()]

func interact(actor: Player = null) -> void:
	if _playing:
		return
	if actor == null or (not required_flag.is_empty() and not WorldState.has_flag(required_flag)):
		Notify.say(locked_message)
		return
	if _found():
		Notify.say(found_message)
		return
	_playing = true
	GameState.daya.unlock(daya_id, actor.data)
	if _found():
		_play_obtain(actor)
	else:
		# Tas penuh: hadiah tertunda dikirim DayaManager, biji tetap di akar.
		_playing = false

func _refresh() -> void:
	if _playing:
		return
	var found := _found()
	_seed.visible = not found
	_aura.visible = not found
	_sparkles.emitting = not found
	_altar.modulate = found_tint if found else Color.WHITE
	if found:
		_altar.frame = dim_frame
	_hint.text = "%s · %s" % [title, found_suffix if found else "Interaksi"]

func _play_obtain(actor: Player) -> void:
	_actor = actor
	if lock_input:
		actor.set_input_locked(&"daya_obtain", true)
	GameState.use_player(actor)
	_sparkles.emitting = false
	_hint.visible = false
	_seed.z_index = 20
	_seed.position = _seed_base
	Juice.play_feedback(release_feedback, _seed.global_position)
	var tw := create_tween()
	# 1. Akar menyala terang dan biji melompat lepas.
	tw.tween_property(_altar, "modulate", Color(1.8, 1.6, 1.2), 0.08)
	tw.parallel().tween_property(_seed, "scale", Vector2(0.7, 1.4) * pop_scale, 0.1)
	tw.parallel().tween_property(_aura, "scale", _aura_base * 1.8, rise_time).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_aura, "modulate:a", 0.0, rise_time)
	tw.tween_property(_seed, "position", _seed_base + Vector2(0, -rise_height), rise_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_seed, "scale", Vector2.ONE * pop_scale, rise_time).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_altar, "modulate", Color.WHITE, rise_time)
	# 2. Biji melengkung ke atas kepala pemain.
	var start := _seed_base + Vector2(0, -rise_height)
	tw.tween_method(_arc_to_head.bind(actor, start), 0.0, 1.0, arc_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 3. Diangkat: lonceng, kilau, teks, kamera mendekat.
	tw.tween_callback(_on_hold.bind(actor))
	tw.tween_property(_seed, "scale", Vector2.ONE * pop_scale * 1.25, 0.08)
	tw.tween_property(_seed, "scale", Vector2.ONE * pop_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold_time)
	# 4. Terbang ke tas; rune akar padam.
	tw.tween_callback(_finish.bind(actor))

func _head_of(actor: Player) -> Vector2:
	return to_local(actor.global_position + head_offset) if is_instance_valid(actor) else _seed.position

func _arc_to_head(t: float, actor: Player, start: Vector2) -> void:
	var target := _head_of(actor)
	_seed.position = start.lerp(target, t) + Vector2(0, -arc_height * sin(t * PI))

func _on_hold(actor: Player) -> void:
	GameState.use_player(actor)
	if hold_feedback != null:
		Juice.play_feedback(hold_feedback, _seed.global_position)
	Juice.float_text(obtain_text, _seed.global_position + Vector2(0, -10), obtain_text_color, hold_time)
	if is_instance_valid(actor) and zoom_punch > 0.0:
		CombatJuice.zoom_punch(actor, zoom_punch)
	for i in chime_notes.size():
		get_tree().create_timer(chime_interval * i, false).timeout.connect(Juice.sfx.bind(SfxSynth.chime(), chime_volume_db - i, 0.0, float(chime_notes[i])))

func _finish(actor: Player) -> void:
	GameState.use_player(actor)
	Juice.fly_to_hotbar(_seed.texture, _seed.global_position, "biji_daya_" + daya_id)
	_seed.z_index = 0
	_seed.scale = Vector2.ONE
	_seed.position = _seed_base
	_aura.scale = _aura_base
	_aura.modulate.a = 1.0
	_hint.visible = true
	_playing = false
	_refresh()
	var dim := create_tween()
	_altar.modulate = Color(1.4, 1.3, 1.1)
	dim.tween_property(_altar, "modulate", found_tint, 0.5)
	_release_input()

func _release_input() -> void:
	if is_instance_valid(_actor):
		_actor.set_input_locked(&"daya_obtain", false)
	_actor = null

func _exit_tree() -> void:
	_release_input()
