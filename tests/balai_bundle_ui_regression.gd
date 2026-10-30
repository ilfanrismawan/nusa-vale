extends Node

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func settle() -> void:
	for frame in 6:
		await get_tree().process_frame

func capture(file_name: String) -> void:
	if OS.get_environment("NUSA_BALAI_UI_SCREENSHOT") != "1" or DisplayServer.get_name() == "headless":
		return
	for notice in Notify._box.get_children():
		notice.queue_free()
	await settle()
	RenderingServer.force_draw()
	get_viewport().get_texture().get_image().save_png("res://scratch/" + file_name + ".png")

func petal_keys(menu: BalaiNadiUI) -> Array:
	return menu._petals.map(func(petal): return petal.get_meta("entry").key)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	var rig = load("res://scenes/player/Player.tscn").instantiate()
	add_child(rig)
	var player: Player = rig.get_node("CharacterBody2D")
	player.set_process(false)
	player.set_physics_process(false)
	player.data.bag_level = 2
	player.data.add_item_silent("wood", 80)
	var manager := GameState.balai_nadi
	var menu := load("res://scenes/ui/balai_nadi_ui.tscn").instantiate() as BalaiNadiUI
	menu.player = player
	add_child(menu)
	await settle()
	check(menu.find_children("*", "OptionButton", true, false).is_empty() and menu.find_children("*", "SpinBox", true, false).is_empty(), "radial board has no dropdowns or quantity spinners")
	check(petal_keys(menu) == ["balai_nadi_restoration"] and menu._filtered_projects().size() == 1, "before hall restoration the ring only shows the main hall")
	check(menu._level == BalaiNadiUI.Level.WINGS and menu.get_node("%Radial").visible and not menu.get_node("%Card").visible, "board opens on the centered ring")
	await get_tree().create_timer(0.5, true, false, true).timeout
	var center := Vector2(640, 345)
	var core: Control = menu.get_node("%Core")
	check(((core.get_global_rect().get_center() - menu.get_node("Design").position) / menu.get_node("Design").scale.x).distance_to(center) < 40.0, "core button sits in the middle of the screen")
	var before := player.data.get_item_count("wood")
	menu._select_requirement("wood")
	check(menu._level == BalaiNadiUI.Level.CARD and menu.get_node("%Card").visible and not menu.get_node("%Radial").visible, "selecting a requirement opens the glass card")
	check(player.data.get_item_count("wood") == before and manager.contributed(menu.project_id, "wood") == 0, "selecting a requirement never donates automatically")
	for row in menu._rows.values():
		check(row.button.tooltip_text.is_empty(), "requirement slots have no covering tooltip")
	menu.get_node("%Donate").pressed.emit()
	var needed := manager.required(manager.definition("balai_nadi_restoration"), "wood")
	check(manager.contributed("balai_nadi_restoration", "wood") == mini(80, needed) and player.data.get_item_count("wood") == before - mini(80, needed), "donate gives what is still needed from the bag")
	check(menu._rows.wood.label.text == "%d / %d" % [mini(80, needed), needed], "slot shows donated / needed")
	check(SaveManager.load_game() and manager.contributed("balai_nadi_restoration", "wood") == mini(80, needed), "partial package progress persists through the existing save manager")
	menu._select_requirement("stone")
	check(menu.get_node("%Donate").disabled, "missing selected material disables contribution")
	check(menu.get_node("%RewardTokens").text.contains(str(SkillSystem.RULES.balai_tokens)), "card shows the talent token reward")
	check(menu.get_node("%Back").visible and menu.get_node("%Back").get_global_rect().intersects(menu.get_node("%Card").get_global_rect()), "card shows a back icon button")
	menu.get_node("%Back").pressed.emit()
	check(menu._level == BalaiNadiUI.Level.WINGS and menu.get_node("%Radial").visible, "back from the card returns to the ring")
	for id in manager.definition("balai_nadi_restoration").requirements:
		if id == "money":
			GameState.money = 2000
		else:
			player.data.add_item_silent(id, manager.remaining("balai_nadi_restoration", id))
		manager.contribute(player.data, "balai_nadi_restoration", id)
	menu._refresh()
	check(manager.wings_unlocked() and petal_keys(menu) == Array(menu.presentation.radial_wings), "finishing the hall blooms every wing petal")
	menu._set_selection(1)
	check(menu.get_node("%BonusPill").visible and menu.get_node("%BonusLabel").text.contains(manager.wing("alam").bonus_text), "selected wing shows only its bonus")
	menu._activate()
	check(menu._level == BalaiNadiUI.Level.BUNDLES and menu._filtered_projects().size() == 7 and menu._filtered_projects().all(func(project): return project.wing_id == "alam"), "choosing a wing shows its bundle petals")
	check(menu._petals.size() == 7 and not menu.get_node("%BonusPill").visible, "bundle ring has one petal per nature bundle")
	await capture("balai-radial-alam")
	menu._select_project_id("bug_bundle")
	check(menu._rows.size() == manager.definition("bug_bundle").requirements.size() and menu._rows.has("luna_moth"), "card shows every requirement without paging")
	var tapper_reward := GameState._resolve_item(str(manager.definition("bug_bundle").reward_items.keys()[0]))
	check(tapper_reward != null and menu.get_node("%RewardIcon").texture == tapper_reward.icon, "reward preview uses the actual reward item icon")
	menu._back()
	check(menu._level == BalaiNadiUI.Level.BUNDLES and menu._petals[menu._sel].get_meta("entry").key == "bug_bundle", "back from a card keeps the bundle selected")
	menu._back()
	check(menu._level == BalaiNadiUI.Level.WINGS and menu._petals[menu._sel].get_meta("entry").key == "alam", "back from bundles keeps the wing selected")
	menu._select_wing("karya")
	check(menu._filtered_projects().size() == 4, "craft wing lists its four data-driven bundles")
	menu._donate()
	check(player.data.get_item_count("wood") == before - mini(80, needed), "ring level cannot submit a hidden previous package")
	var wild := manager.definition("wild_forage_bundle")
	menu._select_project_id("wild_forage_bundle")
	var granted := 0
	for id in wild.requirements:
		if granted < manager.slots_needed(wild):
			player.data.add_item(id, manager.required(wild, id))
			granted += 1
	menu.get_node("%DonateAll").pressed.emit()
	check(manager.completed("wild_forage_bundle") and menu.get_node("%CompletedStamp").visible and menu.get_node("%Donate").disabled and menu.get_node("%DonateAll").disabled, "Semua fills an N-of-M bundle and stamps it complete")
	check(not manager.completed("greenhouse_restoration"), "completing one bundle does not complete independent nature packages")
	await capture("balai-radial-completed")
	menu.close_menu()
	await settle()
	check(not player.is_input_locked() and not get_tree().paused, "closing bundle board restores solo controls")
	var other := GameState.ensure_player(1)
	other.bag_level = 2
	other.add_item_silent("wood", 40)
	rig.player_index = 1
	Coop.active = true
	GameState.use_player(GameState.p1())
	menu = load("res://scenes/ui/balai_nadi_ui.tscn").instantiate() as BalaiNadiUI
	menu.player = player
	add_child(menu)
	await settle()
	menu._select_project_id("greenhouse_restoration")
	menu._select_requirement("wood")
	var owner_wood := other.get_item_count("wood")
	var p1_wood := GameState.p1().get_item_count("wood")
	menu._donate()
	check(other.get_item_count("wood") < owner_wood and GameState.p1().get_item_count("wood") == p1_wood, "co-op contribution uses the board owner's bag despite another active player context")
	menu.queue_free()
	await settle()
	check(not player.is_input_locked() and not get_tree().paused, "external co-op board removal releases only its owner")
	Coop.active = false
	var view := SubViewport.new()
	view.size = Vector2i(640, 360)
	add_child(view)
	menu = load("res://scenes/ui/balai_nadi_ui.tscn").instantiate() as BalaiNadiUI
	menu.player = player
	view.add_child(menu)
	await settle()
	menu._select_project_id("wild_forage_bundle")
	await get_tree().create_timer(0.4, true, false, true).timeout
	for control_name in ["%Card", "%Back", "%Donate", "%DonateAll", "%Hints"]:
		var control: Control = menu.get_node(control_name)
		check(view.get_visible_rect().grow(4).encloses(control.get_global_rect()), "glass card fits a co-op viewport: " + control_name)
	menu.close_menu()
	view.queue_free()
	await settle()
	print("BALAI BUNDLE UI REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
