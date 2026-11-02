extends Node

const AnimalPhysics := preload("res://scripts/world/animal_physics.gd")

var failures := 0

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func capture(filename: String) -> void:
	if OS.get_cmdline_user_args().has("--capture-pet"):
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://scratch")
		get_viewport().get_texture().get_image().save_png("res://scratch/" + filename)

func pet_in(world: Node) -> PetActor:
	var found := world.find_children("PetActor", "", true, false)
	for node in found:
		if node is PetActor and not node.is_queued_for_deletion():
			return node
	return null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	for path in DirAccess.get_files_at("res://resources/pets"):
		if not path.ends_with(".tres"):
			continue
		var id := path.get_basename()
		var frames := PetActor.pet_frames(id)
		var ok := frames != null and frames.get_frame_count(&"walk_side") == 4 and frames.get_frame_count(&"sit") == 2
		if ok:
			for anim in ["walk_side", "walk_down", "walk_up", "sit"]:
				ok = ok and not frames.get_frame_texture(anim, 0).get_image().is_invisible()
		check(ok, "pet %s has walking and sitting frames from the Pets sheet" % id)
		check(str(PetActor.option(id).sheet.resource_path).contains("animals/Pets/"), "pet %s sheet comes from animals/Pets" % id)

	GameState.new_game()
	var data := GameState.p1()
	data.load_pet({"pet_id": "dog_brown", "pet_name": "Belang"})
	check(data.pet_affection == 0 and data.pet_day == 0, "old saves without affection keys load as a fresh pet")
	DayCycle.current_day = 3
	DayCycle.hour = 10
	DayCycle.is_running = false
	FarmManager.farm_data.clear()
	var farm: Node2D = load("res://scenes/world/farm.tscn").instantiate()
	get_tree().root.add_child(farm)
	get_tree().current_scene = farm
	await get_tree().physics_frame
	await get_tree().create_timer(0.5, true).timeout
	var player := farm.find_child("CharacterBody2D", true, false) as Player
	check(player != null, "farm player available")
	if player != null:
		player.set_process(false)
		player.set_physics_process(false)
	var pet := pet_in(farm)
	check(pet != null, "pet appears on the farm during the day")
	if pet != null:
		var door: Node2D = null
		for node in get_tree().get_nodes_in_group("scene_door"):
			if node.get_script().resource_path.ends_with("enter_door_house.gd") and farm.is_ancestor_of(node):
				door = node
		check(door != null and pet.global_position.distance_to(door.global_position) < 80.0, "pet plays near the farmhouse door")
		check(pet._badge.text == "Belang", "badge shows the pet's name")
		player.global_position = pet.global_position + Vector2(0, 14)
		await capture("pet-farm.png")
		# Peliharaan di kaki pemain: interaksi tanpa harus tepat menghadapnya (rumah ladang dekat).
		pet._wait = 999.0
		player.global_position = pet.global_position - Player.FEET_OFFSET + Vector2(4, 4)
		player.facing_direction = Vector2.DOWN
		await get_tree().physics_frame
		check(player._try_interact() and data.pet_affection == PetActor.CARE.pet_gain and data.pet_day == 3, "petting a pet at the player's feet raises affection once")
		check(not PetActor.pet().ok and data.pet_affection == PetActor.CARE.pet_gain, "a second pet the same day is refused")
		# Klik kanan pada peliharaan sambil memegang ikan: diberi makan, bukan dimakan sendiri.
		var hand := 7
		data.inventory[hand] = {"item": GameState._resolve_item("fish_anchovy"), "count": 2}
		data.hotbar_page = 0
		player.tool_controller.select_tool(hand, false)
		player.global_position = pet.global_position - Player.FEET_OFFSET + Vector2(-22, 0)
		player.facing_direction = Vector2.LEFT
		await get_tree().physics_frame
		var interacted := player._interact_at(pet.global_position + Vector2(0, -5))
		check(interacted and data.pet_fed_day == 3, "clicking the pet while holding a fish feeds it (handled=%s fed_day=%d)" % [interacted, data.pet_fed_day])
		check(data.inventory[hand] != null and int(data.inventory[hand].count) == 1, "feeding uses one fish")
		check(data.pet_affection == PetActor.CARE.pet_gain + PetActor.CARE.feed_gain, "feeding raises affection")
		# Siul: peliharaan di area yang sama berlari ke sisi pemain.
		pet._wait = 0.0
		# Titik panggil yang bisa dicapai lurus dari peliharaan, cukup jauh supaya ia harus berlari.
		var call_from := pet.global_position + Vector2(0, 70)
		for angle in 16:
			var spot := pet.global_position + Vector2.from_angle(TAU * angle / 16.0) * 64.0
			if AnimalPhysics.is_free(pet, spot, 8.0, [pet.get_rid()]) and not AnimalPhysics.is_blocked(pet, pet.global_position, spot, [pet.get_rid()]):
				call_from = spot
				break
		player.global_position = call_from - Player.FEET_OFFSET
		var whistled := PetActor.whistle(player)
		check(whistled.ok, "whistling calls the pet on the same map")
		check(not PetActor.whistle(player).ok, "whistle has a short cooldown")
		await get_tree().create_timer(2.5, true).timeout
		var gap := pet.global_position.distance_to(player.global_position + Player.FEET_OFFSET)
		check(gap <= PetActor.CARE.call_gap + PetActor.CARE.wander_radius, "called pet runs to the player (gap %.1f)" % gap)
	check(SaveManager.save_game(), "game with a petted pet saves")
	data.pet_affection = 0
	data.pet_day = 0
	check(SaveManager.load_game() and GameState.p1().pet_affection == PetActor.CARE.pet_gain + PetActor.CARE.feed_gain and GameState.p1().pet_day == 3 and GameState.p1().pet_fed_day == 3, "pet affection and feeding survive save/load (%d %d %d)" % [GameState.p1().pet_affection, GameState.p1().pet_day, GameState.p1().pet_fed_day])
	DayCycle.hour = 21
	await get_tree().create_timer(0.5, true).timeout
	check(pet_in(farm) == null, "pet goes indoors at night")
	var farmer := farm.find_child("CharacterBody2D", true, false) as Player
	if farmer != null:
		farmer.remove_meta(&"pet_whistle_ms")
		check(not PetActor.whistle(farmer).ok, "whistling where the pet is not present is not answered")
	DayCycle.current_day = 4
	DayCycle.hour = 10
	await get_tree().create_timer(0.5, true).timeout
	pet = pet_in(farm)
	check(pet != null and GameState.p1().pet_day != DayCycle.current_day, "pet returns next morning ready to be petted again")
	GameState.p1().pet_id = ""
	await get_tree().create_timer(0.5, true).timeout
	check(pet_in(farm) == null, "no pet is shown when none was chosen")
	get_tree().current_scene = self
	farm.queue_free()
	await get_tree().process_frame
	GameState.new_game()
	await get_tree().create_timer(0.5, true).timeout
	print("PET REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
