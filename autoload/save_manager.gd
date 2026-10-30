extends Node

## Save game dalam SLOT_COUNT slot: user://saves/slot_<n>.json (+ .bak dan .tmp per slot).
## Slot aktif (current_slot) dipakai save_game()/load_game() dan auto-save saat tidur/pingsan.
## Save lama satu-file (user://nusa_vale_save.json) dipindah otomatis ke slot 1 saat game dibuka.

const SLOT_COUNT := 3
const SAVE_DIR := "user://saves"
const SLOT_META_PATH := "user://saves/slots.cfg"
const LEGACY_SAVE_PATH := "user://nusa_vale_save.json"
const LEGACY_BACKUP_PATH := "user://nusa_vale_save.json.bak"
const SEASON_NAMES: Array[String] = ["Musim Semi", "Musim Panas", "Musim Gugur", "Musim Dingin"]
## Dipakai ringkasan slot bila save belum punya nama pemain (save versi 6 ke bawah).
const DEFAULT_PLAYER_NAME := "Petani"

## v20: slot kalung/cincin/aksesori + mesin baru (sarang lebah, penggergajian); save lama otomatis kosong.
## v22: Role & EXP per pemain ("skills" di blok player dan tiap karakter co-op); save lama = Lv0.
## v25: permanent friendship locks and per-character household/social reward letters.
## v26: peternakan lanjutan (kerbau, kapibara, kuda, anak hewan, kehamilan, inkubator, bulu bebek); save lama = hewan dewasa tanpa inkubator.
const SAVE_VERSION := 27

signal game_saved
signal game_loaded
signal save_failed(reason: String)
signal load_failed(reason: String)
signal slot_changed(slot: int)

## Slot aktif, 1..SLOT_COUNT. Diingat di SLOT_META_PATH supaya auto-load memilih slot terakhir.
var current_slot: int = 1

## Path file slot aktif. Nama huruf besar dipertahankan dari versi satu-file (dipakai tes).
var SAVE_PATH: String:
	get: return slot_path(current_slot)
var BACKUP_PATH: String:
	get: return slot_path(current_slot) + ".bak"
var TEMP_PATH: String:
	get: return slot_path(current_slot) + ".tmp"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	_migrate_legacy_save()
	current_slot = _read_last_slot()
	call_deferred("_load_on_startup")

func _load_on_startup() -> void:
	load_game()

# ── Slot ────────────────────────────────────────────────────────────

func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, clampi(slot, 1, SLOT_COUNT)]

func _slot_files(slot: int) -> Array[String]:
	var base := slot_path(slot)
	return [base, base + ".bak", base + ".tmp", base + ".bak.tmp"]

## Jadikan slot ini tujuan save_game()/load_game() berikutnya.
func select_slot(slot: int) -> void:
	current_slot = clampi(slot, 1, SLOT_COUNT)
	_write_last_slot(current_slot)
	slot_changed.emit(current_slot)

## Tanpa argumen: slot aktif.
func has_save(slot: int = -1) -> bool:
	var base := slot_path(current_slot if slot < 1 else slot)
	return not _read_save(base).is_empty() or not _read_save(base + ".bak").is_empty()

func has_any_save() -> bool:
	for slot in range(1, SLOT_COUNT + 1):
		if has_save(slot):
			return true
	return false

