extends Node

var failures := 0

class InventoryOwner extends CanvasLayer:
	var data: PlayerData
	var _menu_buttons: Dictionary = {}

	func _owner_input() -> PlayerInput:
		return PlayerInput.solo()

func check(value: bool, message: String) -> void:
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	var data := GameState.p1()
	data.skills.levels["farmer"] = 5
	data.skills.points["farmer"] = SkillSystem.points_for_level(5)
	data.skills.tokens = 2
	var menu = load("res://scenes/ui/skill_tree_ui.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	check(menu.get_node("%Roles").get_child_count() == SkillSystem.roles().size(), "role navigation comes from existing skill catalog")
	check(menu._entries.has("5:a") and menu._entries.has("5:b"), "tree shows both actual specialization branches")
	check(menu.get_node("%Lines").get_child_count() > 0, "tree draws connecting paths")
	menu._select_node("5:a")
	check(data.skills.choice(&"farmer", 5).is_empty(), "node selection only previews without choosing or spending")
	check(not menu.get_node("%Confirm").disabled, "available specialization enables explicit confirmation")
	if OS.get_environment("NUSA_SKILL_TREE_SCREENSHOT") == "1" and DisplayServer.get_name() != "headless":
		await get_tree().process_frame
		await get_tree().process_frame
		RenderingServer.force_draw()
		get_viewport().get_texture().get_image().save_png("res://scratch/skill-tree-ui-preview.png")
	menu._confirm()
	check(data.skills.choice(&"farmer", 5) == "a", "confirmation uses existing permanent branch choice")
	menu._select_node("5:b")
	check(menu.get_node("%Confirm").disabled, "opposite branch is unavailable after choosing")
	menu._confirm()
	check(data.skills.choice(&"farmer", 5) == "a", "disabled action cannot overwrite the selected branch")
	menu._change_page(1)
	check(menu._entries.has("10:a") and not menu._entries.has("1:"), "second tier page exposes later nodes without a long scroll")
	menu._select_node("10:a")
	check(menu.get_node("%Confirm").disabled, "future branch remains locked by active level")
	menu._use_token()
	check(data.skills.tokens == 1 and data.skills.earned_level(&"farmer") == 6 and data.skills.level(&"farmer") == 5, "token grants EXP but does not bypass overnight activation")
	menu._select_role(SkillSystem.role(&"miner"))
	check(menu._page == 0 and menu._selected != "10:a", "changing role resets tree page and selected node")
	var original_size := get_tree().root.size
	get_tree().root.size = Vector2i(640, 360)
	await get_tree().process_frame
	menu._resize()
	var bounds := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	for path in ["%Confirm", "%Close", "%Next", "%UseToken"]:
		check(bounds.encloses(menu.get_node(path).get_global_rect()), "tree control fits a small viewport: " + path)
	get_tree().root.size = original_size
	menu.close_menu()
	await get_tree().process_frame
	check(not is_instance_valid(menu), "closing tree frees its skill-signal subscription")
	var owner := InventoryOwner.new()
	owner.data = PlayerData.new()
	owner.data.index = 1
	owner.data.skills.levels["farmer"] = 5
	add_child(owner)
	menu = load("res://scenes/ui/skill_tree_ui.tscn").instantiate()
	menu.inventory_ui = owner
	owner.add_child(menu)
	menu._select_node("5:b")
	menu._confirm()
	check(owner.data.skills.choice(&"farmer", 5) == "b" and data.skills.choice(&"farmer", 5) == "a", "tree uses inventory owner's skills instead of another active player")
	owner.hide()
	await get_tree().process_frame
	check(not is_instance_valid(menu), "hiding owner inventory also closes its tree overlay")
	owner.queue_free()
	var inventory = load("res://scenes/ui/ui_inventory.tscn").instantiate()
	add_child(inventory)
	inventory._open()
	inventory._show_skills()
	menu = inventory._skill_tree
	check(is_instance_valid(menu) and menu.inventory_ui == inventory, "inventory skill tab opens the native tree with its actual owner")
	check(menu is Control and menu.get_parent() == inventory.book_root and menu.embedded, "skill tree is an embedded Control under the inventory book")
	check(not menu.get_node("Backdrop").visible and not menu.get_node("%Close").visible, "embedded tree has no separate backdrop or close flow")
	inventory._show_relationships()
	check(not menu.visible and inventory._relationship_ui.visible, "NPC tab replaces the tree inside the same book")
	inventory._cycle_tab(-1)
	check(menu.visible and not inventory._relationship_ui.visible, "gamepad moves from NPC to skill page")
	inventory._show_status()
	check(not menu.visible and not inventory._relationship_ui.visible, "status tab hides both embedded pages")
	inventory._show_skills()
	inventory._show_skills()
	check(inventory._skill_tree == menu, "reopening the skill tab cannot create duplicate overlays")
	menu.close_menu()
	await get_tree().process_frame
	check(inventory.visible, "returning from tree keeps inventory open")
	inventory._show_skills()
	menu = inventory._skill_tree
	inventory._close()
	await get_tree().process_frame
	check(is_instance_valid(menu) and not menu.is_visible_in_tree() and not inventory.visible, "closing inventory hides its persistent skill page")
	inventory.queue_free()
	print("SKILL TREE UI REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
