extends Node
var failures := 0

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: " + label)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	var data := GameState.p1()
	var tools := (load("res://resources/cooking/data/cooking_catalog.tres") as CookingCatalog).equipment
	for recipe in CookingManager.all_recipes():
		check(recipe.is_valid_recipe(), "recipe resource is complete: " + recipe.id)
	var custom := RecipeData.new()
	custom.id = "editor_test_recipe"
	custom.display_name = "Editor Test"
	custom.ingredients = {"carrot": 1}
	custom.output_item = GameState._resolve_item("fried_egg")
	custom.output_count = 2
	CookingManager._recipes[custom.id] = custom
	var custom_data := PlayerData.new(-1)
	custom_data.add_item_silent("carrot", 1)
	check(CookingManager.cook(custom_data, custom.id).ok and custom_data.get_item_count("fried_egg") == 2, "editor recipe output item and quantity are respected")
	custom.book_price = 10
	custom_data.load_recipes([custom.id])
	check(CookingManager.knows(custom_data, custom.id), "new recipe IDs load from database without a hardcoded whitelist")
	custom.ingredients.clear()
	var custom_before := custom_data.serialize_inventory()
	check(not CookingManager.cook(custom_data, custom.id).ok and custom_before == custom_data.serialize_inventory(), "incomplete recipes cannot produce free food")
	CookingManager._recipes.erase(custom.id)
	data.bag_level = 2
	var before := data.serialize_inventory()
	check(not CookingManager.cook(data, "vegetable_soup", tools).ok and before == data.serialize_inventory(), "missing ingredients never consume other inventory")
	data.add_item_silent("carrot", 1)
	data.add_item_silent("cabbage", 1)
	check(CookingManager.cook(data, "vegetable_soup", tools).ok and data.get_item_count("vegetable_soup") == 1 and not data.has_item("carrot"), "cooking consumes exact ingredients and creates one food")
	GameState.money = 500
	check(CookingManager.learn(data, "fruit_salad").ok and GameState.money == 300, "recipe purchase charges once")
	check(not CookingManager.learn(data, "fruit_salad").ok and GameState.money == 300, "duplicate recipe purchase rejected")
	var second := GameState.get_player(1)
	check(not CookingManager.knows(second, "fruit_salad"), "recipes belong to the buyer in co-op")
	data.apply_food_effect(load("res://resources/cooking/effects/refreshing.tres"))
	check(SaveManager.save_game(), "cooking save")
	data.learned_recipes.clear()
	check(SaveManager.load_game() and CookingManager.knows(data, "fruit_salad"), "learned recipes survive save/load")
	check(data.active_food_effects.is_empty(), "P1 temporary food effects clear when loading a save")
	var copy := PlayerData.new(2)
	copy.load_dict(data.to_dict())
	check(CookingManager.knows(copy, "fruit_salad"), "co-op player serialization preserves recipes")
	data.load_recipes(["bogus", 10, "fruit_salad", "fruit_salad"])
	check(data.learned_recipes == ["fruit_salad"], "recipe loader rejects invalid and duplicate entries")
	var full := PlayerData.new(-1)
	full.bag_level = 0
	full.add_item_silent("carrot", 2)
	full.add_item_silent("cabbage", 2)
	for i in range(2, full.bag_size):
		full.inventory[i] = {"item": GameState._resolve_item("axe_wood"), "count": 1}
	before = full.serialize_inventory()
	check(not CookingManager.cook(full, "vegetable_soup", tools).ok and before == full.serialize_inventory(), "full bag rolls back all ingredients")
	full.inventory[0].count = 1
	check(CookingManager.cook(full, "vegetable_soup", tools).ok, "slot freed by cooking is available for output")
	var town: Node2D = load("res://scenes/world/town.tscn").instantiate()
	get_tree().root.add_child(town)
	get_tree().current_scene = town
	await get_tree().process_frame
	var player: Player = town.get_node("Player/CharacterBody2D")
	player.set_physics_process(false)
	player.global_position = Vector2(936, 416) - Player.FEET_OFFSET
	player.facing_direction = Vector2.UP
	await get_tree().physics_frame
	check(player._try_interact(), "player interaction opens actual Warung kitchen")
	var menu: Node = null
	for node in Coop.ui_parent(player).get_children():
		if node.get_script() == load("res://scripts/ui/cooking_ui.gd"):
			menu = node
	check(menu != null and get_tree().paused, "kitchen menu uses normal gameplay pause")
	if menu != null:
		menu._close()
	await get_tree().process_frame
	data = player.data
	data.stamina = 50
	var slot := -1
	for i in data.bag_size:
		if data.inventory[i] != null and data.inventory[i].item.item_id == "vegetable_soup":
			slot = i
	check(CookingManager.eat(player, slot).ok and data.stamina == 85, "eating consumes one food and restores stamina")
	data.add_item_silent("fruit_salad", 1)
	for i in data.bag_size:
		if data.inventory[i] != null and data.inventory[i].item.item_id == "fruit_salad":
			slot = i
	check(CookingManager.eat(player, slot).ok and data.stamina == data.max_stamina and data.food_movement_multiplier() > 1.0, "food clamps stamina and applies resource-based effects")
	var configurable_food := GameState._resolve_item("fruit_salad").duplicate() as ItemData
	configurable_food.food_effects = []
	configurable_food.speed_buff_multiplier = 1.4
	configurable_food.speed_buff_seconds = 23.0
	data.inventory[slot] = {"item": configurable_food, "count": 1}
	player.food_speed_remaining = 0.0
	check(CookingManager.eat(player, slot).ok and is_equal_approx(player.food_speed_multiplier, 1.4) and player.food_speed_remaining == 23.0, "food buff strength and duration come from the item resource")
	get_tree().current_scene = self
	town.queue_free()
	await get_tree().process_frame
	# Release audio playback before the headless process tears its audio server down.
	if MusicManager._fade_tween != null and MusicManager._fade_tween.is_valid():
		MusicManager._fade_tween.kill()
	for music_player in MusicManager.get_children():
		if music_player is AudioStreamPlayer:
			music_player.stop()
			music_player.stream = null
	MusicManager._stream_cache.clear()
	await get_tree().create_timer(0.1, true).timeout
	print("COOKING REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
