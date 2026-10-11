class_name FishData
extends Resource

@export var item: ItemData
@export var locations: PackedStringArray = []
@export_range(0, 24) var min_hour: int = 0
@export_range(0, 24) var max_hour: int = 24
@export var weight_mult: float = 1.0
@export_range(-0.1, 0.1, 0.01) var difficulty_offset: float = 0.0


func get_difficulty() -> float:
	return FishTiers.difficulty_of(self)

func get_weight() -> float:
	return FishTiers.weight_of(self)

func is_available(location_id: String, hour: int) -> bool:
	if not locations.has(location_id):
		return false
	if min_hour <= max_hour:
		return hour >= min_hour and hour < max_hour
	return hour >= min_hour or hour < max_hour
