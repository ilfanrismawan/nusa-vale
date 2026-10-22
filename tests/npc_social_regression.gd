extends Node2D

var failures := 0

func check(value: bool, label: String) -> void:
	print(("PASS: " if value else "FAIL: ") + label)
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	var p1 := GameState.p1()
	var p2 := GameState.new_coop_character()
	NPCSocialService.talk(p1, "wira")
	NPCSocialService.talk(p1, "wira")
	check(NPCSocialService.points(p1, "wira") == 20, "chat rewards only once a day")
	check(NPCSocialService.points(p2, "wira") == 0, "relationships belong to each player")
	NPCSocialService.talk(p1, "unknown")
	check(not p1.friendships.has("unknown"), "unknown NPC cannot create a relationship")
	p2.bag_level = 2
	p2.inventory[22] = {"item": GameState._resolve_item("biji_daya_harvest"), "count": 1}
	check(not NPCSocialService.give(p2, "wira", 22).ok and p2.inventory[22].count == 1 and NPCSocialService.points(p2, "wira") == 0, "unique power seed cannot be lost as a gift")
	NPCDatabase.residents.wira.loved_items = ["wood"]
	NPCDatabase.residents.wira.hated_items = ["stone"]
	NPCDatabase.residents.wira.birthday_season = "spring"
	NPCDatabase.residents.wira.birthday_day = 4
	p1.bag_level = 2
	p1.inventory[20] = {"item": GameState._resolve_item("wood"), "count": 10}
	check(NPCSocialService.give(p1, "wira", 20).ok and NPCSocialService.points(p1, "wira") == 100, "loved gift adds 80 points")
	check(not NPCSocialService.give(p1, "wira", 20).ok and p1.inventory[20].count == 9, "duplicate gift neither scores nor consumes")
	DayCycle.current_day = 2
	check(NPCSocialService.give(p1, "wira", 20).ok, "second weekly gift succeeds")
	DayCycle.current_day = 3
	check(not NPCSocialService.give(p1, "wira", 20).ok and p1.inventory[20].count == 8, "third weekly gift rejected atomically")
	DayCycle.current_day = 4
	check(NPCSocialService.give(p1, "wira", 20).points == 640, "birthday permits an extra gift with 8x points")
	check(not NPCSocialService.give(p1, "wira", 20).ok, "birthday bonus cannot repeat")
	DayCycle.current_day = 8
	check(NPCSocialService.give(p1, "wira", 20).ok, "weekly limit resets on day eight")
	p1.inventory[21] = {"item": GameState._resolve_item("stone"), "count": 2}
	DayCycle.current_day = 9
	check(NPCSocialService.give(p1, "wira", 21).points == -40, "hated gift reduces points")
	check(not NPCSocialService.give(p1, "wira", 0).ok and p1.inventory[0] != null, "starter tool is protected")
	check(not NPCSocialService.give(p1, "wira", -1).ok, "invalid gift slot rejected")
	NPCSocialService.talk(p1, "wira")
	var before := NPCSocialService.points(p1, "wira")
	NPCSocialService.advance(p1, 23)
	check(p1.friendships.wira.points == before, "two-week decay grace")
	NPCSocialService.advance(p1, 24)
	NPCSocialService.advance(p1, 24)
	check(p1.friendships.wira.points == before - 2, "decay evaluated once per missed day")
	p1.friendships.wira.points = 2500
	NPCSocialService.advance(p1, 100)
	check(p1.friendships.wira.points == 2500, "ten hearts never decay")
	DayCycle.current_day = 100
	p1.inventory[21] = {"item": GameState._resolve_item("stone"), "count": 2}
	check(NPCSocialService.give(p1, "wira", 21).points == 0 and p1.friendships.wira.locked, "hated gift cannot break permanent maximum friendship")
	NPCSocialService.advance(p1, 200)
	check(p1.friendships.wira.points == 2500, "locked friendship survives later decay checks")
	NPCSocialService.talk(p2, "ubay")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(SaveManager._build_save_data()))
	check(SaveManager._is_valid_save(saved), "social save validates after JSON conversion")
	GameState.new_game()
	check(GameState.p1().friendships.is_empty(), "new game clears relationships")
	SaveManager._apply_save(saved)
	check(GameState.p1().friendships.wira.points == 2500 and GameState.coop_roster[0].friendships.ubay.points == 20, "P1 and P2 relationships survive save/load")
	check(SaveManager.save_game(), "social state writes to an isolated save slot")
	GameState.p1().friendships.clear()
	GameState.coop_roster[0].friendships.clear()
	check(SaveManager.load_game() and GameState.p1().friendships.wira.points == 2500 and GameState.coop_roster[0].friendships.ubay.points == 20, "P1/P2 relationships restore from the actual save file")
	var bad := saved.duplicate(true)
	bad.player.friendships.wira.points = "broken"
	check(not SaveManager._is_valid_save(bad), "malformed relationship rejected before load")
	bad = saved.duplicate(true)
	bad.coop_players[0].friendships.ubay.gifts = -1
	check(not SaveManager._is_valid_save(bad), "malformed P2 relationship rejected")
	bad = saved.duplicate(true)
	bad.player.friendships.wira.locked = "true"
	check(not SaveManager._is_valid_save(bad), "nonboolean permanent friendship lock is rejected")
	var unlocked_legacy := saved.duplicate(true)
	unlocked_legacy.version = 24
	unlocked_legacy.player.friendships.wira.erase("locked")
	SaveManager._apply_save(unlocked_legacy)
	check(NPCSocialService.points(GameState.p1(), "wira") == 2500 and GameState.p1().friendships.wira.locked, "legacy maximum friendship gains permanent lock")
	var legacy := saved.duplicate(true)
	legacy.version = 18
	legacy.player.erase("friendships")
	for entry: Dictionary in legacy.coop_players:
		entry.erase("friendships")
	check(SaveManager._is_valid_save(legacy), "v18 saves without social state remain valid")
	SaveManager._apply_save(legacy)
	check(GameState.p1().friendships.is_empty() and GameState.coop_roster[0].friendships.is_empty(), "legacy load clears previous social state")
	await _test_dialog()
	print("NPC SOCIAL COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)

func _test_dialog() -> void:
	var world: Node2D = load("res://scenes/world/farm.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	var player: Player = world.get_node("Player/CharacterBody2D")
	player.data.inventory[0] = {"item": GameState._resolve_item("wood"), "count": 3}
	player.tool_controller.select_tool(0)
	var dialog: NPCDialogUI = load("res://scenes/ui/npc_dialog_ui.tscn").instantiate()
	dialog.player = player
	dialog.social_npc_id = "wira"
	dialog.lines = PackedStringArray(["Halo!"])
	Coop.ui_parent(player).add_child(dialog)
	check(dialog._gift_button != null and dialog._role_label.text.contains("Persahabatan"), "dialog shows friendship and explicit gift action")
	var gift_event := InputEventJoypadButton.new()
	gift_event.button_index = JOY_BUTTON_Y
	gift_event.pressed = true
	dialog._input(gift_event)
	check(player.data.inventory[0].count == 2 and player.data.friendships.wira.gift_day == DayCycle.current_day, "gamepad Y gives exactly one selected item")
	dialog._give_gift()
	check(player.data.inventory[0].count == 2, "repeated UI action cannot duplicate gifts")
	var cancel_event := InputEventJoypadButton.new()
	cancel_event.button_index = JOY_BUTTON_B
	cancel_event.pressed = true
	dialog._input(cancel_event)
	check(dialog._closed and player.data.inventory[0].count == 2, "gamepad B closes the dialog without gifting")
	world.queue_free()
	await get_tree().process_frame
