extends Node2D
var failures := 0
func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _ready() -> void:
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.current_day = 3
	var cave: Node2D = load("res://scenes/world/cave/cave.tscn").instantiate()
	add_child(cave)
	await get_tree().physics_frame
	for floor_number in [1, 6, 11, 21, 41, 61, 81]:
		var band := CaveManager.DATA.band_for(floor_number)
		var pool := band.dungeon_scenes.duplicate()
		check(pool.size() >= 3, "tier %d has whole-floor scenes" % floor_number)
		for prefab in pool:
			band.dungeon_scenes = [prefab]
			cave.build_floor(floor_number)
			var layout: CaveDungeonLayout = cave.dungeon_layout
			check(layout != null, "dungeon selected: %s" % prefab.resource_path)
			if layout == null:
				continue
			check(layout.reachable.size() == layout.walkable.size() and layout.walkable.size() < 760, "walkable rooms are connected and differ from old rectangle")
			check(not cave.get_node("BaseLayerGround").visible and cave.get_node("PillarWalls").get_child_count() > 0, "authored tiles and derived wall collisions are active")
			var resources := 0
			var enemies := 0
			var gems := 0
			var categories_ok := true
			var routes_clear := true
			var solid: Dictionary = {}
			for node in cave.get_node("FloorContent").get_children():
				if node is Enemy or node is Choppable:
					var cell: Vector2i = cave.cell_of(node.home) if node is Enemy else node.get_meta("cave_cell")
					var zone := layout.find_child(str(node.get_meta("spawn_zone")), true, false) as CaveSpawnZone
					categories_ok = categories_ok and zone != null and zone.cells(cave).has(cell) and layout.reachable.has(cell)
					routes_clear = routes_clear and not layout.routes.has(cell)
					if node is Enemy:
						node.ai_enabled = false
						enemies += 1
						categories_ok = categories_ok and zone.kind == CaveSpawnZone.Kind.ENEMY
					else:
						resources += 1
						solid[cell] = true
						var ore := CaveManager.DATA.ore(node.drop_item_id)
						if ore.is_gem:
							gems += 1
							categories_ok = categories_ok and zone.kind == CaveSpawnZone.Kind.GEM
			check(categories_ok and routes_clear, "spawn respects editor zones, safe areas and protected routes")
			check(resources >= band.rock_min and resources <= band.rock_max and enemies >= band.enemy_min and enemies <= band.enemy_max and gems > 0, "tier budgets and guaranteed gem pocket are filled")
			var reachable := _flood(layout.walkable, cave.cell_of(cave.arrival_position()), solid)
			var accessible := true
			for cell in layout.stair_cells:
				accessible = accessible and reachable.has(cell)
			check(accessible, "stairs remain reachable without breaking rocks")
			var end: Vector2i = layout.stair_cells[0]
			var nav_path := layout.navigation.get_id_path(cave.cell_of(cave.arrival_position()), end)
			var navigation_ok := nav_path.size() > 1
			for point in nav_path:
				navigation_ok = navigation_ok and layout.walkable.has(point) and not solid.has(point)
			check(navigation_ok, "enemy navigation follows corridors and avoids ore rocks")
			var snapshot := _snapshot(cave)
			cave.build_floor(floor_number)
			check(_snapshot(cave) == snapshot, "same seed repeats all resource and enemy placement")
			cave._reveal_stairs(Vector2i(-999, -999))
			check(cave.dungeon_layout.stair_cells.has(cave.cell_of(cave.stairs.global_position)), "stairs use reachable editor candidate")
			await get_tree().physics_frame
		band.dungeon_scenes.assign(pool)
	# A quiet editor-configured floor still has an exit.
	var quiet_band := CaveManager.DATA.band_for(41)
	var saved_counts := [quiet_band.rock_min, quiet_band.rock_max, quiet_band.enemy_min, quiet_band.enemy_max]
	quiet_band.rock_min = 0
	quiet_band.rock_max = 0
	quiet_band.enemy_min = 0
	quiet_band.enemy_max = 0
	cave.build_floor(41)
	check(cave.stairs != null, "empty peaceful floor reveals an exit immediately")
	quiet_band.rock_min = saved_counts[0]
	quiet_band.rock_max = saved_counts[1]
	quiet_band.enemy_min = saved_counts[2]
	quiet_band.enemy_max = saved_counts[3]
	# Invalid edited map is rejected, rather than trapping the player.
	var invalid := load("res://scenes/world/cave/layouts/branching.tscn").instantiate() as CaveDungeonLayout
	add_child(invalid)
	var disabled_zone := CaveSpawnZone.new()
	disabled_zone.position = Vector2(-1000, -1000)
	disabled_zone.spawn_weight = 0.0
	invalid.add_child(disabled_zone)
	check(invalid.prepare(cave), "disabled zones may be parked outside the layout")
	var prop := StaticBody2D.new()
	prop.position = Vector2(104, 200)
	var collider := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(12, 12)
	collider.shape = box
	prop.add_child(collider)
	invalid.add_child(prop)
	check(invalid.prepare(cave) and not invalid.walkable.has(Vector2i(6, 12)), "solid editor props update connectivity and navigation")
	(invalid.get_node("GroundTiles") as TileMapLayer).set_cell(Vector2i(38, 22), 0, Vector2i(4, 4))
	check(not invalid.prepare(cave) and invalid.error_message.contains("terputus"), "disconnected editor island is rejected")
	var broken := PackedScene.new()
	check(broken.pack(invalid) == OK, "invalid template can be validated during floor build")
	var initial_band := CaveManager.DATA.band_for(1)
	var initial_pool := initial_band.dungeon_scenes.duplicate()
	initial_band.dungeon_scenes = [broken]
	cave.build_floor(1)
	check(cave.dungeon_layout == null and cave.get_node("BaseLayerGround").visible, "all-invalid pool falls back to playable legacy floor")
	initial_band.dungeon_scenes.assign(initial_pool)
	invalid.queue_free()
	# Zone edits change gameplay without changing generator code.
	var band := CaveManager.DATA.band_for(41)
	var original := band.dungeon_scenes.duplicate()
	var authored := original[0].instantiate() as CaveDungeonLayout
	var ore_zone: CaveSpawnZone
	for zone in authored.zones():
		if zone.kind == CaveSpawnZone.Kind.ORE:
			ore_zone = zone
			break
	(authored.get_node("Arrival") as Marker2D).position.x -= 16
	ore_zone.item_ids = PackedStringArray(["gold_ore"])
	ore_zone.minimum_count = 3
	ore_zone.maximum_count = 3
	ore_zone.position += Vector2(16, 0)
	var custom := PackedScene.new()
	check(custom.pack(authored) == OK, "edited zones pack as a normal scene")
	var edited_name := ore_zone.name
	authored.free()
	band.dungeon_scenes = [custom]
	cave.build_floor(41)
	cave._place_players()
	var player: Player = cave.get_node("Player/CharacterBody2D")
	check(player.global_position == cave.dungeon_layout.marker_position(cave.dungeon_layout.arrival_path), "arrival follows edited dungeon marker")
	var matching := 0
	for node in cave.get_node("FloorContent").get_children():
		if node is Choppable and node.get_meta("spawn_zone") == edited_name:
			matching += 1
			check(node.drop_item_id == "gold_ore", "Inspector whitelist controls ore kind")
	check(matching == 3, "Inspector min/max controls ore pocket size")
	band.dungeon_scenes.assign(original)
	cave.build_floor(10)
	check(cave.dungeon_layout == null and cave.find_child("CaveLake", true, false) != null, "special lake floor remains available")
	cave.build_floor(60)
	check(cave.arena != null and cave.dungeon_layout == null, "boss arena remains separate")
	cave.build_floor(0)
	check(cave.get_node("BaseLayerGround").visible and cave.has_node("Lobby"), "lobby visuals and interactions return")
	cave.queue_free()
	await get_tree().create_timer(4.0).timeout
	print("DUNGEON LAYOUT REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)

func _flood(walkable: Dictionary, start: Vector2i, solid: Dictionary) -> Dictionary:
	var reached: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + dir
			if walkable.has(next) and not solid.has(next) and not reached.has(next):
				reached[next] = true
				queue.append(next)
	return reached

func _snapshot(cave: Node2D) -> Array:
	var result: Array = [cave.dungeon_layout.scene_file_path]
	for node in cave.get_node("FloorContent").get_children():
		if node is Choppable:
			result.append([node.drop_item_id, node.get_meta("cave_cell")])
		elif node is Enemy:
			node.ai_enabled = false
			result.append([str(node.data.id), node.home])
	return result
