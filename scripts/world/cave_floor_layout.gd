class_name CaveFloorLayout
extends Node2D

## Dekorasi/rintangan buatan editor. Collider persegi/lingkaran otomatis mengunci spawn.
## Untuk sprite non-solid yang juga harus bebas spawn, tambahkan Reserved Regions (tile).
@export var reserved_regions: Array[Rect2i] = []

func occupied_cells(space: Node2D, tile_size: int, include_reserved: bool = true) -> Array[Vector2i]:
	var cells: Dictionary = {}
	for region in (reserved_regions if include_reserved else []):
		for x in range(region.position.x, region.end.x):
			for y in range(region.position.y, region.end.y):
				cells[Vector2i(x, y)] = true
	for node in find_children("*", "CollisionShape2D", true, false):
		var collider := node as CollisionShape2D
		if collider.disabled or not collider.get_parent() is StaticBody2D:
			continue
		var half := Vector2.ZERO
		if collider.shape is RectangleShape2D:
			half = (collider.shape as RectangleShape2D).size * 0.5
		elif collider.shape is CircleShape2D:
			half = Vector2.ONE * (collider.shape as CircleShape2D).radius
		else:
			continue
		var bounds := Rect2(space.to_local(collider.to_global(-half)), Vector2.ZERO)
		for corner in [Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)]:
			bounds = bounds.expand(space.to_local(collider.to_global(corner)))
		var first := Vector2i((bounds.position / tile_size).floor())
		var end := Vector2i((bounds.end / tile_size).ceil())
		for x in range(first.x, end.x):
			for y in range(first.y, end.y):
				cells[Vector2i(x, y)] = true
	var result: Array[Vector2i] = []
	for cell in cells:
		result.append(cell)
	return result
