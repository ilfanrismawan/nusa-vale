extends Node

var failures := 0

func check(value: bool, caption: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + caption)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	GameState.money = 100000
	var store := load("res://resources/cooking/shop/cooking_shop.tres") as CookingShopData
	var catalog := load("res://resources/cooking/data/cooking_catalog.tres") as CookingCatalog
	check(store != null, "editor stock resource loads")
	# Renovasi dapur kini Upgrade Rumah tingkat 1 di Wira (GDD 4.12), bukan stok toko.
	var house := GameState.house
	var sets: Array[CookingShopOffer] = []
	var tools: Array[CookingShopOffer] = []
	for offer in store.offers:
		check(offer.is_valid(), "valid offer: " + str(offer.id))
		if offer.equipment != null:
			tools.append(offer)
		elif offer.kitchen_scene != null:
			sets.append(offer)
	check(not store.offers.any(func(offer: CookingShopOffer): return offer.owned_flag == HouseManager.LEGACY_KITCHEN_FLAG), "kitchen renovation is no longer sold in the shop")
	check(tools.size() == catalog.equipment.size(), "all cooking equipment can be purchased")
	check(sets.size() == 4, "four editable kitchen sets")
	for equipment in catalog.equipment:
		check(tools.any(func(offer: CookingShopOffer): return offer.equipment.id == equipment.id), "stock includes " + str(equipment.id))
	var data := GameState.p1()
	var money := GameState.money
	for offer in tools + sets:
		check(not CookingShopService.purchase(store, offer, data).ok, "locked before house upgrade: " + str(offer.id))
	check(GameState.money == money, "locked purchases do not charge")
	var kitchen := house.next_level()
	data.bag_level = 2
	for item_id in kitchen.materials:
		data.add_item_silent(item_id, kitchen.materials[item_id])
	check(house.order_upgrade(data), "house renovation can be ordered from Wira")
	DayCycle.current_day += kitchen.build_days
	DayCycle.day_passed.emit(DayCycle.current_day)
	check(WorldState.has_flag(HouseManager.LEGACY_KITCHEN_FLAG) and GameState.money == money - kitchen.price, "house upgrade charges exact resource price")
	check(CookingShopService.purchase(store, sets[0], data).ok, "kitchen set unlocks after renovation")
	check(WorldState.has_flag("active_" + str(sets[0].id)), "purchased kitchen set becomes active")
	check(CookingShopService.purchase(store, sets[1], data).ok, "another kitchen color can be purchased")
	check(not WorldState.has_flag("active_" + str(sets[0].id)) and WorldState.has_flag("active_" + str(sets[1].id)), "only one kitchen color is active")
	money = GameState.money
	check(CookingShopService.purchase(store, sets[0], data).ok and GameState.money == money, "owned kitchen sets can be reinstalled for free")
	for offer in tools:
		if not WorldState.has_flag(offer.owned_flag):
			check(CookingShopService.purchase(store, offer, data).ok, "tool installs: " + str(offer.id))
	check(store.installed_equipment().size() == catalog.equipment.size(), "owned equipment feeds household cooking requirements")
	var save := SaveManager._build_save_data()
	WorldState.reset()
	SaveManager._load_world_state(save)
	check(store.installed_equipment().size() == catalog.equipment.size(), "purchases survive existing world flag save/load")
	check(WorldState.has_flag("active_" + str(sets[0].id)), "active kitchen survives save/load")
	var room := load("res://scenes/world/interior/cookware_shop.tscn").instantiate() as Node2D
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	await get_tree().process_frame
	await get_tree().process_frame
	check(room.get_node("Showroom/Fixtures").get_child_count() == 31, "showroom fixtures are separate editable nodes")
	check(room.get_node("Showroom/Obstacles").get_child_count() == 14, "walls, shelves and counter have collision")
	check(room.get_node("Showroom/Fixtures/CenterLeftShelf").position == Vector2(440, 741), "left island matches reference with foot-based Y sort")
	check(room.get_node("Showroom/Fixtures/CenterRightShelf").position == Vector2(840, 741), "right island matches reference with foot-based Y sort")
	var player: Player = room.get_node("Player/CharacterBody2D")
	player.set_physics_process(false)
	await get_tree().physics_frame
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = player.get_node("CollisionShape2D").shape
	query.exclude = [player.get_rid()]
	query.collision_mask = player.collision_mask
	# Dari spawn lewat lorong di antara dua rak tengah (global x ~190-222), lalu ke depan kasir.
	var route: Array[Vector2] = [Vector2(208, 195), Vector2(208, 114), Vector2(300, 114)]
	for segment in route.size() - 1:
		for step in 20:
			var point := route[segment].lerp(route[segment + 1], float(step) / 19.0)
			query.transform = Transform2D(0.0, point)
			check(room.get_world_2d().direct_space_state.intersect_shape(query).is_empty(), "player has a collision-free route to sales counter")
	var counter: Area2D = room.get_node("Showroom/SalesCounterInteraction")
	check(counter.get_node("Trigger").shape.get_rect().has_point(counter.to_local(route.back())), "reachable endpoint overlaps merchant interaction trigger")
	room.get_node("Showroom/SalesCounterInteraction").interact(player)
	await get_tree().process_frame
	var menu: CanvasLayer = room.get_node("Showroom/SalesCounterInteraction")._menu
	check(is_instance_valid(menu) and menu.get_node("%Offers").get_child_count() == store.offers.size(), "actual counter opens native purchase menu")
	var render := OS.get_environment("NUSA_SHOP_SCREENSHOT") == "1" and DisplayServer.get_name() != "headless"
	if render:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://scratch/cookware-shop-menu-preview.png") == OK, "native purchase menu renders")
	menu._close()
	var home := load("res://scenes/world/interior/home_kitchen.tscn").instantiate() as Node2D
	get_tree().root.add_child(home)
	await get_tree().process_frame
	check(home.get_node("RoomDesign/InstalledKitchenSets/wood").visible and not home.get_node("RoomDesign/InstalledKitchenSets/white").visible, "native home furniture uses selected color")
	var home_player: Player = home.get_node("Player/CharacterBody2D")
	home.get_node("RoomDesign/KitchenStation").interact(home_player)
	await get_tree().process_frame
	var cooking_menu: CanvasLayer
	for candidate in get_tree().get_nodes_in_group("player"):
		if candidate is Player:
			candidate.set_physics_process(false)
	for candidate in Coop.ui_parent(home_player).get_children():
		if candidate is CanvasLayer and candidate.get_script() == load("res://scripts/ui/cooking_ui.gd"):
			cooking_menu = candidate
			break
	check(cooking_menu != null and cooking_menu.available_equipment.size() == catalog.equipment.size(), "home opens real cooking with purchased tools")
	if cooking_menu != null:
		cooking_menu._close()
	if render:
		room.hide()
		for child in room.get_node("Player").get_children():
			if child is CanvasLayer:
				child.hide()
		for child in home.get_node("Player").get_children():
			if child is CanvasLayer:
				child.hide()
		home.get_node("KitchenCamera").make_current()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://scratch/home-kitchen-preview.png") == OK, "installed home kitchen renders")
		room.show()
		room.get_node("ShowroomCamera").make_current()
	home.queue_free()
	if render:
		for child in room.get_node("Player").get_children():
			if child is CanvasLayer:
				child.hide()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://scratch/cookware-shop-preview.png") == OK, "showroom screenshot renders")
		print("COOKWARE SHOP SCREENSHOT: E:/nusa-vale/scratch/cookware-shop-preview.png")
	get_tree().current_scene = self
	room.queue_free()
	await get_tree().process_frame
	var custom := tools[0].duplicate() as CookingShopOffer
	custom.owned_flag = "audit_custom_cookware"
	custom.required_flags = PackedStringArray(["audit_missing_requirement"])
	custom.locked_message = "Pasang kitchen set"
	var custom_store := CookingShopData.new()
	custom_store.offers.append(custom)
	money = GameState.money
	check(not CookingShopService.purchase(custom_store, custom, data).ok and GameState.money == money, "editable lock text cannot bypass progression rules")
	custom.required_flags = PackedStringArray()
	var material_id: String = catalog.recipes.recipes[0].ingredients.keys()[0]
	custom.materials = {material_id: 2}
	var inventory_before := data.serialize_inventory()
	check(not CookingShopService.purchase(custom_store, custom, data).ok and GameState.money == money and data.serialize_inventory() == inventory_before, "missing renovation materials cannot charge or partially consume")
	data.add_item(material_id, 2)
	GameState.money = 0
	check(not CookingShopService.purchase(custom_store, custom, data).ok and data.get_item_count(material_id) == 2, "insufficient money preserves renovation materials")
	GameState.money = custom.price + 100
	check(CookingShopService.purchase(custom_store, custom, data).ok and GameState.money == 100 and data.get_item_count(material_id) == 0, "editable material requirements and price are consumed exactly")
	GameState.new_game()
	check(not WorldState.has_flag(HouseManager.LEGACY_KITCHEN_FLAG) and house.level == 0 and store.installed_equipment().is_empty(), "new game clears house and purchase progression")
	print("COOKWARE SHOP COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
