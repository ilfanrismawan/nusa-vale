extends Node2D

## Matching endpoints of native Path2D curves join automatically.
@export_range(0.1, 16, 0.1) var join_distance := 1.0

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

func route(from: Vector2, to: Vector2, npc_id: String = "") -> Array[Vector2]:
	var graph := AStar2D.new()
	for child in get_children():
		var path := child as Path2D
		if path == null or path.curve == null or path.curve.point_count < 2:
			continue
		if not npc_id.is_empty() and (not "npc_id" in path or str(path.npc_id) != npc_id):
			continue
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
			var index := graph.get_closest_point(position)
			if index < 0 or graph.get_point_position(index).distance_to(position) > join_distance:
				index = graph.get_point_count()
				graph.add_point(index, position)
			if previous >= 0 and previous != index:
				graph.connect_points(previous, index)
			previous = index
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
