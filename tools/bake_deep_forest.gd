extends Node
## One-time headless conversion. Re-running with --overwrite replaces editor edits.
const OUTPUT := "res://scenes/world/DeepForest.tscn"

func _ready() -> void:
	call_deferred("_bake")

func _bake() -> void:
	if "--tree-assets-only" in OS.get_cmdline_user_args():
		_save_tree_assets()
		get_tree().quit()
		return
	if FileAccess.file_exists(OUTPUT) and not "--overwrite" in OS.get_cmdline_user_args():
		push_error("Scene already exists. Use --overwrite only to discard editor changes.")
		get_tree().quit(1)
		return
	var root := Node2D.new()
	root.name = "DeepForest"
	root.set_meta("farm_area", "deep_forest")
	var layout := preload("res://scripts/world/deep_forest_layout.gd").new()
	_save_tree_assets()
	layout.build(root)
	var mask := TileMapLayer.new()
	mask.name = "ResourceSpawnMask"
	mask.tile_set = layout.ground.tile_set
	mask.visible = false
	mask.z_index = 4
	mask.self_modulate = Color(1, 0.5, 0.1, 0.6)
	for cell: Vector2i in layout.resource_cells:
		mask.set_cell(cell, 1, Vector2i.ZERO)
	root.add_child(mask)
	var collisions := Node2D.new()
	collisions.name = "Collision"
	root.add_child(collisions)
	for group_name in ["Water", "Cliffs", "MapBounds"]:
		var group := Node2D.new()
		group.name = group_name
		collisions.add_child(group)
	var wall_index := 0
	for child in root.get_children():
		if not child is StaticBody2D: continue
		var shape: RectangleShape2D = child.get_child(0).shape
		var group_name := "Water"
		if shape.size.y > 16 and shape.size.x > 16: group_name = "Cliffs"
		if child.position.x <= 8 or child.position.x >= 1592 or child.position.y <= 8 or child.position.y >= 1272:
			group_name = "MapBounds"
		root.remove_child(child)
		collisions.get_node(group_name).add_child(child)
		child.name = "Blocker%03d" % wall_index
		child.get_child(0).name = "CollisionShape2D"
		wall_index += 1
	var prop_index := 0
	for child in layout.entities.get_children():
		if child is Sprite2D:
			var texture: AtlasTexture = child.texture
			var asset := texture.atlas.resource_path.get_file().get_basename().replace(" ", "")
			if child.name != "AncientAltar": child.name = "%s%04d" % [asset, prop_index]
			for body in child.get_children():
				body.name = "Blocker"
				body.get_child(0).name = "CollisionShape2D"
			prop_index += 1
	var light := CanvasModulate.new()
	light.name = "CanvasModulate"
	light.color = Color(0.72, 0.9, 0.83)
	root.add_child(light)
	var gate := Area2D.new()
	gate.name = "ReturnToForest"
	gate.set_script(preload("res://scripts/world/deep_forest_gate.gd"))
	gate.returning = true
	gate.position = Vector2(800, 80)
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var gate_shape := RectangleShape2D.new()
	gate_shape.size = Vector2(96, 48)
	collision.shape = gate_shape
	gate.add_child(collision)
	var label := Label.new()
	label.name = "Label"
	label.position = Vector2(-115, -50)
	label.text = "↑ Kembali ke Forest [E]"
	label.add_theme_font_size_override("font_size", 10)
	gate.add_child(label)
	root.add_child(gate)
	var spawners := [ForageSpawner.new(), WeedSpawner.new(), preload("res://scripts/world/deep_forest_tree_spawner.gd").new(), DigSpotSpawner.new(), preload("res://scripts/world/deep_forest_ore_spawner.gd").new()]
	var names := ["ForageSpawner", "WeedSpawner", "TreeSpawner", "DigSpotSpawner", "OreSpawner"]
	var daily := [10, 6, 4, 5, 4]
	var caps := [40, 30, 28, 16, 20]
	for i in spawners.size():
		var spawner: ForageSpawner = spawners[i]
		spawner.name = names[i]
		spawner.location_id = "deep_forest"
		spawner.daily_spawn = daily[i]
		spawner.max_active = caps[i]
		root.add_child(spawner)
	_set_owner(root, root)
	# Preserve the Player's packed-scene instance and its original internal owners.
	var player := preload("res://scenes/player/Player.tscn").instantiate()
	player.name = "Player"
	player.position = Vector2(800, 160)
	root.add_child(player)
	player.owner = root
	root.set_script(preload("res://scripts/world/deep_forest.gd"))
	var scene := PackedScene.new()
	var error := scene.pack(root)
	if error == OK: error = ResourceSaver.save(scene, OUTPUT)
	print("DEEP FOREST BAKE: ", error_string(error), "; editable props=", prop_index, "; resource cells=", mask.get_used_cells().size())
	root.free()
	get_tree().quit(0 if error == OK else 1)

func _set_owner(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		_set_owner(child, root)

func _save_tree_assets() -> void:
	for mature in [true, false]:
		var tree := preload("res://scripts/world/deep_forest_layout.gd").make_tree(mature)
		tree.name = "DeepForestTree" if mature else "SmallDeepForestTree"
		_set_owner(tree, tree)
		var scene := PackedScene.new()
		var error := scene.pack(tree)
		var path := "res://scenes/objects/deep_forest_tree.tscn" if mature else "res://scenes/objects/small_deep_forest_tree.tscn"
		if error == OK: error = ResourceSaver.save(scene, path)
		assert(error == OK, "Failed to save Deep Forest tree asset")
		tree.free()
