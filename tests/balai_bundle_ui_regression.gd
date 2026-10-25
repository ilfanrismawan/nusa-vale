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
	check(menu.find_children("*", "OptionButton", true, false).is_empty(), "Balai bundle navigation uses native wing and package cards, not dropdowns")
	check(menu._filtered_projects().size() == manager.definitions.size(), "overview exposes actual restoration projects")
	for card in menu.get_node("%Bundles").get_children():
		check(card.tooltip_text.is_empty(), "package hover does not obscure the board with duplicate details")
	for row in menu._rows.values():
		check(row.button.tooltip_text.is_empty(), "requirement hover leaves donation controls unobstructed")
	check(menu.get_node("%Reward").tooltip_text.is_empty(), "reward details stay in the panel instead of a covering tooltip")
	var before := player.data.get_item_count("wood")
	menu._select_requirement("wood")
	check(player.data.get_item_count("wood") == before and manager.contributed(menu.project_id, "wood") == 0, "selecting a requirement never donates automatically")
	menu.get_node("%Quantity").value = 12
	menu.get_node("%Donate").pressed.emit()
	check(manager.contributed("balai_nadi_restoration", "wood") == 12 and player.data.get_item_count("wood") == before - 12, "donation only consumes explicitly selected quantity")
	check(SaveManager.load_game() and manager.contributed("balai_nadi_restoration", "wood") == 12, "partial package progress persists through the existing save manager")
	menu._select_requirement("stone")
	check(menu.get_node("%Donate").disabled, "missing selected material disables contribution")
	menu._select_wing("alam")
	check(menu._filtered_projects().size() == manager.wing_projects("alam").size() and menu._filtered_projects().size() == 7 and menu._filtered_projects().all(func(project): return project.wing_id == "alam"), "wing filter groups nature packages by editable resource data")
	menu._select_project_id("bug_bundle")
	check(menu._rows.size() == menu.requirements_per_page, "large package fits fixed requirement page")
	menu._change_requirement_page(1)
	check(menu._rows.has("luna_moth") and menu._rows.size() == 1, "requirement paging exposes the remaining bug without scrolling")
	check(menu.get_node("%Reward").text.contains("Tapper") or menu.get_node("%Reward").text.contains("tapper"), "bundle reward preview uses actual reward item data")
	await capture("balai-bundles-bugs")
	menu._select_wing("karya")
	check(menu._filtered_projects().size() == 4 and not menu.get_node("%Empty").visible and menu.get_node("%Detail").visible, "craft wing lists its four data-driven bundles")
	check(menu.get_node("%Status").text.contains("Bonus Sayap Karya"), "wing bonus preview is shown in package status")
	menu._donate()
	check(player.data.get_item_count("wood") == before - 12, "switching wing cannot submit a hidden previous package")
	menu._select_wing("all")
	menu._select_project_id("balai_nadi_restoration")
	menu._select_requirement("wood")
	await capture("balai-bundles-overview")
	for id in manager.definition("balai_nadi_restoration").requirements:
		if id == "money":
			GameState.money = 2000
		else:
			player.data.add_item_silent(id, manager.remaining("balai_nadi_restoration", id))
		menu._contribute(id)
	check(manager.completed("balai_nadi_restoration") and menu.get_node("%Donate").disabled and menu.get_node("%CompletedStamp").visible, "completed package stamps itself and prevents duplicate donations")
	check(not manager.completed("greenhouse_restoration"), "completing the hall does not complete independent nature packages")
	await capture("balai-bundles-completed")
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
	menu.project_id = "greenhouse_restoration"
	add_child(menu)
	await settle()
	menu._select_requirement("wood")
	menu.get_node("%Quantity").value = 9
	var owner_wood := other.get_item_count("wood")
	var p1_wood := GameState.p1().get_item_count("wood")
	menu._donate()
	check(other.get_item_count("wood") == owner_wood - 9 and GameState.p1().get_item_count("wood") == p1_wood, "co-op contribution uses the board owner's bag despite another active player context")
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
	for control_name in ["%Detail", "%Donate", "%Quantity", "%RewardPanel", "%Close"]:
		var control: Control = menu.get_node(control_name)
		check(view.get_visible_rect().grow(1).encloses(control.get_global_rect()), "bundle controls fit a co-op viewport: " + control_name)
	menu.close_menu()
	view.queue_free()
	await settle()
	print("BALAI BUNDLE UI REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
