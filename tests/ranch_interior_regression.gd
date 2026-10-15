extends Node

var failures := 0

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func record(uid: int, item: String, cell: Vector2i) -> Dictionary:
	return {"uid": uid, "item": item, "cell": [cell.x, cell.y], "storage": [], "open": false, "job": {}, "ready": {}}

func settle() -> void:
	await get_tree().create_timer(1.5, true).timeout

func capture(name: String) -> void:
	if OS.get_cmdline_user_args().has("--capture-ranch-interior"):
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://scratch")
		get_viewport().get_texture().get_image().save_png("res://scratch/" + name)

func prepare() -> void:
	GameState.new_game()
	DayCycle.current_day = 1
	DayCycle.hour = 6
	GameState.money = 100000
	StructureManager.records.assign([record(7, "barn", Vector2i(44, 18)), record(19, "chicken_coop", Vector2i(56, 18)), record(31, "barn", Vector2i(44, 25))])
	StructureManager._next_uid = 32
	StructureManager.buy_animal(7, "cow", "Sari")
	StructureManager.buy_animal(7, "goat", "Kiki")
	StructureManager.buy_animal(7, "sheep", "Bulu")
	StructureManager.buy_chicken(19, "Ayu")
	StructureManager.buy_animal(19, "duck", "Duki")
	StructureManager.buy_animal(31, "cow", "Lain")
	for id in [7, 19, 31]:
		StructureManager.coop_state(StructureManager.record_for(id)).hay = 20
	GameState.p1().bag_level = 2
	GameState.p1().add_item_silent("milk_pail", 1)
	GameState.p1().add_item_silent("shears", 1)
	GameState.p1().add_item_silent("animal_brush", 1)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	prepare()
	var farm: Node2D = (load("res://scenes/world/farm.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(farm)
	get_tree().current_scene = farm
	await settle()
	var player: Player = farm.get_node("Player/CharacterBody2D")
	check(StructureManager.enter_ranch(player, 7).ok, "solo entry accepts constructed barn")
	await settle()
	var room := get_tree().current_scene
	check(room.scene_file_path.ends_with("barn_interior.tscn") and room.ranch_uid == 7, "solo door transition loads correct barn interior")
	if not room.has_method("interact_ranch_near"):
		get_tree().quit(1)
		return
	player = room.get_node("Player/CharacterBody2D")
	player.set_physics_process(false)
	check(room.get_node("Animals").get_child_count() == 3, "interior shows this barn's three saved animals")
	check(player.base_layer_ground == room.get_node("BaseLayerGround"), "player binds non-farmable interior ground")
	player.global_position = Vector2(427, 203) - Player.FEET_OFFSET
	check(player._try_interact(), "normal player interact reaches physical feeding trough")
	var state := StructureManager.coop_state(StructureManager.record_for(7))
	check(state.hay == 17 and state.chickens[0].fed_day == DayCycle.current_day, "trough uses actual shared feed stock")
	player.global_position = room.pen_center(0) - Player.FEET_OFFSET
	check(player._try_interact() and state.chickens[0].pet_day == DayCycle.current_day, "physical animal interaction pets saved cow")
	var carried_animal: Node2D = room.get_node("Animals/Animal_1")
	var inventory_before := player.data.serialize_inventory()
	var affection_before := int(state.chickens[0].affection)
	carried_animal.lift_with(player)
	check(player.has_meta("carried_animal") and carried_animal._sprite.z_as_relative == false, "lift renders animal above character without changing herd ownership")
	StructureManager._sync_all()
	player.global_position += Vector2(0, 10)
	carried_animal._physics_process(0.1)
	check(carried_animal.global_position == player.global_position + Vector2(0, -22), "held animal follows player after shared-state refresh")
	check(player._try_interact() and not player.has_meta("carried_animal") and carried_animal.collision_mask == 1, "interaction drops carried animal and restores collision")
	check(player.data.serialize_inventory() == inventory_before and state.chickens[0].affection == affection_before, "lifting/dropping consumes no inventory and does not trigger care")
	carried_animal.lift_with(player)
	player.release_carried_animal()
	check(not player.has_meta("carried_animal") and room.get_node("Animals").get_child_count() == 3, "travel release keeps original herd without duplicate actors")
	await settle()
	carried_animal.home = room.pen_center(0)
	carried_animal.global_position = carried_animal.home
	carried_animal.roam_rect = Rect2(carried_animal.home - Vector2(10, 6), Vector2(20, 12))
	state.dirt = 2
	StructureManager._sync_all()
	player.global_position = Vector2(393, 225) - Player.FEET_OFFSET
	check(player._try_interact() and state.dirt == 1, "physical dirt spot cleans shared barn state")
	check(not StructureManager.pack(player.data, 7).ok, "occupied interior cannot be packed")
	state.chickens[0].ready = "cow_milk"
	StructureManager._sync_all()
	player.global_position = room.pen_center(0) - Player.FEET_OFFSET
	check(player._try_interact() and player.data.get_item_count("cow_milk") == 1, "milk can be harvested inside with the existing tool")
	check(SaveManager.save_game() and SaveManager.load_game() and StructureManager.record_for(7).item == "barn" and room.ranch_uid == 7, "save/load retains non-contiguous building identity while inside")
	player.global_position = Vector2(427, 320)
	await capture("barn-interior.png")
	player.set_physics_process(true)
	player.global_position = Vector2(427, 342)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await settle()
	check(get_tree().current_scene.scene_file_path.ends_with("world/farm.tscn"), "walking onto interior exit automatically returns to farm")
	player = get_tree().current_scene.get_node("Player/CharacterBody2D")
	check(player.global_position.distance_to(StructureManager._ranch_returns[0]) < 4, "exit appears outside the same constructed barn")
	StructureManager.enter_ranch(player, 19)
	await settle()
	room = get_tree().current_scene
	check(room.scene_file_path.ends_with("coop_interior.tscn") and room.ranch_uid == 19 and room.get_node("Animals").get_child_count() == 2, "coop has its own two birds and nesting layout")
	player = room.get_node("Player/CharacterBody2D")
	player.set_physics_process(false)
	var birds := StructureManager.coop_state(StructureManager.record_for(19))
	birds.eggs = 2
	StructureManager._sync_all()
	player.global_position = Vector2(499, 185) - Player.FEET_OFFSET
	check(player._try_interact() and player.data.get_item_count("chicken_egg") == 2, "nest station collects saved eggs inside")
	player.global_position = Vector2(427, 320)
	await capture("coop-interior.png")
	get_tree().current_scene = self
	room.queue_free()
	await settle()
	PauseManager.set_requested(false)
	prepare()
	# Keep this runner outside the current scene when co-op replaces that scene.
	get_tree().current_scene = null
	Coop.start([PlayerInput.DEVICE_KEYBOARD, PlayerInput.DEVICE_NUMPAD])
	await settle()
	var first: Player = Coop.root.body_of(0)
	var second: Player = Coop.root.body_of(1)
	StructureManager.enter_ranch(first, 7)
	await settle()
	check(first.world_root().get_meta("ranch_uid", 0) == 7 and second.world_root().scene_file_path.ends_with("farm.tscn"), "P1 enters barn while P2 remains on farm")
	StructureManager.enter_ranch(second, 31)
	await settle()
	check(second.world_root().get_meta("ranch_uid", 0) == 31 and first.get_world_2d() != second.get_world_2d(), "two barns have separate simultaneous co-op worlds")
	var empty_room := StructureManager.coop_state(StructureManager.record_for(31))
	empty_room.chickens.clear()
	empty_room.next_id = 1
	empty_room.hay = 0
	second.data.bag_level = 2
	StructureManager._sync_all()
	check(not StructureManager.pack(second.data, 31).ok, "even an empty barn cannot be packed while P2 is inside")
	StructureManager.leave_ranch(second)
	await settle()
	StructureManager.enter_ranch(second, 7)
	await settle()
	check(first.get_world_2d() == second.get_world_2d(), "players entering same barn share its interior")
	StructureManager.leave_ranch(first)
	await settle()
	check(first.world_root().scene_file_path.ends_with("farm.tscn") and second.world_root().get_meta("ranch_uid", 0) == 7, "one player's exit preserves the other's interior")
	Coop.stop()
	await settle()
	for voice in Juice._voices:
		voice.stop()
		voice.stream = null
	print("RANCH INTERIOR REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
