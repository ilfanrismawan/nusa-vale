extends Choppable
## Pine layers and masks belong to the scene; never replace editor polygons.

func _setup_tree_layers() -> void:
	_canopy = get_node("CanopyMask/Canopy") as AnimatedSprite2D
	_sync_tree_layers()

func _sync_tree_layers() -> void:
	if _canopy == null or animated_sprite == null:
		return
	_canopy.animation = animated_sprite.animation
	_canopy.set_frame_and_progress(animated_sprite.frame, animated_sprite.frame_progress)

func _wobble() -> void:
	# Move the masks together, retaining each layer's authored transform.
	for layer_name in ["TrunkMask", "CanopyMask"]:
		var layer := get_node(layer_name) as Node2D
		var base := layer.position
		var tween := create_tween()
		tween.tween_property(layer, "position", base + Vector2(1, 0), 0.04)
		tween.tween_property(layer, "position", base + Vector2(-1, 0), 0.06)
		tween.tween_property(layer, "position", base, 0.04)
