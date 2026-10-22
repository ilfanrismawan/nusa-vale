extends Node

var failures := 0

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.current_day = 1
	DayCycle.is_running = false
	FarmManager.farm_data.clear()
	var world := Node2D.new()
	world.name = "ChickenTestFarm"
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	var ground := TileMapLayer.new()
	ground.name = "BaseLayerGround"
	var tiles := TileSet.new()
	tiles.add_custom_data_layer()
	tiles.set_custom_data_layer_name(0, "farmable")
	tiles.set_custom_data_layer_type(0, TYPE_BOOL)
	var atlas := TileSetAtlasSource.new()
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color("78a44f"))
	atlas.texture = ImageTexture.create_from_image(image)
	atlas.create_tile(Vector2i.ZERO)
	tiles.add_source(atlas, 0)
	atlas.get_tile_data(Vector2i.ZERO, 0).set_custom_data("farmable", true)
	ground.tile_set = tiles
	world.add_child(ground)
	for x in 15:
		for y in 10:
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	StructureManager.attach(world)
	var rig := (load("res://scenes/player/Player.tscn") as PackedScene).instantiate()
	world.add_child(rig)
	var player := rig.get_node("CharacterBody2D") as Player
	player.set_process(false)
	player.set_physics_process(false)
	# Kayu 100 memerlukan dua stack (batas 99); siapkan ruang untuk bahan
	# konstruksi di samping seluruh alat dan bibit starter.
	player.data.bag_level = 1
	player.data.add_item_silent("wood", 100)
	player.data.add_item_silent("stone", 50)
	GameState.money = 2000
	player.global_position = ground.map_to_local(Vector2i(2, 3)) - Player.FEET_OFFSET
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Kandang sekarang dibangun lewat layanan Wira, bukan resep tas lama.
	check(StructureManager.check_construction(player, "chicken_coop", Vector2i(3, 3)).ok, "real coop footprint accepts clear farm ground")
	var result := StructureManager.commit_construction(player, "chicken_coop", Vector2i(3, 3), false)
	check(result.ok and GameState.money == 0 and player.data.get_item_count("wood") == 0 and player.data.get_item_count("stone") == 0, "coop construction consumes its quoted money and materials exactly once")
	if StructureManager.records.is_empty():
		get_tree().quit(1)
		return
	var uid := int(StructureManager.records[0].uid)
	var state := StructureManager.coop_state(StructureManager.record_for(uid))
	check(StructureManager.occupies(Vector2i(7, 5)) and not StructureManager.occupies(Vector2i(8, 5)), "coop reserves its complete 5x3 footprint")
	var shop := load("res://resources/shop/general_store.tres") as ShopData
	check(shop.stock.has(GameState._resolve_item("animal_feed")), "feed available in general store")
	GameState.money = 0
	check(not StructureManager.buy_chicken(uid, "Ayu").ok and state.chickens.is_empty(), "unaffordable chicken purchase changes nothing")
	GameState.money = 4000
	check(StructureManager.buy_chicken(uid, "Ayu", "white").ok and StructureManager.buy_chicken(uid, "Budi", "brown").ok and GameState.money == 2400, "adult white and brown chickens bought into the selected coop")
	check(not StructureManager.pack(player.data, uid).ok, "occupied coop cannot be packed or lose animals")
	check(not StructureManager.feed_chickens(player.data, uid).ok, "missing feed does not mark chickens fed")
	check(player.data.buy_item("animal_feed", 2) and GameState.money == 2380, "feed purchase costs 10 G per portion")
	check(StructureManager.feed_chickens(player.data, uid).ok and player.data.get_item_count("animal_feed") == 0, "one feed per hungry chicken consumed")
	check(not StructureManager.feed_chickens(player.data, uid).ok, "feeding cannot charge or reward twice per day")
	check(StructureManager.pet_chicken(uid, 1).ok and not StructureManager.pet_chicken(uid, 1).ok and int(state.chickens[0].affection) == 3, "petting grants affection only once daily")
	check(int(state.eggs) == 0 and not StructureManager.collect_eggs(player.data, uid).ok, "no egg available before the next day")
	check(SaveManager.save_game() and SaveManager.load_game(), "coop and animals survive disk save/load")
	state = StructureManager.coop_state(StructureManager.record_for(uid))
	check(state.chickens.size() == 2 and str(state.chickens[0].name) == "Ayu" and int(state.chickens[1].fed_day) == 1 and int(state.chickens[0].pet_day) == 1, "names, variants, feeding and petting persist")
	DayCycle.advance_day()
	check(int(state.eggs) == 2 and int(state.chickens[0].affection) == 5, "fed chickens produce exactly one egg each at dawn")
	StructureManager._advance_chickens(DayCycle.current_day)
	check(int(state.eggs) == 2, "repeated daily update cannot duplicate eggs")
	check(SaveManager.save_game() and SaveManager.load_game(), "uncollected eggs persist")
	state = StructureManager.coop_state(StructureManager.record_for(uid))
	StructureManager._advance_chickens(DayCycle.current_day)
	check(int(state.eggs) == 2, "reload cannot replay daily egg production")
	DayCycle.advance_day()
	check(int(state.eggs) == 2 and state.chickens.size() == 2 and int(state.chickens[0].affection) == 2, "unfed day gives no eggs; chickens remain alive")
	for i in player.data.bag_size:
		player.data.inventory[i] = {"item": GameState._resolve_item("stone"), "count": 99}
	check(not StructureManager.collect_eggs(player.data, uid).ok and int(state.eggs) == 2, "full bag keeps all eggs safely in coop")
	player.data.inventory[0] = {"item": GameState._resolve_item("chicken_egg"), "count": 98}
	check(StructureManager.collect_eggs(player.data, uid).ok and player.data.get_item_count("chicken_egg") == 99 and int(state.eggs) == 1, "partial collection retains the egg that does not fit")
	player.data.inventory[1] = null
	check(StructureManager.collect_eggs(player.data, uid).ok and int(state.eggs) == 0, "remaining egg collected after freeing space")
	check(not StructureManager.collect_eggs(player.data, uid).ok, "collected eggs cannot be claimed twice")
	var second := GameState.ensure_player(1)
	second.add_item_silent("animal_feed", 2)
	check(StructureManager.feed_chickens(second, uid).ok and second.get_item_count("animal_feed") == 0 and player.data.get_item_count("animal_feed") == 0, "co-op feed comes from the interacting player's bag")
	for i in 2:
		check(StructureManager.buy_chicken(uid).ok, "remaining coop slot can be purchased")
	var money := GameState.money
	check(not StructureManager.buy_chicken(uid).ok and GameState.money == money and state.chickens.size() == 4, "capacity enforced without charging for a fifth chicken")
	var invalid := SaveManager._build_save_data()
	invalid.structures[0].livestock.chickens[0].fed_day = -1
	check(not SaveManager._is_valid_save(invalid), "corrupt livestock state is rejected before altering the world")
	var menu = load("res://scripts/ui/chicken_coop_menu.gd").new()
	menu.player = player
	menu.uid = uid
	rig.add_child(menu)
	await get_tree().process_frame
	check(menu._title.text.contains("4/4") and menu._content.find_child("BuyChicken", true, false) == null, "care UI shows occupied slots and no longer sells animals")
	check(menu._content.find_child("FeedingProgress", true, false).value == 2, "feeding meter reflects only chickens fed today")
	menu._close()
	PauseManager.set_requested(false)
	get_tree().current_scene = self
	world.queue_free()
	await get_tree().process_frame
	GameState.new_game()
	check(StructureManager.records.is_empty(), "new game clears all livestock and buildings")
	print("CHICKEN REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
