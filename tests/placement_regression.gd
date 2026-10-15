extends Node2D

var failures := 0
func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func placement_ui() -> CanvasLayer:
	for child in get_children():
		if child is CanvasLayer and child.get_script() == load("res://scripts/ui/building_placement_ui.gd") and not child._closed:
			return child
	return null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.current_day = 1
	DayCycle.is_running = false
	FarmManager.farm_data.clear()
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
	add_child(ground)
	for x in 48:
		for y in 40:
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	StructureManager.attach(self)
	var rig := (load("res://scenes/player/Player.tscn") as PackedScene).instantiate()
	add_child(rig)
	var player := rig.get_node("CharacterBody2D") as Player
	player.set_process(false)
	player.set_physics_process(false)
	player.global_position = Vector2(24, 16)
	player.data.bag_level = 2
	player.data.add_item_silent("wood", 100)
	player.data.add_item_silent("stone", 50)
	GameState.money = 3000
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(BuildingPlacement.begin(player, "chicken_coop"), "builder opens free placement mode")
	var ui := placement_ui()
	ui.set_target_cell(Vector2i(20, 12))
	check(ui._ghost.valid and get_tree().paused, "distant valid footprint turns green and pauses gameplay")
	var original_position := player.global_position
	ui.confirm()
	check(StructureManager.records.size() == 1 and StructureManager.records[0].cell == [20, 12], "building can be placed far beyond tool range")
	check(GameState.money == 1000 and player.data.get_item_count("wood") == 0 and player.data.get_item_count("stone") == 0, "construction charges exact quoted money and materials on confirmation")
	check(not get_tree().paused and player.visible and player.global_position == original_position, "closing planner restores player, camera and pause state")
	await get_tree().process_frame
	player.global_position = ground.to_global(ground.map_to_local(Vector2i(22, 15))) - Player.FEET_OFFSET
	player.facing_direction = Vector2.UP
	check(StructureManager.closest_structure(player).get("item") == "chicken_coop", "coop door is reachable for right-click entry")
	await get_tree().process_frame
	player.global_position = original_position
	player.data.add_item_silent("chicken_coop", 1)
	BuildingPlacement.begin(player, "chicken_coop", true)
	ui = placement_ui()
	ui.set_target_cell(Vector2i(20, 12))
	check(not ui._ghost.valid, "overlapping building footprint turns red")
	ui.confirm()
	check(StructureManager.records.size() == 1 and player.data.has_item("chicken_coop") and GameState.money == 1000, "invalid confirmation consumes nothing")
	ui.close()
	await get_tree().process_frame
	check(player.data.has_item("chicken_coop"), "cancel preserves crafted building")
	BuildingPlacement.begin(player, "chicken_coop", true)
	ui = placement_ui()
	ui.set_target_cell(Vector2i(30, 12))
	ui.confirm()
	check(StructureManager.records.size() == 2 and not player.data.has_item("chicken_coop") and GameState.money == 1000, "crafted building uses free planner without charging twice")
	await get_tree().process_frame
	FarmManager.farm_data[Vector2i(35, 25)] = {"area": "farm", "state": "tilled", "crop": null, "watered": false}
	check(not StructureManager.check_construction(player, "barn", Vector2i(35, 25)).ok, "cultivated plots block construction")
	check(not StructureManager.check_construction(player, "barn", Vector2i(46, 38)).ok, "entire footprint must remain on farmable ground")
	check(not StructureManager.commit_construction(player, "barn", Vector2i(4, 25), false).ok and GameState.money == 1000, "unaffordable construction leaves resources unchanged")
	var saved_ok := SaveManager.save_game()
	var loaded_ok := SaveManager.load_game()
	check(saved_ok and loaded_ok and StructureManager.records.size() == 2 and StructureManager.records[0].cell == [20, 12], "selected building positions persist through save/load")
	GameState.money = 4000
	player.data.add_item_silent("wood", 200)
	player.data.add_item_silent("stone", 100)
	check(StructureManager.commit_construction(player, "barn", Vector2i(4, 25), false).ok and GameState.money == 1000 and StructureManager.records.size() == 3, "barn uses its own footprint and construction quote")
	player.global_position = ground.to_global(ground.map_to_local(Vector2i(7, 29))) - Player.FEET_OFFSET
	check(StructureManager.closest_structure(player).get("item") == "barn", "barn door is reachable beyond its large collision footprint")
	await get_tree().process_frame
	player.data.add_item_silent("chicken_coop", 1)
	BuildingPlacement.begin(player, "chicken_coop", true)
	ui = placement_ui()
	var mouse_cell := Vector2i(38, 32)
	for edge in [Vector2(-100000, -100000), Vector2(100000, 100000)]:
		ui._camera.global_position = edge
		ui._camera.zoom = Vector2.ONE * 0.01
		ui._clamp_camera()
		var inverse := get_viewport().get_canvas_transform().affine_inverse()
		var visible_world := Rect2(inverse * Vector2.ZERO, inverse * get_viewport().get_visible_rect().size - inverse * Vector2.ZERO)
		check(ui._camera_bounds.grow(0.01).encloses(visible_world), "placement limits pan and zoom so the full viewport stays inside rendered map")
	var picture_world: Vector2 = ground.to_global(ground.map_to_local(mouse_cell)) + Vector2(32, 16) + ui._ghost.picture.position
	ui._camera.global_position = picture_world - Vector2(70, 20)
	ui._camera.zoom = Vector2.ONE * 1.35
	ui._clamp_camera()
	var mouse_point: Vector2 = get_viewport().get_canvas_transform() * picture_world
	ui._target_mouse(mouse_point)
	var picture_screen: Vector2 = get_viewport().get_canvas_transform() * (ui._ghost.global_position + ui._ghost.picture.position)
	check(ui.cell == mouse_cell and picture_screen.distance_to(mouse_point) < 0.1, "visible building stays under mouse after camera pan and zoom")
	var motion := InputEventMouseMotion.new()
	motion.position = mouse_point
	ui._input(motion)
	for frame in 3:
		await get_tree().process_frame
	check(ui.cell == mouse_cell, "mouse-event position remains authoritative across subsequent preview frames")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = mouse_point
	# Dispatch through the viewport so GUI/input routing is covered as well.
	get_viewport().push_input(click, true)
	click.pressed = false
	get_viewport().push_input(click, true)
	check(ui._closed and StructureManager.records.size() == 4 and StructureManager.records[3].cell == [38, 32], "real left click confirms the visible building preview exactly like Enter")
	await get_tree().process_frame
	player.data.add_item_silent("barn", 1)
	BuildingPlacement.begin(player, "barn", true)
	ui = placement_ui()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	ui._camera.zoom = Vector2.ONE * 2.0
	ui._camera.global_position = ui._camera_bounds.get_center()
	ui._clamp_camera()
	var camera_before: Vector2 = ui._camera.global_position
	var drag_press := InputEventMouseButton.new()
	drag_press.button_index = MOUSE_BUTTON_LEFT
	drag_press.pressed = true
	drag_press.position = get_viewport().get_visible_rect().size * 0.5
	ui._input(drag_press)
	var drag_motion := InputEventMouseMotion.new()
	drag_motion.position = drag_press.position + Vector2(80, 0)
	drag_motion.relative = Vector2(80, 0)
	ui._input(drag_motion)
	drag_press.pressed = false
	drag_press.position = drag_motion.position
	ui._input(drag_press)
	check(not ui._closed and StructureManager.records.size() == 4 and ui._camera.global_position != camera_before, "left hold-drag pans without confirming construction")
	ui._input(click)
	check(ui._closed and player.data.has_item("barn") and StructureManager.records.size() == 4 and not get_tree().paused, "right click cancels without consuming building or leaving gameplay paused")
	await get_tree().process_frame
	BuildingPlacement.begin(player, "barn", true)
	ui = placement_ui()
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	ui._unhandled_input(escape)
	check(ui._closed and player.data.has_item("barn") and not get_tree().paused, "Escape cancels the placement safely")
	await get_tree().process_frame
	BuildingPlacement.begin(player, "barn", true)
	ui = placement_ui()
	await get_tree().process_frame
	await get_tree().process_frame
	var cancel_button: Button = ui._confirm_button.get_parent().get_child(1)
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = cancel_button.get_global_rect().get_center()
	click.pressed = true
	get_viewport().push_input(click, true)
	click.pressed = false
	get_viewport().push_input(click, true)
	check((not is_instance_valid(ui) or ui._closed) and player.data.has_item("barn") and not get_tree().paused, "world drag handler leaves placement UI buttons clickable")
	await get_tree().process_frame
	PauseManager.set_reason(&"test_planning", true)
	PauseManager.set_background(true)
	PauseManager.set_requested(false)
	PauseManager.set_background(false)
	check(get_tree().paused, "focus and menu changes cannot resume active planning")
	PauseManager.set_reason(&"test_planning", false)
	check(not get_tree().paused, "planner releases its own pause reason")
	FarmManager.clear_references()
	# Flush deferred menus, placement previews and fixture nodes before engine shutdown.
	StructureManager.reset()
	rig.queue_free()
	ground.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	for voice in Juice._voices:
		voice.stop()
		voice.stream = null
	await get_tree().create_timer(1.0, true).timeout
	print("PLACEMENT REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
