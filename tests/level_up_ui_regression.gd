extends Node

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _ready() -> void:
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	var data := GameState.p1()
	data.skills.levels[&"farmer"] = 5
	data.skills.levels[&"miner"] = 5
	GameState.skills.last_levels.assign([
		{"data": data, "role_id": &"farmer", "from": 4, "to": 5},
		{"data": data, "role_id": &"miner", "from": 3, "to": 5}])
	GameState.skills.show_recap()
	var menu = GameState.skills._ui
	await get_tree().process_frame
	check(menu.scene_file_path == "res://scenes/ui/level_up_ui.tscn", "manager opens editor-native level recap scene")
	check(menu.get_node("%RecapPage").text == "1 / 2", "multiple role increases use pagination")
	check(menu._pending.size() >= 2, "pending branches are gathered from player skill data")
	check(menu.get_node("%RoleIcon").texture != null, "recap uses actual skill icon")
	menu._change_recap(1)
	check(menu.get_node("%Levels").text.contains("3"), "next page shows the matching level range")
	menu._change_recap(1)
	check(menu._recap_page == 0, "recap navigation wraps safely")
	if OS.get_environment("NUSA_LEVEL_UI_SCREENSHOT") == "1" and DisplayServer.get_name() != "headless":
		await get_tree().process_frame
		RenderingServer.force_draw()
		get_viewport().get_texture().get_image().save_png("res://scratch/level-up-ui-preview.png")
	menu._select_branch("a")
	check(data.skills.choice(&"farmer", 5) == "a", "branch confirmation uses existing skill choice backend")
	check(menu._pending.size() == 1, "choosing a branch updates remaining choices")
	menu._close()
	await get_tree().process_frame
	check(data.skills.choice(&"miner", 5).is_empty(), "postponing leaves other branches available for later")
	GameState.skills.show_recap()
	menu = GameState.skills._ui
	check(menu != null and menu.rows.is_empty(), "pending-only recap works without a new level increase")
	menu._select_branch("a")
	check(menu.get_node("%ChoiceEmpty").visible, "all choices resolved shows completion state")
	var reason: StringName = menu._pause_reason
	menu.queue_free()
	await get_tree().process_frame
	check(not PauseManager._reasons.has(reason), "external recap removal releases its pause reason")
	print("LEVEL UP UI REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
