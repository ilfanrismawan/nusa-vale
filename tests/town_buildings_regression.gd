extends Node
var failures := 0

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: " + label)

func settle() -> void:
	await get_tree().create_timer(1.2, true).timeout

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	# Pintu rumah & toko terkunci di luar jam buka (ServiceHours): uji pada Selasa pukul 10.00.
	DayCycle.current_day = 2
	DayCycle.hour = 10
	var town: Node2D = load("res://scenes/world/town.tscn").instantiate()
	get_tree().root.add_child(town)
	get_tree().current_scene = town
	await settle()
	var buildings := town.get_node("YSortEntities/Buildings")
	check(buildings.get_child_count() == 15, "town keeps all 15 existing building positions as scene instances")
	for building in buildings.get_children():
		check(building.scene_file_path.begins_with("res://scenes/world/exterior/town/"), "instanced exterior " + building.name)
		# Kios teh tidak punya interior: penjaganya berdiri di KeeperSpot.
		if building.name == "TeaStall":
			check(building.has_node("Sign") and building.has_node("KeeperSpot") and building.has_node("CollisionShape2D"), "tea stall keeps sign, keeper spot and footprint")
			continue
		check(building.has_node("Door/CollisionShape2D") and building.has_node("Sign") and building.has_node("ReturnSpawn") and (building.has_node("CollisionShape2D") or building.has_node("CollisionPolygon2D")), "door, sign, return marker and physical footprint " + building.name)
		var door := building.get_node("Door")
		check(door.get_signal_connection_list("body_entered").is_empty(), "building entry requires interaction " + building.name)
		check(ResourceLoader.exists(door.target_scene), "interior exists " + building.name)
		if not ResourceLoader.exists(door.target_scene):
			continue
		var room: Node2D = load(door.target_scene).instantiate()
		# Static prefab inspection shares a physics world with Town; prevent unrelated
		# Town players from triggering a temporary room exit at overlapping coordinates.
		var inspected_exit := room.get_node_or_null("ExitDoor") as Area2D
		if inspected_exit != null:
			inspected_exit.monitoring = false
		get_tree().root.add_child(room)
		get_tree().current_scene = room
		await get_tree().process_frame
		var exit_shape := false
		if inspected_exit != null:
			for collider in inspected_exit.get_children():
				if collider is CollisionShape2D and collider.shape != null and not collider.disabled:
					exit_shape = true
				elif collider is CollisionPolygon2D and collider.polygon.size() >= 3 and not collider.disabled:
					exit_shape = true
		check(exit_shape, "automatic exit provided " + building.name)
		if room.get_script() == load("res://scripts/world/town_interior.gd"):
			check(room.has_node("BaseLayerGround") and room.has_node("Walls"), "room floor and walls " + building.name)
		get_tree().current_scene = town
		room.queue_free()
		await get_tree().process_frame
	var player: Player = town.get_node("Player/CharacterBody2D")
	player.set_physics_process(false)
	var entry := buildings.get_node("HerbalHouse/Door")
	var expected_return: Vector2 = buildings.get_node("HerbalHouse/ReturnSpawn").global_position
	entry.interact(player)
	await settle()
	var active := get_tree().current_scene
	check(active.scene_file_path.ends_with("/town/herbal_house.tscn"), "actual interaction enters house interior")
	player = active.get_node("Player/CharacterBody2D")
	check(player.global_position.distance_to(Vector2(240, 256)) < 1, "interior entry uses configured spawn")
	player.global_position = Vector2(240, 306)
	await get_tree().physics_frame
	await settle()
	check(get_tree().current_scene.scene_file_path.ends_with("/world/town.tscn"), "walking over exit automatically returns to town")
	player = get_tree().current_scene.get_node("Player/CharacterBody2D")
	check(player.global_position.distance_to(expected_return) < 2, "exit returns outside the exact building used to enter")
	get_tree().current_scene.queue_free()
	get_tree().current_scene = self
	await get_tree().process_frame
	RoomDoor.town_returns.clear()
	var library: Node2D = load("res://scenes/world/exterior/town/library.tscn").instantiate()
	check(library.get_node("Sign").caption == "Perpustakaan" and ResourceLoader.exists(library.get_node("Door").target_scene), "library prefab is ready for placement with its own sign and interior")
	library.free()
	get_tree().current_scene = null
	Coop.start([PlayerInput.DEVICE_KEYBOARD, PlayerInput.DEVICE_NUMPAD])
	await settle()
	var first: Player = Coop.root.body_of(0)
	var second: Player = Coop.root.body_of(1)
	Coop.root.move_player(first, "res://scenes/world/town.tscn", Vector2(300, 600))
	Coop.root.move_player(second, "res://scenes/world/town.tscn", Vector2(600, 600))
	await settle()
	var shared_town := first.world_root()
	var first_return: Vector2 = shared_town.get_node("YSortEntities/Buildings/HerbalHouse/ReturnSpawn").global_position
	var second_return: Vector2 = shared_town.get_node("YSortEntities/Buildings/HouseBlue/ReturnSpawn").global_position
	shared_town.get_node("YSortEntities/Buildings/HerbalHouse/Door").interact(first)
	shared_town.get_node("YSortEntities/Buildings/HouseBlue/Door").interact(second)
	await settle()
	check(first.world_root().scene_file_path.ends_with("/herbal_house.tscn") and second.world_root().scene_file_path.ends_with("/house_blue.tscn") and first.get_world_2d() != second.get_world_2d(), "co-op players enter two independent house interiors")
	first.world_root().get_node("ExitDoor").interact(first)
	second.world_root().get_node("ExitDoor").interact(second)
	await settle()
	check(first.world_root() == second.world_root() and first.global_position.distance_to(first_return) < 2 and second.global_position.distance_to(second_return) < 2, "co-op exits restore each player's own town door spawn")
	Coop.stop()
	await settle()
	RoomDoor.town_returns.clear()
	print("TOWN BUILDINGS COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
