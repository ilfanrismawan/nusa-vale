extends Node

const ID := "greenhouse_restoration"
const CELL := Vector2i(10000, 10000)
var failures := 0
var completion_count := 0

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func capture(filename: String) -> void:
	if OS.get_cmdline_user_args().has("--capture-greenhouse"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://scratch/" + filename)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	FarmManager.farm_data.clear()
	var manager := GameState.balai_nadi
	manager.project_completed.connect(func(id):
		if id == ID:
			completion_count += 1)
	var farm := load("res://scenes/world/farm.tscn").instantiate() as Node2D
	get_tree().root.add_child(farm)
	get_tree().current_scene = farm
	await get_tree().physics_frame
	await get_tree().physics_frame
	var player := farm.get_node("Player/CharacterBody2D") as Player
	var greenhouse := farm.get_node("Greenhouse")
	player.global_position = Vector2(576, 120)
	player.facing_direction = Vector2.UP
	await get_tree().physics_frame
	check(player._find_interactable() == greenhouse, "Farm greenhouse door uses existing interaction query")
	player._try_interact()
	await get_tree().process_frame
	check(get_tree().current_scene == farm and not manager.completed(ID) and greenhouse.get_node("Sprite2D").region_rect.position.y == 7, "New Game keeps greenhouse damaged and refuses entry")
	await capture("greenhouse-locked.png")
	# Outdoor travel is automatic; the Balai Nadi is now located in town.
	player.global_position = farm.get_node("EnterTown/CollisionShape2D").global_position - Player.FEET_OFFSET
	await get_tree().physics_frame
	await get_tree().create_timer(1.5, true).timeout
	check(get_tree().current_scene.scene_file_path.ends_with("town.tscn"), "Farm boundary automatically reaches town")
	var town := get_tree().current_scene
	player = town.get_node("Player/CharacterBody2D")
	player.global_position = town.get_node("BalaiNadiAccess").global_position
	await get_tree().physics_frame
	await get_tree().create_timer(1.5, true).timeout
	check(get_tree().current_scene.scene_file_path.ends_with("balai_nadi/exterior.tscn"), "Farm sign transitions to separate Balai Nadi exterior")
	player = get_tree().current_scene.get_node("Player/CharacterBody2D")
	player.global_position = Vector2(427, 244)
	player.facing_direction = Vector2.UP
	await get_tree().physics_frame
	# Masuk ke gedung Balai tetap memakai interaksi klik kanan.
	player._try_interact()
	await get_tree().create_timer(1.2, true).timeout
	var balai := get_tree().current_scene
	player = balai.get_node("Player/CharacterBody2D")
	player.global_position = Vector2(427, 260)
	player.facing_direction = Vector2.UP
	await get_tree().physics_frame
	player._try_interact()
	await get_tree().process_frame
	var menu: BalaiNadiUI = balai.get_node("ContributionTable")._menus.get(0)
	check(menu._selector.item_count == 2, "Balai UI offers both independent restoration projects")
	menu._selector.select(1)
	menu._selector.item_selected.emit(1)
	check(menu.project_id == ID and menu._rows.size() == 3 and menu._rows.copper_bar.button.disabled, "Selecting greenhouse displays wood, stone and copper requirements")
	player.data.bag_level = 2
	player.data.add_item("wood", 40)
	menu._rows.wood.button.pressed.emit()
	check(manager.contributed(ID, "wood") == 40 and player.data.get_item_count("wood") == 0 and not WorldState.has_flag("greenhouse_unlocked"), "Partial donation through Balai UI leaves greenhouse locked")
	check(SaveManager.load_game() and manager.contributed(ID, "wood") == 40, "Partial greenhouse donation survives actual disk reload")
	player.data.add_item("wood", 130)
	player.data.add_item("stone", 90)
	player.data.add_item("copper_bar", 8)
	menu._rows.wood.button.pressed.emit()
	menu._rows.stone.button.pressed.emit()
	check(not manager.completed(ID), "Wood and stone alone cannot unlock greenhouse")
	await capture("greenhouse-contributions.png")
	menu._rows.copper_bar.button.pressed.emit()
	check(manager.completed(ID) and WorldState.has_flag("greenhouse_unlocked") and completion_count == 1, "Final contribution unlocks greenhouse once")
	check(player.data.get_item_count("wood") == 20 and player.data.get_item_count("stone") == 15 and player.data.get_item_count("copper_bar") == 3, "Only remaining requirements are deducted")
	check(not manager.completed("balai_nadi_restoration") and menu._rows.wood.button.disabled and menu._status.text.contains("Greenhouse"), "Greenhouse completion is independent and UI shows its own reward")
	menu.close_menu()
	await get_tree().process_frame
	GameState.next_spawn_position = Vector2(576, 120)
	GameState.has_spawn_point = true
	Transition.scene_transition("res://scenes/world/farm.tscn", player)
	await get_tree().create_timer(1.2, true).timeout
	farm = get_tree().current_scene
	player = farm.get_node("Player/CharacterBody2D")
	greenhouse = farm.get_node("Greenhouse")
	check(greenhouse.get_node("Sprite2D").region_rect.position.y == 103 and greenhouse.get_node("Sprite2D2").visible, "Farm greenhouse swaps to clean restored sprite and repaired door")
	var sprite := greenhouse.get_node("Sprite2D") as Sprite2D
	check(sprite.texture.get_image().get_region(Rect2i(sprite.region_rect)).get_used_rect().has_area(), "Restored atlas region contains visible greenhouse artwork")
	await capture("greenhouse-restored.png")
	player.facing_direction = Vector2.UP
	player._try_interact()
	await get_tree().create_timer(1.2, true).timeout
	check(get_tree().current_scene.scene_file_path.ends_with("interior/greenhouse.tscn"), "Restored greenhouse door opens playable growing room")
	var room := get_tree().current_scene
	player = room.get_node("Player/CharacterBody2D")
	check(player.base_layer_ground != null and room.get_node("BaseLayerGround").get_used_cells().size() == 32, "Interior exposes 32 farmable tiles to existing player tools")
	var crop: CropData = load("res://resources/crop_data/tomato.tres")
	DayCycle.current_day = 1
	check(FarmManager.hoe(CELL) and FarmManager.is_crop_in_season(crop) and FarmManager.plant(CELL, crop), "Greenhouse supports existing hoe and out-of-season planting")
	check(FarmManager.water(CELL), "Existing watering works inside greenhouse")
	# Main farm and greenhouse have independent persistence and seasonal behavior.
	var farm_cell := Vector2i(2, 3)
	FarmManager.farm_data[farm_cell] = {"area": "farm", "state": "planted", "crop": crop, "stage": 0, "days_in_stage": 0, "watered": false}
	FarmManager._on_season_changed(DayCycle.Season.SPRING)
	check(FarmManager.farm_data[CELL].crop == crop and FarmManager.farm_data[farm_cell].crop == null, "Season change protects greenhouse while outdoor crops still wither")
	check(SaveManager.save_game() and SaveManager.load_game() and manager.completed(ID) and completion_count == 1 and FarmManager.farm_data[CELL].area == "greenhouse" and FarmManager.farm_data[CELL].watered, "Unlock, greenhouse crop and outdoor plot survive version 9 disk reload without reward replay")
	check(room.get_node("SoilLayer").get_used_cells().size() == 1 and room.get_node("Crop").get_used_cells().size() == 1, "Greenhouse restores only its own plots, without outdoor tiles")
	for day in (crop.get_total_stages() - 1) * crop.days_per_stage:
		FarmManager.water(CELL)
		FarmManager._on_day_passed(day)
	check(FarmManager.can_harvest(CELL), "Greenhouse crops grow to harvest with normal day progression")
	await capture("greenhouse-interior.png")
	check(FarmManager.harvest(CELL) and FarmManager.farm_data[CELL].crop == null and not room.get_node("Crop").get_used_cells().has(CELL), "Existing harvest produces drops and clears greenhouse crop")
	player.global_position = room.get_node("Exit/CollisionShape2D").global_position - Player.FEET_OFFSET
	player.facing_direction = Vector2.DOWN
	await get_tree().physics_frame
	await get_tree().create_timer(1.5, true).timeout
	check(get_tree().current_scene.scene_file_path.ends_with("world/farm.tscn"), "Greenhouse exit returns to farm")
	check(FarmManager.area_id() == "farm" and not FarmManager.is_crop_in_season(crop) and not FarmManager.soil_layer.get_used_cells().has(CELL), "Returning to farm restores seasonal restrictions and hides greenhouse plots")
	check(manager.contribute(GameState.p1(), ID, "wood") == 0, "Completed greenhouse refuses duplicate contributions")
	var old_data := SaveManager._build_save_data()
	old_data.version = 8
	old_data.balai_nadi.projects.erase(ID)
	SaveManager._apply_save(old_data)
	check(not manager.completed(ID) and not WorldState.has_flag("greenhouse_unlocked"), "Version 8 saves without greenhouse project initialize safely")
	GameState.new_game()
	check(manager.contributed(ID, "wood") == 0 and not WorldState.has_flag("greenhouse_unlocked"), "New Game resets greenhouse donations and access")
	print("GREENHOUSE REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
