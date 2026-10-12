class_name DigSpotSpawner
extends ForageSpawner
## Memunculkan titik gali (DigSpot) tiap hari. Gali pakai Sekop.
## Isinya dipilih saat digali dari ForageData yang dig = true (musim & area saat itu).
## Bekas galian mengganti tile: di farm jadi tanah cangkul sungguhan (FarmManager.hoe),
## di area lain jadi tile tanah galian sampai besok pagi.
## Pasang lewat kode: DigSpotSpawner.attach_dig_spots(self, "forest", ^"YSortEntities")

## Tile bekas galian: tanah cangkul tunggal di sheet tanah milik user.
const DUG_TEXTURE := preload("res://assets/farm_rpg/tileset/ext/Tilled Soil and wet soil.png")
const DUG_ATLAS := Vector2i(0, 3)

## Hanya di tanah farmable yang belum dicangkul (dipakai di farm).
@export var only_farmable: bool = false

var _dug_layer: TileMapLayer
var _blockers: Array[TileMapLayer] = []
var _blockers_ready := false
var _check_timer: Timer


static func attach_dig_spots(scene_root: Node, p_location_id: String, p_entities_path: NodePath = ^"YSortEntities", p_daily: int = 2, p_max: int = 5, p_only_farmable: bool = false) -> DigSpotSpawner:
	var spawner := DigSpotSpawner.new()
	spawner.name = "DigSpotSpawner"
	spawner.location_id = p_location_id
	spawner.entities_path = p_entities_path
	spawner.daily_spawn = p_daily
	spawner.max_active = p_max
	spawner.only_farmable = p_only_farmable
	scene_root.add_child(spawner)
	return spawner


func _ready() -> void:
	super()
	_check_timer = Timer.new()
	_check_timer.wait_time = 0.5
	_check_timer.autostart = true
	_check_timer.timeout.connect(_remove_on_tilled)
	add_child(_check_timer)


func _on_day_passed(day: int) -> void:
	_clear_dug()
	super(day)


func _sync(animate_existing: bool) -> void:
	# Titik gali lama yang ternyata bukan di tanah (mis. di jembatan) dibuang.
	if is_inside_tree() and is_instance_valid(_ground) and not only_farmable:
		var items := ForageManager.get_items(_area_key())
		for key in items.keys():
			var cell := ForageManager.cell_from_key(key)
			if not _is_soil(cell):
				ForageManager.remove_item(_area_key(), cell)
	super(animate_existing)
	_restore_dug()


func _area_key() -> String:
	return location_id + "#dig"


func _dug_key() -> String:
	return location_id + "#dug"


func _clear_on_season() -> bool:
	return false


func _pick_id() -> String:
	return "dig" if not ForageManager.candidates(location_id, true).is_empty() else ""


func _make_node(_id: String, cell: Vector2i) -> Node2D:
	var node := DigSpot.new()
	node.setup(self, cell)
	return node


func _cell_allowed(cell: Vector2i) -> bool:
	if ForageManager.has_item_at(_dug_key(), cell):
		return false
	if not only_farmable or not is_instance_valid(FarmManager.base_layer_ground):
		return _is_soil(cell)
	return not FarmManager.farm_data.has(cell) and FarmManager.is_tile_farmable(cell)


## Tanah asli: petak tanah penuh (bukan tepi sungai/danau), tidak di bawah jembatan
## atau sprite besar, dan tidak tertutup layer lain seperti reruntuhan atau dekorasi.
func _is_soil(cell: Vector2i) -> bool:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if _ground.get_cell_source_id(cell + Vector2i(dx, dy)) == -1:
				return false
	var center := _ground.to_global(_ground.map_to_local(cell))
	for rect in _covered:
		if rect.has_point(center):
			return false
	for layer in _blocking_layers():
		var local := layer.local_to_map(layer.to_local(center))
		if layer.get_cell_source_id(local) != -1:
			return false
	return true


## Layer tile di atas tanah yang bukan rumput/jalan tanah (mis. Ruins, Decor).
## Layer di bawah tanah (Water) dan layer rumput yang memakai material yang sama dengan tanah dilewati.
func _blocking_layers() -> Array[TileMapLayer]:
	if _blockers_ready:
		return _blockers
	_blockers_ready = true
	var root: Node = owner if owner else get_parent()
	for node in root.find_children("*", "TileMapLayer", true, false):
		var layer := node as TileMapLayer
		if layer == _ground or layer == _dug_layer or layer.name == &"DugLayer" or not layer.visible:
			continue
		if layer.z_index < _ground.z_index:
			continue
		if layer.material != null and layer.material == _ground.material:
			continue
		if "path" in layer.name.to_lower() or "road" in layer.name.to_lower():
			continue
		_blockers.append(layer)
	return _blockers


func _on_spawned(_count: int) -> void:
	if DiscoveryManager.discover("dig_spot_tip"):
		Notify.say("Ada cacing bergoyang di tanah! Gali pakai Sekop untuk menemukan sesuatu.")


## Dipanggil DigSpot setelah digali.
func on_dug(spot: DigSpot) -> void:
	var cell := spot.cell
	ForageManager.remove_item(_area_key(), cell)
	_nodes.erase(ForageManager.key_of(cell))
	# Farm: jadi tanah cangkul sungguhan, bisa langsung ditanami.
	if only_farmable and FarmManager.hoe(cell):
		return
	ForageManager.add_item(_dug_key(), cell, str(DayCycle.current_day))
	_set_dug_tile(cell)


# ── Tile bekas galian ────────────────────────────────────────────────────────

func _layer() -> TileMapLayer:
	if is_instance_valid(_dug_layer):
		return _dug_layer
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	var src := TileSetAtlasSource.new()
	src.texture = DUG_TEXTURE
	src.texture_region_size = Vector2i(16, 16)
	src.create_tile(DUG_ATLAS)
	ts.add_source(src, 0)
	_dug_layer = TileMapLayer.new()
	_dug_layer.name = "DugLayer"
	_dug_layer.tile_set = ts
	_dug_layer.transform = _ground.transform
	# Di atas semua layer tanah, tepat sebelum node entitas (pohon/pemain tetap di atasnya).
	var parent := _ground.get_parent()
	parent.add_child(_dug_layer)
	var index := _ground.get_index() + 1
	if _holder and _holder.get_parent() == parent:
		index = _holder.get_index()
	parent.move_child(_dug_layer, index)
	_dug_layer.z_index = _ground.z_index
	return _dug_layer


func _set_dug_tile(cell: Vector2i) -> void:
	_layer().set_cell(cell, 0, DUG_ATLAS)


func _restore_dug() -> void:
	if _ground == null:
		return
	var dug := ForageManager.get_items(_dug_key())
	for key in dug.keys():
		if int(dug[key]) != DayCycle.current_day:
			dug.erase(key)
			continue
		_set_dug_tile(ForageManager.cell_from_key(key))


## Hari baru: bekas galian tertutup lagi.
func _clear_dug() -> void:
	ForageManager.get_items(_dug_key()).clear()
	if is_instance_valid(_dug_layer):
		_dug_layer.clear()


func _remove_on_tilled() -> void:
	if not only_farmable:
		return
	for key in _nodes.keys():
		var node: Variant = _nodes[key]
		if is_instance_valid(node) and FarmManager.farm_data.has(node.cell):
			ForageManager.remove_item(_area_key(), node.cell)
			node.queue_free()
			_nodes.erase(key)
