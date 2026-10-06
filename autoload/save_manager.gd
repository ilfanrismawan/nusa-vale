extends Node

const SAVE_PATH := "user://nusa_vale_save.json"
const BACKUP_PATH := "user://nusa_vale_sav.json.bak"
const TEMP_PATH := "user://nusa_vale_save.json.tmp"

const SAVE_VERSION := 2

signal game_saved
signal game_loaded
signal save_failed(reason: String)
signal load_failed(reason: String)


func _ready() -> void:
	call_deferred("_load_on_startup")

func _load_on_startup() -> void:
	load_game()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> bool:
	var data: Dictionary =  _build_save_data()
	
	var json_text: String = JSON.stringify(data, "\t")

	var temp_file := FileAccess.open(
		TEMP_PATH,
		FileAccess.WRITE
	)

	if temp_file == null:
		var reason := (
			"Gagal membuat temporary save file: %s"
			% FileAccess.get_open_error()
		)
		
		push_error(reason)
		save_failed.emit(reason)
		return false
	
	temp_file.store_string(json_text)
	temp_file.close()


	if not FileAccess.file_exists(TEMP_PATH):
		var reason := "Temporary save file tidak ditemukan."
		
		push_error(reason)
		save_failed.emit(reason)
		return false
	
	if FileAccess.file_exists(SAVE_PATH):
		var old_save := FileAccess.open(
			SAVE_PATH,
			FileAccess.READ
		)
		
		if old_save != null:
			var old_data: String = old_save.get_as_text()
			old_save.close()
			
			var backup_file := FileAccess.open(
				BACKUP_PATH,
				FileAccess.WRITE
			)
			
			if backup_file != null:
				backup_file.store_string(old_data)
				backup_file.close()
	
	var dir := DirAccess.open("user://")
	
	if dir == null:
		var reason := "Tidak bisa membuka user directory."
		
		push_error(reason)
		save_failed.emit(reason)
		return false
	
	if dir.file_exists("nusa_vale_save.json"):
		dir.remove("nusa_vale_save.json")
		
	var rename_error := dir.rename(
		"nusa_vale_save.json.tmp",
		"nusa_vale_save.json"
	)
	
	if rename_error != OK:
		var reason := (
			"Gagal  mengganti temporary save: %s"
			% rename_error
		)
		
		push_error(reason)
		save_failed.emit(reason)
		return false

	print(
		"Game tersimpan | Hari %d"
		% DayCycle.current_day
	)
	
	game_saved.emit()
	
	return true
	
func load_game() -> bool:	
	if not FileAccess.file_exists(SAVE_PATH):
		print("Belum ada save file. Memulai game baru.")
		return false
	
	var file := FileAccess.open(
		SAVE_PATH,
		FileAccess.READ
	)

	if file == null:
		var reason := ("Gagal membuka save file: %s" % FileAccess.get_open_error())
		push_error(reason)
		load_failed.emit(reason)
		_try_load_backup()
		return false


	var json_text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_text)
	
	if not parsed is Dictionary:
		var reason := "Save file rusak atau format tidak valid."
		
		push_error(reason)
		load_failed.emit(reason)
		
		return false
		
	var data: Dictionary = parsed
	
	
	var version: int = int(data.get("version", 1))
	if version > SAVE_VERSION:
		var reason := (
			"Save version %d lebih baru dari versi game %d."
			% [version, SAVE_VERSION]
		)
		
		push_error(reason)
		load_failed.emit(reason)
		
		return false
	
	_load_day_cycle(parsed)
	_load_player(parsed)
	_load_inventory(parsed)
	_load_farm(parsed)
	_load_world_state(parsed)
	_load_discoveries(parsed)
	_load_resources(parsed)
	
	print(
		"Loading save version: %d"
		% [version, DayCycle.current_day]
	)
	
	game_loaded.emit()
	
	return true
	
