extends Node
## Autoload "ForageManager": barang liar (foraging) yang sedang tergeletak di tiap area.
## Jenis barang = resources/forage_data/*.tres (ForageData).
## ForageSpawner di scene menaruh node-nya; manager ini mengingat sel mana berisi apa,
## jadi barang tetap sama saat keluar-masuk area dan tersimpan di save (key "forage").
##
## Aturan: tiap hari baru muncul `daily_spawn` barang (sampai `max_active`).
## Hari yang dilewati tanpa berkunjung ikut dihitung. Ganti musim = semua barang lama hilang.

signal foraged(location_id: String, item_id: String)

const DATA_DIR := "res://resources/forage_data"

var _all: Array[ForageData] = []
## area -> {"season": int, "last_day": int, "items": {"x,y": id}}
## Area forage = location_id ("forest"); area rumput liar = "<location_id>#weed".
var areas: Dictionary = {}


func _ready() -> void:
	_load_data()


func _load_data() -> void:
	_all.clear()
	var dir := DirAccess.open(DATA_DIR)
	if dir == null:
		push_warning("ForageManager: folder %s tidak ada." % DATA_DIR)
		return
	for file in dir.get_files():
		# Hasil export menyimpan .tres sebagai .tres.remap
		var res_name := file.trim_suffix(".remap")
		if not res_name.ends_with(".tres"):
			continue
		var data := load(DATA_DIR.path_join(res_name)) as ForageData
		if data and data.item:
			_all.append(data)


## dig = false: barang di permukaan tanah. dig = true: isi titik gali.
func candidates(location_id: String, dig: bool = false) -> Array[ForageData]:
	var season := DayCycle.get_current_season()
	var result: Array[ForageData] = []
	for data in _all:
		if data.dig == dig and data.is_available(location_id, season):
			result.append(data)
	return result


## Pilih satu barang acak sesuai bobot. null jika area/musim ini tidak punya forage.
func pick(location_id: String, dig: bool = false) -> ForageData:
	var pool := candidates(location_id, dig)
	var total := 0.0
	for data in pool:
		total += data.weight
	if total <= 0.0:
		return null
	var roll := randf() * total
	for data in pool:
		roll -= data.weight
		if roll <= 0.0:
			return data
	return pool.back()


## Berapa barang baru yang harus ditaruh sekarang. Sekaligus mencatat hari ini sudah diproses.
## `clear_on_season` = false untuk rumput liar: tetap ada saat musim berganti.
func roll_count(location_id: String, daily_spawn: int, max_active: int, clear_on_season: bool = true) -> int:
	var area := _area(location_id)
	var season_index := _season_index()
	if int(area["season"]) != season_index:
		if clear_on_season:
			area["items"].clear()
			area["last_day"] = 0
		area["season"] = season_index

	var free_slots: int = max_active - area["items"].size()
	var count: int
	if int(area["last_day"]) <= 0:
		# Kunjungan pertama musim ini: langsung agak ramai.
		count = ceili(max_active * 0.6)
	else:
		count = (DayCycle.current_day - int(area["last_day"])) * daily_spawn
	area["last_day"] = DayCycle.current_day
	return clampi(count, 0, maxi(free_slots, 0))


func get_items(location_id: String) -> Dictionary:
	return _area(location_id)["items"]


func has_item_at(location_id: String, cell: Vector2i) -> bool:
	return get_items(location_id).has(key_of(cell))


func add_item(location_id: String, cell: Vector2i, item_id: String) -> void:
	get_items(location_id)[key_of(cell)] = item_id


## Hapus tanpa sinyal (mis. id yang sudah tidak ada di game).
func remove_item(location_id: String, cell: Vector2i) -> void:
	get_items(location_id).erase(key_of(cell))


func take_item(location_id: String, cell: Vector2i) -> void:
	var items := get_items(location_id)
	var key := key_of(cell)
	if not items.has(key):
		return
	var item_id: String = items[key]
	items.erase(key)
	foraged.emit(location_id, item_id)


func cell_from_key(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() < 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))


func reset() -> void:
	areas.clear()


# ── Save ─────────────────────────────────────────────────────────────────────

func to_save() -> Dictionary:
	return areas.duplicate(true)


## Save lama (tanpa key "forage") cukup memanggil ini dengan {}: semua area kosong.
func load_save(data: Variant) -> void:
	reset()
	if not data is Dictionary:
		return
	for location_id in data:
		var entry: Variant = data[location_id]
		if not entry is Dictionary:
			continue
		var area := _area(str(location_id))
		area["season"] = int(entry.get("season", -1))
		area["last_day"] = int(entry.get("last_day", 0))
		var items: Variant = entry.get("items", {})
		if not items is Dictionary:
			continue
		for key in items:
			var item_id := str(items[key])
			area["items"][str(key)] = item_id


# ── Internal ─────────────────────────────────────────────────────────────────

func _area(location_id: String) -> Dictionary:
	if not areas.has(location_id):
		areas[location_id] = {"season": -1, "last_day": 0, "items": {}}
	return areas[location_id]


## Musim ke-berapa sejak hari 1 (tahun ikut dihitung), supaya musim sama tahun depan tetap dianggap baru.
func _season_index() -> int:
	return floori(float(DayCycle.current_day - 1) / DayCycle.DAYS_PER_SEASON)


func key_of(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]