## Ringkasan untuk menu slot. Kosong = slot belum dipakai (atau save rusak tanpa backup).
func get_slot_summary(slot: int) -> Dictionary:
	var base := slot_path(slot)
	var source := base
	var data := _read_save(base)
	if data.is_empty():
		source = base + ".bak"
		data = _read_save(source)
	if data.is_empty():
		return {}
	var day := maxi(1, int(data.day_cycle.get("day", 1)))
	var player: Dictionary = data.player
	var player_name: Variant = player.get("name", "")
	if not player_name is String or (player_name as String).strip_edges().is_empty():
		player_name = DEFAULT_PLAYER_NAME
	# Save versi 6 ke bawah belum punya saved_at: pakai waktu ubah file.
	var saved_at: int = int(data.get("saved_at", 0))
	if saved_at <= 0:
		saved_at = int(FileAccess.get_modified_time(source))
	@warning_ignore("integer_division")
	var season := ((day - 1) / DayCycle.DAYS_PER_SEASON) % SEASON_NAMES.size()
	@warning_ignore("integer_division")
	var year := ((day - 1) / (DayCycle.DAYS_PER_SEASON * SEASON_NAMES.size())) + 1
	return {
		"name": player_name,
		"farm_name": data.get("farm_name", ""),
		"birthday_season": player.get("birthday_season", ""),
		"birthday_day": player.get("birthday_day", 0),
		"day": day,
		"day_of_season": ((day - 1) % DayCycle.DAYS_PER_SEASON) + 1,
		"season": season,
		"season_name": SEASON_NAMES[season],
		"year": year,
		"money": maxi(0, int(player.get("money", 0))),
		"saved_at": saved_at,
		"from_backup": source != base,
	}

## Slot aktif (dipakai Game Baru dan tes).
func delete_save() -> bool:
	return delete_slot(current_slot)

func delete_slot(slot: int) -> bool:
	for save_path in _slot_files(slot):
		if FileAccess.file_exists(save_path):
			var error := DirAccess.remove_absolute(save_path)
			if error != OK:
				return _save_error("Gagal menghapus save slot %d: %s" % [slot, error])
	return true

func _read_last_slot() -> int:
	var config := ConfigFile.new()
	if config.load(SLOT_META_PATH) != OK:
		return 1
	return clampi(int(config.get_value("slots", "last_slot", 1)), 1, SLOT_COUNT)

func _write_last_slot(slot: int) -> void:
	var config := ConfigFile.new()
	config.set_value("slots", "last_slot", slot)
	config.save(SLOT_META_PATH)

## Save satu-file dari sebelum ada slot: salin ke slot 1 (atau slot kosong pertama bila slot 1
## sudah terisi), lalu file lama dinamai *.migrated (tidak dihapus) supaya tidak dipindah dua kali.
func _migrate_legacy_save() -> bool:
	if not FileAccess.file_exists(LEGACY_SAVE_PATH) and not FileAccess.file_exists(LEGACY_BACKUP_PATH):
		return false
	var target_slot := -1
	for slot in range(1, SLOT_COUNT + 1):
		var occupied := false
		for save_path in _slot_files(slot).slice(0, 2):
			occupied = occupied or FileAccess.file_exists(save_path)
		if not occupied:
			target_slot = slot
			break
	if target_slot < 0:
		push_warning("Save lama tidak dipindah: semua slot sudah terisi.")
		return false
	var base := slot_path(target_slot)
	for pair in [[LEGACY_SAVE_PATH, base], [LEGACY_BACKUP_PATH, base + ".bak"]]:
		if not FileAccess.file_exists(pair[0]):
			continue
		var error := DirAccess.copy_absolute(pair[0], pair[1])
		if error != OK:
			push_error("Gagal memindah save lama ke slot %d: %s" % [target_slot, error])
			return false
	for legacy_path in [LEGACY_SAVE_PATH, LEGACY_BACKUP_PATH]:
		if FileAccess.file_exists(legacy_path):
			DirAccess.rename_absolute(legacy_path, legacy_path + ".migrated")
	_write_last_slot(target_slot)
	print("Save lama dipindah ke slot %d." % target_slot)
	return true

# ── Simpan / muat ───────────────────────────────────────────────────

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
	_write_last_slot(current_slot)
	print("Game tersimpan | Slot %d | Hari %d" % [current_slot, DayCycle.current_day])
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
	_write_last_slot(current_slot)
	print("Loading save version: %d (slot %d, hari %d)" % [int(data.get("version", 1)), current_slot, DayCycle.current_day])
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
	if not player.get("name", "") is String or not player.get("id", "") is String:
		return false
	if not NPCSocialService.valid_save(player.get("friendships", {})):
		return false
	if not PlayerData.valid_social_progress(player.get("npc_progress", {})):
		return false
	if not player.get("birthday_season", "") is String or not _valid_numbers(player, ["birthday_day"]):
		return false
	if not player.get("pet_id", "") is String or not player.get("pet_name", "") is String or not _valid_numbers(player, ["pet_affection", "pet_day"]):
		return false
	var order: Variant = player.get("tool_order", {})
	if not order is Dictionary:
		return false
	if not order.is_empty():
		if not order.get("old", "") is String or not order.get("next", "") is String or not _valid_numbers(order, ["ready_day"]):
			return false
		var upgrade := ToolUpgradeManager.get_upgrade_data(str(order.get("old", "")))
		if upgrade.is_empty() or str(upgrade["next"]) != str(order.get("next", "")) or int(order.get("ready_day", 0)) < 1 or int(order.get("ready_day", 0)) > 1000000:
			return false
	return player.get("appearance", {}) is Dictionary and _valid_inventory(player.get("inventory", []))

