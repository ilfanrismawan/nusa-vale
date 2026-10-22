extends Node

const TelevisionScript = preload("res://scripts/world/television.gd")
const TelevisionUIScript = preload("res://scripts/ui/television_ui.gd")

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

	print("=== Test 1: Television Scene & Script Setup ===")
	var tv_scene := load("res://scenes/objects/television.tscn")
	check(tv_scene != null, "Television packed scene loads")
	var tv = tv_scene.instantiate()
	add_child(tv)
	await get_tree().process_frame
	check(tv != null and tv.is_in_group("televisions"), "Television instantiates and is in 'televisions' group")
	check(tv.has_meta("player_interaction") and bool(tv.get_meta("player_interaction")), "Television has player_interaction meta")

	# Check interior_house.gd defines TELEVISION integration
	var room: Node = load("res://scenes/world/interior/interior_house.tscn").instantiate()
	if room.has_node("Player"):
		room.get_node("Player").queue_free()
	add_child(room)
	for f in 3:
		await get_tree().process_frame
	check(room.get_node_or_null("Television") != null, "Interior house scene/script has Television instance")
	room.queue_free()

	print("=== Test 2: Television UI & Weather Forecast ===")
	var player_data := GameState.get_player(0)
	var tv_ui = TelevisionUIScript.new()
	tv_ui.player_data = player_data
	add_child(tv_ui)
	await get_tree().process_frame

	DayCycle.current_day = 10
	var tomorrow := 11
	var expected_weather := GameState.weather.weather_for(tomorrow)
	tv_ui._switch_channel(0)
	var weather_text: String = tv_ui._content_body.text
	if expected_weather == "storm":
		check("BADAI PETIR" in weather_text, "Forecast shows storm warning")
	elif expected_weather == "rain":
		check("HUJAN" in weather_text, "Forecast shows rain advisory")
	else:
		check("CERAH" in weather_text, "Forecast shows sunny weather")

	print("=== Test 3: Television UI & Living Tips ===")
	tv_ui._switch_channel(1)
	check(not tv_ui._content_body.text.is_empty(), "Living tips content is not empty")
	check("🌾" in tv_ui._content_title.text, "Title shows Living tips channel header")

	print("=== Test 4: Television UI & Cooking Recipe Learning ===")
	player_data.learned_recipes.clear()
	var initial_recipe_count := player_data.learned_recipes.size()
	tv_ui._switch_channel(2)
	check(player_data.learned_recipes.size() > initial_recipe_count, "Player learned new recipe from Dapur Nusantara broadcast")
	var learned_id: String = player_data.learned_recipes[0]
	check(CookingManager.knows(player_data, learned_id), "CookingManager confirms recipe is known")

	# Switching to cooking channel again shouldn't duplicate learned recipe
	var count_after_learn := player_data.learned_recipes.size()
	tv_ui._switch_channel(2)
	check(player_data.learned_recipes.size() == count_after_learn, "Re-watching does not duplicate learned recipe")

	print("=== Test 5: UI Close & Cleanup ===")
	tv_ui._close()
	await get_tree().process_frame
	check(tv_ui.is_queued_for_deletion(), "Television UI is queued for deletion on close")

	tv.queue_free()

	print("TELEVISION REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
