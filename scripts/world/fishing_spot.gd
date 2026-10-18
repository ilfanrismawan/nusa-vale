class_name FishingSpot
extends Area2D

const SPOT_LAYER_BIT := 1 << 7

@export var location_id: String = "farm_pond"
## Air luar ruangan membeku di Musim Dingin (GDD 5). Matikan untuk spot khusus
## musim dingin (pemandian air panas, danau bawah tanah).
@export var freezes_in_winter: bool = true

func _ready() -> void:
	collision_layer = SPOT_LAYER_BIT
	collision_mask = 0
	monitoring = false
	monitorable = true
	if location_id.is_empty():
		push_warning("%s: location_id belum diisi." % name)

func is_frozen() -> bool:
	return freezes_in_winter and DayCycle.get_season() == DayCycle.Season.WINTER