func _is_valid_save(data: Dictionary) -> bool:
	if not data.get("farm_name", "") is String:
		return false
	# An empty/unrelated JSON object is not a save.
	if not data.has("player") or not data.has("day_cycle") or not data.has("inventory"):
		return false
	if not _valid_numbers(data, ["version", "saved_at"]):
		return false
	var version := int(data.get("version", 1))
	if not ShippingManager.valid_save(data.get("shipping", {})):
		return false
	if not DailyWeather.valid_save(data.get("weather", {})):
		return false
	if not CaveManager.valid_save(data.get("cave", {})):
		return false
	if not HouseManager.valid_save(data.get("house", {})):
		return false
	if not GameState.gathering.valid_save(data.get("gathering", {})):
		return false
	if not HorrorManager.valid_save(data.get("horror", {})):
		return false
	if not WildlifeJournal.valid_save(data.get("wildlife", {})):
		return false
	if not Campus.valid_save(data.get("campus", {})):
		return false
	if version < 1 or version > SAVE_VERSION:
		return false
	for key in ["day_cycle", "world_state", "unlocks", "discoveries", "resources", "forage", "balai_nadi"]:
		if data.has(key) and not data[key] is Dictionary:
			return false
	if not _valid_numbers(data.day_cycle, ["day", "hour", "minute"]) or not _valid_player(data.player):
		return false
	if not _valid_inventory(data.inventory):
		return false
	for key in ["farm", "coop_players", "structures"]:
		if data.has(key) and not data[key] is Array:
			return false
	for player in data.get("coop_players", []):
		if not _valid_player(player):
			return false
	for structure in data.get("structures", []):
		if structure is Dictionary and structure.get("item") in ["silo", "pasture_grass"]:
			var key := "hay" if structure.item == "silo" else "regrow_day"
			var amount: Variant = structure.get(key, 0)
			if not RanchHusbandry.integer(amount) or amount < 0 or amount > (240 if key == "hay" else 1000000):
				return false
		if structure is Dictionary and structure.get("item") in StructureManager.RANCHES:
			var animals: Variant = structure.get("livestock", {})
			if not RanchHusbandry.valid(animals, str(structure.item)):
				return false
			if not animals.is_empty() and int(animals.last_day) > int(data.day_cycle.get("day", 1)):
				return false
	for entry in data.get("farm", []):
		if entry is Dictionary and not entry.get("area", "farm") is String:
			return false
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
		"farm_name": GameState.farm_name,

		## Versi 7: waktu simpan (unix, UTC) untuk ringkasan slot.
		"saved_at": int(Time.get_unix_time_from_system()),

		"day_cycle": {
			"day": DayCycle.current_day,
			"hour": DayCycle.hour,
			"minute": DayCycle.minute,
		},

		"player": {
			"name": GameState.p1().player_name,
			"birthday_season": GameState.p1().birthday_season,
			"birthday_day": GameState.p1().birthday_day,
			"pet_id": GameState.p1().pet_id,
			"pet_name": GameState.p1().pet_name,
			"pet_affection": GameState.p1().pet_affection,
			"pet_day": GameState.p1().pet_day,
			"money": max(0, GameState.money),
			"stamina": clampi(GameState.p1().stamina, 0, GameState.p1().max_stamina),
			"hp": clampi(GameState.p1().hp, 1, GameState.p1().max_hp),
			"consumed_daya": GameState.p1().consumed_daya.duplicate(),
			"bag_level": GameState.p1().bag_level,
			"watering_water": GameState.p1().watering_water,
			"tool_order": GameState.p1().tool_order.duplicate(true),
			"learned_recipes": GameState.p1().learned_recipes.duplicate(),
			"friendships": GameState.p1().friendships.duplicate(true),
			"npc_progress": GameState.p1().social_progress(),
			"appearance": GameState.p1().appearance.to_dict(),
			"equipment": GameState.p1().serialize_equipment(),
			"skills": GameState.p1().skills.to_dict(),
			# Kemampuan fakultas Universitas; save lama tanpa kunci ini = semua dikuasai.
			"abilities": GameState.p1().abilities.duplicate(),
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
		"structures": StructureManager.to_save(),
		"shipping": GameState.shipping.to_save(),
		"weather": GameState.weather.to_save(),
		# Version 8: shared contributions and one-time completion state.
		"balai_nadi": GameState.balai_nadi.to_save(),
		"daya": GameState.daya.to_save(),
		# Versi 15: lift checkpoint Gua Tambang (GDD 9). Versi 16: boss gua yang sudah kalah (GDD 8.2-C).
		"cave": GameState.cave.to_save(),
		# Versi 17: tingkat rumah + pesanan upgrade di Wira (GDD 4.12).
		"house": GameState.house.to_save(),
		# Versi 18: tapper di pohon (GDD 7, 4A-3).
		"gathering": GameState.gathering.to_save(),
		# Versi 27: Kesulitan Gaib per save + tingkat horor yang sudah diumumkan (GDD 4.1).
		"horror": GameState.horror.to_save(),
		# Catatan Satwa (GDD 4.10.13); kunci opsional, save lama = catatan kosong.
		"wildlife": GameState.wildlife_seen.duplicate(),
		# Fungsi ruangan Sekolah & Universitas; kunci opsional, save lama = kosong.
		"campus": GameState.campus.duplicate(),

		"coop_players": _serialize_coop_players(),
	}

