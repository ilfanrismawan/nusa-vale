extends Node

const SAVE_PATH := "user://nusa_vale_save.json"
const BACKUP_PATH := "user://nusa_vale_save.json.bak"
const TEMP_PATH := "user://nusa_vale_save.json.tmp"

const SAVE_VERSION := 6

signal game_saved
signal game_loaded
signal save_failed(reason: String)
signal load_failed(reason: String)


func _ready() -> void:
	call_deferred("_load_on_startup")

func _load_on_startup() -> void:
	load_game()

func has_save() -> bool:
	return not _read_save(SAVE_PATH).is_empty() or not _read_save(BACKUP_PATH).is_empty()

func delete_save() -> bool:
	for save_path in [SAVE_PATH, BACKUP_PATH, TEMP_PATH, BACKUP_PATH + ".tmp"]:
		if FileAccess.file_exists(save_path):
			var error := DirAccess.remove_absolute(save_path)
			if error != OK:
				return _save_error("Gagal menghapus save lama: %s" % error)
	return true

func _save_error(reason: String) -> bool:
	push_error(reason)
	save_failed.emit(reason)
	return false

func save_game() -> bool:
	# Serialize P1 explicitly without changing the active player's context.
	var data := _build_save_data()
	var temp_file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if temp_file == null:
		return _save_error("Gagal membuat temporary save: %s" % FileAccess.get_open_error())
	temp_file.store_string(JSON.stringify(data, "\t"))
	temp_file.flush()
	var write_error := temp_file.get_error()
	temp_file.close()
	if write_error != OK or _read_save(TEMP_PATH).is_empty():
		return _save_error("Gagal menulis atau memverifikasi temporary save: %s" % write_error)

	# Never replace a healthy backup with a corrupt/incompatible primary save.
	if not _read_save(SAVE_PATH).is_empty():
		var backup_temp := BACKUP_PATH + ".tmp"
		var backup_error := DirAccess.copy_absolute(SAVE_PATH, backup_temp)
		if backup_error == OK:
			backup_error = DirAccess.rename_absolute(backup_temp, BACKUP_PATH)
		if backup_error != OK:
			return _save_error("Gagal membuat backup save: %s" % backup_error)

	# Rename replaces the destination; never delete the previous save first.
	var rename_error := DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if rename_error != OK:
		return _save_error("Gagal mengganti temporary save: %s" % rename_error)
	print("Game tersimpan | Hari %d" % DayCycle.current_day)
	game_saved.emit()
	return true

func load_game() -> bool:
	var data := _read_save(SAVE_PATH)
	if data.is_empty():
		if _try_load_backup():
			return true
		if FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH):
			var reason := "Save utama dan backup tidak dapat dibaca atau format/versinya tidak valid."
			push_error(reason)
			load_failed.emit(reason)
		else:
			print("Belum ada save file. Memulai game baru.")
		return false
	_apply_save(data)
	print("Loading save version: %d (hari %d)" % [int(data.get("version", 1)), DayCycle.current_day])
	game_loaded.emit()
	return true

## Validate before mutating live state. Missing keys remain compatible with old saves.
func _read_save(save_path: String) -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or not _is_valid_save(parsed):
		return {}
	return parsed

func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _valid_numbers(data: Dictionary, keys: Array) -> bool:
	for key in keys:
		if data.has(key) and not _is_number(data[key]):
			return false
	return true

func _valid_inventory(entries: Variant) -> bool:
	if not entries is Array:
		return false
	for entry in entries:
		if not entry is Dictionary or not _valid_numbers(entry, ["slot", "count"]):
			return false
		if not entry.get("id", "") is String:
			return false
	return true

func _valid_player(player: Variant) -> bool:
	if not player is Dictionary or not _valid_numbers(player, ["money", "stamina", "bag_level"]):
		return false
	return player.get("appearance", {}) is Dictionary and _valid_inventory(player.get("inventory", []))

