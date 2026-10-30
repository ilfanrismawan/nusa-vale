extends Node

const Spawner := preload("res://scripts/world/wildlife_spawner.gd")

var failures := 0

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func capture(filename: String) -> void:
	if OS.get_cmdline_user_args().has("--capture-wildlife"):
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://scratch")
		get_viewport().get_texture().get_image().save_png("res://scratch/" + filename)

func data(id: String) -> Resource:
	return load("res://resources/wildlife/%s.tres" % id)

func frames_ok(entry: Resource) -> bool:
	var frames: SpriteFrames = entry.frames()
	for action in ["idle", "walk", "run"]:
		for direction in ["side", "down", "up"]:
			var anim := StringName("%s_%s" % [action, direction])
			if not frames.has_animation(anim) or frames.get_frame_count(anim) < 2:
				return false
			for index in frames.get_frame_count(anim):
				if frames.get_frame_texture(anim, index).get_image().is_invisible():
					return false
	return true

func physics(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	var all := Spawner.all_data()
	check(all.size() == 9, "nine wildlife kinds load from resources/wildlife")
	for entry in all:
		check(frames_ok(entry), "%s has idle/walk/run frames in three directions" % entry.display_name)
		check(str(entry.walk_sheet.resource_path).contains("animals/Forest/"), "%s uses the Forest pack sheet" % entry.display_name)
	check(data("deer_female").is_available("forest", "spring", 10) and not data("deer_female").is_available("forest", "spring", 22), "deer roam by day only")
	check(data("fox_red").is_available("forest", "summer", 18) and not data("fox_red").is_available("forest", "summer", 12), "red fox appears at dusk and dawn")
	check(data("fox_white").is_available("mountain", "winter", 12) and not data("fox_white").is_available("mountain", "summer", 12), "white fox appears only in winter")
	check(not data("turtle").is_available("forest", "winter", 10) and not data("turtle").is_available("mountain", "spring", 10), "turtle keeps to the warm-season forest")
	var farm_pool := Spawner.candidates("farm", "spring", 10)
	check(farm_pool.size() == 1 and farm_pool[0].flies, "only crows visit the farm")

	GameState.new_game()
	DayCycle.current_day = 3
	DayCycle.hour = 10
	DayCycle.is_running = false
	var forest: Node2D = load("res://scenes/world/Forest.tscn").instantiate()
	get_tree().root.add_child(forest)
	get_tree().current_scene = forest
	await physics(6)
	var player := forest.find_child("CharacterBody2D", true, false) as Player
	check(player != null, "forest player available")
	player.set_process(false)
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	var spawner := forest.get_node_or_null("WildlifeSpawner")
	check(spawner != null, "forest attaches a wildlife spawner")
	var animals: Array = spawner.animals()
	check(animals.size() >= 1 and animals.size() <= 4, "forest is populated with up to four animals by day (%d)" % animals.size())
	var all_clear := true
	for animal in animals:
		all_clear = all_clear and animal.global_position.distance_to(player.global_position) >= spawner.player_clearance
	check(all_clear, "animals appear away from the player")
	# Satwa dekat pemain untuk tangkapan layar; dihapus dari luar (queue_free) untuk menguji spawner.
	var posed: Array[Node2D] = []
	for entry in [["deer_male", Vector2(64, 0)], ["rabbit_brown", Vector2(-48, 16)], ["fox_white", Vector2(0, -64)], ["turtle", Vector2(-40, -44)], ["frog", Vector2(40, 40)]]:
		posed.append(spawner.spawn(data(entry[0]), player.global_position + entry[1]))
	await get_tree().create_timer(1.5, true).timeout
	if OS.get_cmdline_user_args().has("--capture-wildlife"):
		await capture("wildlife-posed.png")
	for animal in posed:
		animal.queue_free()
	await physics(2)
	check(spawner.animals().size() == animals.size(), "spawner forgets animals freed elsewhere")

	# Rusa: berjalan di dekatnya membuat kabur, berlari mengejutkan dari 2x jarak.
	var deer: WildAnimal = spawner.spawn(data("deer_female"), player.global_position + Vector2(200, 0))
	await physics(2)
	player.global_position = deer.global_position + Vector2(-deer.data.flee_radius * 1.5, 0)
	await physics(3)
	check(deer.mode != WildAnimal.Mode.FLEE, "a walking player at 1.5x the flee radius does not spook deer")
	player.velocity = Vector2(player.speed * 2.0, 0)
	await physics(3)
	check(deer.mode == WildAnimal.Mode.FLEE, "a running player spooks deer from twice the radius")
	var before := deer.global_position.distance_to(player.global_position)
	await physics(30)
	check(deer.global_position.distance_to(player.global_position) > before, "spooked deer runs away from the player")
	player.velocity = Vector2.ZERO
	await capture("wildlife-forest.png")

	# Kura-kura bersembunyi di tempat.
	var turtle: WildAnimal = spawner.spawn(data("turtle"), player.global_position + Vector2(0, 160))
	await physics(2)
	var shell_spot := turtle.global_position
	player.global_position = turtle.global_position + Vector2(0, -turtle.data.flee_radius * 0.5)
	await physics(10)
	check(turtle.mode == WildAnimal.Mode.HIDE and turtle.global_position.distance_to(shell_spot) < 1.0, "turtle hides in its shell instead of running")

	# Catatan Satwa: diam di luar jarak kabur selama 2 detik.
	var exp_before := player.data.skills.get_points(&"forager")
	var frog: WildAnimal = spawner.spawn(data("frog"), player.global_position + Vector2(-220, 0))
	await physics(2)
	player.velocity = Vector2.ZERO
	player.global_position = frog.global_position + Vector2(frog.data.flee_radius * 1.4, 0)
	await get_tree().create_timer(0.8, true).timeout
	check(not frog.observed and frog.mode != WildAnimal.Mode.FLEE, "a brief look does not count as an observation")
	await get_tree().create_timer(1.8, true).timeout
	check(frog.observed and int(GameState.wildlife_seen.get("frog", 0)) == 1, "standing still outside the flee radius records the frog")
	check(player.data.skills.get_points(&"forager") >= exp_before + WildlifeJournal.FIRST_EXP, "a new species grants forager EXP")
	for id in WildlifeJournal.ids():
		if id != "turtle":
			GameState.wildlife_seen[id] = maxi(1, int(GameState.wildlife_seen.get(id, 0)))
	GameState.wildlife_seen.erase("turtle")
	check(WildlifeJournal.observe(data("turtle"), player.data) and GameState.wildlife_seen.has(WildlifeJournal.COMPLETE_KEY), "the last species completes the journal once")
	check(not WildlifeJournal.observe(data("turtle"), player.data) and int(GameState.wildlife_seen.turtle) == 2, "repeat sightings only count up")
	check(WildlifeJournal.text().begins_with("CATATAN SATWA (%d/%d) · lengkap" % [all.size(), all.size()]), "journal text shows the completed album")
	check(SaveManager.save_game(), "game with a wildlife journal saves")
	GameState.wildlife_seen = {}
	check(SaveManager.load_game() and int(GameState.wildlife_seen.get("frog", 0)) >= 1 and GameState.wildlife_seen.has(WildlifeJournal.COMPLETE_KEY), "wildlife journal survives save/load")
	check(not WildlifeJournal.valid_save({"frog": -1}) and not WildlifeJournal.valid_save([]) and WildlifeJournal.valid_save({}), "invalid wildlife saves are rejected")

	# Gagak: kabur dengan terbang menjauh ke atas lalu menghilang.
	var crow: WildAnimal = spawner.spawn(data("crow"), player.global_position + Vector2(0, 220))
	await physics(2)
	player.global_position = crow.global_position + Vector2(crow.data.flee_radius * 0.5, 0)
	var perch := crow.global_position
	await physics(20)
	check(crow.mode == WildAnimal.Mode.FLEE and crow.global_position.y < perch.y - 4.0, "a crow takes off upward when approached")
	await get_tree().create_timer(WildAnimal.FLEE_SECONDS + 1.2, true).timeout
	check(not is_instance_valid(crow) or crow.is_leaving(), "a flown crow disappears")

	# Memberi makan: memegang wortel memancing kelinci tanpa membuatnya kabur.
	player.data.inventory[player.tool_controller.current_index] = {"item": GameState._resolve_item("carrot"), "count": 3}
	var bunny: WildAnimal = spawner.spawn(data("rabbit_brown"), player.global_position + Vector2(-240, 0))
	await physics(2)
	player.global_position = bunny.global_position + Vector2(bunny.data.flee_radius * 1.6, 0)
	var gap := bunny.global_position.distance_to(player.global_position)
	await get_tree().create_timer(2.5, true).timeout
	check(bunny.mode != WildAnimal.Mode.FLEE and bunny.global_position.distance_to(player.global_position) < gap - 8.0, "holding a carrot lures the rabbit closer instead of scaring it")
	bunny.interact(player)
	check(bunny.tame and player.data.get_item_count("carrot") == 2 and WildlifeJournal.fed_count(bunny.data) == 1, "feeding uses one carrot and tames the rabbit")
	player.data.inventory[player.tool_controller.current_index] = null
	player.global_position = bunny.global_position + Vector2(bunny.data.flee_radius * 0.5, 0)
	await physics(5)
	check(bunny.mode != WildAnimal.Mode.FLEE, "a tame rabbit stays calm near a walking player")
	player.velocity = Vector2(player.speed * 2.0, 0)
	await physics(3)
	check(bunny.mode == WildAnimal.Mode.FLEE, "even a tame rabbit bolts from a running player")
	player.velocity = Vector2.ZERO
	bunny.interact(player)
	check(WildlifeJournal.fed_count(bunny.data) == 1, "feeding counts once per animal")
	bunny.leave_gift()
	var gifts := bunny.get_parent().get_children().filter(func(node: Node) -> bool: return node is ItemPickup and node.item_id == "rabbit_fur")
	check(gifts.size() >= 1 and GameState._resolve_item("rabbit_fur").sell_price == 80, "a tame rabbit can leave rabbit fur behind")
	for gift in gifts:
		gift.queue_free()

	# Gagak di ladang memakan tanaman yang tidak dijaga Orang-orangan Sawah.
	var saved_plots := FarmManager.farm_data.duplicate()
	FarmManager.farm_data.clear()
	var carrot_crop: CropData = load("res://resources/crop_data/carrot.tres")
	for x in FarmManager.CROW_MIN_CROPS:
		FarmManager.farm_data[Vector2i(100 + x, 100)] = {"area": "farm", "state": "planted", "crop": carrot_crop, "stage": 1, "days_in_stage": 0, "watered": false}
	FarmManager.farm_data[Vector2i(100, 120)] = {"area": "greenhouse", "state": "planted", "crop": carrot_crop, "stage": 1, "days_in_stage": 0, "watered": false}
	GameState.weather.current = "sunny"
	check(FarmManager.crow_attack(FarmManager.CROW_CHANCE + 0.01) == Vector2i(-1, -1), "crows skip a lucky day")
	var eaten := FarmManager.crow_attack(0.0)
	check(eaten.y == 100 and FarmManager.farm_data[eaten].crop == null, "crows eat one unguarded field crop but leave the tilled soil")
	check(FarmManager.crow_attack(0.0) == Vector2i(-1, -1), "fewer than twelve unguarded crops attract no crows")
	FarmManager.farm_data[eaten].crop = carrot_crop
	StructureManager.records.append({"uid": 9901, "item": "scarecrow", "cell": [105, 100], "storage": [], "open": false, "job": {}, "ready": {}})
	check(FarmManager.unguarded_crops().is_empty() and FarmManager.crow_attack(0.0) == Vector2i(-1, -1), "a scarecrow guards crops within eight tiles")
	StructureManager.records.pop_back()
	GameState.weather.current = "rain"
	check(FarmManager.crow_attack(0.0) == Vector2i(-1, -1), "crows stay away on rainy days")
	GameState.weather.current = "sunny"
	FarmManager.farm_data.clear()
	FarmManager.farm_data.merge(saved_plots)

	# Malam: satwa siang pergi.
	DayCycle.hour = 22
	spawner.refill()
	await physics(2)
	var day_left := false
	for animal in spawner.animals():
		day_left = day_left or animal.data.time == "day"
	check(not day_left and (not is_instance_valid(deer) or deer.is_leaving()), "day animals leave at night")

	get_tree().current_scene = self
	forest.queue_free()
	await get_tree().process_frame
	GameState.new_game()
	await get_tree().create_timer(0.5, true).timeout
	print("WILDLIFE REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
