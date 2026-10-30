extends Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS: " + message)
	else:
		failures += 1
		push_error(message)
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	GameState.new_game()
	var inv = load("res://scenes/ui/ui_inventory.tscn").instantiate()
	add_child(inv)
	inv._open()
	inv._show_controls()
	await get_tree().process_frame
	var controls = inv._controls_panel
	check(controls.visible and not inv._settings_panel.visible, "dedicated controls tab opens")
	check(inv.get_node("%TabControls/Icon").texture != null, "controls icon loads")
	check(controls.get_node("%Bindings").get_child_count() > 0, "bindings are listed")
	var row: Dictionary = PlayerInput.rows()[0]
	var entry = controls.get_node("%Bindings").get_child(0)
	for kind: String in ["kb", "pad"]:
		var button: Button = entry.get_node("Buttons/Keyboard" if kind == "kb" else "Buttons/Gamepad")
		controls._begin_capture(row["id"], kind, button)
		var cancel := InputEventKey.new()
		cancel.physical_keycode = KEY_ESCAPE
		cancel.pressed = true
		check(controls.capture_input(cancel) and controls._capture.is_empty(), kind + " capture cancels with Escape")
	controls._begin_capture(row["id"], "kb", entry.get_node("Buttons/Keyboard"))
	inv._show_bag_page()
	check(controls._capture.is_empty(), "switching tabs cancels capture")
	inv._show_controls()
	inv._close()
	check(controls._capture.is_empty() and not controls.visible, "closing inventory hides controls")
	print("INVENTORY CONTROLS COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
