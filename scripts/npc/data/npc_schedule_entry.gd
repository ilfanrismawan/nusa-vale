class_name NPCScheduleEntry
extends Resource

@export_range(0, 23) var hour: int = 6
@export_range(0, 59) var minute: int = 0

@export var map_id: StringName
@export var point_id: StringName
@export var activity: StringName = &"idle"

func total_minutes() -> int:
	return hour * 60 + minute
