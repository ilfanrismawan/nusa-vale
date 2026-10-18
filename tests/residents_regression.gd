extends Node

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	var shipping_before := GameState.shipping.to_save().duplicate(true)
	for id in ["wira", "ubay"]:
		var data: Dictionary = NPCDatabase.residents[id]
		var frames: SpriteFrames = load(data.visual.sprite_frames)
		for animation in ["idle_down", "idle_up", "idle_right", "walk_down", "walk_up", "walk_right", "idle_side", "walk_side"]:
			check(frames.has_animation(animation) and frames.get_frame_count(animation) > 0, id + " animation " + animation)
		check(data.romanceable == (id == "ubay"), id + " romance metadata")
	# Every schedule target must resolve to an actual Marker2D in its map.
	var paths := {"hill": "res://scenes/world/hill.tscn", "town": "res://scenes/world/town.tscn", "farm": "res://scenes/world/farm.tscn", "wira_home": "res://scenes/world/interior/wira_home.tscn", "ubay_home": "res://scenes/world/interior/ubay_home.tscn"}
	for map_id: String in paths:
		var scene: Node = load(paths[map_id]).instantiate()
		for id: String in NPCDatabase.residents:
			for entries: Array in NPCDatabase.residents[id].schedules.values():
				for entry: Dictionary in entries:
					if entry.map == map_id:
						check(scene.get_node_or_null("NPCPoints/" + str(entry.point)) is Marker2D, "%s/%s exists" % [map_id, entry.point])
		scene.free()
	# Load each world separately, and exercise both arrival and removal.
	for map_id: String in paths:
		DayCycle.hour = 8
		DayCycle.minute = 0
		var scene: Node = load(paths[map_id]).instantiate()
		# This suite exercises residents; skip expensive player appearance composition.
		var player_root := scene.get_node_or_null("Player")
		if player_root != null:
			player_root.free()
		add_child(scene)
		await get_tree().process_frame
		DayCycle.is_running = false
		var presenter := scene.get_node("NPCMapPresenter")
		for time in [Vector2i(8, 0), Vector2i(17, 0), Vector2i(17, 29), Vector2i(17, 30), Vector2i(22, 0), Vector2i(0, 15)]:
			DayCycle.hour = time.x
			DayCycle.minute = time.y
			presenter.refresh()
			await get_tree().process_frame
			for id: String in NPCDatabase.residents:
				var entry := NPCDatabase.schedule_entry(id, time.x, time.y, false)
				check(presenter.actors.has(id) == (entry.map == map_id), "%s %s at %02d:%02d" % [id, map_id, time.x, time.y])
				if presenter.actors.has(id):
					var actor: VillageNPC = presenter.actors[id]
					check(actor._current_activity == entry.activity, id + " activity dialogue")
					check(actor._schedule_dialog_lines == PackedStringArray(NPCDatabase.residents[id].dialogue[entry.activity]), id + " contextual lines")
		GameState.weather.current = "rain"
		DayCycle.hour = 17
		DayCycle.minute = 0
		GameState.weather.changed.emit()
		await get_tree().process_frame
		check(presenter.actors.has("ubay") == (map_id == "farm"), "rain keeps Ubay pickup in " + map_id)
		check(presenter.actors.has("wira") == (map_id == "hill"), "rain keeps Wira at workshop in " + map_id)
		GameState.weather.current = "sunny"
		scene.queue_free()
		await get_tree().process_frame
	check(GameState.shipping.to_save() == shipping_before, "NPC visits never settle or duplicate shipping sales")
	# A lightweight Player is enough for UI ownership; no appearance build is needed.
	var player := Player.new()
	for id in ["wira", "ubay"]:
		var actor: VillageNPC = load("res://scenes/npc/%sNPC.tscn" % id.capitalize()).instantiate()
		add_child(actor)
		check((actor.interaction_area.collision_mask & player.collision_layer) != 0, id + " interaction detects player layer")
		actor.interact(player)
		check(is_instance_valid(actor._service_menu), id + " opens service choices")
		check(get_tree().paused, id + " menu pauses solo play")
		check(actor._service_menu.process_mode == Node.PROCESS_MODE_ALWAYS, id + " menu remains usable while paused")
		actor._choose_service(0, player)
		check(is_instance_valid(actor._dialog_ui), id + " talk opens dialogue")
		actor._dialog_ui._close()
		await get_tree().process_frame
		actor.interact(player)
		actor._choose_service(1, player)
		if id == "wira":
			check(is_instance_valid(actor._service_menu), "Wira opens existing construction service")
			actor._service_menu._close()
		else:
			check(is_instance_valid(actor._dialog_ui) and actor._dialog_ui.lines[1].contains("tidur"), "Ubay explains existing overnight settlement")
			actor._dialog_ui._close()
		await get_tree().process_frame
		actor.interact(player)
		actor._choose_service(2, player)
		check(not get_tree().paused, id + " close releases pause")
		actor.queue_free()
		await get_tree().process_frame
	player.free()
	print("RESIDENTS REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
