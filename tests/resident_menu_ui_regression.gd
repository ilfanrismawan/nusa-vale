extends Node

var failures := 0

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var view := SubViewport.new()
	view.process_mode = Node.PROCESS_MODE_ALWAYS
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	for size in [Vector2i(458, 327), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(640, 720)]:
		view.size = size
		for id in ["wira", "ubay"]:
			var menu = load("res://scenes/ui/resident_service_menu.tscn").instantiate()
			menu.npc_name = id.capitalize()
			menu.role_title = "Tukang Kayu" if id == "wira" else "Kurir Koperasi"
			menu.service = "carpenter" if id == "wira" else "shipping"
			menu.portrait = load(NPCDatabase.residents[id].visual.portrait)
			var selections: Array[int] = []
			menu.selected.connect(func(index: int): selections.append(index))
			view.add_child(menu)
			for frame in 3:
				await get_tree().process_frame
			var bounds := Rect2(Vector2.ZERO, Vector2(size))
			var rect: Rect2 = menu.panel.get_global_rect()
			check(bounds.encloses(rect), "%s %s popup stays inside owning viewport" % [id, size])
			check(rect.get_center().distance_to(bounds.get_center()) < 1.5, "%s %s popup centered" % [id, size])
			check(menu.panel.theme == load("res://resources/ui/cooking_theme.tres"), "uses shared dialogue theme")
			for name in ["Talk", "Service", "Close"]:
				var button: Button = menu.get_node("%" + name)
				check(rect.encloses(button.get_global_rect()), name + " stays inside popup")
				button.pressed.emit()
			check(selections == [0, 1, 2], "buttons preserve service choices")
			if OS.get_environment("NUSA_UI_SCREENSHOT") == "1" and size == Vector2i(458, 327):
				RenderingServer.force_draw()
				view.get_texture().get_image().save_png("res://scratch/resident-menu-%s.png" % id)
			menu.queue_free()
			await get_tree().process_frame
			check(not get_tree().paused, "closing restores controls")
	view.queue_free()
	print("RESIDENT MENU UI COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
