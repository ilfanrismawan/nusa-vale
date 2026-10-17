extends Node

var failures := 0

func check(value: bool, caption: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + caption)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	GameState.money = 100000
	var room := load("res://scenes/world/interior/town/blacksmith.tscn").instantiate() as Node2D
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	await get_tree().process_frame
	var player: Player = room.get_node("Player/CharacterBody2D")
	player.set_physics_process(false)
	player.data.add_item_silent("copper_bar", 5)
	player.data.add_item_silent("wood", 10)
	var shop := load("res://scenes/ui/tool_upgrade_ui.tscn").instantiate() as ToolUpgradeUI
	shop.player = player
	Coop.ui_parent(player).add_child(shop)
	await get_tree().process_frame
	await get_tree().process_frame
	check(shop._tool_list_box.columns == 4, "reference uses four tier columns")
	check(shop._entries.size() == ToolUpgradeManager.TOOL_TYPES.size() * (ToolUpgradeManager.TIERS.size() - 1), "all existing tool types and upgrade tiers remain accessible")
	check(shop._tool_list_box.get_child_count() == ToolUpgradeManager.TOOL_TYPES.size() * 4, "extra tool rows remain scrollable")
	check(shop.get_node("Design/Detail").position == Vector2(1026, 100), "cream detail panel follows reference")
	check(shop.get_node("%Materials").get_child_count() == 3, "previous tool and both material requirements are shown")
	check(not shop._upgrade_btn.disabled and shop._detail_title.text == GameState._resolve_item("axe_copper").display_name, "next owned tool upgrade is selected")
	check(not shop.get_node("%Description").text.is_empty(), "editable tool-type fallback fills missing item descriptions")
	var before := GameState.money
	shop._change_page(2)
	check(shop._page == 2 and shop._detail_title.text == GameState._resolve_item("axe_obsidian").display_name, "last tier page can be inspected")
	check(shop._upgrade_btn.disabled and GameState.money == before and player.data.tool_order.is_empty(), "previewing future tiers cannot skip missing prerequisite tools")
	shop._change_page(1)
	check(shop._page == 0, "tier pages wrap")
	for entry in shop._entries:
		if entry.next == "axe_copper":
			shop._select_tool(entry)
			break
	if OS.get_environment("NUSA_BLACKSMITH_SCREENSHOT") == "1" and DisplayServer.get_name() != "headless":
		for child in room.get_node("Player").get_children():
			if child is CanvasLayer:
				child.hide()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://scratch/blacksmith-ui-preview.png") == OK, "native blacksmith screen renders")
	var owner := player.data
	var upgrade := ToolUpgradeManager.get_upgrade_data("axe_wood")
	before = GameState.money
	shop._on_upgrade_pressed()
	check(owner.tool_order.get("next") == "axe_copper" and GameState.money == before - int(upgrade.cost), "confirmation creates exact-price order")
	check(not owner.has_item("axe_wood") and shop._order_progress.visible, "work in progress holds original tool and displays progress")
	before = GameState.money
	shop._on_upgrade_pressed()
	check(GameState.money == before and not owner.has_item("axe_copper"), "waiting order cannot charge again or deliver early")
	DayCycle.current_day = int(owner.tool_order.ready_day)
	DayCycle.day_passed.emit(DayCycle.current_day)
	check(shop._upgrade_btn.text == "Ambil alat" and not shop._upgrade_btn.disabled, "ready order exposes collection")
	for index in owner.bag_size:
		if owner.inventory[index] == null:
			owner.inventory[index] = {"item": GameState._resolve_item("wood"), "count": 999}
	shop._on_upgrade_pressed()
	check(not owner.tool_order.is_empty() and not owner.has_item("axe_copper"), "full bag preserves ready order")
	owner.inventory[0] = null
	shop._on_upgrade_pressed()
	check(owner.tool_order.is_empty() and owner.has_item("axe_copper"), "collection delivers upgraded tool once space exists")
	shop._close()
	await get_tree().process_frame
	check(not get_tree().paused, "closing restores gameplay")
	get_tree().current_scene = self
	room.queue_free()
	await get_tree().process_frame
	for voice in Juice._voices:
		voice.stop()
		voice.stream = null
	print("BLACKSMITH UI COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
