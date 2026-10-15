extends Node

var failures := 0
var farm: Node2D
var player: Player

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func settle() -> void:
	for frame in 6:
		await get_tree().process_frame

func capture(filename: String) -> void:
	if OS.get_cmdline_user_args().has("--capture-ranch"):
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://scratch")
		get_viewport().get_texture().get_image().save_png("res://scratch/" + filename)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.current_day = 1
	DayCycle.hour = 6
	FarmManager.farm_data.clear()
	farm = load("res://scenes/world/farm.tscn").instantiate()
	get_tree().root.add_child(farm)
	get_tree().current_scene = farm
	await get_tree().physics_frame
	await get_tree().physics_frame
	player = farm.find_child("CharacterBody2D", true, false) as Player
	if player == null:
		check(false, "farm player available")
		get_tree().quit(1)
		return
	player.set_process(false)
	player.set_physics_process(false)
	player.data.bag_level = 2
	player.data.add_item_silent("wood", 600)
	player.data.add_item_silent("stone", 400)
	player.data.add_item_silent("hay", 50)
	player.data.add_item_silent("milk_pail", 1)
	player.data.add_item_silent("animal_brush", 1)
	GameState.money = 50000
	DayCycle.is_running = false
	var ground := player.base_layer_ground
	var built := false
	for cell in ground.get_used_cells():
		if not StructureManager.check_construction(player, "barn", cell).ok:
			continue
		var grass_cell: Vector2i = cell + Vector2i(3, 6)
		var tile := ground.get_cell_tile_data(grass_cell)
		if tile == null or not tile.get_custom_data("farmable"):
			continue
		var ray := PhysicsRayQueryParameters2D.create(ground.to_global(ground.map_to_local(cell + Vector2i(3, 5))), ground.to_global(ground.map_to_local(grass_cell)), 1)
		if not player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		if StructureManager.commit_construction(player, "barn", cell, false).ok:
			built = true
			break
	check(built, "barn built through actual farm construction checks")
	if not built:
		get_tree().quit(1)
		return
	var record := StructureManager.records[0]
	var uid := int(record.uid)
	StructureManager.buy_animal(uid, "cow", "Sari")
	var state := StructureManager.coop_state(record)
	var actor: Node2D = get_tree().get_first_node_in_group(&"ranch_animal")
	check(actor != null and not actor.visible, "owned animal sprite created and stays indoors with closed door")
	var grass_cell := Vector2i(int(record.cell[0]) + 3, int(record.cell[1]) + 6)
	var grass_id := StructureManager._next_uid
	StructureManager._next_uid += 1
	StructureManager.records.append({"uid": grass_id, "item": "pasture_grass", "cell": [grass_cell.x, grass_cell.y], "storage": [], "open": false, "job": {}, "ready": {}})
	StructureManager._sync_all()
	await get_tree().physics_frame
	GameState.weather.current = "sunny"
	check(StructureManager.toggle_ranch_door(uid).ok and actor.visible, "opening door exposes walking cow in actual farm")
	player.global_position = actor.home + Vector2(0, 32) - Player.FEET_OFFSET
	var camera := player.find_child("Camera2D", true, false) as Camera2D
	if camera != null:
		camera.position_smoothing_enabled = false
		camera.reset_smoothing()
	DayCycle.is_running = true
	var deadline := Time.get_ticks_msec() + 9000
	while int(state.chickens[0].fed_day) != DayCycle.current_day and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	check(int(state.chickens[0].fed_day) == DayCycle.current_day and int(StructureManager.record_for(grass_id).get("regrow_day", 0)) == DayCycle.current_day + 2, "cow physically reaches grass and consumes one persistent portion")
	DayCycle.is_running = false
	await capture("ranch-farm.png")
	StructureManager.toggle_ranch_door(uid)
	check(not actor.visible, "closing door returns animal without deleting shared data")
	state.chickens[0].ready = "cow_milk_large_gold"
	state.chickens[0].affection = 85
	state.dirt = 2
	player.global_position = actor.home - Player.FEET_OFFSET
	player.facing_direction = Vector2.UP
	check(StructureManager.interact_near(player), "farm door enters barn interior by interaction")
	await get_tree().create_timer(1.5, true).timeout
	var active_room := get_tree().current_scene
	player = active_room.get_node("Player/CharacterBody2D") as Player
	StructureManager.open_ranch_menu(player, uid)
	await settle()
	var menu = StructureManager._menus.get(player.data.index)
	check(is_instance_valid(menu) and menu._title.text.contains("Kandang Ternak") and menu._content.find_child("CleanRanch", true, false) != null, "barn menu exposes shared care summary and cleaning")
	check(menu._panel.get_global_rect().end.x <= get_viewport().get_visible_rect().size.x + 1, "care panel fits the game viewport")
	await capture("ranch-barn-menu.png")
	menu._care("harvest", 1)
	check(player.data.get_item_count("cow_milk_large_gold") == 1 and str(state.chickens[0].ready).is_empty(), "real barn UI harvest delivers quality milk")
	menu._close()
	await settle()
	check(not get_tree().paused, "closing ranch menu restores gameplay")
	get_tree().current_scene = self
	active_room.queue_free()
	await settle()
	GameState.new_game()
	await get_tree().create_timer(1, true).timeout
	print("RANCH WORLD REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
