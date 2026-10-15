class_name ForageSpawner
extends Node2D
## Menaruh barang liar (ForageData) di sel kosong area ini.
## Pasang sebagai anak root scene (atau panggil ForageSpawner.attach(self, "forest") dari script scene).
## Sel dipilih acak di dalam tile ground_layer, menghindari collision (air, tembok, pohon) dan area lain.
## WeedSpawner (rumput liar) memakai kelas ini dan mengganti fungsi _area_key/_pick_id/_make_node.

const TILE := 16

@export var location_id: String = "forest"
## Barang baru per hari.
@export_range(0, 20) var daily_spawn: int = 3
## Batas barang yang tergeletak sekaligus.
@export_range(1, 60) var max_active: int = 12
## Jarak aman dari tepi peta (dalam tile).
@export_range(0, 10) var margin_tiles: int = 2
## TileMapLayer tanah, relatif ke root scene.
@export var ground_layer_path: NodePath = ^"BaseLayerGround"
## Tempat node barang ditaruh (supaya ikut y-sort). Kosong / tidak ada = parent spawner ini.
@export var entities_path: NodePath = ^"YSortEntities"

var _ground: TileMapLayer
var _holder: Node
var _nodes: Dictionary = {}  # "x,y" -> node barang
var _covered: Array[Rect2] = []  # area gambar pohon/objek besar, supaya barang tidak tertutup daun


## Buat spawner lewat kode, mis. di forest.gd: ForageSpawner.attach(self, "forest")
static func attach(scene_root: Node, p_location_id: String, p_entities_path: NodePath = ^"YSortEntities") -> ForageSpawner:
	var spawner := ForageSpawner.new()
	spawner.name = "ForageSpawner"
	spawner.location_id = p_location_id
	spawner.entities_path = p_entities_path
	scene_root.add_child(spawner)
	return spawner


func _ready() -> void:
	var root := owner if owner else get_parent()
	_ground = root.get_node_or_null(ground_layer_path) as TileMapLayer
	_holder = root.get_node_or_null(entities_path)
	if _holder == null:
		_holder = get_parent()
	if _ground == null:
		push_warning("ForageSpawner: ground layer '%s' tidak ditemukan." % ground_layer_path)
		return
	DayCycle.day_passed.connect(_on_day_passed)
	# Hanya spawner forage biasa yang menangani tombol E (bukan rumput/pohon/titik gali).
	set_process(get_script() == ForageSpawner)
	# Tunggu collision tilemap & body terdaftar di physics server dulu.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_collect_covered(_holder)
	_collect_scene_covers(root)
	_sync(false)


## Tombol E (interact) memungut barang di depan pemain, seperti tombol aksi di Stardew.
## player.gd mengecek titik 32 px di depan kaki; itu terlalu jauh untuk barang sekecil satu petak,
## jadi spawner forage memeriksa sendiri petak di depan, di bawah, dan di sekitar kaki pemain.
func _process(_delta: float) -> void:
	for node in get_tree().get_nodes_in_group(&"player"):
		var p := node as Player
		if p == null or p.is_input_locked() or p.input == null:
			continue
		# Co-op: tiap area punya spawner sendiri; hanya tangani pemain di area ini.
		var world := p.world_root()
		if not is_instance_valid(world) or not world.is_ancestor_of(self):
			continue
		if not p.input.just_pressed(&"interact"):
			continue
		# Kalau E pemain sudah mengenai hal lain (NPC, pintu, kasur), biarkan player.gd yang menangani.
		var other: Node = p._find_interactable()
		if other != null and not (other is Forageable):
			continue
		try_pickup(p)


func try_pickup(p: Player) -> bool:
	var own := p.get_player_cell()
	var front := own + Vector2i(p.facing_direction)
	var body_front := p.world_to_cell(p.global_position + p.facing_direction * 12.0)
	for cell in [front, body_front, own]:
		var node: Variant = _nodes.get(ForageManager.key_of(cell))
		if is_instance_valid(node) and node is Forageable:
			_bind_player(p)
			node.interact()
			return true
	# Tidak tepat di depan: ambil yang paling dekat dengan kaki (maks. ~1 petak).
	var feet := p.global_position + Vector2(0, 8)
	var best: Forageable = null
	var best_dist := 20.0
	for node in _nodes.values():
		if is_instance_valid(node) and node is Forageable:
			var d: float = (node as Forageable).ground_position().distance_to(feet)
			if d < best_dist:
				best_dist = d
				best = node
	if best:
		_bind_player(p)
		best.interact()
		return true
	return false


## Co-op: barang masuk ke tas pemain yang menekan E.
func _bind_player(p: Player) -> void:
	p.bind_context()


func _on_day_passed(_day: int) -> void:
	_sync(true)


