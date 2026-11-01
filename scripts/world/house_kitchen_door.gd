extends Area2D

## Pintu di dalam rumah ke ruangan hasil upgrade (dapur, gudang). Menolak masuk sebelum flag menyala.
@export var required_flag := "house_kitchen_upgraded"
@export_file("*.tscn") var target_scene := "res://scenes/world/interior/home_kitchen.tscn"
@export var spawn_position := Vector2(96, 105)
@export_multiline var locked_message := "Ruang dapur belum dibangun. Pesan Upgrade Rumah ke Wira, tukang kayu di Bukit."

func _ready() -> void:
	set_meta("player_interaction", true)

func interact(player: Player) -> void:
	if not WorldState.has_flag(required_flag):
		Notify.say(locked_message)
		return
	RoomDoor.travel(player, target_scene, spawn_position)
