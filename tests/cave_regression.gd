extends Node2D

## Phase 4B-3 Gua Tambang: data lantai, lift checkpoint + save, lobi, lantai acak harian,
## tangga turun (batu / semua monster), lift, pindah lantai, dan Toko Combat.
## Tidak menulis save ke disk.

const CAVE_SCENE := "res://scenes/world/cave/cave.tscn"

var failures := 0

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _process(_delta: float) -> void:
	if get_tree().paused:
		get_tree().paused = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.current_day = 3
	_test_data()
	_test_progress()
	_test_shop()
	_test_save()
	await _test_scene()
	await _test_mountain()
	print("CAVE REGRESSION COMPLETE: failures=%d" % failures)
	await get_tree().create_timer(30.0).timeout
	get_tree().quit(1 if failures > 0 else 0)

func _test_data() -> void:
	var data := CaveManager.DATA
	check(data.max_floor == 20 and data.lift_interval == 5, "cave MVP: floors 1-20, lift every 5 floors")
	var first := data.band_for(1)
	check(first != null and first.ore_ids.has("stone") and first.ore_ids.has("coal") and first.ore_ids.has("copper_ore"), "floors 1-20 hold stone, coal, copper (GDD 9)")
	check(not data.band_for(15).ore_ids.has("iron_ore") and data.band_for(30).ore_ids.has("iron_ore"), "iron starts at floor 21")
	check(data.band_for(50).ore_ids.has("gold_ore") and data.band_for(70).ore_ids.has("frost_ore") and data.band_for(90).ore_ids.has("obsidian_ore"), "deeper bands follow the GDD ore table")
	for ore in data.ores:
		check(ore != null and GameState._resolve_item(ore.item_id) != null, "ore item exists: %s" % (ore.item_id if ore != null else "null"))
	check(data.ore("copper_ore").minimum_tool_tier == ToolData.ToolTier.WOOD and data.ore("iron_ore").minimum_tool_tier == ToolData.ToolTier.COPPER, "copper needs a wood pickaxe, iron needs copper")
	for band in data.bands:
		check(band.ore_ids.size() == band.ore_weights.size() and not band.enemies.is_empty(), "band %d-%d has weights and enemies" % [band.first_floor, band.last_floor])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := {}
	for i in 200:
		seen[first.pick_ore(rng)] = true
	check(seen.size() == 3, "weighted pick returns every ore of the band")

func _test_progress() -> void:
	var cave := GameState.cave
	cave.reset()
	check(cave.lift_floors() == [0], "new game: lift only reaches the lobby")
	check(not cave.reach(3) and cave.deepest_lift == 0 and cave.deepest_floor == 3, "floor 3 is not a checkpoint")
	check(cave.reach(5) and cave.deepest_lift == 5, "reaching floor 5 opens its lift")
	check(not cave.reach(5), "the same lift opens only once")
	cave.reach(10)
	check(cave.lift_floors() == [0, 5, 10], "lift lists lobby and each open checkpoint")
	check(cave.floor_seed(4, 3) == cave.floor_seed(4, 3) and cave.floor_seed(4, 3) != cave.floor_seed(4, 4), "layout seed is fixed for a day and changes the next day")
	check(cave.floor_seed(4, 3) != cave.floor_seed(5, 3), "every floor has its own seed")

func _test_shop() -> void:
	var shop := CaveManager.DATA.shop
	check(shop != null and shop.shop_name == "Toko Combat", "combat shop data is linked to the cave")
	var types := {}
	var priced := true
	for item in shop.stock:
		priced = priced and item != null and item.buy_price > 0
		if item != null:
			types[item.item_id.get_slice("_", 0)] = true
	check(priced and shop.stock.size() == 32, "combat shop sells 32 priced items")
	check(types.has("arrow") and types.has("sword") and types.has("bow") and types.has("staff") and types.has("armor") and types.has("boots"), "shop has arrows, weapons and armor")

