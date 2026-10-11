class_name FishingSpot
extends Area2D

const SPOT_LAYER_BIT := 1 << 7

@export var location_id: String = "farm_pond"

func _ready() -> void:
	collision_layer = SPOT_LAYER_BIT
	collision_mask = 0
	monitoring = false
	monitorable = true
	if location_id.is_empty():
		push_warning("%s: location_id belum diisi." % name)
	
