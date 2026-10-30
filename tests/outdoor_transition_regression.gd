extends Node
var failures := 0

func check(ok: bool, label: String) -> void:
	if ok: print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func cross(player: Player, door: Area2D) -> void:
	var collision := door.get_node("CollisionShape2D") as Node2D
	player.velocity = Vector2.ZERO
	player.global_position = collision.global_position - Player.FEET_OFFSET
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().create_timer(1.5, true).timeout
	# World2D sudah dapat berpindah sebelum fade co-op selesai. Pemain nyata
	# masih terkunci pada saat itu; tunggu kontrol kembali sebelum uji pintu lain.
	var deadline := Time.get_ticks_msec() + 15000
	while (Transition.on_transition or (is_instance_valid(player) and player.is_input_locked())) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	check(not Transition.on_transition and (not is_instance_valid(player) or not player.is_input_locked()), "boundary transition releases input before the next crossing")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	get_tree().current_scene = null
	await get_tree().process_frame
	GameState.new_game()
	var farm := preload("res://scenes/world/farm.tscn").instantiate()
	get_tree().root.add_child(farm)
	get_tree().current_scene = farm
	await get_tree().create_timer(1.5, true).timeout
	var player: Player = farm.get_node("Player/CharacterBody2D")
	await cross(player, farm.get_node("EnterTown"))
	var world := get_tree().current_scene
	check(world.scene_file_path.ends_with("town.tscn"), "farm to town automatically travels without interaction")
	for door in world.find_children("*", "Area2D", true, false):
		if door.get_script() == preload("res://scripts/world/exit_door_school.gd") and "/interior/" in door.target_scene:
			check(not door.body_entered.is_connected(door._on_body_entered), "town building entrance still requires interaction: " + str(door.name))
	player = world.get_node("Player/CharacterBody2D")
	var farm_exit: Area2D = world.get_node("FarmEntrance")
	check(not farm_exit.has_method("interact") and not farm_exit.is_in_group("scene_door"), "town boundary is automatic, not an interaction door")
	player.global_position = Vector2(50, 409) - Player.FEET_OFFSET
	await get_tree().physics_frame
	check(not player.test_move(player.global_transform, Vector2(-20, 0)), "town exit can be reached before the boundary wall blocks walking")
	await cross(player, world.get_node("FarmEntrance"))
	world = get_tree().current_scene
	check(world.scene_file_path.ends_with("farm.tscn"), "town to farm automatically travels without interaction")
	player = world.get_node("Player/CharacterBody2D")
	await cross(player, world.get_node("ForestEntrance/Area2D"))
	check(get_tree().current_scene == world, "locked forest still blocks automatic travel")
	# Leave the trigger before re-entering after unlock.
	player.global_position += Vector2(40, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	UnlockManager.unlock("forest")
	await cross(player, world.get_node("ForestEntrance/Area2D"))
	world = get_tree().current_scene
	check(world.scene_file_path.ends_with("Forest.tscn"), "unlocked farm to forest automatically travels")
	player = world.get_node("Player/CharacterBody2D")
	await cross(player, world.get_node("DeepForestEntrance"))
	check(get_tree().current_scene == world, "locked deep forest does not purchase access on contact")
	player.global_position += Vector2(100, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	UnlockManager.unlock("deep_forest")
	await cross(player, world.get_node("DeepForestEntrance"))
	world = get_tree().current_scene
	check(world.scene_file_path.ends_with("DeepForest.tscn"), "unlocked deep forest entry automatically travels")
	player = world.get_node("Player/CharacterBody2D")
	await cross(player, world.get_node("ReturnToForest"))
	world = get_tree().current_scene
	check(world.scene_file_path.ends_with("Forest.tscn"), "deep forest return automatically travels")
	player = world.get_node("Player/CharacterBody2D")
	await cross(player, world.get_node("ExitForest"))
	world = get_tree().current_scene
	check(world.scene_file_path.ends_with("farm.tscn"), "forest to farm automatically travels")
	player = world.get_node("Player/CharacterBody2D")
	await cross(player, world.get_node("EnterTown"))
	world = get_tree().current_scene
	player = world.get_node("Player/CharacterBody2D")
	await cross(player, world.get_node("BalaiNadiAccess"))
	world = get_tree().current_scene
	check(world.scene_file_path.ends_with("balai_nadi/balai.tscn"), "town to Balai courtyard automatically travels")
	player = world.get_node("Player/CharacterBody2D")
	await cross(player, world.get_node("ReturnTown"))
	check(get_tree().current_scene.scene_file_path.ends_with("town.tscn"), "Balai courtyard to town automatically travels")
	get_tree().current_scene.queue_free()
	get_tree().current_scene = null
	await get_tree().process_frame
	Coop.start([PlayerInput.DEVICE_KEYBOARD, PlayerInput.DEVICE_NUMPAD])
	await get_tree().create_timer(1.5, true).timeout
	player = Coop.root.body_of(1)
	await cross(player, player.world_root().get_node("EnterTown"))
	check(player.world_root().scene_file_path.ends_with("town.tscn") and Coop.root.body_of(0).world_root().scene_file_path.ends_with("farm.tscn"), "automatic co-op boundary moves only the crossing player")
	var farm_alias: String = player.world_root().get_node("FarmEntrance").scene_target
	check(Coop.root._key(farm_alias) == Coop.root._key(Coop.root.START_AREA), "UID and resource path share one co-op area key")
	check(Coop.root._key(farm_alias + "#ranch=1") != Coop.root._key(farm_alias + "#ranch=2"), "canonical scene keys keep ranch instances separate")
	await cross(player, player.world_root().get_node("FarmEntrance"))
	check(player.world_root() == Coop.root.body_of(0).world_root(), "automatic co-op return rejoins the shared farm")
	var coop_root: Node = Coop.root
	Coop.stop()
	get_tree().current_scene = null
	coop_root.queue_free()
	await get_tree().process_frame
	print("OUTDOOR TRANSITION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