func _test_save() -> void:
	var cave := GameState.cave
	cave.reset()
	cave.reach(15)
	var saved := SaveManager._build_save_data()
	check(int(SaveManager.SAVE_VERSION) >= 15 and saved.has("cave"), "save stores the cave (v%d)" % SaveManager.SAVE_VERSION)
	check(SaveManager._is_valid_save(saved), "save with cave data is valid")
	cave.reset()
	SaveManager._apply_save(saved)
	check(cave.deepest_lift == 15 and cave.deepest_floor == 15, "lift checkpoint survives save/load")
	var bad := saved.duplicate(true)
	bad["cave"] = "rusak"
	check(not SaveManager._is_valid_save(bad), "broken cave data is rejected")
	cave.load_save({"deepest_lift": 12, "deepest_floor": 99})
	check(cave.deepest_lift == 10 and cave.deepest_floor == 20, "loaded lift snaps to a checkpoint and clamps to the max floor")
	var old := saved.duplicate(true)
	old.erase("cave")
	SaveManager._apply_save(old)
	check(cave.deepest_lift == 0, "old saves without cave data start with no lift")

func _test_scene() -> void:
	GameState.cave.reset()
	GameState.cave.current_floor = 0
	var cave: Node2D = (load(CAVE_SCENE) as PackedScene).instantiate()
	add_child(cave)
	await get_tree().process_frame
	var content := cave.get_node("FloorContent")
	var player := cave.get_node("Player/CharacterBody2D") as Player
	check(cave.floor_number == 0 and content.has_node("CombatShop") and content.has_node("ExitDoor") and content.has_node("Lift") and content.has_node("StairsDown"), "lobby: shop, exit, lift and a hole to floor 1")
	check(_count(content, "enemies") == 0 and _rocks(content).is_empty(), "lobby has no rocks or monsters")
	check(cave.has_node("BaseLayerGround") and (cave.get_node("BaseLayerGround") as TileMapLayer).get_used_cells().size() == 40 * 24, "cave ground covers the room")

	cave.build_floor(1)
	await get_tree().process_frame
	var band := CaveManager.DATA.band_for(1)
	var rocks := _rocks(content)
	check(rocks.size() >= band.rock_min and rocks.size() <= band.rock_max, "floor 1 rock count follows the band (%d)" % rocks.size())
	var enemies := _count(content, "enemies")
	check(enemies >= band.enemy_min and enemies <= band.enemy_max and cave.enemies_left == enemies, "floor 1 monster count follows the band (%d)" % enemies)
	check(content.has_node("LadderUp") and not content.has_node("Lift") and cave.stairs == null, "floor 1: ladder up, no lift, stairs hidden")
	var arrival_free := true
	for rock in rocks:
		var cell: Vector2i = rock.get_meta("cave_cell")
		if cell.distance_to(Vector2i(20, 4)) < 2.0:
			arrival_free = false
	check(arrival_free, "no rock blocks the arrival point")
	var layout := _layout(content)
	cave.build_floor(1)
	await get_tree().process_frame
	check(_layout(content) == layout, "same day: floor 1 layout is the same")
	DayCycle.current_day += 1
	cave.build_floor(1)
	await get_tree().process_frame
	check(_layout(content) != layout, "next day: floor 1 layout changes")
	DayCycle.current_day -= 1

	# Semua monster kalah -> tangga turun.
	cave.build_floor(2)
	await get_tree().process_frame
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if cave.is_ancestor_of(enemy):
			enemy.take_hit(9999, player)
	await _frames(40)
	check(cave.stairs != null, "beating every monster reveals the stairs")

	# Batu terakhir dihancurkan -> tangga turun (monster dibuang dulu tanpa sinyal).
	cave.build_floor(3)
	await get_tree().process_frame
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if cave.is_ancestor_of(enemy):
			enemy.queue_free()
	cave.enemies_left = 0
	for rock in _rocks(content):
		rock.health = 1
		rock.take_hit(1, ToolData.ToolTier.OBSIDIAN)
	await _frames(90)
	check(cave.stairs != null and cave.rocks_left == 0, "breaking every rock reveals the stairs")
	var drops := 0
	for node in content.get_children():
		if node is ItemPickup:
			drops += 1
	check(drops > 0, "broken rocks drop items")

	# Tier beliung: tembaga bisa dengan kayu, besi butuh tembaga.
	var iron: Choppable = cave._spawn_rock("iron_ore", Vector2i(2, 20))
	var copper: Choppable = cave._spawn_rock("copper_ore", Vector2i(4, 20))
	var wood_pick := load("res://resources/item_data/pickaxe_wood.tres")
	check(copper.required_tool_tier() == ToolData.ToolTier.WOOD and iron.required_tool_tier() == ToolData.ToolTier.COPPER, "cave ore tool tiers")
	check(copper.drop_item_id == "copper_ore" and iron.drop_item_id == "iron_ore" and wood_pick != null, "ore rocks drop their ore")

	# Lantai checkpoint membuka lift.
	cave.build_floor(5)
	await get_tree().process_frame
	check(content.has_node("Lift") and GameState.cave.deepest_lift == 5, "floor 5 has a lift and saves the checkpoint")
	var menu = load("res://scripts/ui/cave_lift_menu.gd").new()
	menu.cave = cave
	menu.player = player
	add_child(menu)
	await get_tree().process_frame
	check(menu._floors == [0, 5, -1] and menu._buttons[1].disabled, "lift menu: lobby, floor 5 (current, disabled), close")
	menu.close_menu()

	# Lantai terdalam: tangga tidak muncul (boss sudah kalah = lantai tambang biasa; arena dites di boss_regression).
	GameState.cave.mark_boss_defeated(20)
	cave.build_floor(20)
	await get_tree().process_frame
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if cave.is_ancestor_of(enemy):
			enemy.take_hit(9999, player)
	await _frames(40)
	check(cave.stairs == null, "floor 20 has no stairs down")

	# Pindah lantai lewat tangga: pemain dipindah ke titik tiba.
	player.get_parent().global_position = Vector2(100, 300)
	await cave.go_to_floor(4)
	await _frames(5)
	check(cave.floor_number == 4 and player.global_position.distance_to(cave.arrival_position()) < 2.0, "going down rebuilds the floor and moves the player to the arrival point")
	await cave.go_to_floor(0)
	check(cave.floor_number == 0 and GameState.cave.current_floor == 0, "lift/ladder returns to the lobby")
	cave.queue_free()
	await get_tree().process_frame

