class_name CropData
extends Resource


@export var crop_id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D

@export var growth_stages: Array[Vector2i] = []

@export var days_per_stage: int = 1

@export var harvest_item_id: String = ""
@export var harvest_count: int = 1

@export var tileset_source_id: int = 0

func get_total_stages() -> int:
	return growth_stages.size()
	
func is_harvestable(current_stage: int) -> bool:
	return current_stage >= growth_stages.size() - 1
