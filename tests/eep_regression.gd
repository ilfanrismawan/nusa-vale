extends Node

var failures := 0

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1
		push_error(label)

func walk(actor: VillageNPC) -> bool:
	await get_tree().physics_frame
	var stalled := 0
	for step in 12000:
		if not actor._is_walking:
			actor._physics_process(1.0 / 60.0)
			return actor.global_position.distance_to(actor._target_pos) <= 3.0
		var before := actor.global_position
		actor._physics_process(1.0 / 60.0)
		var moved := before.distance_to(actor.global_position)
		# move_and_slide uses the engine frame delta, even when called manually.
		var allowed := actor.walk_speed * maxf(actor.get_process_delta_time(), actor.get_physics_process_delta_time()) + 1.0
		if moved > allowed:
			return false
		stalled = stalled + 1 if moved < 0.01 else 0
		if stalled > 320:
			print("BLOCKED EEP: ", actor.global_position, " -> ", actor._active_path[0])
			return false
	return false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.current_day = 1
	DayCycle.hour = 7
	DayCycle.minute = 0
	DayCycle.is_running = false
	GameState.weather.current = "rain"
	check(NPCDatabase.residents.has("eep"), "Eep registered through resident resource")
	var definition: Dictionary = NPCDatabase.residents.eep
	check(definition.service == "livestock" and not definition.romanceable, "Eep social and service metadata loaded")
	var frames: SpriteFrames = load(definition.visual.sprite_frames)
	for animation in ["idle_down", "idle_up", "idle_right", "walk_down", "walk_up", "walk_right"]:
		check(frames.has_animation(animation) and frames.get_frame_count(animation) > 0, "Eep has " + animation)
	var world: Node = load("res://scenes/world/interior/eep_home.tscn").instantiate()
	var player_scene := world.get_node_or_null("Player")
	if player_scene != null:
		player_scene.free()
	for body in world.find_children("*", "CharacterBody2D", true, false):
		body.free()
	add_child(world)
	DayCycle.is_running = false
	var presenter := world.get_node("NPCMapPresenter")
	presenter.set_process(false)
	for actor: VillageNPC in presenter.actors.values():
		actor.set_physics_process(false)
	await get_tree().physics_frame
	var eep: VillageNPC = presenter.actors.eep
	check(eep.global_position.distance_to(world.get_node("NPCPaths/EepGateway").global_position) < 3.0, "Eep enters through ranch house doorway")
	check((await walk(eep)), "Eep walks from house doorway to shop counter without obstruction")
	check(not eep._service_available(), "feed checks precede shop opening")
	var network := world.get_node("NPCPaths")
	var eep_curve: Path2D = network.get_node("Eep_stall")
	check(str(eep_curve.npc_id) == "eep", "Eep owns editable Path2D curves")
	DayCycle.hour = 9
	presenter.refresh()
	check((await walk(eep)) and eep._service_available(), "shop opens at 09:00")
	var player := Player.new()
	player.tool_controller = ToolController.new()
	eep.interact(player)
	check(eep._service_menu.get_node("%Service").visible and eep._service_menu.get_node("%Service").text == "Beli Hewan Ternak", "Eep offers explicit livestock service")
	eep._choose_service(1, player)
	var shop: CanvasLayer = eep._service_menu
	check(shop.get_node("%VendorName").text == "Eep" and shop.get_node("%ShopTitle").text == "Peternakan Eep", "shop uses Eep presentation and identity")
	check(shop.get_node("%Vendor").texture != null and shop._species_order.size() == 5, "Eep portrait and all five livestock species available")
	check(shop.get_node("%PurchaseLivestock").disabled, "missing housing prevents purchase")
	GameState.money = 100000
	var before_money := GameState.money
	shop._buy()
	check(GameState.money == before_money, "invalid housing does not charge money")
	var barn := {"uid": 101, "item": "barn", "cell": [44, 18], "storage": [], "open": false, "job": {}, "ready": {}}
	var coop := {"uid": 102, "item": "chicken_coop", "cell": [56, 18], "storage": [], "open": false, "job": {}, "ready": {}}
	StructureManager.records.assign([barn, coop])
	StructureManager._next_uid = 103
	shop._refresh()
	check(not shop.get_node("%PurchaseLivestock").disabled and shop._target_uid == 102, "shop chooses matching poultry housing")
	shop._animal_name = "Pipit"
	shop._buy()
	check(GameState.money == before_money - int(RanchHusbandry.SPECIES.chicken.price) and StructureManager.coop_state(coop).chickens[0].name == "Pipit", "chicken purchase charges once and saves named animal")
	shop._select("cow")
	shop._buy()
	check(StructureManager.coop_state(barn).chickens.size() == 1 and StructureManager.coop_state(barn).chickens[0].species == "cow", "cow purchase uses barn instead of poultry housing")
	shop._select("chicken")
	for index in 3:
		StructureManager.buy_animal(102, "chicken")
	shop._refresh()
	before_money = GameState.money
	shop._buy()
	check(shop.get_node("%PurchaseLivestock").disabled and GameState.money == before_money and StructureManager.coop_state(coop).chickens.size() == 4, "full housing rejects duplicate charge and excess animals")
	shop._close()
	await get_tree().process_frame
	check(not get_tree().paused and not is_instance_valid(eep._service_menu), "shop close clears NPC menu and solo pause")
	eep.interact(player)
	check(eep._service_menu.supplies_available, "Eep offers ranch feed and tools while open")
	eep._choose_service(6, player)
	var supplies: ShopUI = eep._service_menu
	check(supplies.shop_data.stock.size() == 5, "ranch supplies include feed, hay, brush, pail and shears")
	var feed: ItemData = supplies.shop_data.stock[0]
	var feed_before := player.data.get_item_count(feed.item_id)
	before_money = GameState.money
	var price := supplies._unit_price(feed, 1)
	supplies._buy(feed, 1)
	check(player.data.get_item_count(feed.item_id) == feed_before + 1 and GameState.money == before_money - price, "ranch supplies charge once and deliver feed")
	supplies.close_shop()
	await get_tree().process_frame
	DayCycle.hour = 12
	presenter.refresh()
	check((await walk(eep)) and not eep._service_available(), "Eep walks to lunch and closes shop")
	DayCycle.hour = 13
	presenter.refresh()
	check((await walk(eep)) and eep._service_available(), "Eep returns to stall after lunch")
	DayCycle.current_day = 3
	check(not eep._service_available(), "Wednesday closed day follows JSON")
	eep.interact(player)
	check(not eep._service_menu.get_node("%Service").visible, "closed shop still allows conversation without a purchase button")
	eep._choose_service(0, player)
	check(eep._dialog_ui._gift_button != null, "Eep conversation supports friendship and gifts")
	eep._dialog_ui._close()
	await get_tree().process_frame
	DayCycle.current_day = 1
	var fixture := PlayerData.new()
	fixture.inventory[9] = {"item": GameState._resolve_item("hay"), "count": 2}
	var gift := NPCSocialService.give(fixture, "eep", 9)
	check(gift.ok and gift.taste == "liked" and fixture.inventory[9].count == 1, "Eep gift tastes resolve existing items")
	NPCSocialService.points(player.data, "eep")
	player.data.friendships.eep.points = 1000
	DayCycle.hour = 15
	var point: Vector2 = world.get_node("NPCPoints/eep_stall").global_position
	var event := NPCEventService.find_event(player.data, "eep", "eep_home", world.get_node("NPCPoints"), point, eep.global_position)
	check(not event.is_empty(), "Eep four-heart event matches authored conditions")
	NPCEventService.complete(player.data, event)
	check(player.data.story_flags.get("eep_ranch_trust", false), "Eep event completion persists trust flag")
	DayCycle.hour = 17
	presenter.refresh()
	check((await walk(eep)) and not eep._service_available(), "Eep walks to evening rest and closes shop")
	DayCycle.hour = 22
	presenter.refresh()
	check((await walk(eep)) and eep.visible and eep._current_activity == "sleeping", "Eep reaches bed inside his actual house")
	check(not eep._service_available(), "sleeping Eep never sells livestock")
	DayCycle.current_day = 2
	DayCycle.hour = 7
	presenter.refresh()
	check((await walk(eep)) and eep.visible and eep.collision_mask == 1, "Eep returns to sheltered feed checks next morning")
	DayCycle.hour = 12
	presenter.refresh()
	check((await walk(eep)) and eep._target_pos.distance_to(world.get_node("NPCPoints/eep_lunch").global_position) < 3.0, "rainy lunch stays inside the house")
	world.queue_free()
	player.tool_controller.free()
	player.free()
	await get_tree().process_frame
	print("EEP REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
