extends Node2D

var failures := 0

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1
		push_error(label)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	DayCycle.current_day = 1
	GameState.weather.current = "sunny"
	var data := GameState.p1()
	var other := GameState.new_coop_character()
	other.story_flags.p2_only = true
	check(NPCDatabase.residents.size() == 5, "all five resident profiles registered")
	check(NPCSocialService.taste("ubay", "coffee") == "loved", "Ubay gift preferences use recognized JSON field")
	check(NPCDatabase.residents.zarathia.service == "" and NPCDatabase.residents.wira.service == "carpenter", "object and null services normalized")
	check(NPCDatabase.residents.zarathia.visual.expressions.happy == [0, 2], "numeric portrait index converted")
	var original: Dictionary = NPCDatabase.residents.wira.friendship.duplicate(true)
	NPCDatabase.residents.wira.friendship = {"start": 500, "max_hearts": 3}
	var fixture := PlayerData.new()
	check(NPCSocialService.points(fixture, "wira") == 500, "friendship starts at configured points")
	fixture.friendships.wira.points = 740
	NPCSocialService.talk(fixture, "wira")
	check(NPCSocialService.points(fixture, "wira") == 750 and NPCSocialService.summary(fixture, "wira").contains("3/3"), "individual heart cap clamps rewards and display")
	NPCDatabase.residents.wira.friendship = original
	var packet := NPCDialogueResolver.packet(["legacy", {"text": "visible", "expression": "happy"}, {"text": "secret", "requires_flags": ["secret"]}], data)
	check(packet.lines.size() == 2 and packet.expressions[1] == "happy", "legacy strings, expression and flag filtering")
	data.story_flags.secret = true
	check(NPCDialogueResolver.packet({"text": "secret", "requires_flags": ["secret"]}, data).lines.size() == 1, "story flags unlock dialogue")
	for id in ["zarathia", "zarathustra", "wira"]:
		NPCSocialService.points(data, id)
		data.friendships[id].points = 2500
	check(not NPCDialogueResolver.resolve(data, "zarathia", "tea_stall").lines.is_empty(), "heart dialogue tier resolves")
	check(NPCSocialService.can_relationship(data, "zarathia", "dating"), "configured dating heart threshold")
	check(NPCSocialService.commit_relationship(data, "zarathia", "dating"), "dating transition")
	check(not NPCSocialService.can_relationship(data, "zarathustra", "dating"), "existing partner prevents a second commitment")
	GameState.house._set_level(2)
	check(NPCSocialService.commit_relationship(data, "zarathia", "married"), "marriage status transition")
	check(other.romances.is_empty(), "romance belongs to each player")
	var roots := Node2D.new()
	add_child(roots)
	for point in ["wira_overlook", "town_square"]:
		var marker := Marker2D.new()
		marker.name = point
		roots.add_child(marker)
	DayCycle.hour = 17
	DayCycle.minute = 0
	check(NPCEventService.find_event(data, "zarathustra", "town", roots, Vector2.ZERO, Vector2.ZERO).is_empty(), "later event requires earlier reveal")
	var event: Dictionary = NPCEventService.find_event(data, "zarathia", "hill", roots, Vector2.ZERO, Vector2.ZERO)
	check(not event.is_empty(), "first reveal matches hearts, clear weather, time and marker")
	check(NPCEventService.find_event(data, "zarathia", "town", roots, Vector2.ZERO, Vector2.ZERO).is_empty(), "wrong map rejects event")
	check(NPCEventService.find_event(data, "zarathia", "hill", roots, Vector2(500, 0), Vector2.ZERO).is_empty(), "distant player rejects event")
	check(NPCEventService.find_event(data, "zarathia", "hill", null, Vector2.ZERO, Vector2.ZERO).is_empty(), "missing marker rejects event")
	GameState.weather.current = "rain"
	check(NPCEventService.find_event(data, "zarathia", "hill", roots, Vector2.ZERO, Vector2.ZERO).is_empty(), "rain rejects clear-weather event")
	GameState.weather.current = "sunny"
	var actor: VillageNPC = load("res://scenes/npc/ScheduledNPC.tscn").instantiate()
	actor.npc_id = "zarathia"
	add_child(actor)
	check(not actor._service_available(), "null service never falls through to shipping")
	actor.definition = NPCDatabase.residents.wira
	actor._current_activity = "resting"
	check(not actor._service_available(), "service closed outside configured activities")
	actor._current_activity = "working"
	DayCycle.current_day = 7
	check(not actor._service_available(), "service respects configured closed weekday")
	DayCycle.current_day = 1
	check(actor._service_available(), "service opens during work on allowed day")
	actor.definition = NPCDatabase.residents.zarathia
	var player := Player.new()
	player.tool_controller = ToolController.new()
	actor._show_packet(NPCDialogueResolver.packet(event.lines, data), player, event)
	actor._dialog_ui._close()
	check(not data.completed_events.has(event.id), "cancel does not complete event")
	await get_tree().process_frame
	actor._show_packet(NPCDialogueResolver.packet(event.lines, data), player, event)
	var ui: NPCDialogUI = actor._dialog_ui
	check(not ui.allow_gifts and not ui.award_friendship, "story dialog disables gifts and ordinary chat reward")
	for index in ui.lines.size():
		ui._advance_dialog()
	check(data.completed_events.has(event.id) and data.story_flags.story_zarathia_told, "final page commits event and flags")
	await get_tree().process_frame
	check(NPCEventService.find_event(data, "zarathia", "hill", roots, Vector2.ZERO, Vector2.ZERO).is_empty(), "completed event does not repeat")
	event = NPCEventService.find_event(data, "zarathustra", "town", roots, Vector2.ZERO, Vector2.ZERO)
	check(not event.is_empty(), "second reveal unlocked")
	NPCEventService.complete(data, event)
	DayCycle.hour = 19
	event = NPCEventService.find_event(data, "wira", "hill", roots, Vector2.ZERO, Vector2.ZERO)
	check(not event.is_empty(), "father reveal unlocked")
	NPCEventService.complete(data, event)
	check(data.story_flags.get("family_truth_known", false) and data.story_mail.has("letter_from_laras"), "family completion queues one letter")
	NPCEventService.complete(data, event)
	check(data.story_mail.has("letter_from_laras") and NPCEventService.pending_letter(data, "wira").is_empty(), "letter does not duplicate or arrive early")
	DayCycle.current_day = 3
	check(not NPCEventService.pending_letter(data, "wira").is_empty(), "letter arrives after configured delay")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(SaveManager._build_save_data()))
	check(SaveManager._is_valid_save(saved), "story, mail and romance save validates")
	GameState.new_game()
	SaveManager._apply_save(saved)
	data = GameState.p1()
	check(data.completed_events.size() == 3 and data.romances.zarathia == "married" and data.story_mail.has("letter_from_laras"), "story and romance survive save/load")
	check(GameState.coop_roster[0].completed_events.is_empty() and GameState.coop_roster[0].story_flags.get("p2_only", false), "P2 story remains independent and persists")
	actor.npc_id = "wira"
	actor.definition = NPCDatabase.residents.wira
	actor.interact(player)
	check(actor._service_menu.letter_available, "due letter appears in Wira menu")
	actor._choose_service(4, player)
	actor._dialog_ui._close()
	await get_tree().process_frame
	check(not NPCEventService.pending_letter(data, "wira").is_empty(), "cancel keeps letter unread")
	actor.interact(player)
	actor._choose_service(4, player)
	ui = actor._dialog_ui
	for index in ui.lines.size():
		ui._advance_dialog()
	await get_tree().process_frame
	check(NPCEventService.pending_letter(data, "wira").is_empty() and data.story_flags.get("family_letter_read", false), "reading final letter page marks read and unlocks response")
	actor.npc_id = "zarathia"
	actor.definition = NPCDatabase.residents.zarathia
	data.household.clear()
	data.romances.erase("zarathia")
	actor.interact(player)
	actor._choose_service(3, player)
	actor._dialog_ui._close()
	await get_tree().process_frame
	check(not data.romances.has("zarathia"), "cancel confession does not commit relationship")
	for expected in ["dating", "married"]:
		actor.interact(player)
		actor._choose_service(3, player)
		ui = actor._dialog_ui
		for index in ui.lines.size():
			ui._advance_dialog()
		await get_tree().process_frame
		check(data.romances.get("zarathia") == expected, "relationship menu commits " + expected + " after final page")
	check(SaveManager.save_game(), "story progress writes to isolated save file")
	data.load_social_progress({})
	check(SaveManager.load_game() and GameState.p1().story_flags.get("family_letter_read", false) and GameState.p1().romances.get("zarathia") == "married", "read letter and relationship restore from disk")
	data = GameState.p1()
	var bad := data.social_progress()
	bad.mail.values()[0].arrival_day = "invalid"
	check(not PlayerData.valid_social_progress(bad), "malformed letter rejected")
	data.load_social_progress({})
	check(data.story_flags.is_empty() and data.story_mail.is_empty() and data.romances.is_empty(), "legacy progress loads with empty defaults")
	player.tool_controller.free()
	player.free()
	actor.queue_free()
	roots.queue_free()
	await get_tree().process_frame
	print("NPC STORY COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
