extends Node

var failures := 0
const NEW_WALKERS := ["kirana", "bahar", "joko", "ratih", "rian", "damar"]

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func walk(actor: VillageNPC) -> bool:
	var stalled := 0
	for step in 10000:
		if not actor._is_walking:
			return actor.global_position.distance_to(actor._target_pos) <= 3.0
		var before := actor.global_position
		actor._physics_process(1.0 / 60.0)
		stalled = stalled + 1 if before.distance_to(actor.global_position) < 0.01 else 0
		if stalled > 320:
			print("BLOCKED: ", actor.npc_id, " at ", actor.global_position, " towards ", actor._target_pos)
			return false
	return false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	DayCycle.current_day = 1
	GameState.weather.current = "sunny"
	check(NPCDatabase.residents.size() == 14 and NPCDatabase.gift_profiles.is_empty(), "one central registry for all fourteen residents")
	var player := Player.new()
	player.tool_controller = ToolController.new()
	var event_count := 0
	for id: String in NPCDatabase.residents:
		var definition: Dictionary = NPCDatabase.residents[id]
		var frames: SpriteFrames = load(definition.visual.sprite_frames)
		var regions_fit := true
		for animation in frames.get_animation_names():
			for index in frames.get_frame_count(animation):
				var texture := frames.get_frame_texture(animation, index) as AtlasTexture
				if texture != null and texture.atlas != null:
					regions_fit = regions_fit and Rect2(Vector2.ZERO, texture.atlas.get_size()).encloses(texture.region)
		check(regions_fit, id + " every animation frame fits its source image")
		var legacy := NPCDatabase.get_definition(StringName(id))
		check(legacy.display_name == definition.name and legacy.birthday_day == definition.birthday_day, id + " compatibility definition reads central profile")
		NPCSocialService.points(player.data, id)
		player.data.friendships[id].points = 2500
		var roots := Node2D.new()
		add_child(roots)
		for event: Dictionary in definition.heart_events:
			event_count += 1
			var fixture := PlayerData.new()
			NPCSocialService.points(fixture, id)
			fixture.friendships[id].points = int(event.hearts) * 250
			for other: Dictionary in definition.heart_events:
				if other.id != event.id:
					fixture.completed_events[other.id] = true
			for flag in NPCEventService._merged(event, id).requires_flags:
				fixture.story_flags[str(flag)] = true
			var marker := Marker2D.new()
			marker.name = str(event.point)
			roots.add_child(marker)
			var time := str(event.time_range[0]).split(":")
			DayCycle.hour = int(time[0])
			DayCycle.minute = int(time[1])
			var found := NPCEventService.find_event(fixture, id, str(event.map), roots, Vector2.ZERO, Vector2.ZERO)
			check(found.get("id", "") == event.id, id + " event reachable at threshold: " + str(event.id))
			NPCEventService.complete(fixture, event)
			check(NPCEventService.find_event(fixture, id, str(event.map), roots, Vector2.ZERO, Vector2.ZERO).is_empty(), id + " event cannot repeat")
			marker.free()
		# Exercise actual dialogue transaction on one event per resident.
		var actor: VillageNPC = load("res://scenes/npc/ScheduledNPC.tscn").instantiate()
		actor.npc_id = id
		add_child(actor)
		check(actor.portrait_expressions.size() == definition.visual.expressions.size(), id + " all expression regions fit the sheet")
		var event: Dictionary = definition.heart_events.back()
		actor._show_packet(NPCDialogueResolver.packet(event.lines, player.data), player, event)
		actor._dialog_ui._close()
		check(not player.data.completed_events.has(event.id), id + " cancelled event stays incomplete")
		await get_tree().process_frame
		actor._show_packet(NPCDialogueResolver.packet(event.lines, player.data), player, event)
		var dialog: NPCDialogUI = actor._dialog_ui
		for line in dialog.lines.size():
			dialog._advance_dialog()
		check(player.data.completed_events.has(event.id), id + " finished event commits")
		actor.queue_free()
		roots.queue_free()
		await get_tree().process_frame
	# 13 warga lama x 5 tonggak hati + 9 cerita hantu Mbah Darmi (perkenalan dan hati 1-8).
	check(event_count == 65 + 9, "thirteen residents have five heart milestones and Mbah Darmi nine ghost-lore events")
	# Actual map population and physical movement on copied, independent road curves.
	DayCycle.hour = 8
	DayCycle.minute = 0
	var town: Node2D = load("res://scenes/world/town.tscn").instantiate()
	var player_root := town.get_node_or_null("Player")
	if player_root != null:
		player_root.free()
	add_child(town)
	DayCycle.is_running = false
	var presenter := town.get_node("NPCMapPresenter")
	presenter.set_process(false)
	for actor: VillageNPC in presenter.actors.values():
		actor.set_physics_process(false)
	await get_tree().physics_frame
	check(not town.has_node("EmpuBima") and not town.has_node("YSortEntities/ToriNPC") and not town.has_node("YSortEntities/BlacksmithNPC"), "old Wira and Bima duplicates removed from Town")
	for id: String in NEW_WALKERS:
		check(presenter.actors.has(id), id + " is spawned by central presenter")
		if not presenter.actors.has(id):
			continue
		var actor: VillageNPC = presenter.actors[id]
		check(walk(actor), id + " arrival route has no static collision")
	for rainy in [false, true]:
		GameState.weather.current = "rain" if rainy else "sunny"
		for hour in [12, 14, 18, 22, 6, 8]:
			DayCycle.hour = hour
			presenter.refresh()
			for id: String in NEW_WALKERS:
				var actor: VillageNPC = presenter.actors[id]
				check(walk(actor), "%s clear route %02d rain=%s" % [id, hour, rainy])
	# Existing services remain reachable from the same resident menu as chat.
	for id in ["damar", "bima", "joko", "zarathia"]:
		var actor: VillageNPC = presenter.actors.get(id)
		if actor == null:
			# Zarathia comes to Town at 09.00.
			DayCycle.hour = 10
			GameState.weather.current = "sunny"
			presenter.refresh()
			actor = presenter.actors.get(id)
		check(actor != null, id + " service actor present")
		if actor == null:
			continue
		actor._current_activity = "tea_stall" if id == "zarathia" else "working"
		actor.interact(player)
		actor._choose_service(1, player)
		check(is_instance_valid(actor._service_menu), id + " service opens")
		if id in ["joko", "zarathia"]:
			var shop: ShopUI = actor._service_menu
			check(not shop._rows.is_empty() and not shop.shop_data.buys_items, id + " stock loads without an unrestricted resale counter")
			var item: ItemData = shop.shop_data.stock[0]
			var original := GameState._resolve_item(item.item_id)
			check(item != original and original.buy_price != item.buy_price, id + " shop price does not mutate shared item")
			GameState.money = 10000
			var price := shop._unit_price(item, 1)
			var count := player.data.get_item_count(item.item_id)
			shop._buy(item, 1)
			check(GameState.money == 10000 - price and player.data.get_item_count(item.item_id) == count + 1, id + " purchase charges displayed price and grants one item")
			shop.close_shop()
		else:
			actor._service_menu._close()
		await get_tree().process_frame
	var smith: VillageNPC = presenter.actors.bima
	player.data.bag_level = 2
	player.data.add_item_silent("geode", 1)
	var money_before := GameState.money
	smith._current_activity = "working"
	smith.interact(player)
	smith._choose_service(1, player)
	check(is_instance_valid(smith._geode_ui) and GameState.money == money_before, "Bima with geodes opens existing geode service without charging on open")
	if is_instance_valid(smith._geode_ui):
		smith._geode_ui._on_custom_action(&"upgrade")
		check(is_instance_valid(smith._service_menu), "central Bima can switch from geode service to tool upgrade")
		if is_instance_valid(smith._service_menu):
			smith._service_menu._close()
	await get_tree().process_frame
	check(not get_tree().paused, "geode to upgrade transition releases pause after close")
	town.queue_free()
	await get_tree().process_frame
	DayCycle.hour = 10
	var university: Node = load("res://scenes/world/interior/university.tscn").instantiate()
	university.get_node("Furniture/Player").free()
	add_child(university)
	await get_tree().process_frame
	var professor = university.get_node("NPCMapPresenter").actors.get("baskoro")
	check(professor != null and not university.has_node("Furniture/ProfAdrian"), "Baskoro uses central actor without duplicate professor")
	if professor != null:
		professor.interact(player)
		professor._choose_service(0, player)
		check(professor._dialog_ui.social_npc_id == "baskoro", "Baskoro dialogue supports per-player friendship and gifts")
		professor._dialog_ui._close()
	university.queue_free()
	await get_tree().process_frame
	# Rewards for every resident use real recipe IDs and remain independent per character.
	var data := GameState.p1()
	data.bag_level = 2
	for id: String in NPCDatabase.residents:
		NPCSocialService.points(data, id)
		data.friendships[id].points = 2500
	NPCHousehold.advance(data, 1)
	DayCycle.current_day = 2
	for id: String in NPCDatabase.residents:
		var reward: Dictionary = NPCHousehold.rules().recipe_rewards[id][0]
		var key := "friendship_recipe_%s_%s" % [id, reward.recipe]
		check(CookingManager.get_recipe(str(reward.recipe)) != null, id + " reward recipe exists in runtime database")
		var claim := NPCHousehold.claim_letter(data, key)
		check(data.story_mail.has(key) and claim.ok, id + " social recipe mail can be claimed: " + str(claim.message))
		check(not NPCHousehold.claim_letter(data, key).ok, id + " recipe mail cannot be claimed twice")
	var other := GameState.new_coop_character()
	check(other.story_mail.is_empty() and other.completed_events.is_empty(), "new co-op character has independent NPC progress")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(SaveManager._build_save_data()))
	check(SaveManager._is_valid_save(saved), "expanded NPC progress validates in existing save format")
	var mail_count := data.story_mail.size()
	GameState.new_game()
	SaveManager._apply_save(saved)
	check(GameState.p1().story_mail.size() == mail_count and GameState.p1().completed_events.size() >= 13, "new residents' event and mail progress survive save roundtrip")
	player.tool_controller.free()
	player.free()
	check(not get_tree().paused, "resident services release pause when closed")
	print("NPC CENTRALIZATION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
