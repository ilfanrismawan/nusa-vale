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
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.current_day = 1
	DayCycle.is_running = false
	FarmManager.farm_data.clear()
	FarmManager.initialize(self)
	var crop := load("res://resources/crop_data/carrot.tres") as CropData
	FarmManager.farm_data[Vector2i(1, 1)] = {"area": "farm", "state": "planted", "crop": crop, "stage": 0, "days_in_stage": 0, "watered": false}
	FarmManager.farm_data[Vector2i(9, 9)] = {"area": "greenhouse", "state": "planted", "crop": crop, "stage": 0, "days_in_stage": 0, "watered": false}
	check(GameState.weather.current == "sunny", "new game starts with clear weather")
	for candidate in range(1, 200):
		GameState.weather.seed = candidate
		if GameState.weather.weather_for(2) == "rain" and GameState.weather.weather_for(3) == "sunny":
			break
	GameState.weather._day = 1
	DayCycle.advance_day()
	var outside: Dictionary = FarmManager.farm_data[Vector2i(1, 1)]
	var inside: Dictionary = FarmManager.farm_data[Vector2i(9, 9)]
	check(GameState.weather.is_raining() and outside.watered and not inside.watered, "rain waters outdoor farm but not greenhouse")
	check(outside.stage == 0 and outside.days_in_stage == 0, "new morning rain does not retroactively grow yesterday's dry crop")
	var prediction := GameState.weather.weather_for(3)
	check(SaveManager.save_game() and SaveManager.load_game(), "weather persists through disk save/load")
	check(GameState.weather.current == "rain" and GameState.weather.weather_for(3) == prediction, "current weather and future sequence survive reload")
	outside = FarmManager.farm_data[Vector2i(1, 1)]
	inside = FarmManager.farm_data[Vector2i(9, 9)]
	check(outside.watered and not inside.watered, "rainy plot state restored without watering greenhouse")
	DayCycle.advance_day()
	check(GameState.weather.current == "sunny" and not outside.watered, "clear day does not automatically irrigate")
	check(int(outside.stage) * crop.days_per_stage + int(outside.days_in_stage) == 1, "previous rainy day advances crop once")
	check(inside.stage == 0 and inside.days_in_stage == 0, "unwatered greenhouse crop does not grow from outdoor rain")
	var legacy := SaveManager._build_save_data()
	legacy.version = 10
	legacy.erase("weather")
	check(SaveManager._is_valid_save(legacy), "old save without weather remains valid")
	GameState.weather.current = "rain"
	SaveManager._apply_save(legacy)
	check(GameState.weather.current == "sunny", "old save receives clear weather default")
	var invalid := SaveManager._build_save_data()
	invalid.weather.current = "storm"
	check(not SaveManager._is_valid_save(invalid), "unsupported weather rejected before changing state")
	var reference := GameState.weather
	GameState.ensure_player(1)
	check(GameState.weather == reference and not GameState.get_player(1).to_dict().has("weather"), "co-op players share one global weather state")
	FarmManager.clear_references()
	print("WEATHER REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
