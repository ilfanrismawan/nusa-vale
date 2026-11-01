extends "res://scripts/world/exit_door_school.gd"

## Pintu dari ruangan rumah (dapur, gudang) kembali ke interior_house.tscn. Pemain muncul di Marker2D
## `return_marker` milik layout tingkat rumah sekarang; `spawn_position` hanya cadangan.

@export var return_marker := "KitchenReturn"

func _on_body_entered(body: Node2D) -> void:
	spawn_position = HouseInteriorLayout.point(return_marker, spawn_position)
	super(body)
