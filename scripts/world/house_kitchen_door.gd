extends Area2D

@export var required_flag := "house_kitchen_upgraded"
@export_file("*.tscn") var target_scene := "res://scenes/world/interior/home_kitchen.tscn"
@export var spawn_position := Vector2(96, 105)

func _ready() -> void:
	set_meta("player_interaction", true)

func interact(player: Player) -> void:
	if not WorldState.has_flag(required_flag):
		Notify.say("Ruang dapur belum dibangun. Pesan Upgrade Rumah ke Wira, tukang kayu di Bukit.")
		return
	RoomDoor.travel(player, target_scene, spawn_position)
