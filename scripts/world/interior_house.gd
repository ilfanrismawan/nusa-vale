extends Node2D

## Pintu ke ruang dapur (upgrade rumah tingkat 1 di Wira, GDD 4.12). Ditambah dari kode supaya
## interior_house.tscn tidak perlu diedit; pintunya selalu ada dan menolak masuk sebelum dapur dibangun.
const KITCHEN_DOOR := preload("res://scenes/objects/cooking/home_kitchen_entry.tscn")
const TELEVISION := preload("res://scenes/objects/television.tscn")

## Dekat titik kembali dari dapur (home_kitchen.tscn ExitDoor.spawn_position = 344, 159).
@export var kitchen_door_position := Vector2(358, 168)
## Di sudut dinding kanan atas rumah (GDD 4.1).
@export var television_position := Vector2(360, 128)

func _ready() -> void:
	var household := Node2D.new()
	household.name = "Household"
	household.set_script(preload("res://scripts/world/npc_home.gd"))
	add_child(household)
	if get_node_or_null("KitchenDoor") == null:
		var door := KITCHEN_DOOR.instantiate()
		door.name = "KitchenDoor"
		door.position = kitchen_door_position
		add_child(door)
	if get_node_or_null("Television") == null:
		var tv := TELEVISION.instantiate()
		tv.name = "Television"
		tv.position = television_position
		add_child(tv)
