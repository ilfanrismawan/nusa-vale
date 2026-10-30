extends Node

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func _ready() -> void:
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	var manager := GameState.balai_nadi
	var donor := GameState.p1()
	check(manager.WINGS.size() == 4 and manager.restoration_stage() == "Terbengkalai", "Four wings with abandoned initial state")
	GameState.money = 800
	check(manager.contribute(donor, "balai_nadi_restoration", "money", 200) == 200 and GameState.money == 600, "Shared money contribution")
	check(SaveManager.load_game() and GameState.money == 600 and manager.contributed("balai_nadi_restoration", "money") == 200, "Money and progress reload together")
	DirAccess.make_dir_absolute(SaveManager.BACKUP_PATH + ".tmp")
	check(manager.contribute(donor, "balai_nadi_restoration", "money") == 0 and GameState.money == 600, "Failed money save rolls back")
	DirAccess.remove_absolute(SaveManager.BACKUP_PATH + ".tmp")
	manager.contribute(donor, "balai_nadi_restoration", "money")
	for item in {"wood": 100, "stone": 50}:
		donor.add_item(item, manager.remaining("balai_nadi_restoration", item))
		manager.contribute(donor, "balai_nadi_restoration", item)
	check(manager.completed("balai_nadi_restoration") and not UnlockManager.is_unlocked("greenhouse"), "Hall restoration does not automatically unlock greenhouse")
	# Tas awal (12 slot, 10 terisi alat) tidak muat 150 kayu + 75 batu + tembaga sekaligus.
	donor.bag_level = 2
	for item in {"wood": 150, "stone": 75, "copper_bar": 5}:
		donor.add_item(item, manager.remaining("greenhouse_restoration", item))
		manager.contribute(donor, "greenhouse_restoration", item)
	check(UnlockManager.is_unlocked("greenhouse") and WorldState.has_flag("greenhouse_unlocked"), "Nature wing unlocks separate greenhouse facility")
	check(SaveManager.load_game() and UnlockManager.is_unlocked("greenhouse"), "Reward survives disk reload")
	check(manager.contribute(donor, "greenhouse_restoration", "wood") == 0, "No duplicate donations")
	check(manager.restoration_stage() == "Kehidupan Kembali", "Restoration stage follows working facilities")
	GameState.new_game()
	check(not UnlockManager.is_unlocked("greenhouse"), "New game resets greenhouse access")
	var town: Node = load("res://scenes/world/town.tscn").instantiate()
	get_tree().root.add_child(town)
	await get_tree().process_frame
	check(town.has_node("BalaiNadiAccess") and ResourceUID.ensure_path(town.get_node("BalaiNadiAccess").target_scene).ends_with("balai_nadi/balai.tscn"), "Hall access belongs to town separately from greenhouse")
	town.queue_free()
	print("BALAI WINGS COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
