class_name CaveEntrance
extends Area2D

## Mulut Gua Tambang: tekan interaksi untuk masuk ke lobi gua (GDD 9).

const CAVE_SCENE := "res://scenes/world/cave/cave.tscn"
## Posisi tiba di lobi (di bawah pintu masuk).
const ARRIVAL := Vector2(328, 72)

## Kosongkan agar selalu bisa dimasuki; isi id UnlockManager (mis. "cave") untuk mengunci.
@export var required_unlock: String = ""

func _ready() -> void:
	set_meta("player_interaction", true)

func interact(player: Player = null) -> void:
	if player == null:
		player = RoomDoor.player()
	if player == null:
		return
	if not required_unlock.is_empty() and not UnlockManager.is_unlocked(required_unlock):
		Notify.say("Mulut gua masih tertutup reruntuhan.")
		return
	enter(player)

static func enter(player: Player) -> void:
	GameState.cave.current_floor = 0
	if DiscoveryManager.discover("cave"):
		Notify.say("Gua Tambang: lantai baru setiap hari. Hancurkan batu atau kalahkan semua monster untuk menemukan tangga turun.")
	RoomDoor.travel(player, CAVE_SCENE, ARRIVAL)
