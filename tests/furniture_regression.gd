extends Node

var failures := 0

func check(value: bool, label: String) -> void:
	print(("PASS: " if value else "FAIL: ") + label)
	if not value:
		failures += 1

func _ready() -> void:
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	StructureManager.reset()
	FarmManager.farm_data.clear()
	var seat_scene = load("res://scenes/world/exterior/object/seat.tscn")
	var seat = seat_scene.instantiate()
	add_child(seat)
	for direction in range(4):
		seat.facing = direction
		var pose = seat.definition.pose_for(direction)
		check(seat.region_rect == pose.region and seat.seat_point.position == pose.seat_position, "Inspector preset applies direction %d" % direction)
		check(seat.solid.get_node("CollisionShape2D").shape.size == pose.collision_size, "Direction collider %d" % direction)
	seat.facing = 0
	seat.rotate_seat()
	check(seat.facing == 3, "Chair rotates clockwise without rotating the sprite")
	seat.definition = load("res://resources/furniture/wooden_bench.tres")
	seat.facing = 0
	seat.rotate_seat()
	check(seat.facing == 1, "Bench skips unsupported sideways artwork")
	seat.queue_free()
	# Small deterministic farm surface: use real Player/StructureManager without
	# random farm cleanup spawns or existing saves affecting placement results.
	var farm := Node2D.new()
	farm.y_sort_enabled = true
	var ground := TileMapLayer.new()
	ground.name = "BaseLayerGround"
	ground.z_index = -1
	ground.tile_set = TileSet.new()
	ground.tile_set.add_custom_data_layer()
	ground.tile_set.set_custom_data_layer_name(0, "farmable")
	ground.tile_set.set_custom_data_layer_type(0, TYPE_BOOL)
	var atlas := TileSetAtlasSource.new()
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.FOREST_GREEN)
	atlas.texture = ImageTexture.create_from_image(image)
	ground.tile_set.add_source(atlas, 0)
	atlas.create_tile(Vector2i.ZERO)
	atlas.get_tile_data(Vector2i.ZERO, 0).set_custom_data("farmable", true)
	farm.add_child(ground)
	for x in range(8):
		for y in range(8):
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	var embedded = load("res://scenes/player/Player.tscn").instantiate()
	farm.add_child(embedded)
	get_tree().root.add_child(farm)
	get_tree().current_scene = farm
	StructureManager.attach(farm)
	await get_tree().physics_frame
	await get_tree().physics_frame
	DayCycle.is_running = false
	var player = farm.get_node("Player/CharacterBody2D")
	player.data.inventory.fill(null)
	player.data.add_item("wood", 40)
	for recipe in CraftingSystem.CATALOG.recipes:
		if recipe.output_item_id in StructureManager.FURNITURE:
			check(CraftingSystem.craft(player.data, recipe).ok, "Furniture can be crafted: " + recipe.output_item_id)
	var slot := -1
	for i in player.data.bag_size:
		if player.data.inventory[i] != null and player.data.inventory[i]["item"].item_id == "wooden_chair":
			slot = i
	player.tool_controller.current_index = slot
	player.data.add_item("wooden_chair", 1)
	await get_tree().process_frame
	await get_tree().process_frame
	var preview = player.tool_controller.furniture_preview
	var turn := InputEventKey.new()
	turn.pressed = true
	turn.physical_keycode = KEY_R
	var bag_before := JSON.stringify(player.data.serialize_inventory())
	get_viewport().push_input(turn, true)
	await get_tree().process_frame
	check(preview.facing == 2 and preview.find_children("*", "CollisionObject2D", true, false).is_empty(), "R rotates a collision-free placement preview")
	check(JSON.stringify(player.data.serialize_inventory()) == bag_before, "R rotates before hotbar sort can consume the event")
	var placed := false
	var placement_failure := ""
	for cell in player.base_layer_ground.get_used_cells():
		var tile = player.base_layer_ground.get_cell_tile_data(cell)
		if tile == null or not tile.get_custom_data("farmable") or FarmManager.farm_data.has(cell):
			continue
		player.global_position = player.base_layer_ground.to_global(player.base_layer_ground.map_to_local(cell + Vector2i.DOWN * 2)) - Player.FEET_OFFSET
		await get_tree().physics_frame
		await get_tree().physics_frame
		var placement := StructureManager.place(player, slot, cell, 3)
		placement_failure = placement.message
		if placement.ok:
			placed = true
			break
	check(placed, "Place chair from inventory on valid farm ground: " + placement_failure)
	if placed:
		await get_tree().physics_frame
		check(not preview.can_place() and not preview.visible and player.data.get_item_count("wooden_chair") == 1, "Placement closes preview even when chairs remain in the stack")
		var record: Dictionary = StructureManager.records[-1]
		var placed_seat = StructureManager.furniture_node(farm, int(record.uid))
		check(placed_seat != null and placed_seat.facing == 3, "Placed seat uses selected direction")
		placed_seat.rotate_seat()
		placed_seat.facing = 0
		check(placed_seat.facing == 3, "Installed chair cannot rotate until picked up")
		var saved: Array = JSON.parse_string(JSON.stringify(StructureManager.to_save()))
		StructureManager.load_save(saved)
		check(int(StructureManager.records[-1].facing) == 3, "Save/load retains direction")
		var invalid := saved.duplicate(true)
		invalid[-1].facing = 99
		StructureManager.load_save(invalid)
		check(StructureManager.records.is_empty(), "Reject invalid saved direction")
		StructureManager.load_save(saved)
		placed_seat = StructureManager.furniture_node(farm, int(record.uid))
		player.global_position = placed_seat.global_position + Vector2(0, 20)
		placed_seat.interact(player)
		while player.sit_transitioning:
			await get_tree().physics_frame
		check(player.seated_chair == placed_seat and str(player.animation_controller.sprite.animation) == "sit_right", "Placed chair supports sitting")
		var seated_position: Vector2 = player.global_position
		var seated_direction: Vector2 = player.facing_direction
		for action in ["move_up", "move_down", "move_left", "move_right"]:
			Input.action_press(action)
			player.update_facing_direction(Vector2.UP)
			player.get_target_cell()
			await get_tree().physics_frame
			await get_tree().physics_frame
			Input.action_release(action)
		check(player.global_position.is_equal_approx(seated_position) and player.facing_direction == seated_direction and str(player.animation_controller.sprite.animation) == "sit_right", "WASD and mouse aim cannot move or rotate the seated player")
		check(placed_seat.facing == 3, "Seated input cannot change the chair direction")
		check(not StructureManager.pickup_furniture(player, int(record.uid)).ok, "Occupied seat cannot be picked up")
		player.stand_up()
		while player.sit_transitioning:
			await get_tree().physics_frame
		check(StructureManager.pickup_furniture(player, int(record.uid)).ok, "Pick up empty chair")
		check(StructureManager.records.is_empty() and player.data.get_item_count("wooden_chair") == 2, "Pickup removes record and returns inventory item")
		player.tool_controller.select_tool(slot, false)
		await get_tree().process_frame
		check(preview.can_place(), "Explicit hotbar selection starts a new placement")
	print("FURNITURE REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
