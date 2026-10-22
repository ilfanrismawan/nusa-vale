extends Node

var failures := 0

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func walk(actor: VillageNPC) -> bool:
	var stalled := 0
	for step in 10000:
		if not actor._is_walking:
			return actor.global_position.distance_to(actor._target_pos) <= 3.0
		var before := actor.global_position
		actor._physics_process(1.0 / 60.0)
		var moved := before.distance_to(actor.global_position)
		if moved > 2.0:
			push_error("Unexpected NPC teleport")
			return false
		stalled = stalled + 1 if moved < 0.01 else 0
		if stalled > 320:
			if actor.get_slide_collision_count() > 0:
				print("COLLIDER: ", actor.get_slide_collision(0).get_collider().get_path(), " shape ", actor.get_slide_collision(0).get_collider_shape())
			print("BLOCKED: %s at %s towards %s (goal %s)" % [actor.npc_id, actor.global_position, actor._active_path[0], actor._target_pos])
			return false
	return false

func _ready() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	var maps := {"hill": ["wira", 7, 0, 17, 0], "town": ["ubay", 7, 0, 17, 0], "farm": ["ubay", 17, 0, 17, 30], "wira_home": ["wira", 6, 0, 7, 0], "ubay_home": ["ubay", 6, 0, 7, 0], "town_wira": ["wira", 17, 0, 18, 30], "town_return": ["ubay", 17, 30, 22, 0], "hill_evening": ["wira", 18, 30, 21, 0], "town_zarathia": ["zarathia", 9, 0, 16, 30], "hill_zarathia": ["zarathia", 16, 30, 19, 0], "hill_zarathustra": ["zarathustra", 8, 30, 17, 0], "town_zarathustra": ["zarathustra", 17, 0, 19, 0], "home_zarathia": ["zarathia", 6, 30, 9, 0], "home_zarathustra": ["zarathustra", 6, 30, 8, 30]}
	for map_id: String in maps:
		var config: Array = maps[map_id]
		DayCycle.hour = config[1]
		DayCycle.minute = config[2]
		var scene_map: String = {"town_wira": "town", "town_return": "town", "hill_evening": "hill", "town_zarathia": "town", "hill_zarathia": "hill", "hill_zarathustra": "hill", "town_zarathustra": "town", "home_zarathia": "wira_home", "home_zarathustra": "wira_home"}.get(map_id, map_id)
		var path := "res://scenes/world/" + ("interior/" if scene_map.ends_with("_home") else "") + scene_map + ".tscn"
		var scene: Node = load(path).instantiate()
		var player := scene.get_node_or_null("Player")
		if player != null:
			player.free()
		# Dynamic residents can temporarily block roads; verify static layout here.
		for body in scene.find_children("*", "CharacterBody2D", true, false):
			body.free()
		add_child(scene)
		DayCycle.is_running = false
		var presenter := scene.get_node("NPCMapPresenter")
		presenter.set_process(false)
		for actor: VillageNPC in presenter.actors.values():
			actor.set_physics_process(false)
		await get_tree().physics_frame
		var actor: VillageNPC = presenter.actors[config[0]]
		if map_id == "town_return":
			# Wira is already standing by the orders point when Ubay comes back.
			var wira: VillageNPC = presenter.actors["wira"]
			wira.global_position = scene.get_node("NPCPoints/wira_orders").global_position
			wira._active_path.clear()
			wira._is_walking = false
		check(actor._is_walking and actor.global_position.distance_to(actor._target_pos) > 4.0, map_id + " starts at gateway and walks to activity")
		check(walk(actor), map_id + " arrival follows clear route without teleport")
		var extra_times: Array = {
			"town_zarathia": [Vector2i(12, 30), Vector2i(13, 30)],
			"hill_zarathustra": [Vector2i(12, 0), Vector2i(13, 0)]
		}.get(map_id, [])
		for time: Vector2i in extra_times:
			DayCycle.hour = time.x
			DayCycle.minute = time.y
			presenter.refresh()
			check(walk(actor), "%s activity route %02d:%02d" % [map_id, time.x, time.y])
		if map_id == "home_zarathia":
			GameState.weather.current = "rain"
			DayCycle.hour = 9
			DayCycle.minute = 0
			presenter.refresh()
			check(walk(actor) and actor._current_activity == "baking", "Zarathia reaches kitchen during rain")
			GameState.weather.current = "sunny"
		if map_id == "hill" or map_id == "town":
			for time in ([Vector2i(8, 0), Vector2i(12, 0), Vector2i(13, 0)] if map_id == "hill" else [Vector2i(9, 0), Vector2i(12, 0), Vector2i(13, 0)]):
				DayCycle.hour = time.x
				DayCycle.minute = time.y
				presenter.refresh()
				check(walk(actor), "%s local route %02d:%02d" % [map_id, time.x, time.y])
		DayCycle.hour = config[3]
		DayCycle.minute = config[4]
		presenter.refresh()
		check(presenter.actors.has(config[0]) and presenter.departures.has(config[0]), map_id + " departure keeps actor visible")
		check(walk(actor), map_id + " departure reaches doorway or map edge")
		presenter._process(0)
		check(not presenter.actors.has(config[0]), map_id + " removes actor only after exit")
		scene.queue_free()
		await get_tree().process_frame
	print("NPC PATHS COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
