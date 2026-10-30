extends Node

var failures := 0
var started: Array[int] = []

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _ready() -> void:
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	var lobby = preload("res://scenes/ui/coop_lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().process_frame
	await get_tree().process_frame
	check(lobby._slot_panels.size() == 4, "scene binds four player cards")
	check(lobby._btn_start.disabled, "one player cannot start")
	check(lobby.get_node("%BackButton").pressed.is_connected(lobby._close), "back signal connected")
	check(lobby._btn_start.pressed.is_connected(lobby._try_start), "start signal connected")
	var panel: Control = lobby.get_node("UI/Center/Panel")
	check(Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).encloses(panel.get_global_rect()), "lobby panel fits viewport")
	lobby.ready_text = "Siap dari Inspector"
	lobby._join(20)
	check(lobby._slot_status[1].text == "Siap dari Inspector", "exported ready text is respected")
	check(not lobby._btn_start.disabled, "two players enable start")
	lobby._join(21)
	lobby._join(22)
	lobby._join(23)
	check(lobby._devices.size() == 4, "room stays limited to four players")
	lobby._leave(20)
	check(lobby._slot_panels[3].theme_type_variation == &"EmptyCard", "leaving restores empty card theme")
	lobby._leave(PlayerInput.DEVICE_KEYBOARD)
	check(lobby._devices.size() == 3, "host cannot leave using guest action")
	lobby.start_requested.connect(func(devices: Array[int]): started.assign(devices))
	lobby._btn_start.pressed.emit()
	check(started.size() == 3, "start button emits roster")
	await get_tree().process_frame
	check(not is_instance_valid(lobby), "start closes lobby")
	print("COOP LOBBY SCENE COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
