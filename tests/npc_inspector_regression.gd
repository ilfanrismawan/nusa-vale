extends Node
var failures := 0

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _ready() -> void:
	await get_tree().process_frame
	check(NPCDatabase.residents.has("wira") and NPCDatabase.residents.has("ubay"), "autoload scene registers resident resources")
	var profile = load("res://resources/npc_data/characters/wira_resident.tres").duplicate(true)
	check(profile.schedule_source == 1 and profile.definition().schedules.default[0].time == "06:00", "JSON schedule source uses authored schedule")
	profile.schedule_source = 0
	profile.move_speed = 75.0
	profile.waypoint_radius = 1.0
	profile.default_schedule[0].hour = 5
	profile.default_schedule.append(null)
	var data: Dictionary = profile.definition()
	check(data.move_speed == 75.0 and data.waypoint_radius == 1.0, "Inspector movement settings drive runtime data")
	check(data.schedules.default[0].time == "05:00", "Inspector schedule overrides JSON schedule")
	check(data.visual.expressions.has("happy"), "profile preserves existing portrait expressions")
	var network = load("res://scenes/npc/routes/farm_paths.tscn").instantiate()
	add_child(network)
	var start: Vector2 = network.get_node("town").global_position
	var road: Path2D = network.get_node("Ubay_pickup_to_town")
	var goal := road.to_global(road.curve.get_point_position(0))
	check(network.route(start, goal, "ubay").size() > 1, "native Path2D builds full route")
	var moved := road.curve.get_point_position(2) + Vector2(0, 8)
	road.curve.set_point_position(2, moved)
	check(road.to_global(moved) in network.route(start, goal, "ubay"), "editing curve updates runtime route")
	network.get_node("town").destination_maps.clear()
	var gateway = load("res://scripts/npc/npc_route_point.gd").new()
	gateway.position = goal
	gateway.destination_maps = PackedStringArray(["town"])
	network.add_child(gateway)
	check(network.gateway("town") == goal, "editing destination maps changes entrance")
	network.free()
	var isolated = load("res://scripts/npc/npc_route_network.gd").new()
	add_child(isolated)
	for id in ["wira", "ubay", "zarathia", "zarathustra"]:
		var path = load("res://scripts/npc/npc_walk_path.gd").new()
		path.name = id
		path.npc_id = StringName(id)
		path.curve = Curve2D.new()
		path.curve.add_point(Vector2.ZERO)
		path.curve.add_point(Vector2(50, {"wira": 0, "ubay": 50, "zarathia": 75, "zarathustra": 100}[id]))
		path.curve.add_point(Vector2(100, 0))
		isolated.add_child(path)
	var before: Array = isolated.route(Vector2.ZERO, Vector2(100, 0), "wira")
	check(Vector2(50, 0) in before and Vector2(50, 50) not in before, "Wira only uses Wira curves")
	check(Vector2(50, 50) in isolated.route(Vector2.ZERO, Vector2(100, 0), "ubay"), "Ubay only uses Ubay curves")
	check(Vector2(50, 75) in isolated.route(Vector2.ZERO, Vector2(100, 0), "zarathia"), "Zarathia only uses her own curves")
	check(Vector2(50, 100) in isolated.route(Vector2.ZERO, Vector2(100, 0), "zarathustra"), "Zarathustra only uses his own curves")
	isolated.get_node("ubay").curve.set_point_position(1, Vector2(50, 30))
	check(isolated.route(Vector2.ZERO, Vector2(100, 0), "wira") == before, "editing Ubay curve does not affect Wira")
	check(not isolated.get_script().is_tool(), "route network no longer draws over other open editor scenes")
	isolated.free()
	print("NPC INSPECTOR COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
