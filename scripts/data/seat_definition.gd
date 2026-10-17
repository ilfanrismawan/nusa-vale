@tool
class_name SeatDefinition
extends Resource
## Reusable artwork and direction-specific seating alignment.
@export var texture: Texture2D
@export var poses: Array[SeatPose] = []

func pose_for(direction: int) -> SeatPose:
	for pose in poses:
		if pose != null and pose.facing == direction:
			return pose
	return null

func next_facing(current: int) -> int:
	# Clockwise: up, right, down, left. Skip directions without artwork.
	var order := [0, 3, 1, 2]
	var index := order.find(current)
	for step in range(1, 5):
		var candidate: int = order[posmod(index + step, 4)]
		if pose_for(candidate) != null:
			return candidate
	return current

