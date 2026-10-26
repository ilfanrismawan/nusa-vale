extends StaticBody2D
## One body for every scenery collider. Each sprite under `scenery` that has
## `blocker_radius` metadata gets a circle shape at its current transform, built at
## runtime instead of saved as two nodes per tree. Moving, duplicating or deleting a
## tree in the editor keeps its collider in sync.
@export var scenery: NodePath = ^"../../YSortEntities"

func _ready() -> void:
	var circles: Dictionary = {}
	var to_body := global_transform.affine_inverse()
	for child in get_node(scenery).get_children():
		var sprite := child as Node2D
		if sprite == null or not sprite.has_meta("blocker_radius"):
			continue
		var radius: float = sprite.get_meta("blocker_radius")
		if not circles.has(radius):
			var circle := CircleShape2D.new()
			circle.radius = radius
			circles[radius] = circle
		var shape_owner := create_shape_owner(sprite)
		shape_owner_add_shape(shape_owner, circles[radius])
		shape_owner_set_transform(shape_owner, to_body * sprite.global_transform)
