extends Node
## Perilaku gerak warga (Prioritas 1, 2026-11-01): muncul di posisi jadwal saat masuk peta,
## rute putus tidak diulang tiap menit, tembus penghalang tanpa teleport, arah hadap, id menu.

const Presenter := preload("res://scripts/npc/npc_map_presenter.gd")
const ServiceMenu := preload("res://scripts/ui/resident_service_menu.gd")

var failures := 0

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func set_time(hour: int, minute: int = 0) -> void:
	DayCycle.hour = hour
	DayCycle.minute = minute

func open_town() -> Node:
	var scene: Node = load("res://scenes/world/town.tscn").instantiate()
	var player := scene.get_node_or_null("Player")
	if player != null:
		player.free()
	for body in scene.find_children("*", "CharacterBody2D", true, false):
		if not body is VillageNPC:
			body.free()
	add_child(scene)
	await get_tree().process_frame
	var presenter := scene.get_node("NPCMapPresenter")
	presenter.set_process(false)
	for actor: VillageNPC in presenter.actors.values():
		actor.set_physics_process(false)
	await get_tree().physics_frame
	return scene

## Langkah manual; true bila sampai. `passed` diisi bila sempat menembus penghalang.
func walk(actor: VillageNPC, state: Dictionary = {}) -> bool:
	for step in 12000:
		if not actor._is_walking:
			return actor.global_position.distance_to(actor._target_pos) <= 3.0
		var before := actor.global_position
		actor._physics_process(1.0 / 60.0)
		if before.distance_to(actor.global_position) > 2.0:
			state["teleport"] = true
		if actor._passing_through:
			state["passed"] = true
	return false

func _ready() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	DayCycle.current_day = 2
	GameState.weather.current = "sunny"

	check(Presenter.minutes_since({"time": "22:00"}, 0, 15) == 135, "minutes_since wraps past midnight")
	check(Presenter.minutes_since({"time": "08:00"}, 8, 0) == 0, "minutes_since is zero at entry start")
	check(ServiceMenu.TALK == 0 and ServiceMenu.SERVICE == 1 and ServiceMenu.CLOSE == 2 and ServiceMenu.ROMANCE == 3 and ServiceMenu.LETTER == 4 and ServiceMenu.HOUSEHOLD == 5 and ServiceMenu.SUPPLIES == 6, "service menu action ids keep their values")

	# 1. Masuk Town di tengah jadwal: warga sudah di titiknya.
	set_time(10, 0)
	var town := await open_town()
	var presenter := town.get_node("NPCMapPresenter")
	var kirana: VillageNPC = presenter.actors.get("kirana")
	check(kirana != null and not kirana._is_walking and kirana.global_position.distance_to(town.get_node("NPCPoints/kirana_work").global_position) < 2.0, "Kirana already stands at work when Town loads at 10.00")

	# 2. Arah hadap: entri > metadata marker > langkah terakhir.
	var marker := town.get_node("NPCPoints/kirana_rest")
	check(Presenter.facing_for({"facing": "side_left"}, marker) == "side_left", "schedule entry facing wins")
	marker.set_meta("npc_facing", "up")
	check(Presenter.facing_for({}, marker) == "up", "Marker2D npc_facing metadata is used")
	marker.remove_meta("npc_facing")
	check(Presenter.facing_for({}, marker) == "", "empty facing keeps last walking direction")

	# 3. Rute putus: taruh langsung di titik, dicatat sekali.
	var network := town.get_node("NPCPaths")
	for path in network.get_children():
		if path is Path2D and str(path.get("npc_id")) == "kirana":
			path.free()
	network.clear_cache()
	set_time(12, 0)
	presenter.refresh()
	check(presenter._route_failures.has("kirana"), "missing Kirana route is recorded once")
	check(not kirana._is_walking and kirana.global_position.distance_to(town.get_node("NPCPoints/kirana_rest").global_position) < 2.0, "Kirana is placed at lunch point when her route is missing")
	set_time(12, 1)
	presenter.refresh()
	check(presenter.active_entries.get("kirana") == NPCDatabase.schedule_entry("kirana", 12, 1, false), "failed route is not retried every minute")
	town.queue_free()
	await get_tree().process_frame

	# 4. Mulai jadwal tepat waktu: tetap berjalan dari pintu.
	set_time(8, 0)
	town = await open_town()
	presenter = town.get_node("NPCMapPresenter")
	var bahar: VillageNPC = presenter.actors.get("bahar")
	check(bahar != null and bahar._is_walking and bahar.global_position.distance_to(bahar._target_pos) > 4.0, "Bahar walks from his door when his shift starts as Town loads")
	if bahar != null:
		# 5. Penghalang di jalan: tembus setelah sebentar, tidak teleport, tetap sampai.
		var ahead: Vector2 = bahar._target_pos
		for point: Vector2 in bahar._active_path:
			if point.distance_to(bahar.global_position) > 48.0:
				ahead = point
				break
		var wall := StaticBody2D.new()
		wall.collision_layer = 1
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(24, 24)
		shape.shape = rect
		wall.add_child(shape)
		town.add_child(wall)
		# Tepat di waypoint: tanpa menembus, waypoint ini tidak mungkin dicapai.
		wall.global_position = ahead
		await get_tree().physics_frame
		var state := {}
		check(walk(bahar, state), "Bahar still reaches work with a body blocking the road")
		check(bool(state.get("passed", false)), "blocked resident passes through the obstacle")
		check(not bool(state.get("teleport", false)), "passing through never teleports")
		check(bahar.collision_mask == 1 and not bahar._passing_through, "collision is restored once clear of the obstacle")
		check(bahar._last_facing in ["down", "up", "side_left", "side_right"], "arrival keeps the last walking direction")
	town.queue_free()
	await get_tree().process_frame

	print("NPC BEHAVIOR COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
