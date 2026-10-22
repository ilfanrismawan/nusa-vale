extends Node2D

## Pintu keluar lobi dan tangga naik di lantai gua bisa dipakai dengan klik kanan (juga saat
## memegang senjata), tombol E, dan gamepad A; dialog konfirmasi bisa dijawab dengan A / B.
## Event dikirim lewat viewport seperti input asli. Tidak menulis save ke disk.

const CAVE_SCENE := "res://scenes/world/cave/cave.tscn"
const CONFIRM_SCRIPT := preload("res://scripts/ui/cave_confirm_dialog.gd")

var failures := 0
var cave: Node2D
var player: Player

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	GameState.new_game()
	GameState.cave.reset()
	GameState.cave.current_floor = 0
	cave = (load(CAVE_SCENE) as PackedScene).instantiate()
	add_child(cave)
	await _frames(3)
	player = cave.get_node("Player/CharacterBody2D") as Player
	await _go_floor_one()
	await _test_ladder_touch()
	await _test_ladder_right_click_with_weapon()
	await _test_ladder_gamepad()
	await _test_ladder_key()
	await _test_exit_door()
	print("CAVE EXIT INPUT REGRESSION COMPLETE: failures=%d" % failures)
	await get_tree().create_timer(30.0).timeout
	get_tree().quit(1 if failures > 0 else 0)

func _go_floor_one() -> void:
	cave.build_floor(1)
	await _frames(3)
	player.global_position = cave.cell_center(cave.ARRIVAL_CELL)
	player.facing_direction = Vector2.UP
	await _frames(3)

func _test_ladder_touch() -> void:
	await _go_floor_one()
	var ladder := cave.get_node("FloorContent/LadderUp") as Area2D
	await _frames(5)
	check(_dialog() == null, "arriving at the ladder does not ask by itself")
	player.global_position = ladder.global_position + Vector2(0, 50)
	await _frames(3)
	check(await _walk_until_dialog(Vector2.UP), "walking into the ladder asks to go up")
	check(get_tree().paused, "solo: the game pauses while the question is open")
	await _press_joy(JOY_BUTTON_B)
	await _frames(3)
	check(_dialog() == null and cave.floor_number == 1 and not get_tree().paused, "gamepad B cancels and stays on floor 1")
	await _frames(10)
	check(_dialog() == null, "standing still on the ladder does not ask again")
	player.global_position = ladder.global_position + Vector2(0, 50)
	await _frames(3)
	check(await _walk_until_dialog(Vector2.UP), "stepping onto the ladder again asks again")
	await _press_joy(JOY_BUTTON_A)
	await _wait_until(func() -> bool: return cave.floor_number == 0 and not cave._changing, 8.0)
	check(cave.floor_number == 0, "gamepad A after touching the ladder goes up")

func _test_ladder_right_click_with_weapon() -> void:
	await _go_floor_one()
	_hold("sword_wood")
	check(player.holds_weapon(), "player holds a sword on floor 1")
	var ladder := cave.get_node("FloorContent/LadderUp") as Area2D
	await _click_right(ladder.global_position + Vector2(120, 60))
	check(_dialog() == null, "right-click away from the ladder with a sword does not ask (aim stays)")
	await _click_right(ladder.global_position)
	var dialog := _dialog()
	check(dialog != null, "right-click on the ladder while holding a sword asks to go up")
	await _press_joy(JOY_BUTTON_A)
	await _wait_until(func() -> bool: return cave.floor_number == 0 and not cave._changing, 8.0)
	check(cave.floor_number == 0 and _dialog() == null, "gamepad A confirms and goes up to the lobby")

func _test_ladder_gamepad() -> void:
	await _go_floor_one()
	_hold("sword_wood")
	await _press_joy(JOY_BUTTON_A)
	check(_dialog() != null, "gamepad A at the ladder asks to go up (holding a sword)")
	await _press_joy(JOY_BUTTON_B)
	await _frames(3)
	check(_dialog() == null and cave.floor_number == 1 and not player.is_input_locked() and not get_tree().paused, "gamepad B cancels and the player can move again")
	await _press_joy(JOY_BUTTON_A)
	await _frames(2)
	check(_dialog() != null, "gamepad A asks again after cancelling")
	await _press_joy(JOY_BUTTON_A)
	await _wait_until(func() -> bool: return cave.floor_number == 0 and not cave._changing, 8.0)
	check(cave.floor_number == 0, "gamepad A twice goes up to the lobby")

