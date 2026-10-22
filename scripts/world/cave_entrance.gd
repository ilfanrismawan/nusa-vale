class_name CaveEntrance
extends Area2D

## Mulut Gua Tambang: pemain langsung masuk ke lobi gua saat menginjaknya (GDD 9).
## Tombol interaksi di depannya juga tetap bisa dipakai.

const CAVE_SCENE := "res://scenes/world/cave/cave.tscn"
## Posisi tiba di lobi (di bawah pintu masuk).
const ARRIVAL := Vector2(328, 72)

## Kosongkan agar selalu bisa dimasuki; isi id UnlockManager (mis. "cave") untuk mengunci.
@export var required_unlock: String = "cave"

func _ready() -> void:
	set_meta("player_interaction", true)
	# Ikut daftar pintu supaya bisa dimasuki saat pemain berdiri menempel di mulut gua.
	# Tanpa ini interaksi hanya mencari titik 32 px di depan kaki, yang sudah masuk ke dinding tebing.
	add_to_group("scene_door")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is Player and not body.is_input_locked() and not Transition.on_transition:
		interact(body)

func interact(player: Player = null) -> void:
	if player == null:
		player = RoomDoor.player()
	if player == null:
		return
	if required_unlock == "cave":
		UnlockManager.try_unlock_cave()
	if not required_unlock.is_empty() and not UnlockManager.is_unlocked(required_unlock):
		Notify.say("Perbaiki jembatan menuju Hutan untuk membuka akses Gua Tambang.")
		return
	enter(player)

static func enter(player: Player) -> void:
	GameState.cave.current_floor = 0
	if DiscoveryManager.discover("cave"):
		Notify.say("Gua Tambang: lantai baru setiap hari. Hancurkan batu atau kalahkan semua monster untuk menemukan tangga turun.")
	RoomDoor.travel(player, CAVE_SCENE, ARRIVAL)
