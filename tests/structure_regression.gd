extends Node

var failures := 0
var player: Player
var farm: Node2D

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _record(item: String, cell: Vector2i) -> Dictionary:
	var uid := StructureManager._next_uid
	StructureManager._next_uid += 1
	var record := {"uid": uid, "item": item, "cell": [cell.x, cell.y], "storage": [], "open": false, "job": {}, "ready": {}}
	StructureManager.records.append(record)
	return record

func click(button: Button) -> void:
	await get_tree().process_frame
	var ancestor: Node = button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(button)
		ancestor = ancestor.get_parent()
	await get_tree().process_frame
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	check(get_viewport().gui_get_hovered_control() == button, "Storage button receives mouse input")
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame

func install(id: String) -> Dictionary:
	player.data.add_item(id, 1)
	var slot := -1
	for i in player.data.bag_size:
		if player.data.inventory[i] != null and player.data.inventory[i]["item"].item_id == id:
			slot = i
	for candidate in player.base_layer_ground.get_used_cells():
		var tile := player.base_layer_ground.get_cell_tile_data(candidate)
		if tile == null or not tile.get_custom_data("farmable"):
			continue
		player.global_position = player.base_layer_ground.to_global(player.base_layer_ground.map_to_local(candidate + Vector2i.LEFT)) - Player.FEET_OFFSET
		await get_tree().physics_frame
		if StructureManager.place(player, slot, candidate).ok:
			return StructureManager.records[-1]
	return {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	FarmManager.farm_data.clear()
	farm = load("res://scenes/world/farm.tscn").instantiate()
	get_tree().root.add_child(farm)
	get_tree().current_scene = farm
	await get_tree().physics_frame
	await get_tree().physics_frame
	for node in farm.find_children("*", "CharacterBody2D", true, false):
		if node is Player:
			player = node
			break
	check(player != null, "Farm player is available")
	if player == null:
		get_tree().quit(1)
		return
	DayCycle.is_running = false
	player.data.bag_level = 1
	var ground := player.base_layer_ground
	var placed := false
	var placed_uid := 0
	var cell := Vector2i.ZERO
	player.data.add_item("wooden_chest", 1)
	var slot := player.data.find_empty_slot() - 1
	for i in player.data.bag_size:
		if player.data.inventory[i] != null and player.data.inventory[i]["item"].item_id == "wooden_chest":
			slot = i
	# Try ground cells with the real physics checks; stop at the first usable plot.
	for candidate in ground.get_used_cells():
		if placed:
			break
		var tile := ground.get_cell_tile_data(candidate)
		if tile == null or not tile.get_custom_data("farmable"):
			continue
		player.global_position = ground.to_global(ground.map_to_local(candidate + Vector2i(0, 2))) - Player.FEET_OFFSET
		await get_tree().physics_frame
		var result := StructureManager.place(player, slot, candidate)
		if result.ok:
			placed = true
			cell = candidate
			placed_uid = StructureManager.records[0].uid
	check(placed and not player.data.has_item("wooden_chest"), "Placement consumes one crafted object on valid farm ground")
	if not placed:
		get_tree().quit(1)
		return
	player.data.add_item("wooden_chest", 1)
	var before := player.data.serialize_inventory()
	check(not StructureManager.place(player, slot, cell).ok and player.data.serialize_inventory() == before, "Overlapping placement never consumes another object")
	FarmManager.bind_world(farm)
	check(not FarmManager.hoe(cell), "Installed structures protect their footprint from tilling")
	player.data.add_item("wood", 20)
	var wood_slot := -1
	for i in player.data.bag_size:
		if player.data.inventory[i] != null and player.data.inventory[i]["item"].item_id == "wood":
			wood_slot = i
	check(StructureManager.transfer(player.data, placed_uid, wood_slot, true).ok and player.data.get_item_count("wood") == 0, "Chest deposit moves the player's stack into storage")
	var chest_record := StructureManager.record_for(placed_uid)
	check(StructureManager.storage(chest_record).get_item_count("wood") == 20, "Chest holds deposited materials")
	check(not StructureManager.pack(player.data, placed_uid).ok, "Non-empty chest cannot be packed and lose its contents")
	player.global_position = ground.to_global(ground.map_to_local(cell + Vector2i.DOWN)) - Player.FEET_OFFSET
	player.facing_direction = Vector2.UP
	check(StructureManager.interact_near(player), "Nearby chest opens through the player's interaction path")
	await get_tree().process_frame
	var menu = StructureManager._menus[player.data.index]
	check(menu.visible and get_tree().paused and not player.ui_inventory.visible, "Chest menu pauses solo without opening inventory over it")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://scratch/menu_wooden_chest.png")
	var withdraw: Button = menu.get_node("%ChestSlots").get_child(int(chest_record.storage[0].slot))
	await click(withdraw)
	check(player.data.get_item_count("wood") == 20, "Chest UI withdraw button moves the real stored stack")
	for button in menu.get_node("%BagSlots").get_children():
		var entry: Variant = player.data.inventory[int(button.get_meta("slot"))]
		if entry != null and entry.item.item_id == "wood":
			await click(button)
			break
	check(player.data.get_item_count("wood") == 0 and StructureManager.storage(chest_record).get_item_count("wood") == 20, "Chest UI deposit button stores the real stack")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	get_viewport().push_input(esc, true)
	await get_tree().process_frame
	check(not get_tree().paused and not player.ui_inventory.visible, "Esc closes storage without opening another menu")
	var other := PlayerData.new(1)
	var chest_slot: int = chest_record.storage[0].slot
	check(StructureManager.transfer(other, placed_uid, chest_slot, false).ok and other.get_item_count("wood") == 20 and player.data.get_item_count("wood") == 0, "Other co-op players withdraw into their own bag")
	var chest := StructureManager.storage(chest_record)
	for i in chest.bag_size:
		chest.inventory[i] = {"item": GameState._resolve_item("stone"), "count": 99}
	chest_record.storage = chest.serialize_inventory()
	player.data.add_item("wood", 5)
	before = player.data.serialize_inventory()
	check(not StructureManager.transfer(player.data, placed_uid, wood_slot, true).ok and player.data.serialize_inventory() == before, "Full chest preserves the source stack")
	chest_record.storage = [{"slot": 0, "id": "wood", "count": 7}]
	var furnace := await install("furnace")
	check(not furnace.is_empty(), "Two-by-two furnace can be placed with real terrain and collision checks")
	if furnace.is_empty():
		get_tree().quit(1)
		return
	var recipe: FurnaceRecipe = load("res://resources/furnace/furnace_copper.tres")
	player.data.add_item("copper_ore", recipe.input_amount)
	check(StructureManager.smelt(player.data, furnace.uid, recipe).ok and not player.data.has_item("copper_ore"), "Furnace consumes ore and starts a persisted job")
	check(not StructureManager.pack(player.data, furnace.uid).ok, "Working furnace cannot be packed")
	var gate := _record("wooden_gate", cell + Vector2i(8, 0))
	StructureManager.toggle_gate(gate.uid)
	check(gate.open, "Gate can be opened")
	check(SaveManager.save_game(), "Building positions, chest contents and furnace jobs save")
	StructureManager.reset()
	check(SaveManager.load_game() and StructureManager.records.size() == 3, "Structures restore through actual JSON save/load")
	var loaded_chest := StructureManager.records[0]
	var loaded_furnace := StructureManager.records[1]
	check(StructureManager.storage(loaded_chest).get_item_count("wood") == 7, "Chest contents survive game save/load")
	check(StructureManager.records[2].open and not loaded_furnace.job.is_empty(), "Gate state and furnace progress survive game save/load")
	DayCycle.is_running = true
	StructureManager._process(recipe.process_time + 1)
	DayCycle.is_running = false
	check(loaded_furnace.job.is_empty() and loaded_furnace.ready.id == "copper_bar", "Furnace completion retains its output for collection")
	var full := PlayerData.new(2)
	for i in full.bag_size:
		full.inventory[i] = {"item": GameState._resolve_item("stone"), "count": 99}
	check(not StructureManager.collect(full, loaded_furnace.uid).ok and not loaded_furnace.ready.is_empty(), "Full bag cannot lose the furnace output")
	check(StructureManager.collect(other, loaded_furnace.uid).ok and other.has_item("copper_bar") and loaded_furnace.ready.is_empty(), "Furnace output goes to the interacting co-op player's bag")
	check(StructureManager.pack(other, loaded_furnace.uid).ok and other.has_item("furnace"), "Empty furnace can be packed back into inventory")
	var bench := await install("crafting_workbench")
	check(not bench.is_empty(), "Two-by-one workbench can be installed")
	player.facing_direction = Vector2.RIGHT
	check(StructureManager.interact_near(player), "Workbench interaction opens its menu")
	await get_tree().process_frame
	menu = StructureManager._menus[player.data.index]
	var open_crafting: Button = menu._content.get_child(0)
	await click(open_crafting)
	check(player.ui_inventory.visible and player.ui_inventory._crafting_panel.visible, "Workbench opens the inventory crafting page")
	player.ui_inventory._close()
	check(StructureManager.pack(player.data, bench.uid).ok and player.data.has_item("crafting_workbench"), "Workbench can be returned to the bag")
	var jar := await install("preserves_jar")
	check(not jar.is_empty(), "Two-by-two preserves jar can be installed on farm")
	var strawberry_recipe: PreservesJarRecipe = load("res://resources/preserves_jar/preserves_strawberry.tres")
	player.data.add_item("strawberry", strawberry_recipe.input_amount)
	check(StructureManager.preserve(player.data, jar.uid, strawberry_recipe).ok and not player.data.has_item("strawberry"), "Preserves jar consumes crop and starts processing job")
	check(not StructureManager.pack(player.data, jar.uid).ok, "Working preserves jar cannot be packed")
	DayCycle.is_running = true
	StructureManager._process(strawberry_recipe.process_time + 1)
	DayCycle.is_running = false
	check(jar.job.is_empty() and jar.ready.id == "strawberry_jam", "Preserves jar completes into artisan jam")
	check(StructureManager.collect(player.data, jar.uid).ok and player.data.has_item("strawberry_jam") and jar.ready.is_empty(), "Player collects artisan jam from preserves jar")
	var jam_item := GameState._resolve_item("strawberry_jam")
	var strawberry_item := GameState._resolve_item("strawberry")
	check(jam_item != null and jam_item.sell_price > strawberry_item.sell_price, "Artisan product has higher sell value than raw crop for expanded economy")
	check(StructureManager.pack(player.data, jar.uid).ok and player.data.has_item("preserves_jar"), "Empty preserves jar can be packed back to inventory")
	await test_chest_tiers()
	await test_item_gestures()
	StructureManager.reset()
	StructureManager.load_save([{"item": "wooden_chest", "cell": ["invalid", 1]}])
	check(StructureManager.records.is_empty(), "Malformed placement records are rejected")
	get_tree().current_scene = self
	farm.queue_free()
	await get_tree().process_frame
	print("STRUCTURE REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)

func test_chest_tiers() -> void:
	StructureManager.reset()
	player.data.load_inventory([])
	var record := await install("wooden_chest")
	check(not record.is_empty(), "Chest tier fixture can be installed on farm")
	if record.is_empty():
		return
	record.storage = [{"slot": 23, "id": "stone", "count": 99}]
	var previous := StructureManager.to_save()
	var bag := player.data.serialize_inventory()
	check(not StructureManager.upgrade_chest(player.data, record.uid).ok and previous == StructureManager.to_save() and bag == player.data.serialize_inventory(), "Missing upgrade materials leave both chest and bag unchanged")
	for id in StructureManager.CHESTS.slice(1):
		var recipe := StructureManager.next_chest_recipe(record.uid)
		player.data.load_inventory([])
		for material in recipe.ingredients:
			player.data.add_item_silent(material, recipe.ingredients[material])
		for slot in player.data.bag_size:
			if player.data.inventory[slot] == null:
				player.data.inventory[slot] = {"item": GameState._resolve_item("fiber"), "count": 99}
		check(StructureManager.upgrade_chest(player.data, record.uid).ok and record.item == id, "In-place upgrade works without an empty bag slot: " + id)
		var chest := StructureManager.storage(record)
		var capacity: int = GameState._resolve_item(id).storage_slots
		check(chest.bag_size == capacity and chest.inventory.size() == capacity and chest.inventory[23]["count"] == 99, "Upgrade preserves old contents and expands usable capacity: " + id)
		var filled := chest.serialize_inventory()
		for slot in chest.bag_size:
			chest.inventory[slot] = {"item": GameState._resolve_item("stone"), "count": 99}
		record.storage = chest.serialize_inventory()
		player.data.inventory[0] = {"item": GameState._resolve_item("wood"), "count": 8}
		bag = player.data.serialize_inventory()
		check(not StructureManager.transfer(player.data, record.uid, 0, true).ok and bag == player.data.serialize_inventory(), "Full chest tier refuses deposit without item loss: " + id)
		record.storage = filled
		chest = StructureManager.storage(record)
		chest.inventory[capacity - 1] = {"item": GameState._resolve_item("wood"), "count": 7}
		record.storage = chest.serialize_inventory()
		var other := PlayerData.new(1)
		check(StructureManager.transfer(other, record.uid, capacity - 1, false).ok and other.get_item_count("wood") == 7, "Co-op can withdraw from the highest tier slot: " + id)
	check(not StructureManager.upgrade_chest(player.data, record.uid).ok and StructureManager.next_chest_recipe(record.uid) == null, "Shadow chest is the final tier")
	check(player.data.bag_size == 24 and player.data.inventory.size() == 36, "Chest capacities do not change player bag limits")
	StructureManager.reset()
	for i in StructureManager.CHESTS.size():
		var saved := _record(StructureManager.CHESTS[i], Vector2i(300 + i * 2, 300))
		var capacity := StructureManager.chest_capacity(saved)
		saved.storage = [{"slot": capacity - 1, "id": "gold_bar", "count": 3}, {"slot": capacity, "id": "wood", "count": 8}]
	check(SaveManager.save_game(), "All chest tiers save through the real save manager")
	StructureManager.reset()
	check(SaveManager.load_game() and StructureManager.records.size() == StructureManager.CHESTS.size(), "All chest tiers restore from JSON")
	for saved in StructureManager.records:
		var chest := StructureManager.storage(saved)
		check(chest.inventory[chest.bag_size - 1] != null and chest.get_item_count("gold_bar") == 3 and chest.get_item_count("wood") == 0, "Save load retains high slots and rejects slots beyond tier capacity: " + saved.item)
	StructureManager.reset()
	player.data.load_inventory([])
	record = await install("wooden_chest")
	record.storage = [{"slot": 23, "id": "stone", "count": 4}]
	player.data.add_item_silent("wood", 30)
	player.data.add_item_silent("copper_bar", 5)
	player.facing_direction = Vector2.RIGHT
	check(StructureManager.interact_near(player), "Tier upgrade menu opens by interaction")
	await get_tree().process_frame
	var menu = StructureManager._menus[player.data.index]
	var upgrade: Button = menu.get_node("%Upgrade")
	await click(upgrade)
	check(record.item == "copper_chest" and menu.get_node("%ChestTitle").text.contains("36 slot") and StructureManager.storage(record).get_item_count("stone") == 4, "Upgrade button refreshes tier header and preserves contents")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://scratch/menu_copper_chest.png")
	menu._close()
	await get_tree().process_frame
	check(not StructureManager.pack(player.data, record.uid).ok, "Tiered nonempty chest cannot be packed")
	record.storage = []
	check(StructureManager.pack(player.data, record.uid).ok and player.data.has_item("copper_chest"), "Packing returns the actual upgraded tier")
	var golden := await install("gold_chest")
	check(not golden.is_empty() and StructureManager.chest_capacity(golden) == 60, "Crafted gold chest can be placed directly")
	check(player.animation_controller.item_gesture_playing and String(player.animation_controller.sprite.animation).begins_with("item_drop_"), "Successful building placement starts the character item drop pose")

func test_item_gestures() -> void:
	await get_tree().create_timer(1.2).timeout
	player.data.load_inventory([])
	player.data.inventory[0] = {"item": GameState._resolve_item("wood"), "count": 2}
	player.data.hotbar_page = 0
	player.tool_controller.current_index = 0
	var event := InputEventAction.new()
	event.action = &"use_tool"
	event.pressed = true
	player.tool_controller._unhandled_input(event)
	check(player.data.get_item_count("wood") == 1 and player.animation_controller.item_gesture_playing, "Hotbar action drops exactly one material and starts the item drop pose")
	var dropped: ItemPickup
	for node in farm.find_children("*", "Area2D", true, false):
		if node is ItemPickup and node.item_id == "wood" and node._ignore_body == player:
			dropped = node
	check(dropped != null and dropped.amount == 1, "Hotbar material remains recoverable on the ground")
	await get_tree().create_timer(1.2).timeout
	if dropped != null:
		dropped._ignore_body = null
		dropped._can_collect = true
		dropped._on_body_entered(player)
		check(player.data.get_item_count("wood") == 2 and String(player.animation_controller.sprite.animation).begins_with("pick_up_"), "Ground pickup returns the material and starts the pickup pose")
		check(is_instance_valid(player._pickup_visual) and player._pickup_visual.get_parent() == player and player._pickup_visual.texture == dropped._raw_icon and player._pickup_visual.texture != dropped._icon, "Collected item uses the raw icon while the dropped world item keeps its outline")
		check(held_icon_count() == 1, "Auto-selecting a picked item creates only one held icon")
		var frames := player.animation_controller.sprite.sprite_frames
		var anim := player.animation_controller.sprite.animation
		var duration := frames.get_frame_count(anim) / frames.get_animation_speed(anim)
		await get_tree().create_timer(duration * 0.55).timeout
		check(is_instance_valid(player._pickup_visual) and player._pickup_visual.position.y < -3.0, "Pickup icon follows the hands as they rise")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://scratch/pickup_held_item.png")
	await get_tree().create_timer(1.2).timeout
	check(is_instance_valid(player._pickup_visual) and player.animation_controller.carrying_item and String(player.animation_controller.sprite.animation).begins_with("carry_idle_"), "Collected item stays held overhead while idle after pickup completes")
	check(is_equal_approx(player._pickup_visual.position.y + float(player._pickup_visual.get_meta("visible_height")) * 0.5, -6.0), "Visible bottom of the held icon rests on raised hands despite texture padding")
	for action in [&"walk", &"run", &"idle"]:
		player.animation_controller.play(action)
		check(String(player.animation_controller.sprite.animation).begins_with("carry_" + String(action) + "_") and is_instance_valid(player._pickup_visual), "Held icon and carrying pose persist during " + String(action))
	player.data.inventory[1] = {"item": GameState._resolve_item("stone"), "count": 1}
	player.tool_controller.select_tool(1)
	check(held_icon_count() == 1 and player._pickup_visual.texture == GameState._resolve_item("stone").icon and player._carried_item_id.is_empty(), "Scrolling after pickup replaces the held item with exactly one preview")
	player.data.inventory[2] = {"item": GameState._resolve_item("axe_wood"), "count": 1}
	await get_tree().create_timer(0.35).timeout
	player.tool_controller.select_tool(2)
	await get_tree().create_timer(0.35).timeout
	player.tool_controller.select_tool(1)
	await get_tree().create_timer(0.2).timeout
	check(held_icon_count() == 1 and player._pickup_visual.texture == GameState._resolve_item("stone").icon, "Old preview timers cannot clear a newer preview after scrolling A-B-A")
	await get_tree().create_timer(0.65).timeout
	check(held_icon_count() == 0 and not player.animation_controller.carrying_item, "Latest preview expires and restores normal pose")
	player.tool_controller.select_tool(1)
	player.tool_controller.select_tool(3)
	check(held_icon_count() == 0 and not player.animation_controller.carrying_item, "Selecting an empty hotbar slot immediately clears the previous icon")
	for slot in player.data.bag_size:
		player.data.inventory[slot] = {"item": GameState._resolve_item("stone"), "count": 99}
	var pickup := ItemPickup.spawn(farm, player.global_position + Vector2(100, 0), "wood", 1)
	pickup._can_collect = true
	pickup._on_body_entered(player)
	check(not player.animation_controller.item_gesture_playing and pickup.amount == 1 and not pickup.is_queued_for_deletion(), "Full bag refuses pickup without a success animation or lost ground item")
	pickup.queue_free()
	check(not StructureManager.place(player, -1, Vector2i.ZERO).ok and not player.animation_controller.item_gesture_playing, "Failed placement does not play a drop gesture")

func held_icon_count() -> int:
	var count := 0
	for child in player.get_children():
		if child is Sprite2D and str(child.name).begins_with("HeldPickupItem"):
			count += 1
	return count
