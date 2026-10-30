extends Node2D
## Menaruh satwa liar (GDD 4.10.13) sesuai area, musim, dan jam. Jenisnya = resources/wildlife/*.tres.
## Tidak disimpan di save: tiap area dimuat dan tiap jam berganti, jumlahnya diisi lagi sampai
## max_animals; satwa yang jam/musimnya lewat atau sudah kabur jauh menghilang.
## Edit node WildlifeSpawner pada scene area, atau scene dasar scenes/world/wildlife_spawner.tscn.

const DATA_DIR := "res://resources/wildlife"
const WILDLIFE_DATA := preload("res://scripts/data/wildlife_data.gd")

@export var enabled: bool = true
## Daftar satwa untuk area ini; kosong berarti tidak ada satwa yang muncul.
@export var species: Array[WildlifeData] = []
@export_range(1, 200) var attempts_per_animal: int = 40
@export_range(0, 20) var edge_margin: int = 2

@export var location_id: String = "forest"
@export_range(0, 12) var max_animals: int = 4
@export var ground_layer_path: NodePath = ^"BaseLayerGround"
@export var entities_path: NodePath = ^"YSortEntities"
## Satwa muncul di luar pandangan dekat pemain.
@export_range(0.0, 400.0) var player_clearance: float = 140.0

static var _all: Array[Resource] = []

var _root: Node
var _ground: TileMapLayer
var _holder: Node
var _animals: Array[Node2D] = []
var _last_hour := -1


static func attach(scene_root: Node, p_location_id: String, p_entities_path: NodePath = ^"YSortEntities", p_max: int = 4) -> Node2D:
	var spawner: Node2D = load("res://scenes/world/wildlife_spawner.tscn").instantiate()
	spawner.name = "WildlifeSpawner"
	spawner.location_id = p_location_id
	spawner.entities_path = p_entities_path
	spawner.max_animals = p_max
	scene_root.add_child(spawner)
	return spawner


static func all_data() -> Array[Resource]:
	if not _all.is_empty():
		return _all
	var dir := DirAccess.open(DATA_DIR)
	if dir == null:
		return _all
	for file in dir.get_files():
		var res_name := file.trim_suffix(".remap")
		if res_name.ends_with(".tres"):
			var data := load(DATA_DIR.path_join(res_name))
			if data != null and data.get_script() == WILDLIFE_DATA:
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
		push_warning("WildlifeSpawner: ground layer '%s' tidak ditemukan." % ground_layer_path)
		return
	DayCycle.time_tick.connect(_on_time_tick)
	DayCycle.season_changed.connect(func(_s: int) -> void: refill())
	await get_tree().physics_frame
	await get_tree().physics_frame
	refill()


func _on_time_tick(hour: int, _minute: int) -> void:
	if hour != _last_hour:
		refill()


func animals() -> Array[Node2D]:
	# Parameter tanpa tipe: satwa yang sudah dihapus tidak bisa dikonversi ke Node2D.
	_animals.assign(_animals.filter(func(a) -> bool: return is_instance_valid(a) and not a.is_queued_for_deletion() and not a.is_leaving()))
	return _animals


func refill() -> void:
	if not enabled or not is_inside_tree() or _ground == null:
		return
	_last_hour = DayCycle.hour
	var season := DayCycle.get_current_season()
	for animal in animals().duplicate():
		if not animal.data.is_available(location_id, season, DayCycle.hour):
			animal.despawn()
			_animals.erase(animal)
	var pool: Array[Resource] = []
	for entry in species:
		if entry != null and entry.is_available(location_id, season, DayCycle.hour):
			pool.append(entry)
	if pool.is_empty():
		return
	var tries := 0
	while _animals.size() < max_animals and tries < max_animals * attempts_per_animal:
		tries += 1
		var cell := _random_cell()
		if _is_free(cell):
			spawn(_pick(pool), _ground.to_global(_ground.map_to_local(cell)))


func spawn(data: Resource, at: Vector2) -> Node2D:
	var animal := WildAnimal.new()
	animal.setup(data)
	_holder.add_child(animal)
	animal.place(at)
	_animals.append(animal)
	return animal


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
	var rect := _ground.get_used_rect().grow(-edge_margin)
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
	# Butuh ruang kosong sedikit di sekitarnya, bukan hanya satu titik.
	for offset in [Vector2.ZERO, Vector2(6, 0), Vector2(-6, 0), Vector2(0, 6), Vector2(0, -6)]:
		var query := PhysicsPointQueryParameters2D.new()
		query.position = center + offset
		query.collide_with_bodies = true
		query.collide_with_areas = false
		if not space.intersect_point(query, 1).is_empty():
			return false
	return true
