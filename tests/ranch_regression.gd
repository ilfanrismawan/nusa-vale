extends Node

var failures := 0

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func building(id: int, item: String, cell: Vector2i) -> Dictionary:
	return {"uid": id, "item": item, "cell": [cell.x, cell.y], "storage": [], "open": false, "job": {}, "ready": {}}

func new_day() -> void:
	DayCycle.current_day += 1
	DayCycle.hour = 6
	StructureManager._advance_chickens(DayCycle.current_day)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.current_day = 1
	DayCycle.is_running = false
	GameState.money = 100000
	var data := GameState.ensure_player(0)
	data.bag_level = 2
	data.inventory.fill(null)
	data.add_item_silent("hay", 99)
	data.add_item_silent("milk_pail", 1)
	data.add_item_silent("shears", 1)
	data.add_item_silent("animal_brush", 1)
	StructureManager.records.assign([building(1, "barn", Vector2i.ZERO), building(2, "chicken_coop", Vector2i(10, 0)), building(3, "silo", Vector2i(20, 0)), building(4, "pasture_grass", Vector2i(2, 6))])
	var barn := StructureManager.record_for(1)
	var coop := StructureManager.record_for(2)
	check(StructureManager.buy_animal(1, "cow", "Sari").ok and StructureManager.buy_animal(1, "goat", "Kiki").ok and StructureManager.buy_animal(1, "sheep", "Bulu").ok, "cow/goat/sheep purchased into barn")
	check(not StructureManager.buy_animal(1, "duck").ok, "species cannot enter wrong housing")
	var animals := StructureManager.coop_state(barn)
	check(StructureManager.feed_chickens(data, 1).ok and data.get_item_count("hay") == 96, "barn feed costs one hay per animal")
	check(StructureManager.pet_chicken(1, 1).ok and not StructureManager.pet_chicken(1, 1).ok, "shared petting is once daily")
	check(StructureManager.brush_animal(data, 1, 1).ok and not StructureManager.brush_animal(data, 1, 1).ok, "brushing requires brush and cannot repeat")
	new_day()
	check(animals.chickens[0].ready == "cow_milk" and animals.chickens[1].ready == "" and animals.chickens[2].ready == "", "species production intervals: day one only cow ready")
	check(StructureManager.harvest_animal(data, 1, 1).ok and data.get_item_count("cow_milk") == 1 and not StructureManager.harvest_animal(data, 1, 1).ok, "milk harvest consumes readiness once")
	check(StructureManager.clean_ranch(data, 1).ok and animals.dirt == 0, "one cleaning clears one daily dirt")
	StructureManager.feed_chickens(data, 1)
	new_day()
	check(animals.chickens[1].ready == "goat_milk" and animals.chickens[2].ready == "", "goat ready after two cared days")
	StructureManager.feed_chickens(data, 1)
	StructureManager.clean_ranch(data, 1)
	new_day()
	check(animals.chickens[2].ready == "wool", "sheep ready after three cared days")
	var other := GameState.ensure_player(1)
	other.bag_level = 0
	for slot in other.bag_size:
		other.inventory[slot] = {"item": GameState._resolve_item("stone"), "count": 99}
	other.inventory[0] = {"item": GameState._resolve_item("shears"), "count": 1}
	check(not StructureManager.harvest_animal(other, 1, 3).ok and animals.chickens[2].ready == "wool", "full co-op bag preserves ready wool")
	other.inventory[1] = null
	check(StructureManager.harvest_animal(other, 1, 3).ok and other.get_item_count("wool") == 1 and data.get_item_count("wool") == 0, "harvest belongs to interacting player's inventory")
	var before := data.stamina
	check(not StructureManager.harvest_animal(data, 1, 3).ok and data.stamina == before, "failed harvesting costs no stamina")
	new_day()
	new_day()
	check(animals.chickens[0].sick and animals.chickens.size() == 3, "two hungry days cause illness without losing animals")
	while int(animals.dirt) > 0:
		StructureManager.clean_ranch(data, 1)
	StructureManager.feed_chickens(data, 1)
	new_day()
	check(not animals.chickens[0].sick, "one full fed/clean day recovers illness")
	check(StructureManager.buy_animal(2, "duck", "Duki").ok, "duck available in coop")
	var birds := StructureManager.coop_state(coop)
	birds.chickens[0].affection = 85
	StructureManager.feed_chickens(data, 2)
	new_day()
	StructureManager.clean_ranch(data, 2)
	StructureManager.feed_chickens(data, 2)
	new_day()
	check(birds.products.get("duck_egg_large_gold", 0) == 1, "duck produces large gold egg after two cared days")
	check(StructureManager.collect_eggs(data, 2).ok and data.get_item_count("duck_egg_large_gold") == 1, "quality product reaches inventory")
	check(StructureManager.store_hay(data, 1, 10).ok and animals.hay == 10, "ranch stores actual hay portions")
	data.add_item_silent("wood", 400)
	data.add_item_silent("stone", 250)
	check(StructureManager.upgrade_ranch(data, 1).ok and RanchHusbandry.capacity(animals) == 8 and StructureManager.upgrade_ranch(data, 1).ok and RanchHusbandry.capacity(animals) == 12, "two paid upgrades unlock 8/12 capacity")
	animals.hay = 1
	StructureManager.record_for(3).hay = 6
	new_day()
	check(animals.hay == 0 and StructureManager.record_for(3).hay == 4 and animals.chickens[2].fed_day == DayCycle.current_day, "Deluxe consumes local hay then shared silo exactly")
	var silo_before: int = StructureManager.record_for(3).hay
	StructureManager._advance_chickens(DayCycle.current_day)
	check(StructureManager.record_for(3).hay == silo_before, "repeated day processing cannot consume silo twice")
	GameState.weather.current = "rain"
	check(not StructureManager.toggle_ranch_door(1).ok, "rain prevents opening grazing door")
	GameState.weather.current = "sunny"
	check(StructureManager.toggle_ranch_door(1).ok, "sunny day opens grazing door")
	animals.chickens[0].fed_day = DayCycle.current_day - 1
	check(StructureManager.graze_animal(1, 1, 4).ok and not StructureManager.graze_animal(1, 2, 4).ok, "one grass patch feeds only one animal")
	check(StructureManager.record_for(4).regrow_day == DayCycle.current_day + 2, "grazed patch regrows after two days")
	StructureManager._ranch_time(18, 0)
	check(not animals.door, "animals return safely at 18:00")
	check(SaveManager.save_game() and SaveManager.load_game(), "new ranch state survives real disk save/load")
	animals = StructureManager.coop_state(StructureManager.record_for(1))
	check(animals.chickens[0].name == "Sari" and animals.tier == 2 and animals.chickens[0].species == "cow", "names/species/upgrades persist")
	var invalid := SaveManager._build_save_data()
	invalid.structures[0].livestock.chickens[0].ready = "gold_bar"
	check(not SaveManager._is_valid_save(invalid), "foreign ready product is rejected without world mutation")
	var legacy := {"chickens": [{"id": 1, "name": "Lama", "variant": "white", "fed_day": 0, "pet_day": 0, "affection": 42}], "eggs": 3, "next_id": 2, "last_day": DayCycle.current_day}
	check(RanchHusbandry.valid(legacy), "legacy chicken save accepted")
	RanchHusbandry.migrate(legacy)
	check(legacy.eggs == 3 and legacy.chickens[0].affection == 42 and legacy.chickens[0].species == "chicken", "migration preserves old eggs and affection")
	var machine := building(10, "cheese_press", Vector2i(30, 0))
	StructureManager.records.append(machine)
	data.add_item_silent("cow_milk_large_gold", 1)
	check(StructureManager.process_animal_product(data, 10, "cow_milk_large_gold").ok and data.get_item_count("cow_milk_large_gold") == 0, "cheese press consumes one quality milk")
	check(not StructureManager.process_animal_product(data, 10, "cow_milk").ok and not StructureManager.pack(data, 10).ok, "busy artisan cannot overwrite a job or be packed")
	check(SaveManager.save_game() and SaveManager.load_game(), "artisan process survives disk save/load")
	machine = StructureManager.records[-1]
	DayCycle.is_running = true
	StructureManager._process(21)
	DayCycle.is_running = false
	check(machine.ready.get("id") == "cheese_large_gold", "artisan preserves product size and gold quality")
	check(StructureManager.collect(data, machine.uid).ok and data.get_item_count("cheese_large_gold") == 1, "finished cheese collected exactly once")
	check(StructureManager.artisan_output("loom", "wool_silver") == "cloth_silver" and StructureManager.artisan_output("mayonnaise_maker", "duck_egg") == "duck_mayonnaise", "wool and duck egg have matching artisan recipes")
	check(GameState._resolve_item("cheese_large_gold").sell_price > GameState._resolve_item("cow_milk_large_gold").sell_price, "processing raises the sale value")
	data.add_item_silent("hay", 20)
	StructureManager.records.append(building(11, "barn", Vector2i(40, 0)))
	StructureManager.records.append(building(12, "chicken_coop", Vector2i(50, 0)))
	check(StructureManager.buy_animal(11, "pig", "Ndut").ok and not StructureManager.buy_animal(11, "ostrich").ok and StructureManager.buy_animal(12, "ostrich", "Jangkung").ok, "pig lives in the barn and ostrich in the poultry coop")
	var sty := StructureManager.coop_state(StructureManager.record_for(11))
	var nest := StructureManager.coop_state(StructureManager.record_for(12))
	sty.chickens[0].affection = 90
	nest.chickens[0].affection = 90
	for day in 3:
		StructureManager.feed_chickens(data, 11)
		StructureManager.feed_chickens(data, 12)
		new_day()
		while int(sty.dirt) > 0:
			StructureManager.clean_ranch(data, 11)
		while int(nest.dirt) > 0:
			StructureManager.clean_ranch(data, 12)
		if day == 1:
			check(sty.chickens[0].ready.is_empty(), "pig needs three cared days per truffle")
		if day == 2:
			check(sty.chickens[0].ready == "truffle_gold" and RanchHusbandry.valid(sty, "barn"), "a loved pig finds a gold truffle after three cared days (no large size)")
			check(StructureManager.harvest_animal(data, 11, 1).ok and data.get_item_count("truffle_gold") == 1, "truffle is taken by hand without a tool")
	check(int(nest.products.get("ostrich_egg_gold", 0)) == 1 and RanchHusbandry.valid(nest, "chicken_coop"), "a loved ostrich lays a gold egg after three cared days")
	check(StructureManager.collect_eggs(data, 12).ok and data.get_item_count("ostrich_egg_gold") == 1, "ostrich eggs are collected with the coop eggs")
	check(RanchHusbandry.base_egg("ostrich_egg_gold") == "ostrich_egg" and RanchHusbandry.HATCH.ostrich_egg.species == "ostrich", "ostrich eggs hatch in the incubator")
	check(not StructureManager.brush_animal(data, 12, 1).ok, "ostrich is poultry and is petted, not brushed")
	for kind in RanchHusbandry.SPECIES:
		check(RanchVisual.frames(kind).get_frame_count(&"default") == 2, "owned sprite loaded for " + kind)
		for direction in ["side", "down", "up"]:
			for baby in [false, true]:
				var walk := RanchVisual.frames(kind, "white", true, direction, baby)
				check(walk.get_frame_count(&"default") >= 4 and walk.get_frame_texture(&"default", 0).get_image() != null and not walk.get_frame_texture(&"default", 0).get_image().is_invisible(), "%s %s walk frame has pixels (baby=%s)" % [kind, direction, baby])
	check(RanchVisual.sheet_path("capybara").begins_with("Forest/") and RanchVisual.sheet_path("cow").begins_with("Farm/"), "livestock sprites come from the Farm/Forest pack folders")
	check(RanchVisual.sheet_path("cow", "white", true).contains("Baby") and not RanchVisual.has_baby_sheet("buffalo"), "calves use the pack's baby sheet; buffalo falls back to the adult sheet")
	check(RanchVisual.sheet_path("horse", "flaxen") == "Farm/Horse/2/idle.png" and RanchVisual.frames("horse", "bay", true, "side").get_frame_count(&"default") == 6, "pasture horse uses Farm/Horse coats and its run sheet")
	RanchVisual._cache.clear()
	ChickenVisual._cache.clear()
	# Let short care SFX finish before tearing down the audio server.
	await get_tree().create_timer(1.0, true).timeout
	print("RANCH REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit.call_deferred(1 if failures else 0)
