extends Node

var failures := 0

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _ready() -> void:
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	DayCycle.is_running = false
	GameState.new_game()
	_test_economy()
	_test_character()
	await _test_trees()
	print("GAMEPLAY REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)

func _test_economy() -> void:
	var data := GameState.p1()
	var money := GameState.money
	var seeds := data.get_item_count("seed_carrot")
	check(not data.buy_item("seed_carrot", -2) and GameState.money == money and data.get_item_count("seed_carrot") == seeds, "negative purchase cannot create money")
	check(not data.buy_item("seed_carrot", 0) and GameState.money == money, "zero purchase is rejected")
	check(not data.remove_item("seed_carrot", -2) and data.get_item_count("seed_carrot") == seeds, "negative removal cannot create items")
	check(not data.remove_item("seed_carrot", 0), "zero removal is rejected")
	check(not GameState.spend_money(-10) and GameState.money == money, "negative spending cannot create money")
	check(data.buy_item("seed_carrot", 1) and data.get_item_count("seed_carrot") == seeds + 1 and GameState.money == money - 25, "normal purchase charges correct price")
	var crop := GameState._resolve_item("carrot")
	for i in data.inventory.size():
		data.inventory[i] = null
	data.inventory[0] = {"item": crop, "count": 2}
	data.inventory[20] = {"item": crop, "count": 3}
	var bin := ShippingBin.new()
	add_child(bin)
	money = GameState.money
	bin.sell_harvested_items()
	check(data.inventory[0] == null and data.inventory[20].count == 3 and GameState.money == money + 2 * crop.sell_price, "shipping sells active slots and preserves locked slots")
	money = GameState.money
	bin.sell_harvested_items()
	check(GameState.money == money and data.inventory[20].count == 3, "repeated shipping cannot pay for locked items")
	data.bag_level = 1
	bin.sell_harvested_items()
	check(data.inventory[20] == null and GameState.money == money + 3 * crop.sell_price, "unlocked items sell exactly once")
	bin.queue_free()

func _test_character() -> void:
	var catalog := load("res://resources/character/character_catalog.tres") as CharacterCatalog
	var look := catalog.sanitize(CharacterAppearance.new())
	check(look.eye_color == "black" and look.hair_color == "black" and look.outfit_color == "blue", "sanitizer preserves default colors used by assets")
	var valid_paths := true
	for sheet in catalog.sheets:
		var paths := CharacterSpriteBuilder._layer_paths(sheet, catalog, look, 0)
		var clothes := false
		var hair := false
		for path in paths:
			clothes = clothes or path.contains("/Clothers/")
			hair = hair or path.contains("/Hair's/") or path.contains("/Hair/")
		# Sleep intentionally has no outfit/hair directories.
		if DirAccess.dir_exists_absolute(sheet.part_folder.path_join("Clothers/Farm")):
			valid_paths = valid_paths and clothes
		if DirAccess.dir_exists_absolute(sheet.part_folder.path_join("Hair's/Josh")) or DirAccess.dir_exists_absolute(sheet.part_folder.path_join("Hair/Josh")):
			valid_paths = valid_paths and hair
	check(valid_paths, "all available default clothing and hair layers resolve")
	look.hair_color = ""
	look.outfit_color = ""
	look = catalog.sanitize(look)
	check(not look.hair_color.is_empty() and not look.outfit_color.is_empty(), "empty saved colors receive usable defaults")
	var all_colors_valid := true
	for part in catalog.parts:
		if part.asset.contains("{color}") and not part.has_colors():
			var colors := catalog._asset_colors(part)
			all_colors_valid = all_colors_valid and not colors.is_empty() and catalog._valid_color(part.id, "invalid_saved_color") in colors
	check(all_colors_valid, "hidden color choices recover a real asset color for every part")

func _test_trees() -> void:
	ForageManager.reset()
	DayCycle.current_day = 10
	ForageManager.add_item("audit#tree", Vector2i.ZERO, "pine|small|1")
	var world := Node2D.new()
	add_child(world)
	var ground := TileMapLayer.new()
	ground.tile_set = TileSet.new()
	ground.tile_set.tile_size = Vector2i(16, 16)
	ground.name = "BaseLayerGround"
	world.add_child(ground)
	var spawner := TreeSpawner.new()
	spawner.location_id = "audit"
	spawner.max_active = 1
	world.add_child(spawner)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	check(ForageManager.get_items("audit#tree")["0,0"] == "pine|big|1" and spawner._nodes.has("0,0"), "returning to area restores a mature tree after absent days")
	var foreign_view := SubViewport.new()
	foreign_view.world_2d = World2D.new()
	add_child(foreign_view)
	var foreign_body := Node2D.new()
	foreign_view.add_child(foreign_body)
	foreign_body.global_position = ground.map_to_local(Vector2i(10, 10))
	foreign_body.add_to_group("choppable")
	foreign_body.add_to_group("player")
	check(spawner._cell_allowed(Vector2i(10, 10)), "co-op entities in another world do not block tree spawning")
	var local_body := Node2D.new()
	world.add_child(local_body)
	local_body.global_position = foreign_body.global_position
	local_body.add_to_group("choppable")
	check(not spawner._cell_allowed(Vector2i(10, 10)), "local trees still enforce minimum spacing")
	world.queue_free()
	foreign_view.queue_free()
	await get_tree().process_frame
