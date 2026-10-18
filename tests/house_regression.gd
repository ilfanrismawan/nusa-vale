extends Node

## Upgrade rumah di Wira (GDD 4.12, save v17): data tingkat, pesanan, hari pengerjaan,
## bonus stamina, flag dapur, save/load + migrasi save lama, menu tukang kayu, pintu dapur.
## Tidak menulis save ke disk.

var failures := 0
var _log: PackedStringArray = []

func check(value: bool, label: String) -> void:
	_log.append(("PASS: " if value else "FAIL: ") + label)
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func settle() -> void:
	for frame in 5:
		await get_tree().process_frame

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	DayCycle.current_day = 3
	_test_data()
	_test_order()
	_test_save()
	await _test_menu()
	await _test_kitchen_door()
	GameState.new_game()
	check(GameState.house.level == 0 and not GameState.house.is_building() and GameState.p1().max_stamina == PlayerData.MAX_STAMINA, "new game resets the house")
	print("HOUSE REGRESSION COMPLETE: failures=%d" % failures)
	_log.append("HOUSE REGRESSION COMPLETE: failures=%d" % failures)
	var file := FileAccess.open("user://house_regression.log", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log))
		file.close()
	await get_tree().create_timer(40.0).timeout
	get_tree().quit(1 if failures > 0 else 0)

func _give(data: PlayerData, level: HouseLevelData) -> void:
	data.bag_level = 2
	for id in level.materials:
		data.add_item_silent(id, level.materials[id])
	GameState.money = maxi(GameState.money, level.price)

func _pass_days(count: int) -> void:
	for day in count:
		DayCycle.current_day += 1
		DayCycle.day_passed.emit(DayCycle.current_day)

func _test_data() -> void:
	var house := GameState.house
	check(house.max_level() == 3, "three house levels")
	for number in range(1, house.max_level() + 1):
		var level := house.data_for(number)
		check(level != null and not level.display_name.is_empty() and level.price > 0 and level.build_days > 0, "level %d has name, price, days" % number)
		for id in level.materials:
			check(GameState._resolve_item(id) != null, "level %d material exists: %s" % [number, id])
	check(house.data_for(1).grants_flags.has(HouseManager.LEGACY_KITCHEN_FLAG), "level 1 opens the existing kitchen room")
	check(house.data_for(2).stamina_bonus > 0 and house.data_for(3).stamina_bonus > 0, "levels 2 and 3 raise max stamina")

func _test_order() -> void:
	var house := GameState.house
	var data := GameState.p1()
	GameState.money = 0
	check(not house.order_upgrade(data) and not house.is_building(), "no money: order refused")
	var kitchen := house.next_level()
	_give(data, kitchen)
	var money := GameState.money
	check(house.order_upgrade(data), "kitchen upgrade ordered")
	check(GameState.money == money - kitchen.price and data.get_item_count("wood") == 0, "price and materials consumed")
	check(house.is_building() and house.days_remaining() == kitchen.build_days and house.level == 0, "work takes days")
	check(not house.can_order(data), "only one order at a time")
	_pass_days(kitchen.build_days - 1)
	check(house.level == 0 and not WorldState.has_flag(HouseManager.LEGACY_KITCHEN_FLAG), "not finished early")
	_pass_days(1)
	check(house.level == 1 and not house.is_building() and WorldState.has_flag(HouseManager.LEGACY_KITCHEN_FLAG), "kitchen finished after build days")
	check(data.max_stamina == PlayerData.MAX_STAMINA, "level 1 gives no stamina bonus")
	var bedroom := house.next_level()
	_give(data, bedroom)
	check(house.order_upgrade(data), "bedroom ordered")
	_pass_days(bedroom.build_days)
	check(house.level == 2 and data.max_stamina == PlayerData.MAX_STAMINA + bedroom.stamina_bonus, "bedroom raises max stamina")
	var p2 := GameState.ensure_player(1)
	check(p2.max_stamina == data.max_stamina, "bonus applies to co-op players too")
	GameState.players.resize(1)

func _test_save() -> void:
	var house := GameState.house
	var data := GameState.p1()
	var grand := house.next_level()
	_give(data, grand)
	check(house.order_upgrade(data), "grand house ordered")
	data.stamina = data.max_stamina
	var saved := SaveManager._build_save_data()
	check(int(SaveManager.SAVE_VERSION) == 17 and saved.has("house") and SaveManager._is_valid_save(saved), "save v17 stores the house")
	var json: Dictionary = JSON.parse_string(JSON.stringify(saved))
	GameState.new_game()
	SaveManager._apply_save(json)
	check(house.level == 2 and house.is_building() and int(house.order.level) == 3, "level and pending order survive save/load")
	check(GameState.p1().stamina == PlayerData.MAX_STAMINA + 20, "saved stamina above 100 is not clipped")
	_pass_days(house.days_remaining())
	check(house.level == 3 and WorldState.has_flag("house_cellar_upgraded"), "loaded order still finishes")
	var bad := saved.duplicate(true)
	bad.house = {"level": "x"}
	check(not SaveManager._is_valid_save(bad), "malformed house data is rejected")
	# Save v16: tidak ada "house", dapur dibeli di toko lama.
	var legacy := saved.duplicate(true)
	legacy.erase("house")
	legacy.version = 16
	legacy.world_state = {HouseManager.LEGACY_KITCHEN_FLAG: true}
	GameState.new_game()
	SaveManager._apply_save(legacy)
	check(SaveManager._is_valid_save(legacy) and house.level == 1 and not house.is_building(), "v16 kitchen renovation migrates to house level 1")
	legacy.world_state = {}
	GameState.new_game()
	SaveManager._apply_save(legacy)
	check(house.level == 0, "v16 save without kitchen starts at level 0")

func _test_menu() -> void:
	GameState.new_game()
	var rig = load("res://scenes/player/Player.tscn").instantiate()
	add_child(rig)
	var player: Player = rig.get_node("CharacterBody2D")
	player.set_process(false)
	player.set_physics_process(false)
	var menu = load("res://scenes/ui/carpenter_menu.tscn").instantiate()
	menu.player = player
	add_child(menu)
	await settle()
	check(menu._selected_id == menu.HOUSE_ID and menu.get_node("%DetailTitle").text.contains(GameState.house.data_for(1).display_name), "Wira's menu opens on the house upgrade")
	check(menu.get_node("%ChooseButton").disabled and menu.get_node("%Materials").get_child_count() == GameState.house.data_for(1).materials.size(), "house detail lists materials; missing ones block")
	_give(player.data, GameState.house.data_for(1))
	GameState.money_changed.emit(GameState.money)
	await settle()
	check(not menu.get_node("%ChooseButton").disabled, "materials in the bag enable the order")
	menu._choose_selected()
	await settle()
	check(GameState.house.is_building() and is_instance_valid(menu) and menu.get_node("%ChooseButton").disabled, "ordering from the menu starts the build and keeps the menu open")
	menu._select("barn")
	check(menu.get_node("%DetailTitle").text == GameState._resolve_item("barn").display_name, "farm buildings still listed")
	menu.queue_free()
	rig.queue_free()
	await settle()
	check(not get_tree().paused, "menu closes cleanly")

func _test_kitchen_door() -> void:
	var room: Node = load("res://scenes/world/interior/interior_house.tscn").instantiate()
	room.get_node("Player").queue_free()
	add_child(room)
	await settle()
	var door: Node = room.get_node_or_null("KitchenDoor")
	check(door != null and door.get("required_flag") == HouseManager.LEGACY_KITCHEN_FLAG, "house interior has the kitchen door")
	room.queue_free()
	await settle()
