class_name ProductReadySound
extends AudioStreamPlayer2D
## Max Distance menjadi radius dengar. Kejadian yang lewat saat jauh tidak diantrekan.

@export var enabled := true
var _was_ready := false

func update_ready(product_ready: bool) -> void:
	var first_ready := product_ready and not _was_ready
	_was_ready = product_ready
	if first_ready:
		play_if_near()

func play_if_near() -> bool:
	if not enabled or stream == null or not is_inside_tree():
		return false
	for candidate in get_tree().get_nodes_in_group(&"player"):
		# Player.tscn juga memberi grup ini ke wrapper; hanya karakter aktual yang didengar.
		if not candidate is Player or candidate.get_world_2d() != get_world_2d():
			continue
		var feet: Vector2 = candidate.global_position + Player.FEET_OFFSET
		if global_position.distance_squared_to(feet) <= max_distance * max_distance:
			play()
			return true
	return false
