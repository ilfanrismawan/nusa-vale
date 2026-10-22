extends Node

var failures := 0

func check(value: bool, label: String) -> void:
	print(("PASS: " if value else "FAIL: ") + label)
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func hearts(data: PlayerData, id: String) -> void:
	NPCSocialService.points(data, id)
	data.friendships[id].points = NPCSocialService.max_points(id)
	NPCSocialService.points(data, id)

func _ready() -> void:
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	var data := GameState.p1()
	var other := GameState.new_coop_character()
	hearts(data, "zarathia")
	check(NPCSocialService.commit_relationship(data, "zarathia", "dating"), "dating available at required hearts")
	check(not NPCSocialService.commit_relationship(data, "zarathia", "married"), "marriage requires upgraded bedroom")
	GameState.house._set_level(2)
	check(NPCSocialService.commit_relationship(data, "zarathia", "married"), "proposal queues household ceremony")
	check(not NPCHousehold.celebrate(data, "zarathia"), "ceremony cannot happen before scheduled day")
	DayCycle.current_day += 1
	check(NPCHousehold.ceremony_ready(data, "zarathia"), "ceremony opens on following day")
	check(NPCDatabase.schedule_entry("zarathia", 12, 0, false).map == "player_home", "pending ceremony brings partner home")
	hearts(other, "zarathia")
	other.romances.zarathia = "dating"
	check(not NPCHousehold.prepare(other, "zarathia", "spouse"), "co-op cannot move the same NPC into two households")
	var home: Node2D = load("res://scenes/world/interior/interior_house.tscn").instantiate()
	get_tree().root.add_child(home)
	get_tree().current_scene = home
	await get_tree().process_frame
	var actor: VillageNPC = home.get_node("Household").actors.zarathia
	var body: Player = home.get_node("Player/CharacterBody2D")
	check(actor.position.x >= 280 and actor.position.x <= 365 and actor.position.y == 180, "partner appears inside the actual home floor")
	actor.interact(body)
	actor._choose_service(5, body)
	actor._dialog_ui._close()
	await get_tree().process_frame
	check(not data.household.celebrated, "cancelling ceremony does not commit household")
	actor.interact(body)
	actor._choose_service(5, body)
	var ceremony: NPCDialogUI = actor._dialog_ui
	for page in ceremony.lines.size():
		ceremony._advance_dialog()
	await get_tree().process_frame
	check(data.household.celebrated and not NPCHousehold.celebrate(data, "zarathia"), "finishing ceremony dialogue commits household exactly once")
	get_tree().current_scene = self
	home.queue_free()
	await get_tree().process_frame
	check(NPCDatabase.schedule_entry("zarathia", 6, 0, false).map == "player_home", "partner at home for breakfast")
	check(NPCDatabase.schedule_entry("zarathia", 12, 0, false).map != "player_home", "partner keeps daytime work routine")
	check(not NPCHousehold.home_entry("zarathia", 20).is_empty(), "partner returns home in evening")
	var count := data.story_mail.size()
	NPCHousehold.advance(data, DayCycle.current_day)
	check(data.story_mail.size() == count, "revisiting home cannot duplicate daily breakfast or rewards")
	other.romances.clear()
	hearts(other, "ubay")
	check(not NPCHousehold.prepare(other, "ubay", "spouse"), "nonromantic resident cannot bypass roommate rules via spouse API")
	check(NPCHousehold.roommate_available(other, "ubay"), "nonromantic friend can become a roommate")
	check(NPCHousehold.prepare(other, "ubay", "roommate") and other.romances.is_empty(), "roommate uses independent nonromantic household state")
	DayCycle.current_day += 1
	check(NPCHousehold.celebrate(other, "ubay"), "roommate welcome completes")
	# Actual farm/ranch chores, before the persistence assertions below.
	var previous_farm := FarmManager.farm_data.duplicate(true)
	FarmManager.farm_data[Vector2i(900, 900)] = {"area": "farm", "crop": load("res://resources/crop_data/carrot.tres"), "watered": false}
	FarmManager.farm_data[Vector2i(901, 900)] = {"area": "greenhouse", "crop": load("res://resources/crop_data/carrot.tres"), "watered": false}
	DayCycle.current_day = 4
	data.household.last_help_day = 0
	NPCHousehold.advance(data, 4)
	check(FarmManager.farm_data[Vector2i(900, 900)].watered and not FarmManager.farm_data[Vector2i(901, 900)].watered, "household waters outdoor crops without changing greenhouse plots")
	FarmManager.farm_data = previous_farm
	var ranch := {"uid": 990, "item": "chicken_coop", "cell": [90, 90], "storage": [], "open": false, "job": {}, "ready": {}}
	StructureManager.records.append(ranch)
	var money_before := GameState.money
	GameState.money = 10000
	check(StructureManager.buy_animal(990, "chicken").ok, "household chore fixture has a chicken")
	GameState.money = money_before
	data.add_item_silent("animal_feed", 2)
	var feed_before := data.get_item_count("animal_feed")
	DayCycle.current_day = 5
	data.household.last_help_day = 0
	NPCHousehold.advance(data, 5)
	check(StructureManager.coop_state(ranch).chickens[0].fed_day == DayCycle.current_day and data.get_item_count("animal_feed") == feed_before - 1, "household feeding consumes owner's actual supplies")
	NPCHousehold.advance(data, 5)
	check(data.get_item_count("animal_feed") == feed_before - 1, "household chores cannot consume supplies twice in a day")
	StructureManager.records.erase(ranch)
	hearts(data, "wira")
	NPCHousehold.advance(data, DayCycle.current_day)
	var letter_id := "friendship_recipe_wira_omelet"
	check(data.story_mail.has(letter_id), "heart threshold queues recipe and material gift")
	check(not NPCHousehold.claim_letter(data, letter_id).ok, "reward cannot be claimed before arrival")
	DayCycle.current_day += 1
	data.bag_level = 0
	for i in data.bag_size:
		data.inventory[i] = {"item": GameState._resolve_item("stone"), "count": 99}
	check(not NPCHousehold.claim_letter(data, letter_id).ok and not data.story_mail[letter_id].read and not data.learned_recipes.has("omelet"), "full bag preserves unread letter and unlearned recipe atomically")
	data.inventory[0] = null
	var money := GameState.money
	check(NPCHousehold.claim_letter(data, letter_id).ok and data.learned_recipes.has("omelet") and data.get_item_count("wood") == 5, "claim learns recipe for free and grants materials")
	check(GameState.money == money and not other.learned_recipes.has("omelet"), "recipe reward does not charge money or leak to co-op")
	check(not NPCHousehold.claim_letter(data, letter_id).ok and data.get_item_count("wood") == 5, "claimed letter cannot grant rewards twice")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(SaveManager._build_save_data()))
	check(SaveManager._is_valid_save(saved), "household, recipes and locked friendships validate after JSON conversion")
	check(SaveManager.save_game(), "social expansion writes to isolated save")
	GameState.new_game()
	check(SaveManager.load_game(), "social expansion reloads from disk")
	data = GameState.p1()
	check(data.household.npc == "zarathia" and data.household.celebrated and data.friendships.wira.locked and data.learned_recipes.has("omelet"), "P1 household, permanent lock and recipe persist")
	check(GameState.coop_roster[0].household.mode == "roommate", "offline co-op roommate persists")
	var bad := data.social_progress()
	bad.household.celebrated = "yes"
	check(not PlayerData.valid_social_progress(bad), "malformed household rejected")
	bad = data.social_progress()
	bad.mail[letter_id].items.wood = -1
	check(not PlayerData.valid_social_progress(bad), "negative letter reward rejected")
	data.load_social_progress({})
	check(data.household.is_empty(), "legacy social save defaults to no household")
	await _test_mailbox_and_roommate()
	# Let the audio server release playback references before headless teardown.
	if MusicManager._fade_tween != null and MusicManager._fade_tween.is_valid():
		MusicManager._fade_tween.kill()
	for music_player in MusicManager.get_children():
		if music_player is AudioStreamPlayer:
			music_player.stop()
			music_player.stream = null
	MusicManager._stream_cache.clear()
	await get_tree().create_timer(0.1, true).timeout
	print("HOUSEHOLD COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)

func _test_mailbox_and_roommate() -> void:
	GameState.new_game()
	DayCycle.is_running = false
	GameState.house._set_level(2)
	var data := GameState.p1()
	hearts(data, "ubay")
	var home: Node2D = load("res://scenes/world/interior/interior_house.tscn").instantiate()
	get_tree().root.add_child(home)
	get_tree().current_scene = home
	await get_tree().process_frame
	var body: Player = home.get_node("Player/CharacterBody2D")
	var actor: VillageNPC = load("res://scenes/npc/ScheduledNPC.tscn").instantiate()
	actor.npc_id = "ubay"
	home.get_node("Household").add_child(actor)
	actor.interact(body)
	actor._choose_service(5, body)
	actor._dialog_ui._close()
	await get_tree().process_frame
	check(data.household.is_empty(), "cancel roommate invitation leaves household empty")
	actor.interact(body)
	actor._choose_service(5, body)
	var ui: NPCDialogUI = actor._dialog_ui
	for page in ui.lines.size():
		ui._advance_dialog()
	await get_tree().process_frame
	check(data.household.get("mode") == "roommate" and data.romances.is_empty(), "roommate invitation UI commits without romance")
	actor.queue_free()
	await get_tree().process_frame
	DayCycle.current_day += 1
	home.get_node("Household").refresh()
	actor = home.get_node("Household").actors.ubay
	actor.interact(body)
	actor._choose_service(5, body)
	ui = actor._dialog_ui
	for page in ui.lines.size():
		ui._advance_dialog()
	await get_tree().process_frame
	check(data.household.celebrated, "roommate welcome completes through home UI")
	data.story_mail.clear()
	data.story_mail.ui_mail = {"subject": "Hadiah UI", "body": "Resep dan kayu", "npc": "wira", "arrival_day": DayCycle.current_day, "read": false, "sets_flags": [], "recipes": ["omelet"], "items": {"wood": 3}}
	var mailbox := Area2D.new()
	mailbox.set_script(load("res://scripts/world/social_mailbox.gd"))
	home.add_child(mailbox)
	mailbox.interact(body)
	mailbox._dialog._close()
	await get_tree().process_frame
	check(not data.story_mail.ui_mail.read and not data.learned_recipes.has("omelet"), "closing mailbox UI does not claim recipe")
	mailbox.interact(body)
	ui = mailbox._dialog
	for page in ui.lines.size():
		ui._advance_dialog()
	await get_tree().process_frame
	check(data.story_mail.ui_mail.read and data.learned_recipes.has("omelet") and data.get_item_count("wood") == 3, "mailbox final page grants recipe and materials")
	get_tree().current_scene = self
	home.queue_free()
	await get_tree().process_frame
