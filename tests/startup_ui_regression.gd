extends Node

var failures := 0
var confirmed := 0

func check(value: bool, message: String) -> void:
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func settle() -> void:
	for frame in 6:
		await get_tree().process_frame

func capture(file_name: String) -> void:
	if OS.get_environment("NUSA_STARTUP_SCREENSHOT") != "1" or DisplayServer.get_name() == "headless":
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
	var menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	add_child(menu)
	await settle()
	check(menu.btn_coop == menu.get_node("%BtnCoop") and menu.btn_new.get_parent().get_child_count() > 5, "main menu uses editor-owned controls including local co-op")
	menu._tween.kill()
	for control in [menu.title_label, menu.btn_new, menu.btn_continue, menu.btn_coop, menu.btn_settings, menu.btn_quit, menu.version_label]:
		control.modulate.a = 1.0
	await capture("main-menu-preview")
	menu.queue_free()
	await settle()
	var creator := load("res://scenes/ui/character_creator_ui.tscn").instantiate() as CharacterCreatorUI
	creator.ask_name = true
	creator.allow_cancel = false
	creator.pause_game = false
	creator.finished.connect(func(_look: CharacterAppearance): confirmed += 1)
	add_child(creator)
	await settle()
	check(creator.get_node("%Confirm").disabled and not creator.get_node("%Cancel").visible, "new-game profile displays required fields and blocks empty submission")
	creator._confirm()
	check(confirmed == 0 and GameState.p1().player_name.is_empty(), "direct confirm cannot bypass required validation")
	creator._name_edit.text = "   "
	creator._farm_edit.text = "   "
	creator._set_birthday(0, 1)
	creator._validate_profile()
	check(creator.get_node("%Confirm").disabled, "whitespace-only names are not accepted")
	creator._name_edit.text = "  Sari  "
	creator._farm_edit.text = "  Kebun Senja  "
	creator._set_birthday(-1, 1)
	creator._validate_profile()
	check(creator.get_node("%Confirm").disabled, "birthday season must be explicitly chosen")
	creator._set_birthday(3, 0)
	creator._validate_profile()
	check(creator.get_node("%Confirm").disabled, "birthday day must be explicitly chosen")
	creator._set_birthday(3, DayCycle.DAYS_PER_SEASON)
	creator._validate_profile()
	check(not creator.get_node("%Confirm").disabled, "complete profile enables confirmation")
	check(creator._preview_actions.size() > 1 and creator._preview.sprite_frames != null, "appearance editor preserves animated character preview")
	creator._cycle(0, 1)
	creator._turn(1)
	check(creator._preview.sprite_frames.has_animation(creator._preview.animation), "changing appearance and rotation keeps a valid animation")
	await capture("character-customize-preview")
	creator._confirm()
	creator._confirm()
	await settle()
	check(confirmed == 1 and GameState.p1().player_name == "Sari" and GameState.farm_name == "Kebun Senja", "confirmation trims and commits profile once")
	check(GameState.p1().birthday_season == "winter" and GameState.p1().birthday_day == DayCycle.DAYS_PER_SEASON, "birthday uses actual game season and day")
	check(SaveManager.save_game(), "profile saves to normal game slot")
	GameState.farm_name = ""
	GameState.p1().player_name = ""
	GameState.p1().birthday_season = ""
	GameState.p1().birthday_day = 0
	check(SaveManager.load_game() and GameState.farm_name == "Kebun Senja" and GameState.p1().birthday_day == DayCycle.DAYS_PER_SEASON, "farm name and birthday survive save/load")
	check(SaveManager.get_slot_summary(SaveManager.current_slot).get("farm_name") == "Kebun Senja", "slot metadata includes the saved farm name")
	var other := PlayerData.new(1)
	other.birthday_season = "summer"
	other.birthday_day = 7
	var restored := PlayerData.new(1)
	restored.load_dict(other.to_dict())
	check(restored.birthday_season == "summer" and restored.birthday_day == 7, "co-op birthdays serialize independently")
	restored.load_dict({})
	check(restored.birthday_day == 0 and restored.birthday_season.is_empty(), "legacy player data supports missing birthday")
	restored.load_birthday({"birthday_season": "winter", "birthday_day": 999})
	check(restored.birthday_day == 0, "out-of-calendar birthday is not loaded")
	var legacy := SaveManager._build_save_data()
	legacy.erase("farm_name")
	legacy.player.erase("birthday_day")
	legacy.player.erase("birthday_season")
	SaveManager._apply_save(legacy)
	check(GameState.farm_name.is_empty() and GameState.p1().birthday_day == 0, "old saves clear absent profile fields rather than retaining another slot")
	var wardrobe := load("res://scenes/ui/character_creator_ui.tscn").instantiate() as CharacterCreatorUI
	wardrobe.pause_game = false
	add_child(wardrobe)
	await settle()
	check(not wardrobe.get_node("%Identity").visible and not wardrobe.get_node("%Confirm").disabled, "wardrobe remains usable without requiring new-game identity")
	wardrobe._cancel()
	await settle()
	GameState.farm_name = "Old farm"
	GameState.p1().birthday_season = "spring"
	GameState.p1().birthday_day = 1
	GameState.new_game()
	check(GameState.farm_name.is_empty() and GameState.p1().birthday_day == 0, "new game resets profile identity")
	SaveManager.select_slot(3)
	SaveManager.delete_save()
	menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	add_child(menu)
	var devices: Array[int] = [PlayerInput.DEVICE_KEYBOARD, PlayerInput.DEVICE_NUMPAD]
	menu._start_coop(devices)
	await settle()
	var coop_creator: CharacterCreatorUI
	for child in menu.get_children():
		if child is CharacterCreatorUI:
			coop_creator = child
	check(coop_creator != null and coop_creator.ask_name and coop_creator.get_node("%Confirm").disabled and not SaveManager.has_save(), "empty co-op slot requires a complete profile before saving or starting")
	menu.queue_free()
	await settle()
	print("STARTUP UI REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
