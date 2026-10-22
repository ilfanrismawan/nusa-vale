extends Node

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func settle() -> void:
	for frame in 8:
		await get_tree().process_frame

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	for card in Notify._box.get_children():
		card.queue_free()
	await settle()
	Notify.say("")
	check(Notify._box.get_child_count() == 0, "empty notifications do not allocate cards")
	for index in 7:
		Notify.say("Notifikasi uji %d: barang sudah tersimpan dengan aman." % index)
	check(Notify._box.get_child_count() == Notify.maximum_visible, "notification bursts stay within the visible limit immediately")
	await settle()
	var card: Control = Notify._box.get_child(0)
	check(card.get_node("%Message").text.contains("3") and card.mouse_filter == Control.MOUSE_FILTER_IGNORE, "toast cards retain latest messages and do not block clicks")
	check(get_viewport().get_visible_rect().encloses(card.get_global_rect()), "notification stack stays within the viewport")
	check(card.get_theme_stylebox("panel") is StyleBoxFlat and card.get_node("%Lifetime") is ProgressBar, "native notification exposes editable panel and lifetime meter")
	var rig = load("res://scenes/player/Player.tscn").instantiate()
	add_child(rig)
	var player: Player = rig.get_node("CharacterBody2D")
	player.set_process(false)
	player.set_physics_process(false)
	player.data.inventory[0] = null
	player.tool_controller.current_index = 0
	var hints := load("res://scenes/ui/action_hints.tscn").instantiate() as ActionHints
	hints.player = player
	add_child(hints)
	ActionHints.enabled = true
	ActionHints._enabled_loaded = true
	var keyboard := InputEventKey.new()
	keyboard.physical_keycode = KEY_E
	keyboard.pressed = true
	player.input.note_event(keyboard)
	hints._timer = 0
	hints._process(0)
	await settle()
	check(hints.visible and hints.build_text().contains("[E] Interaksi") and hints.get_node("%Hints").get_child_count() > 1, "keyboard controls render as separate key badges")
	for badge in hints.get_node("%Hints").get_children():
		check(badge.mouse_filter == Control.MOUSE_FILTER_IGNORE and get_viewport().get_visible_rect().encloses(badge.get_global_rect()), "control badges are bounded and click-through")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	player.input.note_event(pad)
	hints._timer = 0
	hints._process(0)
	check(hints.build_text().contains("[A] Interaksi / Lompat"), "shared gamepad bindings merge into one descriptive badge")
	ActionHints.enabled = false
	hints._timer = 0
	hints._process(0)
	check(not hints.visible, "control hint setting still hides the native badges")
	ActionHints.enabled = true
	hints._timer = 0
	hints._process(0)
	var view := SubViewport.new()
	view.size = Vector2i(640, 360)
	add_child(view)
	var small := load("res://scenes/ui/action_hints.tscn").instantiate() as ActionHints
	small.player = player
	view.add_child(small)
	small._process(0)
	await settle()
	for badge in small.get_node("%Hints").get_children():
		check(view.get_visible_rect().encloses(badge.get_global_rect()), "control badges wrap inside a co-op-sized viewport")
	small.set_process(false)
	var combat: Array[Dictionary] = [
		{"key": "RB", "label": "Serang"},
		{"key": "RT", "label": "Serangan berat"},
		{"key": "B singkat", "label": "Roll"},
		{"key": "LB", "label": "Tangkis"},
		{"key": "LT", "label": "Weapon art"},
		{"key": "R3", "label": "Kunci target"},
	]
	small._rebuild(combat)
	small.show()
	await settle()
	for badge in small.get_node("%Hints").get_children():
		check(view.get_visible_rect().encloses(badge.get_global_rect()), "combat badges remain bounded after wrapping")
	if OS.get_environment("NUSA_HUD_FEEDBACK_SCREENSHOT") == "1" and DisplayServer.get_name() != "headless":
		player.hud_ui.action_hints.set_process(false)
		player.hud_ui.action_hints.hide()
		Notify.say("Resep baru dipelajari! Kamu bisa mengaturnya di editor.")
		await get_tree().create_timer(0.25, true).timeout
		RenderingServer.force_draw()
		get_viewport().get_texture().get_image().save_png("res://scratch/hud-feedback-preview.png")
	for notice in Notify._box.get_children():
		notice.queue_free()
	await settle()
	Notify.say("Pesan ini selesai walaupun permainan dijeda.")
	var notice = Notify._box.get_child(0)
	notice.display_seconds = 0.1
	notice.fade_seconds = 0.05
	notice.entrance_seconds = 0.0
	if notice._animation != null:
		notice._animation.kill()
	notice.present(notice.text)
	PauseManager.set_requested(true)
	await get_tree().create_timer(0.3, true).timeout
	check(Notify._box.get_child_count() == 0, "notification lifetime finishes while gameplay is paused")
	PauseManager.set_requested(false)
	view.queue_free()
	hints.queue_free()
	rig.queue_free()
	await settle()
	print("HUD FEEDBACK VISUAL REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
