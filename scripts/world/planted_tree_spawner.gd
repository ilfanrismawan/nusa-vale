extends TreeSpawner
## Pohon yang ditanam pemain dari biji pohon (GDD 7). Tidak menumbuhkan pohon acak;
## hanya menyimpan pohon tanaman di ForageManager area "<location_id>#planted" ("jenis|ukuran|hari tanam")
## dan membesarkannya setelah grow_days hari (aturan TreeSpawner).
## Pasang lewat kode: load("res://scripts/world/planted_tree_spawner.gd").attach_planted(self, "farm", ^"YSort")

const GROUP := &"planted_trees"


static func attach_planted(scene_root: Node, p_location_id: String, p_entities_path: NodePath) -> Node:
	var spawner = load("res://scripts/world/planted_tree_spawner.gd").new()
	spawner.name = "PlantedTreeSpawner"
	spawner.location_id = p_location_id
	spawner.entities_path = p_entities_path
	scene_root.add_child(spawner)
	return spawner


func _ready() -> void:
	daily_spawn = 0
	max_active = 0
	# Pemain berdiri tepat di sebelah petak yang ditanami.
	player_clearance = 0.0
	add_to_group(GROUP)
	super()


func _area_key() -> String:
	return location_id + "#planted"


func plant(cell: Vector2i, kind: String) -> bool:
	if _ground == null:
		return false
	if not FarmManager.get_cell_data(cell).is_empty():
		Notify.say("Tanah yang dicangkul untuk tanaman. Tanam biji pohon di tanah biasa.")
		return false
	if not _is_free(cell) or not _cell_allowed(cell):
		Notify.say("Terlalu sempit. Pohon butuh ruang kosong sekitar dua petak.")
		return false
	var id := "%s|%s|%d" % [kind, SMALL, DayCycle.current_day]
	ForageManager.add_item(_area_key(), cell, id)
	_place(cell, id, true)
	Notify.say("Pohon ditanam! Dalam %d hari tumbuh jadi pohon besar." % grow_days)
	return true


func _on_spawned(_count: int) -> void:
	pass
