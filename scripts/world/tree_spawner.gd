class_name TreeSpawner
extends ForageSpawner
## Menumbuhkan pohon baru tiap hari supaya kayu tidak habis.
## Pohon baru muncul sebagai pohon kecil (small_*_tree), lalu jadi pohon besar setelah grow_days hari.
## Pasang lewat kode: TreeSpawner.attach_trees(self, "forest", ^"YSortEntities")
## Data disimpan lewat ForageManager di area "<location_id>#tree", nilai "<jenis>|<ukuran>|<hari tanam>".

const SCENE_SMALL := "res://scenes/objects/small_%s_tree.tscn"
const SCENE_BIG := "res://scenes/objects/%s_tree.tscn"
const SMALL := "small"
const BIG := "big"

## Jenis pohon yang boleh tumbuh di area ini.
@export var tree_kinds: PackedStringArray = ["pine", "birch", "maple", "mahogany"]
## Hari dari pohon kecil sampai pohon besar.
@export_range(1, 28) var grow_days: int = 7
## Jarak minimal (px) dari pohon/batu lain supaya daun tidak bertumpuk.
@export var min_spacing: float = 28.0
## Jarak minimal (px) dari pemain saat pohon muncul.
@export var player_clearance: float = 40.0


static func attach_trees(scene_root: Node, p_location_id: String, p_entities_path: NodePath = ^"YSortEntities", p_daily: int = 2, p_max: int = 12) -> TreeSpawner:
	var spawner := TreeSpawner.new()
	spawner.name = "TreeSpawner"
	spawner.location_id = p_location_id
	spawner.entities_path = p_entities_path
	spawner.daily_spawn = p_daily
	spawner.max_active = p_max
	scene_root.add_child(spawner)
	return spawner


func _sync(animate_existing: bool) -> void:
	# Proses umur juga saat area dimuat kembali setelah beberapa hari.
	_grow(DayCycle.current_day)
	super(animate_existing)


## Pohon kecil yang sudah cukup umur jadi pohon besar.
func _grow(day: int) -> void:
	var items := ForageManager.get_items(_area_key())
	for key in items.keys():
		var parts := str(items[key]).split("|")
		if parts.size() < 3 or parts[1] != SMALL:
			continue
		# Forest Whisperer (Forager Lv10 A): pohon tumbuh 2x lebih cepat.
		if day - int(parts[2]) < SkillSystem.tree_grow_days(grow_days):
			continue
		items[key] = "%s|%s|%s" % [parts[0], BIG, parts[2]]
		# Node lama dibuang; _sync menaruh versi besarnya.
		if _nodes.has(key):
			var node: Variant = _nodes[key]
			if is_instance_valid(node):
				node.set_meta(&"growing", true)
				node.queue_free()
			_nodes.erase(key)


func _area_key() -> String:
	return location_id + "#tree"


func _clear_on_season() -> bool:
	return false


func _pick_id() -> String:
	if tree_kinds.is_empty():
		return ""
	var kind := tree_kinds[randi() % tree_kinds.size()]
	return "%s|%s|%d" % [kind, SMALL, DayCycle.current_day]


func _make_node(id: String, cell: Vector2i) -> Node2D:
	var parts := id.split("|")
	if parts.is_empty():
		return null
	var path := (SCENE_BIG if parts.size() > 1 and parts[1] == BIG else SCENE_SMALL) % parts[0]
	if not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	var node := scene.instantiate() as Node2D
	if node == null:
		return null
	if "persistent" in node:
		node.persistent = false  # posisinya dicatat ForageManager, bukan chopped_trees
	node.name = "SpawnedTree_%d_%d" % [cell.x, cell.y]
	node.set_meta("tree_kind", parts[0])
	node.tree_exiting.connect(_on_tree_removed.bind(node, cell))
	return node


func _on_tree_removed(node: Node, cell: Vector2i) -> void:
	# Hanya pohon yang ditebang yang dihapus dari data (bukan karena pindah scene / tumbuh).
	if node.has_meta(&"growing"):
		return
	if "is_destroyed" in node and node.is_destroyed:
		ForageManager.remove_item(_area_key(), cell)
		_nodes.erase(ForageManager.key_of(cell))
		if SkillSystem.household(&"tree_replant") > 0.0:
			var kind := str(node.get_meta("tree_kind", "pine"))
			ForageManager.add_item(_area_key(), cell, "%s|%s|%d" % [kind, SMALL, DayCycle.current_day])


func _cell_allowed(cell: Vector2i) -> bool:
	var pos := _ground.to_global(_ground.map_to_local(cell))
	for group in [&"choppable", &"mineable", &"weed"]:
		for other in get_tree().get_nodes_in_group(group):
			if other is Node2D and (other as Node2D).get_world_2d() == get_world_2d() and (other as Node2D).global_position.distance_to(pos) < min_spacing:
				return false
	for player in get_tree().get_nodes_in_group(&"player"):
		if player is Node2D and (player as Node2D).get_world_2d() == get_world_2d() and (player as Node2D).global_position.distance_to(pos) < player_clearance:
			return false
	return true


func _on_spawned(_count: int) -> void:
	if DiscoveryManager.discover("tree_spawn_tip"):
		Notify.say("Pohon muda tumbuh di hutan. Dalam seminggu jadi pohon besar.")
