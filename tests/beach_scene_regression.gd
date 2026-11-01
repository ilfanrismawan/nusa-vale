extends Node
## Regresi scene Pantai: jalan selatan Town terkunci sampai Nelayan Lv 2, lalu Town <-> Pantai,
## laut = spot beach_sea yang tidak membeku, ForageSpawner "beach", dermaga bisa dilewati, air menahan pemain.
## NUSA_SAVE_AUDIT=1 Godot.exe --headless --path . res://tests/beach_scene_regression.tscn
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
	var deadline := Time.get_ticks_msec() + 15000
	while (Transition.on_transition or (is_instance_valid(player) and player.is_input_locked())) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

## Pemain berdiri dengan kaki di `feet`; true bila bisa bergerak sejauh `motion`.
func can_walk(player: Player, feet: Vector2, motion: Vector2) -> bool:
	player.global_position = feet - Player.FEET_OFFSET
	return not player.test_move(player.global_transform, motion)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	get_tree().current_scene = null
	await get_tree().process_frame
	GameState.new_game()
	check(not UnlockManager.is_unlocked("beach"), "new game beach is locked")
	check(not UnlockManager.try_unlock_beach(), "beach stays locked before Nelayan Lv %d" % UnlockManager.BEACH_FISHER_LEVEL)

	var town := preload("res://scenes/world/town.tscn").instantiate()
	get_tree().root.add_child(town)
	get_tree().current_scene = town
	await get_tree().create_timer(1.5, true).timeout
	var player: Player = town.get_node("Player/CharacterBody2D")
	var access: Area2D = town.get_node("BeachAccess")
	check(access.scene_target == "res://scenes/world/beach.tscn", "town BeachAccess targets the beach scene")
	var gate := (access.get_node("CollisionShape2D") as Node2D).global_position
	# Berjalan lurus ke selatan sampai tertahan dinding batas; kaki pemain harus sudah masuk trigger.
	player.global_position = gate + Vector2(0, -64) - Player.FEET_OFFSET
	await get_tree().physics_frame
	for step in 40:
		if player.move_and_collide(Vector2(0, 2)) != null:
			break
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(access.overlaps_body(player), "town south path reaches BeachAccess before the boundary wall")
	await cross(player, access)
	check(get_tree().current_scene == town, "locked beach does not travel")

	GameState.p1().skills.levels["fisher"] = UnlockManager.BEACH_FISHER_LEVEL
	check(UnlockManager.try_unlock_beach(), "Nelayan Lv %d unlocks beach" % UnlockManager.BEACH_FISHER_LEVEL)
	var unlocks := UnlockManager.get_unlocks()
	UnlockManager.reset()
	UnlockManager.load_unlocks(unlocks)
	check(UnlockManager.is_unlocked("beach"), "beach access survives save round trip")

	player.global_position += Vector2(0, -80)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await cross(player, access)
	var beach := get_tree().current_scene
	check(beach != null and beach.scene_file_path.ends_with("beach.tscn"), "unlocked town south path travels to beach")
	if beach == null or not beach.scene_file_path.ends_with("beach.tscn"):
		get_tree().quit(1)
		return
	player = beach.get_node("Player/CharacterBody2D")
	check(player.global_position.distance_to(Vector2(480, 72) - Player.FEET_OFFSET) < 24.0 or player.global_position.distance_to(Vector2(480, 72)) < 24.0, "player arrives at the beach north entrance")

	var spot := beach.get_node("SeaFishingSpot") as FishingSpot
	check(spot != null and spot.location_id == "beach_sea", "sea is a beach_sea fishing spot")
	check(spot != null and not spot.freezes_in_winter, "sea does not freeze in winter")
	var forage := beach.get_node("ForageSpawner") as ForageSpawner
	check(forage != null and forage.location_id == "beach", "beach has a ForageSpawner for location beach")
	var ground := beach.get_node("BaseLayerGround") as TileMapLayer
	check(ground.get_used_cells().size() > 1000, "sand ground layer is painted")
	var beach_fish := 0
	for file in DirAccess.get_files_at("res://resources/fish_data"):
		if file.ends_with(".tres"):
			var data: Resource = load("res://resources/fish_data/" + file)
			if "beach_sea" in data.get("locations"):
				beach_fish += 1
	check(beach_fish > 0, "fish data exists for beach_sea (%d)" % beach_fish)

	await get_tree().physics_frame
	# Dermaga: badan kolom 34-36 (x 544-592), kepala T baris 41-42 (y 656-688).
	check(can_walk(player, Vector2(568, 470), Vector2(0, 170)), "pier body is walkable over the sea")
	check(can_walk(player, Vector2(568, 672), Vector2(-56, 0)) and can_walk(player, Vector2(568, 672), Vector2(56, 0)), "pier head is walkable")
	check(not can_walk(player, Vector2(568, 560), Vector2(48, 0)), "water beside the pier blocks walking")
	check(not can_walk(player, Vector2(300, 440), Vector2(0, 120)), "shoreline water blocks walking")
	check(can_walk(player, Vector2(480, 96), Vector2(0, 260)), "north entrance leads down onto the sand")

	await cross(player, beach.get_node("ExitToTown"))
	town = get_tree().current_scene
	check(town != null and town.scene_file_path.ends_with("town.tscn"), "beach north exit returns to town")
	if town != null and town.has_node("Player/CharacterBody2D"):
		player = town.get_node("Player/CharacterBody2D")
		await get_tree().physics_frame
		check(can_walk(player, player.global_position + Player.FEET_OFFSET, Vector2(0, -40)), "town arrival from beach is not stuck")
	print("BEACH SCENE COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
