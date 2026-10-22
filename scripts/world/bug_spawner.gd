extends Node2D
## Menaruh serangga liar (GDD 7, 4A-3) sesuai area, musim, dan jam. Jenisnya = resources/bugs/*.tres (BugData).
## Serangga tidak disimpan di save: tiap area dimuat dan tiap jam berganti, jumlahnya diisi lagi sampai max_bugs,
## dan serangga yang jam/musimnya sudah lewat pergi.
## Pasang sebagai node (Inspector) atau lewat kode:
##   load("res://scripts/world/bug_spawner.gd").attach(self, "forest", ^"YSortEntities")
## Di gua (root punya sinyal floor_built): diisi ulang tiap lantai tambang, ditaruh di entities_path ("FloorContent").

const DATA_DIR := "res://resources/bugs"
const BUG_DATA := preload("res://scripts/data/bug_data.gd")
const CRITTER := preload("res://scripts/world/bug_critter.gd")

## Area, cocok dengan BugData.locations ("farm", "forest", "town", "mountain", "cave").
@export var location_id: String = "forest"
## Serangga yang ada sekaligus.
@export_range(0, 20) var max_bugs: int = 5
## TileMapLayer tanah, relatif ke root scene.
@export var ground_layer_path: NodePath = ^"BaseLayerGround"
## Tempat node serangga ditaruh (ikut y-sort). Kosong / tidak ada = parent spawner ini.
@export var entities_path: NodePath = ^"YSortEntities"
## Jarak minimum (px) dari pemain saat serangga muncul.
@export_range(0.0, 200.0) var player_clearance: float = 64.0

static var _all: Array[Resource] = []

var _root: Node
var _ground: TileMapLayer
var _holder: Node
var _bugs: Array[Node2D] = []
var _last_hour := -1


static func attach(scene_root: Node, p_location_id: String, p_entities_path: NodePath = ^"YSortEntities", p_max: int = 5) -> Node2D:
	var spawner: Node2D = load("res://scripts/world/bug_spawner.gd").new()
	spawner.name = "BugSpawner"
	spawner.location_id = p_location_id
	spawner.entities_path = p_entities_path
	spawner.max_bugs = p_max
	scene_root.add_child(spawner)
	return spawner


static func all_data() -> Array[Resource]:
	if not _all.is_empty():
		return _all
	var dir := DirAccess.open(DATA_DIR)
	if dir == null:
		push_warning("BugSpawner: folder %s tidak ada." % DATA_DIR)
		return _all
	for file in dir.get_files():
		var res_name := file.trim_suffix(".remap")
		if not res_name.ends_with(".tres"):
			continue
		var data := load(DATA_DIR.path_join(res_name))
		if data != null and data.get_script() == BUG_DATA and data.item != null:
			_all.append(data)
	return _all


static func candidates(p_location_id: String, season: String, hour: int) -> Array[Resource]:
	var result: Array[Resource] = []
	for data in all_data():
		if data.is_available(p_location_id, season, hour):
			result.append(data)
	return result


func _ready() -> void:
	_root = owner if owner else get_parent()
	_ground = _root.get_node_or_null(ground_layer_path) as TileMapLayer
	_holder = _root.get_node_or_null(entities_path)
	if _holder == null:
		_holder = get_parent()
	if _ground == null:
		push_warning("BugSpawner: ground layer '%s' tidak ditemukan." % ground_layer_path)
		return
	DayCycle.time_tick.connect(_on_time_tick)
	DayCycle.season_changed.connect(func(_s: int) -> void: _refill())
	if _root.has_signal(&"floor_built"):
		_root.connect(&"floor_built", _on_floor_built)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_refill()


func _on_time_tick(hour: int, _minute: int) -> void:
	if hour != _last_hour:
		_refill()


func _on_floor_built(_floor: int) -> void:
	# Isi lantai lama (termasuk serangganya) sudah dibuang cave.gd.
	_bugs.clear()
	_refill.call_deferred()


func _floor_allows_bugs() -> bool:
	if not _root.has_signal(&"floor_built"):
		return true
	return int(_root.get("floor_number")) > 0 and _root.get("arena") == null


func _refill() -> void:
	if not is_inside_tree() or _ground == null:
		return
	_last_hour = DayCycle.hour
	var season := DayCycle.get_current_season()
	for bug in _bugs.duplicate():
		if not is_instance_valid(bug) or bug.is_queued_for_deletion():
			_bugs.erase(bug)
		elif not bug.data.is_available(location_id, season, DayCycle.hour):
			bug.despawn()
			_bugs.erase(bug)
	if not _floor_allows_bugs():
		return
	var pool := candidates(location_id, season, DayCycle.hour)
	if pool.is_empty():
		return
	var tries := 0
	while _bugs.size() < max_bugs and tries < max_bugs * 30:
		tries += 1
		var cell := _random_cell()
		if not _is_free(cell):
			continue
		spawn(_pick(pool), _ground.to_global(_ground.map_to_local(cell)))


func spawn(data: Resource, at: Vector2) -> Node2D:
	var bug: Node2D = CRITTER.new()
	bug.setup(data)
	_holder.add_child(bug)
	bug.place(at)
	_bugs.append(bug)
	return bug


func _pick(pool: Array[Resource]) -> Resource:
	var total := 0.0
	for data in pool:
		total += data.weight
	var roll := randf() * total
	for data in pool:
		roll -= data.weight
		if roll <= 0.0:
			return data
	return pool.back()


func _random_cell() -> Vector2i:
	var rect := _ground.get_used_rect().grow(-1)
	if rect.size.x <= 0 or rect.size.y <= 0:
		rect = _ground.get_used_rect()
	return Vector2i(randi_range(rect.position.x, rect.end.x - 1), randi_range(rect.position.y, rect.end.y - 1))


func _is_free(cell: Vector2i) -> bool:
	if _ground.get_cell_source_id(cell) == -1:
		return false
	var center := _ground.to_global(_ground.map_to_local(cell))
	for node in get_tree().get_nodes_in_group(&"player"):
		if node is Node2D and (node as Node2D).get_world_2d() == get_world_2d() and (node as Node2D).global_position.distance_to(center) < player_clearance:
			return false
	var space := get_world_2d().direct_space_state
	if space == null:
		return false
	var query := PhysicsPointQueryParameters2D.new()
	query.position = center
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return space.intersect_point(query, 1).is_empty()
