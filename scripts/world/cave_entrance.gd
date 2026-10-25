class_name CaveEntrance
extends Area2D

## Mulut Gua Tambang: pemain langsung masuk ke lobi gua saat menginjaknya (GDD 9).
## Tombol interaksi di depannya juga tetap bisa dipakai.
## Gambar pintu (Door Mine.png): kiri = terkunci (berpalang), kanan = terbuka.
## Saat pertama terlihat terbuka, palang bergetar, pecah, lalu pintu berganti ke versi terbuka.

const CAVE_SCENE := "res://scenes/world/cave/cave.tscn"
## Posisi tiba di lobi (di bawah pintu masuk).
const ARRIVAL := Vector2(328, 72)

## Kosongkan agar selalu bisa dimasuki; isi id UnlockManager (mis. "cave") untuk mengunci.
@export var required_unlock: String = "cave"
## Potongan Door Mine.png untuk tiap keadaan.
@export var locked_region := Rect2(0, 0, 32, 32)
@export var open_region := Rect2(32, 0, 32, 32)
## Jeda setelah scene muncul sebelum animasi membuka dimulai (layar transisi selesai dulu).
@export var open_delay := 0.8

## Penanda sudah pernah melihat animasi membuka (disimpan lewat DiscoveryManager, tanpa ubah versi save).
const OPENED_SEEN := "cave_door_opened"

@onready var _sprite: Sprite2D = get_node_or_null("Sprite2D")
var _opening := false
var _rattling := false

func _ready() -> void:
	set_meta("player_interaction", true)
	# Ikut daftar pintu supaya bisa dimasuki saat pemain berdiri menempel di mulut gua.
	# Tanpa ini interaksi hanya mencari titik 32 px di depan kaki, yang sudah masuk ke dinding tebing.
	add_to_group("scene_door")
	body_entered.connect(_on_body_entered)
	UnlockManager.unlock_changed.connect(_on_unlock_changed)
	if not _is_open():
		_show_region(locked_region)
	elif DiscoveryManager.has_discovered(OPENED_SEEN) or DiscoveryManager.has_discovered("cave"):
		# Sudah pernah masuk gua (save lama): langsung tampil terbuka tanpa animasi.
		DiscoveryManager.discover(OPENED_SEEN)
		_show_region(open_region)
	else:
		_show_region(locked_region)
		_play_open.call_deferred(open_delay)

func _is_open() -> bool:
	return required_unlock.is_empty() or UnlockManager.is_unlocked(required_unlock)

func _show_region(region: Rect2) -> void:
	if _sprite != null:
		_sprite.region_enabled = true
		_sprite.region_rect = region

func _on_unlock_changed(unlock_id: String, unlocked: bool) -> void:
	if unlock_id != required_unlock or not is_inside_tree():
		return
	if unlocked:
		_play_open(0.2)
	else:
		_show_region(locked_region)

## Animasi membuka: palang bergetar tiga kali makin keras, kilat putih, berganti ke pintu terbuka.
func _play_open(delay: float) -> void:
	if _opening or _sprite == null:
		return
	_opening = true
	DiscoveryManager.discover(OPENED_SEEN)
	var base := _sprite.position
	var tween := create_tween()
	tween.tween_interval(delay)
	for i in 3:
		var push := 1.0 + i
		tween.tween_callback(Juice.play.bind(&"mine", _door_center(), float(i) * 2.0))
		tween.tween_property(_sprite, "position", base + Vector2(push, 0), 0.04)
		tween.tween_property(_sprite, "position", base - Vector2(push, 0), 0.06)
		tween.tween_property(_sprite, "position", base, 0.04)
		tween.tween_interval(0.25 - i * 0.05)
	tween.tween_property(_sprite, "modulate", Color(3, 3, 3, 1), 0.06)
	tween.tween_callback(_burst_open)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.25)
	tween.parallel().tween_property(_sprite, "scale", Vector2.ONE, 0.25).from(Vector2(1.15, 0.85)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_finish_open)

func _burst_open() -> void:
	_show_region(open_region)
	Juice.play(&"mine_break", _door_center())
	Juice.shake(3.0, 0.2)

func _finish_open() -> void:
	_opening = false
	Juice.play(&"sparkle", _door_center())
	Juice.float_text("Terbuka!", _door_center() + Vector2(0, -20), Color(1.0, 0.85, 0.4))

## Kunci masih terpasang: palang bergoyang sedikit.
func _rattle_locked() -> void:
	if _rattling or _sprite == null:
		return
	_rattling = true
	var base := _sprite.position
	var tween := create_tween()
	tween.tween_property(_sprite, "position", base + Vector2(1, 0), 0.04)
	tween.tween_property(_sprite, "position", base - Vector2(1, 0), 0.06)
	tween.tween_property(_sprite, "position", base, 0.04)
	tween.tween_callback(func() -> void: _rattling = false)

func _door_center() -> Vector2:
	return _sprite.global_position if _sprite != null else global_position

func _on_body_entered(body: Node2D) -> void:
	if body is Player and not body.is_input_locked() and not Transition.on_transition:
		interact(body)

func interact(player: Player = null) -> void:
	if player == null:
		player = RoomDoor.player()
	if player == null or _opening:
		return
	# Syarat baru saja terpenuhi di sini: tunggu animasi membuka selesai sebelum bisa masuk.
	if required_unlock == "cave" and not UnlockManager.is_unlocked("cave") and UnlockManager.try_unlock_cave():
		return
	if not _is_open():
		_rattle_locked()
		if UnlockManager.miner_level_waiting_for_sleep():
			Notify.say("EXP Penambang sudah cukup. Tidur dulu agar naik ke Lv %d, lalu Gua Tambang terbuka." % UnlockManager.CAVE_MINER_LEVEL)
		else:
			Notify.say("Gua Tambang butuh Penambang Lv %d. Pecahkan batu dan bijih untuk menambah EXP Penambang." % UnlockManager.CAVE_MINER_LEVEL)
		return
	enter(player)

static func enter(player: Player) -> void:
	GameState.cave.current_floor = 0
	if DiscoveryManager.discover("cave"):
		Notify.say("Gua Tambang: lantai baru setiap hari. Hancurkan batu atau kalahkan semua monster untuk menemukan tangga turun.")
	RoomDoor.travel(player, CAVE_SCENE, ARRIVAL)
