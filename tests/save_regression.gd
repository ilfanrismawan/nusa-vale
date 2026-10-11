extends Node

var failures := 0
var loaded_count := 0
var failed_count := 0

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func write_save(save_path: String, data: Variant) -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func _ready() -> void:
	# Refuse to write anything unless launched with an isolated audit user directory.
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		push_error("Run save tests with an isolated APPDATA directory named nusa-save-audit-* and NUSA_SAVE_AUDIT=1.")
		get_tree().quit(2)
		return
	await get_tree().process_frame
	DayCycle.is_running = false
	SaveManager.game_loaded.connect(func(): loaded_count += 1)
	SaveManager.load_failed.connect(func(_reason): failed_count += 1)
	check(SaveManager.delete_save(), "clean isolated test directory")
	GameState.new_game()
	GameState.money = 987
	DayCycle.current_day = 35
	var p2 := GameState.ensure_player(1)
	p2.stamina = 42
	p2.bag_level = 2
	p2.add_item_silent("seed_carrot", 8)
	GameState.use_player(p2)
	check(SaveManager.save_game(), "save succeeds from P2 context")
	check(GameState.current == p2, "save preserves active player context")
	var original := SaveManager._read_save(SaveManager.SAVE_PATH)
	check(original.player.stamina == GameState.p1().stamina and original.coop_players[0].stamina == 42, "P1/P2 are serialized separately")
	GameState.money = 1
	p2.stamina = 1
	GameState.p1().hotbar_page = 4
	check(SaveManager.load_game(), "round trip succeeds")
	check(GameState.money == 987 and DayCycle.current_day == 35 and p2.stamina == 42 and GameState.players[1] == p2 and GameState.hotbar_page == 0, "round trip restores state and preserves P2 reference")
	check(SaveManager.save_game(), "save replaces existing file and creates backup")
	DirAccess.remove_absolute(SaveManager.SAVE_PATH)
	check(SaveManager.has_save() and SaveManager.load_game(), "backup-only save is available and loads")
	check(failed_count == 0, "successful recovery does not emit load_failed")
	write_save(SaveManager.SAVE_PATH, {"broken": true})
	var backup_text := FileAccess.get_file_as_string(SaveManager.BACKUP_PATH)
	check(SaveManager.load_game(), "invalid primary falls back to backup")
	check(SaveManager.save_game() and FileAccess.get_file_as_string(SaveManager.BACKUP_PATH) == backup_text, "corrupt primary never replaces good backup")
	var malformed := original.duplicate(true)
	malformed.player = []
	write_save(SaveManager.SAVE_PATH, malformed)
	check(SaveManager.load_game(), "wrong section type falls back without runtime error")
	malformed = original.duplicate(true)
	malformed.day_cycle.hour = {}
	write_save(SaveManager.SAVE_PATH, malformed)
	check(SaveManager.load_game(), "wrong numeric type falls back")
	malformed = original.duplicate(true)
	malformed.farm = [{"cell": {}, "stage": 0}]
	write_save(SaveManager.SAVE_PATH, malformed)
	check(SaveManager.load_game(), "wrong farm cell type falls back")
	malformed = original.duplicate(true)
	malformed.version = SaveManager.SAVE_VERSION + 1
	write_save(SaveManager.SAVE_PATH, malformed)
	check(SaveManager.load_game(), "incompatible version recovers supported backup")
	DirAccess.remove_absolute(SaveManager.BACKUP_PATH)
	GameState.money = 321
	var previous_loaded := loaded_count
	check(not SaveManager.load_game() and GameState.money == 321 and loaded_count == previous_loaded and failed_count == 1, "failed load leaves live state intact and emits failure once")
	var legacy := original.duplicate(true)
	legacy.erase("version")
	for key in ["coop_players", "forage", "resources", "discoveries", "unlocks", "world_state"]:
		legacy.erase(key)
	legacy.player.erase("appearance")
	GameState.chopped_trees.append("old_tree")
	ForageManager.areas["forest"] = {}
	write_save(SaveManager.SAVE_PATH, legacy)
	check(SaveManager.load_game() and GameState.players.size() == 1 and GameState.chopped_trees.is_empty() and ForageManager.areas.is_empty(), "legacy save restores defaults and clears stale state")
	check(SaveManager.save_game(), "create valid backup before I/O failure")
	var primary_text := FileAccess.get_file_as_string(SaveManager.SAVE_PATH)
	DirAccess.make_dir_absolute(SaveManager.BACKUP_PATH + ".tmp")
	check(not SaveManager.save_game() and FileAccess.get_file_as_string(SaveManager.SAVE_PATH) == primary_text, "backup write failure preserves primary")
	DirAccess.remove_absolute(SaveManager.BACKUP_PATH + ".tmp")
	var farm_save := original.duplicate(true)
	farm_save.farm = [{"cell": [2, 3], "crop": "res://resources/crop_data/carrot.tres", "stage": 9999, "watered": true}]
	write_save(SaveManager.SAVE_PATH, farm_save)
	check(SaveManager.load_game(), "farm save with excessive growth stage loads")
	var plot: Dictionary = FarmManager.farm_data[Vector2i(2, 3)]
	check(plot.stage == plot.crop.get_total_stages() - 1, "crop growth stage is clamped to valid tile index")
	check(SaveManager.save_game(), "save farm and refresh backup")
	DirAccess.remove_absolute(SaveManager.SAVE_PATH)
	DirAccess.make_dir_absolute(SaveManager.SAVE_PATH)
	backup_text = FileAccess.get_file_as_string(SaveManager.BACKUP_PATH)
	check(SaveManager.load_game(), "unreadable primary path recovers backup")
	check(not SaveManager.save_game() and FileAccess.get_file_as_string(SaveManager.BACKUP_PATH) == backup_text, "rename failure keeps recoverable backup")
	DirAccess.remove_absolute(SaveManager.SAVE_PATH)
	check(SaveManager.delete_save() and not SaveManager.has_save(), "new game clears primary and backup")
	print("SAVE AUDIT COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
