extends Node

var failures := 0

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	GameState.new_game()
	StructureManager.reset()

	print("=== Test 1: Dynamic Quality Resolution & Pricing ===")
	var potato_normal := GameState._resolve_item("potato")
	var potato_silver := GameState._resolve_item("potato_silver")
	var potato_gold := GameState._resolve_item("potato_gold")
	check(potato_normal != null, "Normal potato resolves")
	check(potato_silver != null and potato_silver.quality == ItemData.Quality.SILVER, "Silver potato resolves dynamically with quality SILVER")
	check(potato_gold != null and potato_gold.quality == ItemData.Quality.GOLD, "Gold potato resolves dynamically with quality GOLD")
	check(potato_silver.sell_price == int(potato_normal.sell_price * 1.25), "Silver price is 1.25x base: %d vs %d" % [potato_silver.sell_price, int(potato_normal.sell_price * 1.25)])
	check(potato_gold.sell_price == int(potato_normal.sell_price * 1.5), "Gold price is 1.5x base: %d vs %d" % [potato_gold.sell_price, int(potato_normal.sell_price * 1.5)])

	print("=== Test 2: Permanent Fruit Trees & Seasonal Resistance ===")
	FarmManager.farm_data.clear()
	var apple_crop := load("res://resources/crop_data/apple.tres") as CropData
	check(apple_crop != null and apple_crop.is_fruit_tree(), "Apple is recognized as fruit tree")
	FarmManager.farm_data[Vector2i(5, 5)] = {
		"area": "farm",
		"state": "planted",
		"crop": apple_crop,
		"stage": apple_crop.get_total_stages() - 1,
		"days_in_stage": 0,
		"watered": true
	}
	check(FarmManager.can_harvest(Vector2i(5, 5)), "Mature apple tree can be harvested")
	var harvested := FarmManager.harvest(Vector2i(5, 5))
	check(harvested, "Harvest succeeded")
	var tree_data: Dictionary = FarmManager.farm_data.get(Vector2i(5, 5), {})
	check(tree_data.get("crop") == apple_crop, "Fruit tree is not erased upon harvest")
	check(int(tree_data.get("stage", 0)) == apple_crop.get_total_stages() - 2, "Fruit tree stage set to regrow stage (%d)" % (apple_crop.get_total_stages() - 2))

	# Season advance: make sure apple tree does NOT wither even when season changes to winter
	DayCycle.current_day = 84 # last day of fall
	DayCycle.advance_day() # advances to winter (day 85)
	check(DayCycle.get_current_season() == "winter", "Day transitioned to winter")
	var winter_tree: Dictionary = FarmManager.farm_data.get(Vector2i(5, 5), {})
	check(winter_tree.get("crop") == apple_crop, "Fruit tree survives season change into winter without withering")

	print("=== Test 3: Artisan Machines (Keg, Oil Maker, Fish Smoker) ===")
	check(StructureManager.IDS.has("keg"), "Keg is registered in StructureManager.IDS")
	check(StructureManager.IDS.has("oil_maker"), "Oil Maker is registered in StructureManager.IDS")
	check(StructureManager.IDS.has("fish_smoker"), "Fish Smoker is registered in StructureManager.IDS")
	check(StructureManager.IDS.has("lightning_rod"), "Lightning Rod is registered in StructureManager.IDS")

	# Test outputs
	check(StructureManager.artisan_output("keg", "wheat") == "beer", "Keg converts wheat -> beer")
	check(StructureManager.artisan_output("keg", "grape") == "wine", "Keg converts grape -> wine")
	check(StructureManager.artisan_output("keg", "honey") == "mead", "Keg converts honey -> mead")
	check(StructureManager.artisan_output("oil_maker", "corn") == "oil", "Oil Maker converts corn -> oil")
	check(StructureManager.artisan_output("oil_maker", "truffle") == "truffle_oil", "Oil Maker converts truffle -> truffle_oil")
	check(StructureManager.artisan_output("fish_smoker", "fish_salmon") == "smoked_fish", "Fish Smoker converts raw fish -> smoked_fish")
	check(StructureManager.artisan_output("fish_smoker", "fish_salmon_gold") == "smoked_fish_gold", "Fish Smoker preserves gold quality")

	# Test artisan job processing
	var player := GameState.current
	player.load_inventory([])
	player.add_item_silent("wheat", 1)
	var keg_record := {
		"uid": 777,
		"item": "keg",
		"cell": [10, 10],
		"storage": [],
		"open": false,
		"job": {},
		"ready": {}
	}
	StructureManager.records.append(keg_record)
	var proc := StructureManager.process_animal_product(player, 777, "wheat")
	check(proc.ok and not keg_record.job.is_empty(), "Keg starts processing wheat")
	keg_record.job.seconds = 0.05
	DayCycle.is_running = true
	StructureManager._process(0.1) # finish processing
	check(not keg_record.ready.is_empty() and keg_record.ready.id == "beer", "Keg finishes and produces beer")
	var col := StructureManager.collect(player, 777)
	check(col.ok and player.has_item("beer"), "Beer collected into player bag")

	print("=== Test 4: Lightning Rod & Badai Petir (Storm) ===")
	check(DailyWeather.STATES.has("storm"), "DailyWeather supports 'storm'")
	GameState.weather.current = "storm"
	check(GameState.weather.is_storm(), "is_storm() returns true during storm")
	check(GameState.weather.is_raining(), "is_raining() returns true during storm for auto-watering")
	check(GameState.weather.display_name() == "Badai Petir", "display_name is 'Badai Petir'")

	var rod_record := {
		"uid": 888,
		"item": "lightning_rod",
		"cell": [12, 12],
		"storage": [],
		"open": false,
		"job": {},
		"ready": {}
	}
	StructureManager.records.append(rod_record)
	StructureManager._advance_lightning_rods()
	check(not rod_record.ready.is_empty() and rod_record.ready.id == "battery_pack", "Lightning Rod captures storm energy and generates battery_pack")
	var col_bat := StructureManager.collect(player, 888)
	check(col_bat.ok and player.has_item("battery_pack"), "Battery Pack collected into player bag")

	print("ARTISAN PRODUCTION REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
