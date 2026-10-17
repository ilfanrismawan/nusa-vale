@tool
class_name SeatPose
extends Resource
## One direction of a seat. All coordinates are local pixels at the ground pivot.
@export_enum("Atas", "Bawah", "Kiri", "Kanan") var facing: int = 1
@export var region := Rect2(130, 13, 11, 18)
@export var sprite_offset := Vector2(0, -5)
@export var seat_position := Vector2(0, -5)
@export var visual_offset := Vector2(0, -6)
@export var collision_size := Vector2(8, 5)
@export var collision_position := Vector2.ZERO
@export_range(0, 64, 1) var backrest_height: float = 0