func _test_ladder_key() -> void:
	await _go_floor_one()
	_hold("pickaxe")
	await _press_key(KEY_E)
	check(_dialog() != null, "E key at the ladder asks to go up")
	await _press_key(KEY_ENTER)
	await _wait_until(func() -> bool: return cave.floor_number == 0 and not cave._changing, 8.0)
	check(cave.floor_number == 0, "Enter confirms and goes up")

func _test_exit_door() -> void:
	if cave.floor_number != 0:
		cave.build_floor(0)
		await _frames(3)
	var door := cave.get_node("Lobby/ExitDoor") as Area2D
	# Berdiri sedekat mungkin di bawah pintu (dinding atas menahan pemain).
	player.global_position = door.global_position + Vector2(0, 40)
	player.facing_direction = Vector2.UP
	_hold("sword_wood")
	check(await _walk_until_dialog(Vector2.UP), "walking into the exit door asks to leave (game paused)")
	await _press_joy(JOY_BUTTON_B)
	await _frames(3)
	check(_dialog() == null and cave.floor_number == 0 and not get_tree().paused, "gamepad B keeps the player in the cave")
	await _click_right(door.global_position)
	check(_dialog() != null, "right-click on the exit door while holding a sword asks to leave")
	await _press_joy(JOY_BUTTON_B)
	await _frames(3)
	check(_dialog() == null, "gamepad B cancels leaving")
	await _press_joy(JOY_BUTTON_A)
	check(_dialog() != null, "gamepad A at the exit door asks to leave")
	var dialog := _dialog()
	if dialog != null:
		dialog.get_cancel_button().pressed.emit()
	await _frames(3)
	_hold("pickaxe")
	await _click_right(door.global_position)
	check(_dialog() != null, "right-click on the exit door with a tool asks to leave")
	dialog = _dialog()
	if dialog != null:
		dialog.get_cancel_button().pressed.emit()
	await _frames(3)

# ── Bantuan ──────────────────────────────────────────────────────

func _hold(item_id: String) -> void:
	var data := player.data
	data.hotbar_page = 0
	data.inventory[0] = {"item": GameState._resolve_item(item_id), "count": 1}
	player.tool_controller.select_tool(0, false)

func _dialog() -> ConfirmationDialog:
	for node in get_tree().root.find_children("*", "ConfirmationDialog", true, false):
		if node.get_script() == CONFIRM_SCRIPT and not node.is_queued_for_deletion() and node.visible:
			return node
	return null

func _click_right(world_pos: Vector2) -> void:
	var view := get_viewport()
	var screen: Vector2 = view.get_canvas_transform() * world_pos
	view.warp_mouse(screen)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_RIGHT
		e.pressed = pressed
		e.position = screen
		e.global_position = screen
		e.button_mask = MOUSE_BUTTON_MASK_RIGHT if pressed else 0
		# screen sudah dalam koordinat viewport; parse_input_event mengubahnya lagi
		# mengikuti stretch window (berbeda pada backend headless).
		view.push_input(e, true)
		await _frames(2)

func _press_joy(button: JoyButton) -> void:
	for pressed in [true, false]:
		var b := InputEventJoypadButton.new()
		b.button_index = button
		b.pressed = pressed
		b.device = 0
		Input.parse_input_event(b)
		await _frames(2)

func _press_key(key: Key) -> void:
	for pressed in [true, false]:
		var k := InputEventKey.new()
		k.physical_keycode = key
		k.keycode = key
		k.pressed = pressed
		Input.parse_input_event(k)
		await _frames(2)

## Tahan tombol gerak sampai dialog konfirmasi muncul (maks. 1,5 detik).
func _walk_until_dialog(direction: Vector2) -> bool:
	var key: StringName = &"move_up" if direction == Vector2.UP else &"move_down"
	Input.action_press(key)
	var ok := false
	for i in 90:
		await get_tree().physics_frame
		if _dialog() != null:
			ok = true
			break
	Input.action_release(key)
	await _frames(2)
	return ok

func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func _wait_until(condition: Callable, timeout: float) -> bool:
	var waited := 0.0
	while not condition.call() and waited < timeout:
		await get_tree().process_frame
		waited += get_process_delta_time()
	return condition.call()
