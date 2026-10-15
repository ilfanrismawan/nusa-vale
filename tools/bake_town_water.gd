extends SceneTree

func _initialize() -> void:
	var town: Node2D = load("res://scenes/world/town.tscn").instantiate()
	for node_name in ["WaterDecoration", "TownRiverSpot"]:
		var existing := town.get_node_or_null(node_name)
		if existing:
			existing.free()
	preload("res://scripts/world/town_water.gd").build(town)
	print("Water decorations: ", town.get_node("WaterDecoration").get_used_cells().size(), "; fishing regions: ", town.get_node("TownRiverSpot").get_child_count())
	var packed := PackedScene.new()
	packed.pack(town)
	var result := ResourceSaver.save(packed, "res://scenes/world/town.tscn")
	town.free()
	quit(result)
