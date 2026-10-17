extends Node

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func settle() -> void:
	for frame in 5:
		await get_tree().process_frame

func capture(file_name: String) -> void:
	if OS.get_environment("NUSA_SERVICE_SCREENSHOT") != "1" or DisplayServer.get_name() == "headless":
		return
	await settle()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://scratch/" + file_name + ".png")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	GameState.p1().player_name = "Sari"
	GameState.farm_name = "Kebun Senja"
	check(SaveManager.save_game(), "save-slot fixture writes to isolated slot")
	var slots := load("res://scenes/ui/save_slot_menu.tscn").instantiate() as SaveSlotMenu
	slots.mode = SaveSlotMenu.Mode.LOAD
	add_child(slots)
	await settle()
	check(slots._list.get_child_count() == SaveManager.SLOT_COUNT, "native save screen builds actual configured slot count")
	check(not slots._list.get_child(0).get_node("Action").disabled and slots._list.get_child(1).get_node("Action").disabled, "load only enables populated slots")
	check(slots._list.get_child(0).get_node("FarmName").text == "Kebun Senja", "save card displays persisted farm name")
	slots._on_delete_pressed(1)
	check(slots._confirm_layer.visible and slots._list.get_child(0).get_node("Action").disabled, "delete requires modal confirmation and blocks background actions")
	slots._hide_confirm()
	check(SaveManager.has_save(1), "cancelled deletion preserves save")
	await capture("save-load-slots-preview")
	slots._close()
	await settle()
	slots = load("res://scenes/ui/save_slot_menu.tscn").instantiate() as SaveSlotMenu
	slots.mode = SaveSlotMenu.Mode.NEW_GAME
	add_child(slots)
	slots._on_slot_pressed(1, true)
	check(slots._confirm_layer.visible and SaveManager.has_save(1), "new game cannot overwrite an occupied slot before confirmation")
	slots._hide_confirm()
	slots._close()
	await settle()
	slots = load("res://scenes/ui/save_slot_menu.tscn").instantiate() as SaveSlotMenu
	slots.mode = SaveSlotMenu.Mode.SAVE
	add_child(slots)
	slots._on_slot_pressed(2, false)
	await settle()
	check(SaveManager.has_save(2) and SaveManager.current_slot == 2, "native save mode writes the selected empty slot")
	slots = load("res://scenes/ui/save_slot_menu.tscn").instantiate() as SaveSlotMenu
	slots.mode = SaveSlotMenu.Mode.LOAD
	add_child(slots)
	slots._on_slot_pressed(3, false)
	check(not slots._closed, "direct load action cannot bypass empty-slot validation")
	slots._on_delete_pressed(2)
	slots._on_confirm_yes()
	check(not SaveManager.has_save(2) and SaveManager.has_save(1), "confirmed deletion only removes the selected save slot")
	slots._close()
	await settle()
	SaveManager.select_slot(1)
	var creator := load("res://scenes/ui/character_creator_ui.tscn").instantiate() as CharacterCreatorUI
	creator.ask_name = true
	creator.pause_game = false
	add_child(creator)
	await settle()
	creator._calendar.open(-1, 0)
	check(creator._calendar.visible and creator._calendar.get_node("%Days").get_child_count() == DayCycle.DAYS_PER_SEASON, "birthday opens a native grid calendar for all game dates")
	creator._calendar._change_season(1)
	var season: int = creator._calendar._season
	creator._calendar._pick_day(17)
	check(not creator._calendar.visible and creator._birthday_day == 17 and creator._birthday_season == season, "calendar click commits chosen season and date")
	creator._select_pet(1)
	check(creator.get_node("%Confirm").disabled and creator.get_node("%PetIcon").texture != null, "choosing a pet displays its asset and requires a name")
	creator._pet_name.text = "  Piko  "
	creator._validate_profile()
	check(not creator.get_node("%Confirm").disabled, "named pet and complete profile enable confirmation")
	creator._show_page(2)
	await capture("pet-selection-preview")
	creator._calendar.open(creator._birthday_season, creator._birthday_day)
	check(creator._calendar.get_node("%SeasonIcon").texture != null and creator._calendar.get_node("%BirthdayIcon").texture != null, "birthday calendar displays season and cake assets")
	check(creator._calendar.get_node("%Days").get_child(16).get_node("BirthdayMarker").visible, "selected birthday has a cake marker")
	creator._calendar._change_season(1)
	var markers := 0
	for button in creator._calendar.get_node("%Days").get_children():
		if button.get_node("BirthdayMarker").visible:
			markers += 1
	check(markers == 0, "birthday marker only appears in its selected season")
	creator._calendar._change_season(-1)
	await capture("birthday-calendar-preview")
	creator._calendar.hide()
	creator._confirm()
	await settle()
	check(GameState.p1().pet_id == "dog" and GameState.p1().pet_name == "Piko", "profile commits pet choice and trimmed pet name")
	check(SaveManager.save_game(), "pet profile saves")
	GameState.p1().pet_id = ""
	GameState.p1().pet_name = ""
	check(SaveManager.load_game() and GameState.p1().pet_id == "dog" and GameState.p1().pet_name == "Piko", "pet profile survives normal save/load")
	var other := PlayerData.new(1)
	other.load_dict(GameState.p1().to_dict())
	check(other.pet_name == "Piko", "co-op player data round-trips pet identity")
	other.load_dict({})
	check(other.pet_id.is_empty() and other.pet_name.is_empty(), "legacy player data clears absent pet identity")
	var rig = load("res://scenes/player/Player.tscn").instantiate()
	add_child(rig)
	var player: Player = rig.get_node("CharacterBody2D")
	player.set_process(false)
	player.set_physics_process(false)
	player.data.bag_level = 2
	player.data.add_item_silent("wood", 20)
	var record := {"uid": 90001, "item": "wooden_chest", "cell": [0, 0], "storage": [], "open": false, "job": {}, "ready": {}}
	StructureManager.records.append(record)
	var chest = load("res://scenes/ui/chest_ui.tscn").instantiate()
	chest.player = player
	chest.uid = record.uid
	add_child(chest)
	await settle()
	check(chest.get_node("%BagSlots").get_child_count() == player.data.bag_size and chest.get_node("%ChestSlots").get_child_count() == StructureManager.chest_capacity(record), "chest grids reflect bag size and actual chest tier")
	var wood_slot := -1
	for index in player.data.bag_size:
		if player.data.inventory[index] != null and player.data.inventory[index].item.item_id == "wood":
			wood_slot = index
			break
	chest._transfer(wood_slot, true)
	await settle()
	check(player.data.get_item_count("wood") == 0 and StructureManager.storage(record).get_item_count("wood") == 20, "native chest transfers the owner's stack without duplicating items")
	chest._pack()
	check(chest._opened and StructureManager.record_for(record.uid).get("item") == "wooden_chest", "non-empty chest cannot be packed")
	var recipe := StructureManager.next_chest_recipe(record.uid)
	if recipe != null:
		for id in recipe.ingredients:
			player.data.add_item_silent(id, int(recipe.ingredients[id]))
		chest._upgrade()
		await settle()
		check(record.item == recipe.output_item_id and StructureManager.storage(record).get_item_count("wood") == 20, "native upgrade preserves chest contents")
	await capture("chest-ui-preview")
	var wood_index := -1
	var storage := StructureManager.storage(record)
	for index in storage.bag_size:
		if storage.inventory[index] != null and storage.inventory[index].item.item_id == "wood":
			wood_index = index
			break
	chest._transfer(wood_index, false)
	await settle()
	check(player.data.get_item_count("wood") == 20 and StructureManager.storage(record).get_item_count("wood") == 0, "native withdrawal returns contents to the owner")
	chest.queue_free()
	await settle()
	check(not player.is_input_locked() and not get_tree().paused, "removing chest UI restores player controls")
	print("SLOT CALENDAR PET CHEST REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
