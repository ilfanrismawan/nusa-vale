extends Node2D

## Matching endpoints of native Path2D curves join automatically.
@export_range(0.1, 16, 0.1) var join_distance := 1.0

## Graf A* per NPC dibangun sekali per peta (kurva tidak berubah saat game berjalan).
var _graphs: Dictionary = {}

func gateway(other_map: String, npc_id: String = "") -> Vector2:
	var fallback: Marker2D
	var shared: Marker2D
	for marker in get_children():
		if not marker is Marker2D or not "destination_maps" in marker:
			continue
		var owner := str(marker.npc_id)
		if not owner.is_empty() and owner != npc_id:
			continue
		if other_map in marker.destination_maps:
			if owner == npc_id and not owner.is_empty():
				return marker.global_position
			shared = marker
		if marker.default_gateway:
			fallback = marker
	if shared != null:
		return shared.global_position
	if fallback != null:
		return fallback.global_position
	push_error("No NPC gateway for %s in %s" % [other_map, name])
	return global_position

func _ready() -> void:
	# Path2D ditambah/dilepas saat runtime (mis. ResidentRoom, tes) membatalkan cache.
	child_entered_tree.connect(func(_node: Node): clear_cache())
	child_exiting_tree.connect(func(_node: Node): clear_cache())

## Dipanggil otomatis saat kurva/anak NPCPaths berubah; boleh juga dipanggil manual.
func clear_cache() -> void:
	_graphs.clear()

func _cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / join_distance), floori(position.y / join_distance))

## Kurva yang dipakai NPC ini; bila ada kurva yang diganti (resource baru) cache dibangun ulang.
func _signature(npc_id: String) -> Array:
	var result := []
	for child in get_children():
		var path := child as Path2D
		if path == null or path.curve == null:
			continue
		if not npc_id.is_empty() and (not "npc_id" in path or str(path.npc_id) != npc_id):
			continue
		result.append(path.curve.get_instance_id())
	return result

func _graph(npc_id: String) -> AStar2D:
	var signature := _signature(npc_id)
	if _graphs.has(npc_id) and _graphs[npc_id].signature == signature:
		return _graphs[npc_id].graph
	var graph := AStar2D.new()
	# Spatial hash: joining stays linear instead of scanning every point per sample.
	var buckets: Dictionary = {}
	for child in get_children():
		var path := child as Path2D
		if path == null or path.curve == null or path.curve.point_count < 2:
			continue
		if not npc_id.is_empty() and (not "npc_id" in path or str(path.npc_id) != npc_id):
			continue
		# Kurva yang diedit saat runtime (Inspector/tes) membatalkan cache.
		if not path.curve.changed.is_connected(clear_cache):
			path.curve.changed.connect(clear_cache)
		var previous := -1
		var samples := PackedVector2Array()
		var straight := true
		for index in path.curve.point_count:
			if path.curve.get_point_in(index) != Vector2.ZERO or path.curve.get_point_out(index) != Vector2.ZERO:
				straight = false
			samples.append(path.curve.get_point_position(index))
		if not straight:
			samples = path.curve.get_baked_points()
		for point in samples:
			var position := path.to_global(point)
			var cell := _cell(position)
			var index := -1
			var best := join_distance
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					for candidate: int in buckets.get(cell + Vector2i(dx, dy), []):
						var distance := graph.get_point_position(candidate).distance_to(position)
						if distance <= best:
							best = distance
							index = candidate
			if index < 0:
				index = graph.get_point_count()
				graph.add_point(index, position)
				if not buckets.has(cell):
					buckets[cell] = []
				buckets[cell].append(index)
			if previous >= 0 and previous != index:
				graph.connect_points(previous, index)
			previous = index
	_graphs[npc_id] = {"graph": graph, "signature": signature}
	return graph

func route(from: Vector2, to: Vector2, npc_id: String = "") -> Array[Vector2]:
	var graph := _graph(npc_id)
	var result: Array[Vector2] = []
	if graph.get_point_count() == 0:
		push_warning("No Path2D assigned to NPC: " + npc_id)
		return result
	var points := graph.get_point_path(graph.get_closest_point(from), graph.get_closest_point(to))
	if points.is_empty():
		push_warning("Disconnected Path2D curves for NPC: " + npc_id)
		return result
	for point in points:
		if point.distance_to(from) > 2.0:
			result.append(point)
	if result.is_empty() or result.back().distance_to(to) > 2.0:
		result.append(to)
	return result
