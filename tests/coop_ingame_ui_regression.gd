extends Node
var failures := 0
var chosen: PlayerData
var leave_confirmed := false
var leave_cancelled := false
func check(ok: bool, text: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + text)
	if not ok:
		failures += 1
		push_error(text)
func frames() -> void:
	for i in 5:
		await get_tree().process_frame
func menu_in(view: SubViewport, leave: bool = false):
	var menu = preload("res://scenes/ui/coop_join_menu.tscn").instantiate()
	menu.device = 7
	menu.leave_mode = leave
	view.add_child(menu)
	return menu
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	# SaveManager memuat slot yang ada di frame awal; tunggu supaya daftar karakter uji tidak tertimpa.
	await frames()
	GameState.new_game()
	for i in GameState.MAX_COOP_CHARACTERS:
		GameState.new_coop_character().player_name = "Karakter tersimpan dengan nama panjang %d" % i
	var view := SubViewport.new()
	view.size = Vector2i(639, 720)
	add_child(view)
	var menu = menu_in(view)
	await frames()
	check(menu._rows.size() == GameState.MAX_COOP_CHARACTERS + 1, "all saved characters have rows")
	check(menu._entries.back().disabled, "new character disabled when roster full")
	for dimensions in [Vector2i(639, 720), Vector2i(639, 359), Vector2i(426, 239)]:
		view.size = dimensions
		await frames()
		var panel: Control = menu.get_node("UI/Frame/Center/Card")
		print("CARD ", dimensions, " ", panel.get_global_rect())
		check(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(panel.get_global_rect()), "join menu fits %s" % dimensions)
		menu._selected = menu._entries.size() - 1
		menu._refresh()
		await frames()
		check(menu.get_node("%Scroll").scroll_vertical > 0, "selection scrolls to last character")
	var wrong := InputEventJoypadButton.new()
	wrong.device = 6
	wrong.button_index = JOY_BUTTON_A
	wrong.pressed = true
	check(menu._action_of(wrong).is_empty(), "other player's controller ignored")
	menu._selected = 0
	menu._refresh()
	var before: int = GameState.coop_roster.size()
	menu._delete()
	check(GameState.coop_roster.size() == before and menu._delete_armed, "delete requires confirmation")
	menu._cancel()
	check(not menu._delete_armed and not menu._done, "cancel disarms deletion without closing")
	menu._delete()
	menu._delete()
	check(GameState.coop_roster.size() == before - 1, "confirmed delete rebuilds roster")
	var expected: PlayerData = menu._entries[0].data
	menu.chosen.connect(func(data: PlayerData): chosen = data)
	menu._accept()
	await frames()
	check(chosen == expected, "chosen character emitted")
	view.size = Vector2i(639, 720)
	menu = menu_in(view)
	menu._selected = menu._entries.size() - 1
	menu._accept()
	await frames()
	var creator: CharacterCreatorUI
	for child in view.get_children():
		if child is CharacterCreatorUI:
			creator = child
	check(creator != null and not menu._panel.visible, "new character opens creator")
	if creator != null:
		check(creator.guest and not creator.pause_game, "guest creator does not pause game")
		creator._cancel()
		await frames()
		check(menu._panel.visible, "creator cancel restores selection")
	menu.queue_free()
	await frames()
	for dimensions in [Vector2i(639, 359), Vector2i(426, 239)]:
		view.size = dimensions
		var leave = menu_in(view, true)
		leave.player_name = "Sari"
		await frames()
		var panel: Control = leave.get_node("UI/Frame/Center/Card")
		check(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(panel.get_global_rect()), "leave menu fits %s" % dimensions)
		check(leave._entries[0].kind == "cancel", "leave defaults to keep playing")
		leave.confirmed.connect(func(): leave_confirmed = true)
		leave.cancelled.connect(func(): leave_cancelled = true)
		leave._accept()
		await frames()
		check(leave_cancelled and not leave_confirmed, "default choice keeps player in game")
		leave = menu_in(view, true)
		leave.confirmed.connect(func(): leave_confirmed = true)
		leave._selected = 1
		leave._accept()
		await frames()
		check(leave_confirmed, "exit choice emits confirmation")
		leave_confirmed = false
		var wait = preload("res://scenes/ui/coop_wait_panel.tscn").instantiate()
		view.add_child(wait)
		wait.get_node("%Title").text = "Karakter dengan nama sangat panjang Siap Bergabung"
		wait.get_node("%Reason").text = "Menunggu pergantian area selesai. Pemain akan masuk otomatis."
		await frames()
		panel = wait.get_node("Frame/Center/Card")
		print("WAIT ", dimensions, " ", panel.get_global_rect())
		check(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(panel.get_global_rect()), "wait menu fits %s" % dimensions)
		wait.queue_free()
		await frames()
	view.queue_free()
	await frames()
	# Perlakukan transisi sebagai kondisi menunggu tanpa memuat world atau save.
	var fake_player := Node2D.new()
	fake_player.add_to_group("player")
	add_child(fake_player)
	Transition.on_transition = true
	var pane = preload("res://scenes/ui/coop_join_pane.tscn").instantiate()
	pane.player_number = 4
	pane.device = 7
	add_child(pane)
	await frames()
	check(pane.get_node("Backdrop").get_rect() == pane._container.get_rect(), "blur limited to joining player's quadrant")
	var embedded = pane._view.get_node("CoopJoinMenu")
	check(not embedded.get_node("%Backdrop").visible, "embedded menu uses host viewport blur")
	check(not pane.owns_event(wrong), "join pane excludes other controller")
	pane._on_chosen(GameState.coop_roster[0])
	await frames()
	check(pane._wait_panel.visible and not pane._wait_label.text.is_empty(), "blocked join shows waiting reason")
	pane._wait_panel.get_node("%Action").pressed.emit()
	await frames()
	check(not is_instance_valid(pane), "wait cancel closes pane")
	Transition.on_transition = false
	fake_player.queue_free()
	await frames()
	print("COOP INGAME UI COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
