extends Node

var failures := 0

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func wait_for_planner(parent: Node) -> CanvasLayer:
	for i in 100:
		await get_tree().create_timer(0.05, true).timeout
		for child in parent.get_children():
			if child.get_script() == load("res://scripts/ui/building_placement_ui.gd"):
				return child
	return null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	get_tree().current_scene = null
	await get_tree().process_frame
	seed(20261015)
	GameState.new_game()
	DayCycle.is_running = false
	var town = load("res://scenes/world/town.tscn").instantiate()
	get_tree().root.add_child(town)
	get_tree().current_scene = town
	await get_tree().process_frame
	var player: Player = town.get_node("Player/CharacterBody2D")
	player.global_position = Vector2(935, 447)
	var origin := player.global_position
	var npc = town.get_node("NPCMapPresenter").actors["damar"]
	npc.interact(player)
	npc._choose_service(1, player)
	check(is_instance_valid(npc._service_menu), "town carpenter opens building service")
	npc._service_menu._choose("barn")
	await get_tree().create_timer(1.3, true).timeout
	var farm := get_tree().current_scene
	var planner := await wait_for_planner(farm)
	check(planner != null and farm.scene_file_path == BuildingPlacement.FARM, "carpenter opens actual farm map for solo placement")
	if planner != null:
		planner.close()
	await get_tree().create_timer(1.3, true).timeout
	town = get_tree().current_scene
	player = town.get_node("Player/CharacterBody2D")
	check(town.scene_file_path == "res://scenes/world/town.tscn" and player.global_position.distance_to(origin) < 1 and not get_tree().paused, "cancel returns to carpenter position without leaving game paused")
	get_tree().current_scene = null
	town.queue_free()
	await get_tree().process_frame
	Coop.start([PlayerInput.DEVICE_KEYBOARD, PlayerInput.DEVICE_NUMPAD])
	await get_tree().create_timer(1.0, true).timeout
	player = Coop.root.body_of(1)
	Coop.root.move_player(player, "res://scenes/world/town.tscn", origin)
	await get_tree().create_timer(1.0, true).timeout
	town = player.world_root()
	npc = town.get_node("NPCMapPresenter").actors["damar"]
	npc.interact(player)
	npc._choose_service(1, player)
	npc._service_menu._choose("chicken_coop")
	planner = await wait_for_planner(Coop.root.view_of(1))
	check(planner != null and Coop.root.body_of(0).world_root() == player.world_root(), "co-op carpenter opens planner only in purchasing player's viewport")
	if planner != null:
		planner.close()
	await get_tree().create_timer(1.0, true).timeout
	check(player.world_root().scene_file_path == "res://scenes/world/town.tscn" and player.global_position.distance_to(origin) < 1 and Coop.root.body_of(0).world_root().scene_file_path == BuildingPlacement.FARM and not get_tree().paused, "co-op cancellation returns buyer while other player stays at farm")
	var farmer: Player = Coop.root.body_of(0)
	StructureManager.open_ranch_menu(farmer, -1)
	check(not StructureManager.has_menu(farmer.data.index), "missing ranch ID cannot open an invalid care menu")
	farmer.data.bag_level = 2
	farmer.data.add_item_silent("chicken_coop", 1)
	check(farmer.data.has_item("chicken_coop"), "construction fixture has its crafted coop in the active bag")
	var location := Vector2i.ZERO
	var found := false
	# Spawned resources can obstruct the old hard-coded rectangle. Search real farm terrain.
	for candidate in farmer.base_layer_ground.get_used_cells():
		if StructureManager.check_construction(farmer, "chicken_coop", candidate).ok:
			location = candidate
			found = true
			break
	var construction := StructureManager.commit_construction(farmer, "chicken_coop", location, true) if found else {"ok": false, "message": "No empty footprint found in search area"}
	check(found and construction.ok, "co-op constructs a shared coop on the actual farm: " + str(construction.message))
	if not construction.ok:
		print("CARPENTER REGRESSION COMPLETE: failures=%d" % failures)
		get_tree().quit(1)
		return
	farmer.global_position = farmer.base_layer_ground.to_global(farmer.base_layer_ground.map_to_local(location + Vector2i(2, 3))) - Player.FEET_OFFSET
	farmer.facing_direction = Vector2.UP
	check(StructureManager.interact_near(farmer), "co-op farmer can enter the coop from its entrance")
	await get_tree().create_timer(1.3, true).timeout
	check(farmer.world_root().scene_file_path.ends_with("coop_interior.tscn"), "coop entrance transitions to its interior")
	StructureManager.open_ranch_menu(farmer, int(farmer.world_root().get_meta("ranch_uid", 0)))
	var menu = StructureManager._menus[0]
	await get_tree().process_frame
	await get_tree().process_frame
	var menu_bounds: Rect2 = menu._panel.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, menu._panel.size)
	check(menu.get_parent() == Coop.root.view_of(0) and Coop.root.view_of(0).get_visible_rect().grow(0.01).encloses(menu_bounds), "coop menu renders at a bounded size in the interacting player's displayed viewport")
	menu._close()
	await get_tree().process_frame
	StructureManager.leave_ranch(farmer)
	await get_tree().create_timer(1.3, true).timeout
	check(farmer.world_root().scene_file_path == BuildingPlacement.FARM, "coop exit returns to the farm")
	farmer.data.add_item_silent("barn", 1)
	BuildingPlacement.begin(farmer, "barn", true)
	planner = await wait_for_planner(Coop.root.view_of(0))
	var preview_world: Vector2 = farmer.base_layer_ground.to_global(farmer.base_layer_ground.map_to_local(location)) + Vector2(40, 24) + planner._ghost.picture.position
	planner._camera.global_position = preview_world
	planner._camera.zoom = Vector2.ONE * 1.2
	planner._clamp_camera()
	var pointer: Vector2 = Coop.root.view_of(0).get_canvas_transform() * preview_world
	planner._target_mouse(pointer)
	var preview_screen: Vector2 = Coop.root.view_of(0).get_canvas_transform() * (planner._ghost.global_position + planner._ghost.picture.position)
	check(planner.cell == location and preview_screen.distance_to(pointer) < 0.1, "co-op mouse and even-sized barn preview align in the purchasing viewport")
	var motion := InputEventMouseMotion.new()
	motion.position = pointer
	planner._input(motion)
	for frame in 3:
		await get_tree().process_frame
	check(planner.cell == location, "co-op preview keeps the mouse-event position across rendered frames")
	var inverse: Transform2D = Coop.root.view_of(0).get_canvas_transform().affine_inverse()
	var shown := Rect2(inverse * Vector2.ZERO, inverse * Coop.root.view_of(0).get_visible_rect().size - inverse * Vector2.ZERO)
	check(planner._camera_bounds.grow(0.01).encloses(shown), "co-op placement camera keeps the displayed viewport within farm limits")
	var cancel := InputEventMouseButton.new()
	cancel.button_index = MOUSE_BUTTON_RIGHT
	cancel.pressed = true
	planner._input(cancel)
	check(planner._closed and farmer.data.has_item("barn") and not get_tree().paused, "co-op right click cancels placement without consuming the building")
	print("CARPENTER REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
