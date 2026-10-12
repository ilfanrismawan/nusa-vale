class_name WeedSpawner
extends ForageSpawner
## Menumbuhkan rumput liar (WeedData) tiap hari. Ditebas dengan sabit.
## Pasang lewat kode: WeedSpawner.attach(self, "farm", ^"YSort")
## only_farmable = true (farm): rumput hanya tumbuh di tanah farmable yang belum dicangkul,
## dan langsung hilang kalau tanahnya dicangkul.

const DATA_DIR := "res://resources/weed_data"

static var _all: Array[WeedData] = []

@export var only_farmable: bool = false

var _check_timer: Timer


static func attach_weeds(scene_root: Node, p_location_id: String, p_entities_path: NodePath = ^"YSortEntities", p_daily: int = 4, p_max: int = 25, p_only_farmable: bool = false) -> WeedSpawner:
	var spawner := WeedSpawner.new()
	spawner.name = "WeedSpawner"
	spawner.location_id = p_location_id
	spawner.entities_path = p_entities_path
	spawner.daily_spawn = p_daily
	spawner.max_active = p_max
	spawner.only_farmable = p_only_farmable
	scene_root.add_child(spawner)
	return spawner


static func all_weeds() -> Array[WeedData]:
	if _all.is_empty():
		var dir := DirAccess.open(DATA_DIR)
		if dir:
			for file in dir.get_files():
				var f := file.trim_suffix(".remap")
				if f.ends_with(".tres"):
					var res := load(DATA_DIR.path_join(f)) as WeedData
					if res:
						_all.append(res)
	return _all


static func find_weed(p_id: String) -> WeedData:
	for w in all_weeds():
		if w.id == p_id:
			return w
	return null


func _ready() -> void:
	super()
	# Rumput yang tanahnya dicangkul langsung hilang.
	_check_timer = Timer.new()
	_check_timer.wait_time = 0.5
	_check_timer.autostart = true
	_check_timer.timeout.connect(_remove_on_tilled)
	add_child(_check_timer)


func _area_key() -> String:
	return location_id + "#weed"


func _clear_on_season() -> bool:
	return false


func _pick_id() -> String:
	var season := DayCycle.get_current_season()
	var total := 0.0
	var pool: Array[WeedData] = []
	for w in all_weeds():
		if w.locations.has(location_id) and w.weight > 0.0 and w.is_in_season(season):
			pool.append(w)
			total += w.weight
	if pool.is_empty():
		return ""
	var r := randf() * total
	for w in pool:
		r -= w.weight
		if r <= 0.0:
			return w.id
	return pool[-1].id


## Rumput yang musimnya sudah lewat (mis. Rumput Berbunga di musim dingin) dibuang dulu.
func _sync(animate_existing: bool) -> void:
	if is_inside_tree():
		var season := DayCycle.get_current_season()
		var items := ForageManager.get_items(_area_key())
		for key in items.keys():
			var data := find_weed(str(items[key]))
			if data != null and not data.is_in_season(season):
				ForageManager.remove_item(_area_key(), ForageManager.cell_from_key(key))
	super(animate_existing)


func _make_node(id: String, cell: Vector2i) -> Node2D:
	var data := find_weed(id)
	if data == null:
		return null
	var node := Weed.new()
	node.setup(data, _area_key(), cell)
	return node


func _cell_allowed(cell: Vector2i) -> bool:
	if not _uses_farm_soil():
		return true
	if FarmManager.farm_data.has(cell):
		return false
	return FarmManager.is_tile_farmable(cell)


func _on_spawned(_count: int) -> void:
	if DiscoveryManager.discover("weed_tip"):
		Notify.say("Rumput liar tumbuh! Tebas pakai sabit untuk dapat Fiber atau bahan lain.")


func _uses_farm_soil() -> bool:
	return only_farmable and is_instance_valid(FarmManager.base_layer_ground)


func _remove_on_tilled() -> void:
	if not _uses_farm_soil():
		return
	for key in _nodes.keys():
		var node: Variant = _nodes[key]
		if not is_instance_valid(node):
			continue
		if FarmManager.farm_data.has(node.cell):
			node.remove_quietly()
			_nodes.erase(key)