func _build_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,

		"day_cycle": {
			"day": DayCycle.current_day,
			"hour": DayCycle.hour,
			"minute": DayCycle.minute,
		},

		"player": {
			"money": max(0, GameState.money),
			"stamina": clampi(GameState.stamina, 0, GameState.MAX_STAMINA),
			"bag_level": GameState.bag_level,
		},

		"inventory": _serialize_inventory(),

		"farm": _serialize_farm(),

		"world_state": WorldState.flags.duplicate(true),

		"discoveries": DiscoveryManager.discoveries.duplicate(true),

		"resources": {
			"chopped_trees": GameState.chopped_trees.duplicate(),
			"mined_rocks": GameState.mined_rocks.duplicate(),
		},
	}
	
func _load_day_cycle(data: Dictionary) -> void:
	var day_data: Dictionary = data.get(
		"day_cycle",
		{}
	)
	
	if not day_data is Dictionary:
		day_data = {}
	
	DayCycle.current_day = max(
		1,
		int(day_data.get("day", 1))
	)
	
	DayCycle.hour = clampi(
		int(day_data.get("hour", 6)),
		0,
		23
	)
	
	DayCycle.minute = clampi(
		int(day_data.get("minute", 0)),
		0,
		59
	)
	
func _load_player(data: Dictionary) -> void:
	var player_data: Dictionary = data.get(
		"player", 
		{}
	)
	
	if not player_data is Dictionary:
		player_data = {}
	
	GameState.money = max(
		0,
		int(player_data.get("money", 100))
	)
	
	GameState.stamina = clampi(
		int(player_data.get("stamina",GameState.MAX_STAMINA)), 0, GameState.MAX_STAMINA
	)
	
	GameState.bag_level = clampi(
		int(player_data.get("bag_level", 0)),
		0,
		GameState.BAG_SIZES.size() - 1
	)
	
	GameState.stamina_changed.emit(
		GameState.stamina,
		GameState.MAX_STAMINA
	)
	
	GameState.money_changed.emit(
		GameState.money
	)
	
func _serialize_inventory() -> Array:
	var result: Array = []
	
	for i in range(GameState.inventory.size()):
		var slot: Variant = GameState.inventory[i]
		
		if slot == null:
			continue
		
		if not slot is Dictionary:
			continue
		
		if slot.get("item") == null:
			continue
		
		var item: ItemData = slot["item"]
		
		if item == null:
			continue
		
		var count: int = int(
			slot.get("count", 1)
		)
		
		if count <= 0:
			continue
		
		count = mini(count, item.max_stack)
		
		result.append({
			"slot": i,
			"id": item.item_id,
			"count": count,
		})
		
	return result

func _load_inventory(data: Dictionary) -> void:
	for i in range(GameState.INVENTORY_SIZE):
		GameState.inventory[i] = null
	
	var inventory_data: Variant = data.get(
		"inventory",
		[]
	)	
	
	if not inventory_data is Array:
		return
	
	for entry in inventory_data:
		if not entry is Dictionary:
			continue
		
		var item_id: String = str(entry.get("id", ""))
		if item_id.is_empty():
			continue
		
		var count: int = int(entry.get("count", 1))
		var slot_id: int = int(entry.get("slot", -1))
		
		if slot_id < 0:
			continue
		if slot_id >= GameState.INVENTORY_SIZE:
			continue
		if count <= 0:
			continue
			
		var item: ItemData = GameState._resolve_item(item_id)
		
		if item == null:
			push_warning("Item tidak ditemukan saat load: %s" % item_id)
			continue
			
		count = mini(count, item.max_stack)
		
		GameState.inventory[slot_id] = {
			"item": item,
			"count": count,
		}
		
func _serialize_farm() -> Array:
	var farm_data: Array = []
	
	for cell: Vector2i in FarmManager.farm_data:
		var d: Dictionary = (
			FarmManager.farm_data[cell]
		)
		
		var crop: CropData = d.get("crop")
		
		farm_data.append({
			"cell": [cell.x, cell.y],
			"state": str(d.get("state", "")),
			"crop": (
				crop.resource_path
				if crop != null
				else ""
					),
			"stage": max(0, int(d.get("stage", 0))),
			"days_in_stage": max(0, int(d.get("days_in_stage", 0))),
			"watered": bool(d.get("watered", false)),
		})
		
	return farm_data
	
