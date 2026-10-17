extends Node

var failures := 0

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func settle() -> void:
	for frame in 5:
		await get_tree().process_frame

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
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
	var menu = load("res://scenes/ui/carpenter_menu.tscn").instantiate()
	menu.player = player
	add_child(menu)
	await settle()
	var balance := GameState.money
	menu._select("barn")
	check(GameState.money == balance and menu.get_node("%DetailTitle").text == GameState._resolve_item("barn").display_name, "selecting a building previews details without spending")
	GameState.money = 0
	GameState.money_changed.emit(0)
	check(menu.get_node("%ChooseButton").disabled, "missing money blocks construction action")
	player.data.bag_level = 2
	player.data.add_item_silent("wood", 200)
	player.data.add_item_silent("stone", 100)
	GameState.money = 10000
	GameState.money_changed.emit(10000)
	check(not menu.get_node("%ChooseButton").disabled and menu.get_node("%Materials").get_child_count() == 2, "native detail reads actual owner materials and construction quote")
	player.data.remove_item("wood", 200)
	GameState.inventory_changed.emit()
	await settle()
	check(menu.get_node("%ChooseButton").disabled, "inventory changes refresh affordability")
	if OS.get_environment("NUSA_UI_SCREENSHOT") == "1":
		DisplayServer.window_set_size(Vector2i(1600, 900))
		menu._resize()
		await settle()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://scratch/carpenter-ui-preview.png")
	menu.queue_free()
	await settle()
	check(not get_tree().paused and not player.is_input_locked(), "external carpenter removal releases player controls")
	var dialog := load("res://scenes/ui/npc_dialog_ui.tscn").instantiate() as NPCDialogUI
	dialog.player = player
	dialog.npc_name = "Tori"
	dialog.role_title = "Petualang"
	dialog.portrait_texture = load("res://assets/farm_rpg/Character/NPC'S/Tori/Portrait Tori.png")
	dialog.lines = ["Selamat datang di Nusa Vale! Ada yang bisa kubantu hari ini?", "Sampai jumpa di desa."]
	add_child(dialog)
	await settle()
	check(dialog._text_label.text == dialog.lines[0] and dialog._name_label.text == "Tori", "native dialogue renders speaker and original lines")
	check(get_viewport().get_visible_rect().encloses(dialog._text_label.get_global_rect()), "dialogue text remains inside viewport")
	if OS.get_environment("NUSA_UI_SCREENSHOT") == "1":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://scratch/npc-dialog-ui-preview.png")
	dialog._advance_dialog()
	check(dialog._next_button.text == dialog.finish_text, "last dialogue page displays finish action")
	dialog._advance_dialog()
	await settle()
	check(not get_tree().paused and not player.is_input_locked(), "finishing native dialogue restores controls")
	print("DIALOG CARPENTER UI REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