func _apply_save(data: Dictionary) -> void:
	var farm_name: Variant = data.get("farm_name", "")
	GameState.farm_name = farm_name if farm_name is String else ""
	GameState.p1().clear_food_effects()
	GameState.use_player(GameState.p1())
	_load_day_cycle(data)
	# Sebelum pemain: stamina tersimpan bisa di atas 100 berkat bonus rumah.
	GameState.house.load_save(data.get("house", {}))
	GameState.weather.load_save(data.get("weather", {}))
	_load_player(data)
	GameState.shipping.load_save(data.get("shipping", {}))
	ToolUpgradeManager.load_order(GameState.p1(), data.get("player", {}).get("tool_order", {}))
	_load_inventory(data)
	_load_farm(data)
	_load_world_state(data)
	# Save v16 ke bawah tanpa "house": renovasi dapur lama dihitung rumah tingkat 1.
	GameState.house.sync_with_world()
	_load_unlocks(data)
	GameState.balai_nadi.load_save(data.get("balai_nadi", {}))
	_load_discoveries(data)
	_load_resources(data)
	_load_appearance(data)
	_load_forage(data)
	StructureManager.load_save(data.get("structures", []))
	_load_coop_players(data)
	GameState.daya.load_save(data.get("daya", {}))
	GameState.cave.load_save(data.get("cave", {}))
	GameState.gathering.load_save(data.get("gathering", {}))
	# Setelah gua, hari, dan unlock: tingkat horor dihitung dari progres itu.
	GameState.horror.load_save(data.get("horror", {}))
	WildlifeJournal.load_save(data.get("wildlife", {}))
	Campus.load_save(data.get("campus", {}))
	if GameState.weather.is_raining():
		FarmManager.apply_rain()

## Versi 6: tas/stamina/penampilan pemain co-op (uang tetap satu, milik bersama).
## Versi 21: daftar semua karakter co-op save ini (bukan hanya yang sedang main), tiap entri punya "id".
func _serialize_coop_players() -> Array:
	var result: Array = []
	for player in GameState.coop_roster:
		result.append(player.to_dict())
	return result