func _is_valid_save(data: Dictionary) -> bool:
	# An empty/unrelated JSON object is not a save.
	if not data.has("player") or not data.has("day_cycle") or not data.has("inventory"):
		return false
	if not _valid_numbers(data, ["version"]):
		return false
	var version := int(data.get("version", 1))
	if version < 1 or version > SAVE_VERSION:
		return false
	for key in ["day_cycle", "world_state", "unlocks", "discoveries", "resources", "forage"]:
		if data.has(key) and not data[key] is Dictionary:
			return false
	if not _valid_numbers(data.day_cycle, ["day", "hour", "minute"]) or not _valid_player(data.player):
		return false
	if not _valid_inventory(data.inventory):
		return false
	for key in ["farm", "coop_players"]:
		if data.has(key) and not data[key] is Array:
			return false
	for player in data.get("coop_players", []):
		if not _valid_player(player):
			return false
	for entry in data.get("farm", []):
		if not entry is Dictionary or not _valid_numbers(entry, ["stage", "days_in_stage"]):
			return false
		var cell: Variant = entry.get("cell", [])
		if not cell is Array or cell.size() != 2:
			return false
		if not _is_number(cell[0]) or not _is_number(cell[1]):
			return false
	var resources: Dictionary = data.get("resources", {})
	for key in ["chopped_trees", "mined_rocks"]:
		if resources.has(key) and not resources[key] is Array:
			return false
	for area in data.get("forage", {}).values():
		if not area is Dictionary or not _valid_numbers(area, ["season", "last_day"]):
			return false
		if not area.get("items", {}) is Dictionary:
			return false
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
			"stamina": clampi(GameState.p1().stamina, 0, GameState.MAX_STAMINA),
			"bag_level": GameState.p1().bag_level,
			"appearance": GameState.p1().appearance.to_dict(),
		},

		"inventory": _serialize_inventory(),

		"farm": _serialize_farm(),

		"world_state": WorldState.flags.duplicate(true),
		
		"unlocks": UnlockManager.get_unlocks(),

		"discoveries": DiscoveryManager.discoveries.duplicate(true),

		"resources": {
			"chopped_trees": GameState.chopped_trees.duplicate(),
			"mined_rocks": GameState.mined_rocks.duplicate(),
		},

		"forage": ForageManager.to_save(),

		"coop_players": _serialize_coop_players(),
	}

func _apply_save(data: Dictionary) -> void:
	GameState.use_player(GameState.p1())
	_load_day_cycle(data)
	_load_player(data)
	_load_inventory(data)
	_load_farm(data)
	_load_world_state(data)
	_load_unlocks(data)
	_load_discoveries(data)
	_load_resources(data)
	_load_appearance(data)
	_load_forage(data)
	_load_coop_players(data)

## Versi 6: tas/stamina/penampilan P2-P4 dari co-op lokal (uang tetap satu, milik bersama).
func _serialize_coop_players() -> Array:
	var result: Array = []
	for i in range(1, GameState.players.size()):
		result.append(GameState.players[i].to_dict())
	return result

## Save lama tanpa key ini: belum ada pemain co-op; mereka dibuat dengan alat awal saat bergabung.
func _load_coop_players(data: Dictionary) -> void:
	var entries: Variant = data.get("coop_players", [])
	if not entries is Array:
		entries = []
	var player_count := mini(entries.size(), GameState.MAX_PLAYERS - 1)
	for i in player_count:
		var entry: Variant = entries[i]
		var player := GameState.ensure_player(i + 1)
		if entry is Dictionary:
			player.load_dict(entry)
	GameState.players.resize(player_count + 1)
	GameState.use_player(GameState.p1())
	GameState.inventory_changed.emit()

## Versi 5: barang forage yang tergeletak per area. Save lama tanpa key ini = semua area kosong.
func _load_forage(data: Dictionary) -> void:
	ForageManager.load_save(data.get("forage", {}))

## Versi 4: penampilan karakter. Save lama tanpa key ini memakai default (Josh).
func _load_appearance(data: Dictionary) -> void:
	var player_data: Variant = data.get("player", {})
	var appearance_data: Variant = {}
	if player_data is Dictionary:
		appearance_data = player_data.get("appearance", {})
	if not appearance_data is Dictionary:
		appearance_data = {}
	GameState.set_appearance(CharacterAppearance.from_dict(appearance_data))

func _load_unlocks(data: Dictionary) -> void:
	UnlockManager.reset()
	var unlock_data: Variant = data.get("unlocks", {})
	if unlock_data is Dictionary:
		UnlockManager.load_unlocks(unlock_data)
		
	if WorldState.has_flag("bridge_repaired"):
		UnlockManager.unlock("forest")
	
func _load_day_cycle(data: Variant) -> void:
	var day_data: Variant = data.get(
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
	
func _load_player(data: Variant) -> void:
	var player_data: Variant = data.get(
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
	
	GameState.hotbar_page = 0
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
	return GameState.p1().serialize_inventory()

func _load_inventory(data: Dictionary) -> void:
	GameState.p1().load_inventory(data.get("inventory", []))

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
		
		var cell_data: Variant = entry.get(
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
	
		if crop != null and crop.get_total_stages() == 0:
			crop = null
		FarmManager.farm_data[cell] = {
			"state": "planted" if crop != null else "tilled",
			"crop": crop,
			"stage": clampi(int(entry.get("stage", 0)), 0, maxi(0, crop.get_total_stages() - 1)) if crop != null else 0,
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
	
func _load_discoveries(data: Variant) -> void:
	DiscoveryManager.reset()
	
	var discovery_data: Variant = data.get(
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
	var resource_data: Variant = data.get(
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
	var data := _read_save(BACKUP_PATH)
	if data.is_empty():
		return false
	_apply_save(data)
	print("Backup save berhasil dipulihkan.")
	game_loaded.emit()
	return true
