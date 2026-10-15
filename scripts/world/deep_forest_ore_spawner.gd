extends ForageSpawner

func _area_key() -> String:
	return location_id + "#ore"

func _clear_on_season() -> bool:
	return false

func _pick_id() -> String:
	return "iron" if randf() < 0.65 else "copper"

func _make_node(id: String, cell: Vector2i) -> Node2D:
	var path := "res://scenes/objects/RockIron.tscn" if id == "iron" else "res://scenes/objects/RockCopper.tscn"
	var rock := load(path).instantiate() as Choppable
	rock.persistent = false
	rock.drop_count = 5
	rock.name = "DeepOre_%d_%d" % [cell.x, cell.y]
	rock.tree_exiting.connect(_on_removed.bind(rock, cell))
	return rock

func _on_removed(rock: Choppable, cell: Vector2i) -> void:
	if rock.is_destroyed:
		ForageManager.remove_item(_area_key(), cell)
		_nodes.erase(ForageManager.key_of(cell))

func _on_spawned(_count: int) -> void:
	pass
