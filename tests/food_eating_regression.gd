extends Node
## Makan hasil panen/forage/artisan: aturan nilai (selalu di bawah barang jadinya), klik kanan
## di dunia dan di tas, efek makan (kunci input lalu lepas), stamina penuh menolak.
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
	_check_balance()

	var forest: Node2D = load("res://scenes/world/Forest.tscn").instantiate()
	get_tree().root.add_child(forest)
	await get_tree().physics_frame
	var player: Player = forest.get_node("Player/CharacterBody2D")
	var data := player.data
	player.global_position = Vector2(560, 500)
	player.facing_direction = Vector2.DOWN
	await get_tree().physics_frame

	# Klik kanan di dunia sambil memegang apel.
	data.inventory[0] = {"item": GameState._resolve_item("apple"), "count": 3}
	player.tool_controller.current_index = 0
	data.hotbar_page = 0
	data.stamina = 40
	check(FoodEating.held_edible(player) != null, "held apple counts as edible")
	player._unhandled_input(_right_click())
	for i in 3:
		await get_tree().physics_frame
	var apple: ItemData = GameState._resolve_item("apple")
	check(data.get_item_count("apple") == 2 and data.stamina == 40 + apple.stamina_restore, "right click in the world eats the held crop")
	check(FoodEating.is_eating(player) and player.is_input_locked(), "eating plays the effect and holds the player")
	check(not FoodEating.eat(player, 0).ok and data.get_item_count("apple") == 2, "a second bite waits for the current one")
	await get_tree().create_timer(2.0).timeout
	check(not FoodEating.is_eating(player) and not player.is_input_locked(), "eating effect ends and frees the player")

	# Stamina penuh: makanan mentah ditolak tanpa menghabiskan item.
	data.stamina = data.max_stamina
	check(not FoodEating.eat(player, 0).ok and data.get_item_count("apple") == 2, "full stamina refuses raw food")

	# Klik kanan di tas.
	var bag = player.ui_inventory
	bag._open()
	await get_tree().process_frame
	data.stamina = 30
	data.inventory[5] = {"item": GameState._resolve_item("cheese"), "count": 2}
	data.inventory[6] = {"item": GameState._resolve_item("wood"), "count": 5}
	bag.refresh_inventory()
	bag._on_slot_clicked(5, MOUSE_BUTTON_RIGHT)
	check(data.get_item_count("cheese") == 1 and data.stamina > 30, "right click on a bag slot eats artisan food")
	check(not bag._drop_dialog_open(), "eating from the bag does not open the drop dialog")
	await get_tree().create_timer(2.0).timeout
	bag._on_slot_clicked(6, MOUSE_BUTTON_RIGHT)
	check(bag._drop_dialog_open() and data.get_item_count("wood") == 5, "right click on non-food still opens the drop dialog")
	bag._drop_dialog.hide()
	bag._close()

	forest.queue_free()
	await get_tree().process_frame
	print("FOOD EATING REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)

func _right_click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	return event

## Setiap item mentah yang bisa dimakan bernilai di bawah semua barang jadi yang dibuat darinya.
func _check_balance() -> void:
	var products := {}
	for recipe in CookingManager.all_recipes():
		for ingredient in recipe.ingredients:
			products.get_or_add(ingredient, []).append(recipe.output_item)
	for machine in StructureManager.ARTISANS:
		for input in StructureManager.ARTISANS[machine]:
			var output := GameState._resolve_item(StructureManager.ARTISANS[machine][input])
			if output != null:
				products.get_or_add(input, []).append(output)
	var edible_raw := 0
	var too_high: Array[String] = []
	for file in DirAccess.get_files_at("res://resources/item_data"):
		if not file.ends_with(".tres"):
			continue
		var item := load("res://resources/item_data/" + file) as ItemData
		if item == null or item.category == ItemData.Category.FOOD or not item.is_edible():
			continue
		edible_raw += 1
		if item.stamina_restore > 26:
			too_high.append(item.item_id)
		for product in products.get(item.item_id, []):
			if product != null and product.is_edible() and item.stamina_restore >= product.stamina_restore:
				too_high.append("%s>=%s" % [item.item_id, product.item_id])
	check(edible_raw >= 100, "crops, forage and artisan goods are edible (%d)" % edible_raw)
	check(too_high.is_empty(), "raw food stays below every finished good made from it %s" % str(too_high))
	for id in ["wheat", "rice", "sunflower", "fish_carp", "beef", "salt", "wood", "biji_daya_forest"]:
		var item := GameState._resolve_item(id)
		check(item != null and not item.is_edible(), "%s is not edible" % id)
	check(GameState._resolve_item("omelet").is_edible(), "cooked food stays edible")
