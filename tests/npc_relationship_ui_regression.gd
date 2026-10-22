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
	check(ui._ids.size() == 12, "all twelve NPCs appear")
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
	check(ui._ids.is_empty() and ui.get_node("%Empty").visible, "empty search has useful state")
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
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png("res://scratch/npc_relationship_preview.png")
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
	check(is_instance_valid(inventory._relationship_ui), "NPC tab opens relationship scene")
	check(inventory._relationship_ui is Control and inventory._relationship_ui.get_parent() == inventory.book_root, "NPC page lives inside the inventory book")
	inventory._relationship_ui.get_node("%Search").grab_focus()
	inventory._input(typing)
	check(inventory.visible and inventory._relationship_ui.visible, "typing I in embedded search keeps inventory open")
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
