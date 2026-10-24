extends Node

var failures := 0
const RANCH := "res://scenes/world/eep_ranch.tscn"
const HOME := "res://scenes/world/interior/eep_home.tscn"

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func walk(actor: VillageNPC) -> bool:
	var stalled := 0
	for step in 12000:
		if not actor._is_walking:
			actor._physics_process(1.0 / 60.0)
			return actor.global_position.distance_to(actor._target_pos) <= 3.0
		var before := actor.global_position
		actor._physics_process(1.0 / 60.0)
		stalled = stalled + 1 if before.distance_to(actor.global_position) < 0.01 else 0
		if stalled > 320:
			print("BLOCKED EEP ", actor.global_position, " -> ", actor._target_pos)
			return false
	return false

func cross(actor: Player, area: Area2D) -> void:
	actor.global_position = area.get_node("CollisionShape2D").global_position - Player.FEET_OFFSET
	await get_tree().physics_frame
	await get_tree().physics_frame
	var deadline := Time.get_ticks_msec() + 15000
	await get_tree().create_timer(1.4, true).timeout
	while (Transition.on_transition or (is_instance_valid(actor) and actor.is_input_locked())) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

func clear_spawn(world: Node2D, position: Vector2) -> bool:
	var shape := CircleShape2D.new()
	shape.radius = 5
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, position + Player.FEET_OFFSET)
	query.collision_mask = 1
	query.collide_with_areas = false
	var hits := world.get_world_2d().direct_space_state.intersect_shape(query)
	for hit: Dictionary in hits:
		if not hit.collider is Player:
			print("SPAWN BLOCKER ", hit.collider.get_path())
			return false
	return true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.hour = 7
	DayCycle.minute = 0
	DayCycle.current_day = 1
	GameState.weather.current = "sunny"
	var exterior: Node2D = load(RANCH).instantiate()
	exterior.get_node("Player").free()
	add_child(exterior)
	DayCycle.is_running = false
	var presenter := exterior.get_node("NPCMapPresenter")
	presenter.set_process(false)
	var eep: VillageNPC = presenter.actors.eep
	eep.set_physics_process(false)
	await get_tree().physics_frame
	check(exterior.get_node("NorthToFarm").scene_target.ends_with("farm.tscn") and exterior.get_node("WestToTown").scene_target.ends_with("town.tscn"), "north leads to Farm and west leads to Town")
	check(exterior.get_node("Scenery/EepRanchHouse/Door").target_scene == HOME, "ranch building opens Eep home and shop")
	check(exterior.get_node("PondWater").get_used_cells().size() > 200 and exterior.get_node("Scenery/PastureFence").get_child_count() > 40, "authored pond and fenced pasture present")
	check(clear_spawn(exterior, Vector2(608,64)) and clear_spawn(exterior, Vector2(48,320)) and clear_spawn(exterior, Vector2(816,288)), "ranch entrance and home return spawns are clear")
	check(walk(eep), "Eep walks from home doorway to morning feeding point")
	DayCycle.hour = 9
	presenter.refresh()
	check(presenter.departures.has("eep") and walk(eep), "Eep leaves pasture through home door to open shop")
	presenter._process(0)
	check(not presenter.actors.has("eep"), "exterior Eep removed only after doorway arrival")
	exterior.queue_free()
	await get_tree().process_frame
	# Physical routes inside: counter, lunch, evening room and bed.
	DayCycle.hour = 9
	var home: Node2D = load(HOME).instantiate()
	home.get_node("Player").free()
	add_child(home)
	DayCycle.is_running = false
	presenter = home.get_node("NPCMapPresenter")
	presenter.set_process(false)
	eep = presenter.actors.eep
	eep.set_physics_process(false)
	await get_tree().physics_frame
	check(walk(eep) and eep._service_available(), "Eep reaches shop counter at 09:00")
	for hour in [12,13]:
		DayCycle.hour = hour
		presenter.refresh()
		check(walk(eep), "Eep interior route at " + str(hour))
	GameState.weather.current = "rain"
	for hour in [17,22,7,9]:
		DayCycle.hour = hour
		presenter.refresh()
		check(walk(eep), "sheltered evening, sleep and morning route at " + str(hour))
	check(clear_spawn(home,Vector2(320,384)), "interior entry spawn clear")
	home.queue_free()
	await get_tree().process_frame
	# Real solo boundary transitions, including house door and return.
	GameState.weather.current = "sunny"
	DayCycle.hour = 10
	var farm: Node2D = load("res://scenes/world/farm.tscn").instantiate()
	get_tree().root.add_child(farm)
	get_tree().current_scene = farm
	await get_tree().create_timer(0.8,true).timeout
	check(clear_spawn(farm,Vector2(992,928)), "Farm south return spawn is clear")
	var farm_corridor_clear := true
	for y in range(928,977,8):
		farm_corridor_clear = clear_spawn(farm,Vector2(992,y)) and farm_corridor_clear
	check(farm_corridor_clear, "Farm south corridor reaches ranch trigger without crossing cliff blockers")
	var actor: Player = farm.get_node("Player/CharacterBody2D")
	await cross(actor,farm.get_node("EnterEepRanch"))
	var world: Node2D = get_tree().current_scene
	check(world.scene_file_path == RANCH, "solo Farm south boundary enters ranch north")
	actor = world.get_node("Player/CharacterBody2D")
	world.get_node("Scenery/EepRanchHouse/Door").interact(actor)
	await get_tree().create_timer(1.5,true).timeout
	world = get_tree().current_scene
	check(world.scene_file_path == HOME, "solo ranch door enters actual house/shop")
	actor = world.get_node("Player/CharacterBody2D")
	await cross(actor,world.get_node("ExitDoor"))
	world = get_tree().current_scene
	check(world.scene_file_path == RANCH, "house exit returns to ranch doorway")
	actor = world.get_node("Player/CharacterBody2D")
	await cross(actor,world.get_node("WestToTown"))
	world = get_tree().current_scene
	check(world.scene_file_path.ends_with("town.tscn"), "west ranch exit reaches Town")
	check(clear_spawn(world,Vector2(1184,640)), "Town return spawn clear")
	var town_corridor_clear := true
	for x in range(1184,1297,8):
		town_corridor_clear = clear_spawn(world,Vector2(x,640)) and town_corridor_clear
	check(town_corridor_clear, "Town east corridor reaches ranch trigger")
	actor = world.get_node("Player/CharacterBody2D")
	await cross(actor,world.get_node("RanchEntrance"))
	world = get_tree().current_scene
	check(world.scene_file_path == RANCH, "Town east gate returns to ranch west")
	actor = world.get_node("Player/CharacterBody2D")
	await cross(actor,world.get_node("NorthToFarm"))
	world = get_tree().current_scene
	check(world.scene_file_path.ends_with("farm.tscn"), "ranch north exit returns to Farm")
	get_tree().current_scene = null
	world.queue_free()
	await get_tree().process_frame
	Coop.start([PlayerInput.DEVICE_KEYBOARD,PlayerInput.DEVICE_NUMPAD])
	await get_tree().create_timer(1.0,true).timeout
	actor = Coop.root.body_of(1)
	await cross(actor,actor.world_root().get_node("EnterEepRanch"))
	check(actor.world_root().scene_file_path == RANCH and Coop.root.body_of(0).world_root().scene_file_path.ends_with("farm.tscn"), "co-op ranch boundary moves only crossing player")
	await cross(actor,actor.world_root().get_node("WestToTown"))
	check(actor.world_root().scene_file_path.ends_with("town.tscn") and not actor.is_input_locked(), "co-op ranch to Town releases crossing player control")
	print("EEP RANCH COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
