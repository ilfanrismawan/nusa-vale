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
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	# Keep this runner alive when Coop.start replaces the current scene.
	get_tree().current_scene = null
	await get_tree().process_frame
	for count in [2, 3, 4]:
		GameState.new_game()
		var devices: Array[int] = [PlayerInput.DEVICE_KEYBOARD, PlayerInput.DEVICE_NUMPAD]
		while devices.size() < count:
			devices.append(devices.size() + 10)
		Coop.start(devices)
		await get_tree().create_timer(1.0).timeout
		check(Coop.has_root() and Coop.player_count() == count, "co-op %d starts" % count)
		if not Coop.has_root():
			continue
		for i in count:
			check(is_instance_valid(Coop.root.body_of(i)) and Coop.root.view_of(i) != null, "P%d body and viewport exist" % (i + 1))
		GameState.weather.current = "rain"
		GameState.weather.changed.emit()
		await get_tree().process_frame
		for i in count:
			var weather = Coop.root.view_of(i).get_node_or_null("WeatherViewP%d" % i)
			check(weather != null and weather._rain.visible and Coop.root.body_of(i).hud_ui.weather_label.text == "Hujan", "P%d sees the same outdoor rain and weather status" % (i + 1))
		Coop.root.body_of(0).bind_context()
		var new_plot := Vector2i.ZERO
		var hoed := false
		for candidate in FarmManager.base_layer_ground.get_used_cells():
			if FarmManager.is_tile_farmable(candidate) and FarmManager.hoe(candidate):
				new_plot = candidate
				hoed = true
				break
		check(hoed and FarmManager.farm_data[new_plot].watered and FarmManager.watered_layer.get_cell_source_id(new_plot) != -1, "new outdoor plot is immediately watered and rendered during rain")
		check(FarmManager.plant(new_plot, load("res://resources/crop_data/carrot.tres")) and FarmManager.farm_data[new_plot].watered, "new planting stays watered during the rainy day")
		var p1 := GameState.get_player(0)
		var p2 := GameState.get_player(1)
		var before := p1.get_item_count("seed_carrot")
		p2.add_item("seed_carrot", 1)
		check(p1.get_item_count("seed_carrot") == before and p2.get_item_count("seed_carrot") == before + 1, "inventories are independent")
		GameState.next_spawn_position = Vector2(1113, 290)
		GameState.has_spawn_point = true
		Transition.scene_transition("res://scenes/world/interior/interior_house.tscn", Coop.root.body_of(1))
		await get_tree().create_timer(1.0).timeout
		check(Coop.root.body_of(1).world_root() != Coop.root.body_of(0).world_root(), "P2 enters house while P1 stays outside")
		check(not Coop.root.view_of(1).get_node("WeatherViewP1")._rain.visible and Coop.root.view_of(0).get_node("WeatherViewP0")._rain.visible, "rain visual stays outdoors when another co-op player enters house")
		GameState.next_spawn_position = Vector2(1136, 285)
		GameState.has_spawn_point = true
		Transition.scene_transition("res://scenes/world/farm.tscn", Coop.root.body_of(1))
		await get_tree().create_timer(1.0).timeout
		check(Coop.root.body_of(1).world_root() == Coop.root.body_of(0).world_root(), "P2 returns to shared farm")
		var old_root: Node = Coop.root
		Coop.stop()
		get_tree().current_scene = null
		old_root.queue_free()
		await get_tree().process_frame
	print("COOP SMOKE COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
