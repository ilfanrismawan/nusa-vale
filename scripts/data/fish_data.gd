class_name FishData
extends Resource

@export var item: ItemData
@export var locations: PackedStringArray = []
@export_range(0, 24) var min_hour: int = 0
@export_range(0, 24) var max_hour: int = 0
@export_range(0.0, 1.0) var difficulty: float = 0.5
@export var weight: float = 1.0

func is_available(location_id: String, hour: int) -> bool:
	if not locations.has(location_id):
		return false
	if min_hour <= max_hour:
		return hour >= min_hour and hour < max_hour
	return hour >= min_hour or hour < max_hour