func _sync(animate_existing: bool) -> void:
	if not is_inside_tree():
		return
	var area := _area_key()
	var new_count := ForageManager.roll_count(area, daily_spawn, max_active, _clear_on_season())
	var items := ForageManager.get_items(area)

	# Buang node yang sudah tidak ada di data (mis. musim berganti).
	for key in _nodes.keys():
		if not items.has(key) or not is_instance_valid(_nodes[key]):
			if is_instance_valid(_nodes[key]):
				_nodes[key].queue_free()
			_nodes.erase(key)

	# Pulihkan barang yang tersimpan.
	for key in items:
		if not _nodes.has(key):
			_place(ForageManager.cell_from_key(key), str(items[key]), animate_existing)
	# id yang gagal dibuat (file-nya dihapus) dibuang dari data.
	for key in items.keys():
		if not _nodes.has(key):
			ForageManager.remove_item(area, ForageManager.cell_from_key(key))

	# Tumbuhkan barang baru.
	var placed := 0
	var tries := 0
	while placed < new_count and tries < new_count * 40:
		tries += 1
		var id := _pick_id()
		if id.is_empty():
			break
		var cell := _random_cell()
		if not _is_free(cell):
			continue
		ForageManager.add_item(area, cell, id)
		_place(cell, id, true)
		placed += 1

	if placed > 0:
		_on_spawned(placed)


func _place(cell: Vector2i, id: String, animate: bool) -> void:
	var node := _make_node(id, cell)
	if node == null:
		return
	_holder.add_child(node)
	node.global_position = _ground.to_global(_ground.map_to_local(cell))
	if node.has_method("apply_sort_shift"):
		node.apply_sort_shift()
	if animate and node.has_method("play_appear"):
		node.play_appear()
	_nodes[ForageManager.key_of(cell)] = node


# ── Bisa diganti oleh turunan (WeedSpawner) ──────────────────────────────────

func _area_key() -> String:
	return location_id


func _clear_on_season() -> bool:
	return true


func _pick_id() -> String:
	var data := ForageManager.pick(location_id)
	return data.item.item_id if data else ""


func _make_node(id: String, cell: Vector2i) -> Node2D:
	var item := GameState._resolve_item(id)
	if item == null:
		return null
	var node := Forageable.new()
	node.setup(item, _area_key(), cell)
	return node


func _cell_allowed(_cell: Vector2i) -> bool:
	return true


func _on_spawned(_count: int) -> void:
	if DiscoveryManager.discover("forage_tip"):
		Notify.say("Ada barang liar di tanah! Hadap ke barang lalu tekan E, atau klik pakai Tangan.")


func _random_cell() -> Vector2i:
	var world := _ground.get_parent()
	if world.has_method("random_resource_cell"):
		return world.random_resource_cell()
	var rect := _ground.get_used_rect().grow(-margin_tiles)
	if rect.size.x <= 0 or rect.size.y <= 0:
		rect = _ground.get_used_rect()
	return Vector2i(
		randi_range(rect.position.x, rect.end.x - 1),
		randi_range(rect.position.y, rect.end.y - 1)
	)


func _is_free(cell: Vector2i) -> bool:
	if _ground.get_cell_source_id(cell) == -1:
		return false
	# Authored worlds can reserve paths and restrict resources to reachable glades.
	var world := _ground.get_parent()
	if world.has_method("is_resource_cell") and not world.is_resource_cell(cell):
		return false
	if ForageManager.has_item_at(_area_key(), cell):
		return false
	if not _cell_allowed(cell):
		return false
	var center := _ground.to_global(_ground.map_to_local(cell))
	for rect in _covered:
		if rect.has_point(center):
			return false
	var space := get_world_2d().direct_space_state
	if space == null:
		return false
	var circle := CircleShape2D.new()
	circle.radius = TILE * 0.45
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, center)
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.collision_mask = 0xFFFFFFFF
	# Apa pun yang kena (termasuk pemain, barang lain, pintu) = sel terpakai.
	return space.intersect_shape(query, 1).is_empty()


## Sprite besar di luar node entitas (jembatan, air terjun) juga menutup tanah di bawahnya.
## Sprite selebar peta (latar belakang) dilewati supaya tidak menutup semuanya.
func _collect_scene_covers(node: Node) -> void:
	var map_size := Vector2(_ground.get_used_rect().size * TILE)
	for child in node.get_children():
		if child == _holder or child == self or child is CanvasLayer or child is Player:
			continue
		var before := _covered.size()
		if child is Sprite2D or child is AnimatedSprite2D:
			_collect_covered_one(child)
		if _covered.size() > before:
			var r: Rect2 = _covered[-1]
			if r.size.x > map_size.x * 0.5 and r.size.y > map_size.y * 0.5:
				_covered.pop_back()
		_collect_scene_covers(child)


## Kumpulkan kotak gambar sprite besar (pohon, batu besar) di bawah node entitas.
func _collect_covered(node: Node) -> void:
	for child in node.get_children():
		if child is Forageable or child is Weed:
			continue
		_collect_covered_one(child)
		_collect_covered(child)


func _collect_covered_one(child: Node) -> void:
	var rect := Rect2()
	if child is Sprite2D and child.texture:
		rect = child.get_rect()
	elif child is AnimatedSprite2D and child.sprite_frames:
		var tex: Texture2D = child.sprite_frames.get_frame_texture(child.animation, 0)
		if tex:
			var size := tex.get_size()
			rect = Rect2(-size / 2.0 if child.centered else Vector2.ZERO, size)
			rect.position += child.offset
	if rect.size.x > TILE * 1.5 or rect.size.y > TILE * 1.5:
		var xf: Transform2D = child.global_transform
		_covered.append(xf * rect)
