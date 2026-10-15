extends TreeSpawner

func _make_node(id: String, cell: Vector2i) -> Node2D:
	var parts := id.split("|")
	var mature := parts.size() > 1 and parts[1] == BIG
	var path := "res://scenes/objects/deep_forest_tree.tscn" if mature else "res://scenes/objects/small_deep_forest_tree.tscn"
	var node := (load(path) as PackedScene).instantiate() as Choppable
	node.persistent = false
	node.name = "SpawnedTree_%d_%d" % [cell.x, cell.y]
	node.tree_exiting.connect(_on_tree_removed.bind(node, cell))
	return node