func _rocks(content: Node) -> Array[Choppable]:
	var result: Array[Choppable] = []
	for node in content.get_children():
		if node is Choppable and not node.is_queued_for_deletion():
			result.append(node)
	return result

func _count(content: Node, group: StringName) -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group(group):
		if content.is_ancestor_of(node) and not node.is_queued_for_deletion():
			count += 1
	return count

func _layout(content: Node) -> Array:
	var cells: Array = []
	for rock in _rocks(content):
		cells.append([rock.get_meta("cave_cell"), rock.drop_item_id])
	cells.sort()
	return cells

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _test_mountain() -> void:
	var mountain: Node2D = (load("res://scenes/world/mountain.tscn") as PackedScene).instantiate()
	add_child(mountain)
	await get_tree().process_frame
	var mouth := mountain.get_node_or_null("CaveEntrance")
	var exit := mountain.get_node_or_null("ExitToHill")
	check(mouth is CaveEntrance and mouth.has_meta("player_interaction"), "mountain has the cave mouth")
	check(exit != null and exit.get("scene_target") == "res://scenes/world/hill.tscn", "mountain leads back to the hill")
	check(CaveManager.DATA.exit_scene == "res://scenes/world/mountain.tscn", "leaving the cave lobby goes to the mountain")
	mountain.queue_free()
	var state := (load("res://scenes/world/hill.tscn") as PackedScene).get_state()
	var linked := false
	for i in state.get_node_count():
		if state.get_node_name(i) == &"EnterMountain":
			for p in state.get_node_property_count(i):
				if state.get_node_property_name(i, p) == &"scene_target" and str(state.get_node_property_value(i, p)) == "res://scenes/world/mountain.tscn":
					linked = true
	check(linked, "hill has a path north to the mountain")
	await get_tree().process_frame
