extends Node
## Audit headless jadwal & jalur resident di Town.
## Jalankan: Godot --headless --path . res://tools/audit_town_npc.tscn
## Melaporkan: (1) resident yang berhenti di titik sama/berdempetan pada waktu
## yang sama, (2) rute yang tersangkut collider dunia, (3) titik/gateway yang
## berada di dalam collider.

const MAP_ID := "town"
## Jarak minimum antar resident yang sedang diam (lebar sprite ~16 px).
const MIN_SPACING := 14.0
const STEP_MINUTES := 10

var issues := 0

func report(label: String) -> void:
	issues += 1
	print("ISSUE: " + label)

func walk(actor: VillageNPC) -> bool:
	var stalled := 0
	for step in 12000:
		if not actor._is_walking:
			return true
		var before := actor.global_position
		actor._physics_process(1.0 / 60.0)
		stalled = stalled + 1 if before.distance_to(actor.global_position) < 0.01 else 0
		if stalled > 240:
			var collider := ""
			if actor.get_slide_collision_count() > 0:
				collider = str(actor.get_slide_collision(0).get_collider().get_path())
			report("%s tersangkut di %s menuju %s (collider %s)" % [actor.npc_id, actor.global_position.round(), actor._active_path[0].round(), collider])
			actor.global_position = actor._target_pos
			actor._active_path.clear()
			actor._is_walking = false
			return false
	return false

func blocked(space: PhysicsDirectSpaceState2D, at: Vector2) -> String:
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(10, 8)
	query.shape = shape
	query.transform = Transform2D(0, at)
	query.collision_mask = 1
	var hits := space.intersect_shape(query, 1)
	return "" if hits.is_empty() else str(hits[0].collider.get_path())

func _ready() -> void:
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	DayCycle.hour = 6
	DayCycle.minute = 0
	var town: Node2D = load("res://scenes/world/town.tscn").instantiate()
	town.get_node("Player").free()
	add_child(town)
	DayCycle.is_running = false
	var presenter := town.get_node("NPCMapPresenter")
	presenter.set_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState2D = town.get_world_2d().direct_space_state
	var points := town.get_node("NPCPoints")
	for marker: Node2D in points.get_children():
		var hit := blocked(space, marker.global_position)
		if not hit.is_empty():
			report("titik %s di dalam collider %s" % [marker.name, hit])
	for marker in town.get_node("NPCPaths").get_children():
		if marker is Marker2D:
			var hit := blocked(space, marker.global_position)
			if not hit.is_empty():
				report("gateway %s di dalam collider %s" % [marker.name, hit])
	for rainy in [false, true]:
		GameState.weather.current = "rain" if rainy else "sunny"
		print("== Cuaca: %s ==" % ("hujan" if rainy else "cerah"))
		var seen_pairs := {}
		for minutes in range(6 * 60, 24 * 60, STEP_MINUTES):
			DayCycle.hour = minutes / 60
			DayCycle.minute = minutes % 60
			presenter.refresh()
			for actor: VillageNPC in presenter.actors.values():
				walk(actor)
			presenter._process(0)
			var stamp := "%02d:%02d" % [DayCycle.hour, DayCycle.minute]
			var standing: Array = []
			for id: String in presenter.actors:
				var actor: VillageNPC = presenter.actors[id]
				if actor.visible and not presenter.departures.has(id):
					standing.append(actor)
			for i in standing.size():
				for j in range(i + 1, standing.size()):
					var a: VillageNPC = standing[i]
					var b: VillageNPC = standing[j]
					var distance := a.global_position.distance_to(b.global_position)
					if distance >= MIN_SPACING:
						continue
					var key := "%s|%s|%s|%s" % [a.npc_id, b.npc_id, presenter.active_entries[a.npc_id].point, presenter.active_entries[b.npc_id].point]
					if seen_pairs.has(key):
						continue
					seen_pairs[key] = true
					report("%s %s (%s) & %s (%s) berjarak %.1f px di %s" % [stamp, a.npc_id, presenter.active_entries[a.npc_id].point, b.npc_id, presenter.active_entries[b.npc_id].point, distance, a.global_position.round()])
	print("AUDIT TOWN NPC SELESAI: issues=%d" % issues)
	get_tree().quit(1 if issues else 0)