func _load_farm(data: Dictionary) -> void:
	FarmManager.farm_data.clear()
	
	var farm_data: Variant = data.get(
		"farm",
		[]
	)
	
	if not farm_data is Array:
		return
	
	for entry in farm_data:
		if not entry is Dictionary:
			continue
		
		var cell_data: Array = entry.get(
			"cell",
			[]
		)
		
		if not cell_data is Array:
			continue
			
		if cell_data.size() < 2:
			continue
			
		var cell := Vector2i(
			int(cell_data[0]),
			int(cell_data[1])
		)
		
		var crop: CropData = null
		
		var crop_path: String = str(entry.get("crop", ""))
		
		if not crop_path.is_empty():
			if ResourceLoader.exists(crop_path):
				crop = load(crop_path) as CropData
			else:
				push_warning("Crop resource tidak ditemukan: %s" % crop_path)
	
		FarmManager.farm_data[cell] = {
			"state": str(entry.get("state", "tilled")),
			"crop": crop,
			"stage": max(0, int(entry.get("stage", 0))),
			"days_in_stage": max(0, int(entry.get("days_in_stage", 0))),
			"watered": bool(entry.get("watered", false))
		}
		
func _load_world_state(data: Dictionary) -> void:
	WorldState.reset()
	
	var world_data: Variant = data.get(
		"world_state",
		{}
	)
	
	if not world_data is Dictionary:
		return
	
	for flag_id in world_data:		
		var id: String = str(flag_id)
		
		WorldState.flags[id] = bool(world_data[flag_id])
	
func _load_discoveries(data: Dictionary) -> void:
	DiscoveryManager.reset()
	
	var discovery_data: Dictionary = data.get(
		"discoveries",
		{}
	)
	
	if not discovery_data is Dictionary:
		return
		
	for discovery_id in discovery_data:
		if bool(discovery_data[discovery_id]):
			DiscoveryManager.discover(
				str(discovery_id)
			)
			
func _load_resources(data: Dictionary) -> void:	
	var resource_data: Dictionary = data.get(
		"resources",
		{}
	)
	
	if not resource_data is Dictionary:
		return
	
	GameState.chopped_trees.clear()
	
	var chopped_trees: Variant = resource_data.get("chopped_trees", [])
	if chopped_trees is Array:
		for tree_id in chopped_trees:
			GameState.chopped_trees.append(str(tree_id))
	
	GameState.mined_rocks.clear()
	
	var mined_rocks: Variant = resource_data.get("mined_rocks", [])
	
	if mined_rocks is Array:
		for rock_id in mined_rocks:
			GameState.mined_rocks.append(str(rock_id))
			
func _try_load_backup() -> bool:
	if not FileAccess.file_exists(BACKUP_PATH):
		push_warning("Tidak ada backup save.")
		return false
	print("Mencoba memulihkan backup save..")
	
	var backup_file := FileAccess.open(BACKUP_PATH, FileAccess.READ)
	
	if backup_file== null:
		push_error("Gagal membuka backup save: %s" % FileAccess.get_open_error()) 
		return false
	
	var json_text: String = backup_file.get_as_text()
	backup_file.close()
	
	var parsed: Variant = JSON.parse_string(json_text)
	
	if not parsed is Dictionary:
		push_error("Backup save juga rusak.")
		return false
	
	var backup_data: Dictionary = parsed
	
	var version: int = int(backup_data.get("version", 1))
	
	if version > SAVE_VERSION:
		push_error("Backup save terlalu baru.")
		return false
	
	_load_day_cycle(backup_data)
	_load_player(backup_data)
	_load_inventory(backup_data)
	_load_farm(backup_data)
	_load_world_state(backup_data)
	_load_discoveries(backup_data)
	_load_resources(backup_data)
	
	print("Backup save berhasil dipulihkan.")
	
	game_loaded.emit()
	
	return true
