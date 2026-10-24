extends Node2D

var failures := 0

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1
		push_error(label)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	DayCycle.current_day = 1
	var ids: Array = NPCDatabase.residents.keys() + NPCDatabase.gift_profiles.keys()
	check(ids.size() == 13, "thirteen centralized NPC gift profiles registered")
	for id: String in ids:
		check(NPCSocialService.known(id), id + " supports social gifts")
		var seen: Array = []
		for category: String in ["loved", "liked", "neutral", "disliked", "hated"]:
			var values: Variant = NPCSocialService._preference(id, category)
			check(not values.is_empty(), id + " has " + category + " items")
			for item_id: String in values:
				check(item_id not in seen, id + "/" + item_id + " has one taste")
				seen.append(item_id)
				var item: ItemData = GameState._resolve_item(item_id)
				check(item != null and item.icon != null and item.icon.get_width() > 0 and item.icon.get_height() > 0, item_id + " loads with an icon")
				check(NPCSocialService.taste(id, item_id) == category, id + "/" + item_id + " resolves " + category)
			var data := PlayerData.new()
			NPCSocialService.points(data, id)
			data.friendships[id].points = 500
			data.inventory[9] = {"item": GameState._resolve_item(values[0]), "count": 2}
			var result := NPCSocialService.give(data, id, 9)
			check(result.ok and result.taste == category and result.points == NPCSocialService.GIFT_POINTS[category] and data.inventory[9].count == 1, id + " can give " + category + " gift atomically")
	check(NPCSocialService.taste("wira", "rice") == "neutral", "unlisted items keep neutral fallback")
	var player := Player.new()
	player.tool_controller = ToolController.new()
	player.data.inventory[9] = {"item": GameState._resolve_item("wood"), "count": 2}
	for scene_path in ["res://scenes/npc/CarpenterNPC.tscn", "res://scenes/npc/BlacksmithNPC.tscn"]:
		var actor: Node = load(scene_path).instantiate()
		add_child(actor)
		actor.interact(player)
		var menu: CanvasLayer = actor._menu if "_menu" in actor else actor._ui
		check(menu.get_node("Design/SocialButton").visible, actor.name + " exposes gift dialogue")
		menu._open_social_dialog()
		await get_tree().process_frame
		var dialog: NPCDialogUI
		for child in Coop.ui_parent(player).get_children():
			if child is NPCDialogUI:
				dialog = child
		check(dialog != null and dialog._gift_button != null, actor.name + " opens working gift action")
		check(dialog.get_viewport().get_visible_rect().encloses(dialog._text_label.get_global_rect()), "gift dialogue remains inside viewport")
		dialog._close()
		actor.queue_free()
		await get_tree().process_frame
	var kirana: Node = load("res://scenes/npc/npc.tscn").instantiate()
	add_child(kirana)
	kirana.interact(player)
	check(kirana._dialog_ui is NPCDialogUI and kirana._dialog_ui._gift_button != null, "legacy Kirana opens scene-backed gift dialogue")
	kirana._dialog_ui._close()
	kirana.queue_free()
	await get_tree().process_frame
	player.tool_controller.free()
	player.free()
	check(not get_tree().paused, "closing gift dialogue releases pause")
	print("NPC GIFTS COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
