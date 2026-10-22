class_name CaveDungeonLayout
extends CaveFloorLayout

## Bentuk lantai dilukis di GroundTiles. Sel selain ground menjadi tembok permanen.
@export var display_name: String = "Dungeon"
@export var map_bounds: Rect2i = Rect2i(0, 0, 40, 24)
@export var protect_routes: bool = true
@export var arrival_path: NodePath = NodePath("Arrival")
@export var ladder_path: NodePath = NodePath("LadderUp")
@export var lift_path: NodePath = NodePath("Lift")
var walkable: Dictionary = {}
var reachable: Dictionary = {}
var routes: Dictionary = {}
var stair_cells: Array[Vector2i] = []
var error_message: String = ""
var navigation := AStarGrid2D.new()

func marker_position(path: NodePath) -> Vector2:
	return (get_node(path) as Marker2D).global_position

func zones() -> Array[CaveSpawnZone]:
	var result: Array[CaveSpawnZone] = []
	for node in find_children("*", "Node2D", true, false):
		if node is CaveSpawnZone:
			result.append(node)
	return result

## Validasi sebelum generator menyembunyikan scene lama atau membuat isi lantai.
func prepare(space: Node2D, tile_size: int = 16) -> bool:
	walkable.clear()
	reachable.clear()
	routes.clear()
	stair_cells.clear()
	error_message = ""
	var ground := get_node_or_null("GroundTiles") as TileMapLayer
	if ground == null or map_bounds.size.x < 1 or map_bounds.size.y < 1:
		return _invalid("GroundTiles atau Map Bounds tidak valid")
	for path in [arrival_path, ladder_path, lift_path]:
		if not get_node_or_null(path) is Marker2D:
			return _invalid("Marker penting hilang: %s" % path)
	for cell in ground.get_used_cells():
		var point := space.to_local(ground.to_global(ground.map_to_local(cell)))
		var mapped := Vector2i((point / tile_size).floor())
		if not map_bounds.has_point(mapped):
			return _invalid("Ground berada di luar Map Bounds")
		walkable[mapped] = true
	# Props solid buatan editor ikut mengubah keterhubungan dan rute.
	for cell in occupied_cells(space, tile_size, false):
		walkable.erase(cell)
	for cell in occupied_cells(space, tile_size):
		routes[cell] = true
	var start := _cell(space, marker_position(arrival_path), tile_size)
	if not walkable.has(start):
		return _invalid("Arrival tidak berada di lantai")
	var previous: Dictionary = {start: start}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + direction
			if walkable.has(next) and not previous.has(next):
				previous[next] = cell
				queue.append(next)
	reachable = previous.duplicate()
	if reachable.size() != walkable.size():
		return _invalid("Ada lantai yang terputus dari Arrival")
	# Lift adalah objek dinding: titik kaki interaksi terletak 24 px di bawah marker.
	var lift_cell := _cell(space, marker_position(lift_path) + Vector2(0, 24), tile_size)
	var ladder_cell := _cell(space, marker_position(ladder_path) + Vector2(0, 16), tile_size)
	if not reachable.has(lift_cell) or not reachable.has(ladder_cell):
		return _invalid("Tangga naik atau lift tidak dapat dicapai")
	var targets: Array[Vector2i] = [lift_cell, ladder_cell]
	var candidates := get_node_or_null("StairCandidates")
	if candidates != null:
		for marker in candidates.get_children():
			if marker is Marker2D:
				var cell := _cell(space, marker.global_position, tile_size)
				if not reachable.has(cell):
					return _invalid("Kandidat tangga tidak dapat dicapai")
				stair_cells.append(cell)
				targets.append(cell)
	if stair_cells.is_empty():
		return _invalid("Tambahkan minimal satu Marker2D di StairCandidates")
	for zone in zones():
		if zone.kind != CaveSpawnZone.Kind.SAFE and (zone.spawn_weight <= 0.0 or zone.maximum_count <= 0):
			continue
		var inside: Array[Vector2i] = []
		for cell in zone.cells(space, tile_size):
			if reachable.has(cell):
				inside.append(cell)
		if inside.is_empty() and zone.kind != CaveSpawnZone.Kind.SAFE:
			return _invalid("Zona tidak menyentuh lantai: %s" % zone.name)
		if not inside.is_empty():
			targets.append(inside[inside.size() / 2])
		if zone.kind == CaveSpawnZone.Kind.SAFE:
			for cell in inside:
				routes[cell] = true
	if protect_routes:
		for target in targets:
			var cell := target
			while cell != start:
				routes[cell] = true
				cell = previous[cell]
			routes[start] = true
	# Kandidat tangga selalu bebas isi, walau perlindungan rute dimatikan.
	for cell in stair_cells:
		routes[cell] = true
	navigation.region = map_bounds
	navigation.cell_size = Vector2.ONE * tile_size
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	navigation.update()
	for y in range(map_bounds.position.y, map_bounds.end.y):
		for x in range(map_bounds.position.x, map_bounds.end.x):
			var cell := Vector2i(x, y)
			navigation.set_point_solid(cell, not walkable.has(cell))
	return true

func _cell(space: Node2D, point: Vector2, tile_size: int) -> Vector2i:
	return Vector2i((space.to_local(point) / tile_size).floor())

func _invalid(message: String) -> bool:
	error_message = message
	return false
