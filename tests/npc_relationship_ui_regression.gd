extends Node

const Journal = preload("res://scripts/ui/npc_relationship_ui.gd")

class OwnerRoot:
	extends Node2D
	var player_index := 1

var failures := 0

func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	var player := Player.new()
	player.tool_controller = ToolController.new()
	NPCSocialService.points(player.data, "zarathia")
	player.data.friendships.zarathia.points = 1500
	player.data.friendships.zarathia.talk_day = DayCycle.current_day
	var ui: Journal = load("res://scenes/ui/npc_relationship_ui.tscn").instantiate()
	ui.player = player
	add_child(ui)
	await get_tree().process_frame
	check(ui._ids.size() == 13, "all thirteen NPCs appear")
	check(ui.get_node("%Residents").columns == 4, "each paper leaf has two columns")
	check(not ui.get_node("%Right").visible, "details are hidden until a card is clicked")
	var pager = ui.get_node("%ResidentsPager")
	check(pager.page_size == 8 and pager.get_node("Page").text == "Lembar 1 / 2", "eight residents per spread, four per paper half")
	pager._change(1)
	check(pager._turn_leaf.position.x == 220.0 and pager._turn_leaf.pivot_offset.x == -10.0, "turning sheet starts on right with hinge at book centre")
	check(pager.get_node("Next").disabled and pager.get_node("Previous").disabled, "navigation locked during page turn")
	await get_tree().create_timer(0.48).timeout
	check(pager._turn_leaf.scale.x < 0.0, "right sheet crosses the spine and overlays left page")
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png("res://scratch/npc_relationship_turn_preview.png")
	while pager._turning:
		await get_tree().process_frame
	check(pager.current_page == 1 and pager.get_node("Next").disabled, "next turns right sheet onto left and reaches second spread")
	check(ui.get_node("%Residents").scale == Vector2.ONE and ui.get_node("%Paper").scale == Vector2.ONE, "page turn restores paper and card transforms")
	check(not ui._buttons[ui._ids[0]].visible and ui._buttons[ui._ids[8]].visible, "second leaf displays its own residents")
	ui.refresh()
	check(pager.current_page == 1, "live refresh preserves the current leaf")
	await pager._change(-1)
	check(pager.current_page == 0 and pager.get_node("Previous").disabled, "previous flips back to first leaf")
	ui._buttons["zarathia"].pressed.emit()
	ui.get_node("%BackToResidents").pressed.emit()
	await get_tree().process_frame
	pager.reveal(0)
	await get_tree().process_frame
	# Keep all visible cards and navigation clear of the binding and decorative frame.
	var design: Control = ui.get_node("Design")
	for card: Button in ui._buttons.values():
		if card.visible:
			var local_rect := Rect2(design.get_global_transform().affine_inverse() * card.global_position, card.size)
			check((Rect2(4, 4, 196, 216).grow(0.2).encloses(local_rect) or Rect2(220, 4, 196, 216).grow(0.2).encloses(local_rect)), "card stays inside a paper half: " + card.npc_id)
	var rows := {}
	var visible_count := 0
	for card: Button in ui._buttons.values():
		if card.visible:
			rows[int(card.position.y)] = true
			visible_count += 1
	check(rows.size() == 2 and visible_count == 8, "spread contains two rows and eight cards")
	var left_count := 0
	var right_count := 0
	for card: Button in ui._buttons.values():
		if card.visible:
			if card.position.x < 200:
				left_count += 1
			else:
				right_count += 1
	check(left_count == 4 and right_count == 4, "each paper half has four NPC cards")
	var resident: Button = ui._buttons["zarathia"]
	check(resident.get_node("%GiftIcon").texture != null and resident.get_node("%TalkIcon").texture != null, "gift and talk use actual icons")
	check(resident.get_node("%GiftCheck1").text == "0/2" and resident.get_node("%TalkCheck").text == "1/1", "icon counters retain live activity state")
	check(resident.get_node("%NameLabel").text == "Zarathia", "card is populated after entering tree")
	resident.pressed.emit()
	check(ui.selected_id == "zarathia" and ui.get_node("%Right").visible and not ui.get_node("%Left").visible, "clicking card opens NPC details")
	check(ui.get_node_or_null("%Section") == null, "detail section dropdown removed")
	check(ui.get_node("%DetailsLeft").visible and ui.get_node("%Profile").visible and ui.get_node("%GiftList").visible, "profile and gifts are shown simultaneously on separate leaves")
	check(ui.get_node("%Profile").get_parent() == ui.get_node("%DetailsLeft"), "profile belongs to left paper")
	var gift_button: Button = ui.get_node("%Gifts").get_child(0)
	gift_button.pressed.emit()
	check(ui.get_node("%Profile").visible and ui.get_node("%GiftDetail").visible, "opening gift detail preserves left profile")
	ui.get_node("%GiftBack").pressed.emit()
	check(ui.get_node("%GiftList").visible and ui.get_node("%Profile").visible, "gift back restores list without hiding profile")
	ui.get_node("%ActivityToggle").pressed.emit()
	check(ui.get_node("%Activity").visible and ui.get_node("%GiftList").visible, "journal stays accessible alongside gifts")
	ui.get_node("%ActivityToggle").pressed.emit()
	check(ui.get_node("%BackToResidents").get_theme_font("font") is FontVariation, "back button uses local optical font correction")
	var back_font := ui.get_node("%BackToResidents").get_theme_font("font") as FontVariation
	var activity_font := ui.get_node("%ActivityToggle").get_theme_font("font") as FontVariation
	var gift_font := ui.get_node("%GiftBack").get_theme_font("font") as FontVariation
	check(back_font != activity_font and back_font != gift_font and activity_font != gift_font, "button optical corrections use independent font resources")
	var original_top := back_font.spacing_top
	var other_top := activity_font.spacing_top
	back_font.spacing_top -= 1
	check(activity_font.spacing_top == other_top, "editing back font does not alter other buttons")
	back_font.spacing_top = original_top
	check(gift_button.get_theme_font_size("font_size") == 16 and gift_button.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "gift item buttons use 16px and nearest")
	for path: String in ["%GiftTabs", "%GiftBack", "%GiftHeading", "%GiftHint"]:
		var control: Control = ui.get_node(path)
		check(control.get_theme_font_size("font_size") == 16 and control.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "gift typography: " + path)
	for path: String in ["Body", "Navigation/Previous", "Navigation/Page", "Navigation/Next"]:
		var control: Control = ui.get_node("%GiftInfo").get_node(path)
		check(control.get_theme_font_size("font_size") == 16 and control.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "gift detail typography: " + path)
	check(ui.get_node("%GiftTabs").get_popup().get_theme_font_size("font_size") == 16, "gift category popup uses 16px")
	if DisplayServer.get_name() != "headless":
		await get_tree().process_frame
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png("res://scratch/npc_detail_spread_preview.png")
	ui.get_node("%BackToResidents").pressed.emit()
	check(ui.get_node("%Left").visible and not ui.get_node("%Right").visible, "back button returns to cards")
	ui.get_node("%Search").grab_focus()
	var typing := InputEventKey.new()
	typing.physical_keycode = KEY_I
	typing.keycode = KEY_I
	typing.pressed = true
	ui._input(typing)
	check(not ui._closed, "typing inventory shortcut in search does not close journal")
	check(get_tree().paused, "standalone journal pauses solo game")
	ui._select_npc("zarathia")
	check(ui.get_node("%Name").text == "Zarathia" and ui.get_node("%Points").text.contains("1500"), "selected NPC shows live friendship")
	check(ui.get_node("%Hearts").get_child_count() == 10, "heart capacity follows NPC settings")
	check(ui.get_node("%Journal").text.contains("Bicara hari ini: Sudah"), "daily conversation state displayed")
	for category in 5:
		ui._select_category(category)
		check(ui.get_node("%Gifts").get_child_count() > 0, "gift cards for category %d" % category)
		for card: Button in ui.get_node("%Gifts").get_children():
			check(card.icon != null, "gift card has actual item icon")
	ui.get_node("%Search").text = "ubay"
	ui._rebuild_list()
	check(ui._ids.size() == 1 and ui.selected_id == "ubay", "search filters names and updates selection")
	ui.get_node("%Search").text = "not-a-resident"
	ui._rebuild_list()
	check(ui._ids.is_empty() and not ui.get_node("%Details").visible, "empty search clears stale NPC details")
	ui.get_node("%Search").text = ""
	ui.get_node("%Filter").select(2)
	ui._rebuild_list()
	check(ui._ids.size() == 2, "romance filter follows data")
	ui._select_npc("zarathia")
	player.data.romances.zarathia = "dating"
	ui.refresh()
	check(ui.get_node("%Status").text == "Berpacaran", "dating status displayed")
	var other := GameState.new_coop_character()
	GameState.players.append(other)
	var owner_root := OwnerRoot.new()
	owner_root.add_child(player)
	Coop.active = true
	ui.refresh()
	ui._select_npc("zarathia")
	check(ui.data() == other and ui.get_node("%Points").text.begins_with("0 /") and ui.get_node("%Status").text != "Berpacaran" and ui.get_node("%Journal").text.contains(other.player_name), "journal reads P2 data without showing P1 relationship")
	Coop.active = false
	owner_root.remove_child(player)
	ui.get_node("%Filter").select(0)
	ui.refresh()
	ui._select_npc("zarathia")
	ui._select_category(0)
	ui.get_node("%Search").release_focus()
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		pager.reveal(0)
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png("res://scratch/npc_relationship_preview.png")
		await pager._change(1)
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png("res://scratch/npc_relationship_page2_preview.png")
		await pager._change(-1)
	for size in [Vector2i(1280, 720), Vector2i(640, 360), Vector2i(1920, 1080)]:
		get_viewport().size = size
		ui._resize()
		await get_tree().process_frame
		check(get_viewport().get_visible_rect().encloses(ui.get_node("Design").get_global_rect()), "journal fits viewport %s" % size)
	PauseManager.set_background(false)
	ui.close_menu()
	await get_tree().process_frame
	check(not get_tree().paused, "journal close releases solo pause")
	Coop.active = true
	owner_root.add_child(player)
	var coop_ui: Journal = load("res://scenes/ui/npc_relationship_ui.tscn").instantiate()
	coop_ui.player = player
	add_child(coop_ui)
	check(not get_tree().paused and player._input_locks.has(&"menu"), "co-op journal locks only its player and keeps world running")
	coop_ui.close_menu()
	await get_tree().process_frame
	check(not player._input_locks.has(&"menu"), "co-op journal close releases owner lock")
	Coop.active = false
	owner_root.remove_child(player)
	owner_root.free()
	var inventory: CanvasLayer = load("res://scenes/ui/ui_inventory.tscn").instantiate()
	inventory.player = player
	add_child(inventory)
	inventory._open()
	check(inventory._menu_buttons.has("NPC"), "inventory exposes NPC tab")
	inventory._show_relationships()
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		inventory._relationship_ui.get_node("%ResidentsPager").reveal(0)
		await get_tree().process_frame
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png("res://scratch/npc_relationship_book_preview.png")
	check(is_instance_valid(inventory._relationship_ui), "NPC tab opens relationship scene")
	check(inventory._relationship_ui is Control and inventory._relationship_ui.get_parent() == inventory.book_root, "NPC page lives inside the inventory book")
	inventory._relationship_ui.get_node("%Search").grab_focus()
	inventory._input(typing)
	check(inventory.visible and inventory._relationship_ui.visible, "typing I in embedded search keeps inventory open")
	inventory._relationship_ui._open_npc("zarathia")
	check(inventory._relationship_ui.get_node("%DetailsLeft").visible and inventory._relationship_ui.get_node("%GiftList").visible, "embedded inventory displays both detail leaves")
	if DisplayServer.get_name() != "headless":
		await get_tree().process_frame
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png("res://scratch/npc_detail_book_preview.png")
	inventory._relationship_ui._show_residents()
	inventory._show_bag_page()
	check(not inventory._relationship_ui.visible and inventory.book_root.get_node("LeftPage").visible, "bag tab replaces NPC content")
	inventory._show_relationships()
	inventory._relationship_ui.close_menu()
	await get_tree().process_frame
	check(inventory.visible and get_tree().paused and not inventory._relationship_ui.is_visible_in_tree(), "back returns to inventory and retains its pause")
	inventory._show_relationships()
	inventory._close()
	await get_tree().process_frame
	check(not get_tree().paused and not inventory._relationship_ui.is_visible_in_tree(), "inventory close also closes NPC journal")
	inventory.queue_free()
	player.tool_controller.free()
	player.free()
	await get_tree().process_frame
	print("NPC RELATIONSHIP UI COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
