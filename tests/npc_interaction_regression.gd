extends Node2D

var failures := 0
var finished_count := 0

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func settle() -> void:
	for i in 5:
		await get_tree().process_frame

func visible_dialog(dialog: NPCDialogUI) -> bool:
	var rect := dialog._text_label.get_global_rect()
	var bounds := dialog.get_viewport().get_visible_rect()
	return rect.size.y > 0 and bounds.encloses(rect)

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
	var npc: VillageNPC = load("res://scenes/npc/ToriNPC.tscn").instantiate()
	npc.schedule.clear()
	add_child(npc)
	npc.set_physics_process(false)
	npc.global_position = Vector2(100, 100)
	player.global_position = Vector2(100, 132)
	player.facing_direction = Vector2.UP
	npc.dialog_lines = ["Halo! Selamat menikmati harimu di Nusa Vale.", "Sampai jumpa."]
	await get_tree().physics_frame
	await get_tree().physics_frame
	player._try_interact()
	await settle()
	check(is_instance_valid(npc._dialog_ui) and visible_dialog(npc._dialog_ui), "solo player interaction opens NPC text inside the screen")
	check(get_tree().paused, "visible dialogue owns the gameplay pause")
	var dialog: NPCDialogUI = npc._dialog_ui
	dialog.finished.connect(func(): finished_count += 1)
	var enter := InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	enter.keycode = KEY_ENTER
	enter.pressed = true
	dialog._input(enter)
	check(dialog._current_line_idx == 1 and not dialog._closed, "Enter advances one dialogue line")
	dialog._close()
	dialog._close()
	check(finished_count == 1 and not get_tree().paused and not player.is_input_locked(), "dialogue closes once and restores solo controls")
	await settle()
	npc._on_body_entered(player)
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	npc._unhandled_input(right_click)
	await settle()
	check(is_instance_valid(npc._dialog_ui) and visible_dialog(npc._dialog_ui), "right click opens a visible NPC dialogue")
	npc._dialog_ui.queue_free()
	await settle()
	check(not get_tree().paused and not player.is_input_locked(), "unexpected dialogue removal releases pause and player lock")
	npc._dialog_ui = null
	var empty := NPCDialogUI.new()
	empty.player = player
	add_child(empty)
	check(not get_tree().paused and not player.is_input_locked(), "empty dialogue does not leave gameplay paused")
	await settle()
	npc.dialog_lines = ["Satu baris dialog."]
	player.set_process(true)
	Input.parse_input_event(right_click)
	await settle()
	check(is_instance_valid(npc._dialog_ui), "real right-click input opens the dialogue")
	right_click.pressed = false
	Input.parse_input_event(right_click)
	Input.parse_input_event(enter)
	await settle()
	check(not is_instance_valid(npc._dialog_ui) and not get_tree().paused, "Enter closes the last line without immediately reopening dialogue")
	enter.pressed = false
	Input.parse_input_event(enter)
	await settle()
	enter.pressed = true
	Input.parse_input_event(enter)
	await settle()
	check(is_instance_valid(npc._dialog_ui) and visible_dialog(npc._dialog_ui), "Enter proximity interaction opens the first dialogue line on screen")
	if is_instance_valid(npc._dialog_ui):
		npc._dialog_ui._close()
	enter.pressed = false
	Input.parse_input_event(enter)
	await settle()
	player.set_process(false)
	get_tree().current_scene = null
	Coop.start([PlayerInput.DEVICE_KEYBOARD, PlayerInput.DEVICE_NUMPAD])
	await get_tree().create_timer(1.0, true).timeout
	var second: Player = Coop.root.body_of(1)
	second.set_process(false)
	second.set_physics_process(false)
	npc = load("res://scenes/npc/ToriNPC.tscn").instantiate()
	npc.schedule.clear()
	second.world_root().add_child(npc)
	npc.set_physics_process(false)
	npc.global_position = Vector2(1000, 1000)
	second.global_position = Vector2(1000, 1032)
	second.facing_direction = Vector2.UP
	await get_tree().physics_frame
	await get_tree().physics_frame
	Coop.root.body_of(0).bind_context()
	second._try_interact()
	await settle()
	check(is_instance_valid(npc._dialog_ui) and npc._dialog_ui.player == second and npc._dialog_ui.get_parent() == Coop.root.view_of(1) and visible_dialog(npc._dialog_ui), "co-op interaction opens dialogue for the actual player despite another active context")
	npc._dialog_ui._close()
	check(not second.is_input_locked() and not get_tree().paused, "co-op dialogue closing restores controls")
	print("NPC INTERACTION REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