## Save lama tanpa key ini: belum ada karakter co-op. Save v6-v20: P2-P4 lama menjadi karakter
## co-op pertama di daftar (id dibuat baru). Setelah dimuat game selalu mulai sendiri (P1);
## pemain lain bergabung lagi dan memilih karakternya.
func _load_coop_players(data: Dictionary) -> void:
	var entries: Variant = data.get("coop_players", [])
	if not entries is Array:
		entries = []
	GameState.players.resize(1)
	GameState.coop_roster.clear()
	var ids := {}
	for entry in entries:
		if GameState.coop_roster.size() >= GameState.MAX_COOP_CHARACTERS:
			break
		if not entry is Dictionary:
			continue
		var player := PlayerData.new(1)
		player.reset_to_starter()
		player.load_dict(entry)
		if player.character_id.is_empty() or ids.has(player.character_id):
			player.character_id = GameState._new_character_id()
		if player.player_name.strip_edges().is_empty():
			player.player_name = "Pemain %d" % (GameState.coop_roster.size() + 2)
		ids[player.character_id] = true
		GameState.coop_roster.append(player)
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
	
	GameState.p1().load_daya(player_data.get("consumed_daya", []))
	GameState.p1().load_recipes(player_data.get("learned_recipes", []))
	GameState.p1().load_friendships(player_data.get("friendships", {}))
	GameState.p1().load_social_progress(player_data.get("npc_progress", {}))
	GameState.stamina = clampi(
		int(player_data.get("stamina",GameState.MAX_STAMINA)), 0, GameState.p1().max_stamina
	)
	
	# Versi 22: Role & EXP. Dimuat sebelum HP karena perk Combat menambah HP maks.
	GameState.p1().skills.load_dict(player_data.get("skills", {}))
	Abilities.load_save(GameState.p1(), player_data)
	# Versi 14: HP per pemain. Save lama tanpa key ini = HP penuh.
	GameState.p1().hp = clampi(int(player_data.get("hp", PlayerData.MAX_HP)), 1, GameState.p1().max_hp)

	# Versi 7: nama pemain. Save lama tanpa key ini = kosong (ringkasan slot memakai "Petani").
	var player_name: Variant = player_data.get("name", "")
	GameState.p1().player_name = player_name if player_name is String else ""
	GameState.p1().load_birthday(player_data)
	GameState.p1().load_pet(player_data)

	GameState.p1().watering_water = clampi(int(player_data.get("watering_water", 20)), 0, 350)
	GameState.hotbar_page = 0
	GameState.bag_level = clampi(
		int(player_data.get("bag_level", 0)),
		0,
		GameState.BAG_SIZES.size() - 1
	)
	
	GameState.stamina_changed.emit(
		GameState.stamina,
		GameState.p1().max_stamina
	)
	
	GameState.money_changed.emit(
		GameState.money
	)
	
func _serialize_inventory() -> Array:
	return GameState.p1().serialize_inventory()

func _load_inventory(data: Dictionary) -> void:
	GameState.p1().load_inventory(data.get("inventory", []))
	GameState.p1().load_equipment(data.get("player", {}).get("equipment", {}))

func _serialize_farm() -> Array:
	var farm_data: Array = []
	
	for cell: Vector2i in FarmManager.farm_data:
		var d: Dictionary = (
			FarmManager.farm_data[cell]
		)
		
		var crop: CropData = d.get("crop")
		
		farm_data.append({
			"area": str(d.get("area", "farm")),
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
			"regrow": bool(d.get("regrow", false)),
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
			"area": str(entry.get("area", "farm")),
			"state": "planted" if crop != null else "tilled",
			"crop": crop,
			"stage": clampi(int(entry.get("stage", 0)), 0, maxi(0, crop.get_total_stages() - 1)) if crop != null else 0,
			"days_in_stage": max(0, int(entry.get("days_in_stage", 0))),
			"watered": bool(entry.get("watered", false)),
			# Opsional sejak 26 Oktober 2026; save lama = belum pernah dipanen.
			"regrow": bool(entry.get("regrow", false))
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
	_write_last_slot(current_slot)
	print("Backup save slot %d berhasil dipulihkan." % current_slot)
	game_loaded.emit()
	return true
