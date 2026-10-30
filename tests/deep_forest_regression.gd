extends Node
var failures := 0

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func _ready() -> void:
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	# Tas awal (12 slot, 10 terisi alat) tidak muat 150 kayu + 75 batu sekaligus.
	GameState.current.bag_level = 2
	GameState.money = 5000
	GameState.add_item("wood", 150)
	GameState.add_item("stone", 75)
	check(not UnlockManager.purchase_deep_forest(), "forest prerequisite blocks purchase")
	check(GameState.money == 5000 and GameState.get_item_count("wood") == 150, "failed purchase consumes nothing")
	UnlockManager.unlock("forest")
	GameState.money = 2999
	check(not UnlockManager.purchase_deep_forest(), "insufficient money blocks purchase")
	GameState.money = 5000
	GameState.remove_item("stone", 1)
	check(not UnlockManager.purchase_deep_forest() and GameState.money == 5000, "insufficient material consumes nothing")
	GameState.add_item("stone", 1)
	check(UnlockManager.purchase_deep_forest(), "requirements unlock deep forest")
	check(GameState.money == 2000 and GameState.get_item_count("wood") == 0 and GameState.get_item_count("stone") == 0, "one-time exact cost")
	check(not UnlockManager.purchase_deep_forest() and GameState.money == 2000, "repeat unlock never charges")
	var saved := UnlockManager.get_unlocks()
	UnlockManager.reset()
	UnlockManager.load_unlocks(saved)
	check(UnlockManager.is_unlocked("deep_forest"), "unlock save roundtrip")
	UnlockManager.reset()
	UnlockManager.load_unlocks({"forest": true})
	check(not UnlockManager.is_unlocked("deep_forest"), "old saves keep new area locked")
	var forest := load("res://scenes/world/Forest.tscn").instantiate() as Node2D
	get_tree().root.add_child(forest)
	get_tree().current_scene = forest
	await get_tree().physics_frame
	await get_tree().physics_frame
	var entrance := forest.get_node("DeepForestEntrance") as Area2D
	var ground := forest.get_node("BaseLayerGround") as TileMapLayer
	check(ground.get_cell_source_id(ground.local_to_map(entrance.position)) >= 0, "entrance stands on forest ground")
	var query := PhysicsPointQueryParameters2D.new()
	query.position = entrance.global_position
	query.collide_with_areas = false
	check(forest.get_world_2d().direct_space_state.intersect_point(query).is_empty(), "entrance is not inside a solid obstacle")
	get_tree().current_scene = self
	forest.queue_free()
	await get_tree().process_frame
	var deep := load("res://scenes/world/DeepForest.tscn").instantiate() as Node2D
	check(deep.has_node("BaseLayerGround") and deep.has_node("ResourceSpawnMask") and deep.has_node("ForageSpawner"), "editable map and spawners exist before runtime")
	check(deep.get_node("YSortEntities").get_child_count() > 1000, "scenery is serialized in tscn")
	var edited_ground := deep.get_node("BaseLayerGround") as TileMapLayer
	edited_ground.set_cell(Vector2i(3, 3), 0, Vector2i(6, 2))
	deep.get_node("ForageSpawner").daily_spawn = 11
	var altar_position: Vector2 = deep.get_node("YSortEntities/AncientAltar").position + Vector2(0, 2)
	deep.get_node("YSortEntities/AncientAltar").position = altar_position
	# A previous version could have saved loot where the redesigned river runs.
	ForageManager.add_item("deep_forest", Vector2i(20, 10), "mooncap")
	get_tree().root.add_child(deep)
	get_tree().current_scene = deep
	for i in 8:
		await get_tree().physics_frame
	DayCycle.is_running = false
	check(edited_ground.get_cell_atlas_coords(Vector2i(3, 3)) == Vector2i(6, 2), "runtime preserves terrain edits")
	check(deep.get_node("ForageSpawner").daily_spawn == 11, "runtime preserves Inspector spawn settings")
	check(deep.get_node("YSortEntities/AncientAltar").position == altar_position, "runtime preserves prop placement")
	check(deep.get_node("ReturnToForest").get_child_count() == 2, "baked gate has no duplicate collision or label")
	check(deep.get_node("BaseLayerGround").get_used_rect().size == Vector2i(100, 80), "larger map built")
	check(deep.has_node("ReturnToForest"), "return exit exists")
	check(deep.has_node("RiverBanks") and deep.has_node("MossyCliffs") and deep.has_node("DeepWaterfall1"), "deep forest landscape assets built")
	check(not ForageManager.has_item_at("deep_forest", Vector2i(20, 10)), "old layout loot relocated off the river")
	check(ForageManager.get_items("deep_forest").size() > 12, "more forage than regular forest capacity")
	check(ForageManager.get_items("deep_forest#ore").size() > 0, "renewable ore spawned")
	check(not ForageManager.candidates("deep_forest", true).is_empty(), "rare dig loot exists")
	_check_routes(deep)
	for area: String in ["deep_forest", "deep_forest#tree", "deep_forest#ore", "deep_forest#dig"]:
		for key: String in ForageManager.get_items(area):
			check(deep.is_resource_cell(ForageManager.cell_from_key(key)), "resources stay in reachable glades")
	var count := ForageManager.get_items("deep_forest").size()
	deep.queue_free()
	get_tree().current_scene = self
	await get_tree().process_frame
	deep = load("res://scenes/world/DeepForest.tscn").instantiate()
	get_tree().root.add_child(deep)
	get_tree().current_scene = deep
	for i in 8:
		await get_tree().physics_frame
	check(ForageManager.get_items("deep_forest").size() == count, "same-day revisit does not regenerate loot")
	get_tree().current_scene = self
	deep.queue_free()
	await get_tree().process_frame
	print("DEEP FOREST COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)

func _check_routes(deep: Node2D) -> void:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, 100, 80)
	grid.cell_size = Vector2(16, 16)
	grid.offset = Vector2(8, 8)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var shape := CircleShape2D.new()
	shape.radius = 6.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collide_with_areas = false
	query.exclude = [deep.get_node("Player/CharacterBody2D").get_rid()]
	var space := deep.get_world_2d().direct_space_state
	for y in 80:
		for x in 100:
			query.transform = Transform2D(0, Vector2(x * 16 + 8, y * 16 + 8))
			grid.set_point_solid(Vector2i(x, y), not space.intersect_shape(query, 1).is_empty())
	var start := Vector2i(50, 10)
	for destination in [Vector2i(50, 5), Vector2i(50, 42), Vector2i(63, 25), Vector2i(34, 60), Vector2i(68, 61), Vector2i(11, 45), Vector2i(20, 30), Vector2i(17, 59)]:
		# A harvestable rock/tree may occupy the exact center of a glade.
		var reachable := false
		for y in range(-2, 3):
			for x in range(-2, 3):
				var target: Vector2i = destination + Vector2i(x, y)
				if not grid.is_point_solid(target) and not grid.get_id_path(start, target).is_empty():
					reachable = true
		check(reachable, "walkable route to " + str(destination))
