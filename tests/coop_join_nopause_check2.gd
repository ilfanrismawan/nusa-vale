extends Node

## Tes drop-in co-op (GDD 4.14): input P1 + gamepad, daftar karakter co-op di save v21,
## bergabung dari main sendiri di Farm tanpa menjeda P1 (F2/B batal), pemain ke-3 tanpa
## membangun ulang layar, lalu keluar lagi. Tidak menulis slot save.

const RESULT_PATH := "res://tests/coop_join_nopause_result2.txt"

var failures := 0

func note(text: String) -> void:
	print(text)
	# Hasil juga ditulis ke RESULT_PATH supaya bisa dibaca setelah keluar.
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(RESULT_PATH) else FileAccess.WRITE
	var file := FileAccess.open(RESULT_PATH, mode)
	if file != null:
		file.seek_end()
		file.store_line(text)

func check(value: bool, label: String) -> void:
	if value:
		note("PASS: " + label)
	else:
		failures += 1
		note("FAIL: " + label)
		push_error("FAIL: " + label)

func _pad(device: int, button: JoyButton = JOY_BUTTON_A) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = device
	e.button_index = button
	e.pressed = true
	return e

func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().process_frame
	var up := event.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame

func _numpad(code: Key) -> InputEventKey:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.pressed = true
	return k

func _stick(device: int) -> InputEventJoypadMotion:
	var m := InputEventJoypadMotion.new()
	m.device = device
	m.axis = JOY_AXIS_LEFT_X
	m.axis_value = -1.0
	return m

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

## Tunggu sampai `done` true (perpindahan selesai) atau batas waktu habis.
func _wait_until(done: Callable, timeout: float = 15.0) -> void:
	var start := Time.get_ticks_msec()
	while not done.call() and Time.get_ticks_msec() - start < int(timeout * 1000.0):
		await get_tree().process_frame
	await _wait(0.5)

func _settled(count: int) -> bool:
	if Coop.is_switching() or Transition.on_transition:
		return false
	if count <= 1:
		return not Coop.active and get_tree().get_first_node_in_group("player") != null
	return Coop.has_root() and Coop.player_count() == count and Coop.root.body_of(count - 1) != null

## Jendela tes sering tidak fokus (editor di depan): jeda fokus PauseManager akan
## membuat game terlihat "dijeda menu", jadi abaikan selama tes.
func _process(_delta: float) -> void:
	if PauseManager.background:
		PauseManager.set_background(false)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RESULT_PATH))
	await get_tree().process_frame
	# Tes tetap hidup saat scene diganti: scene "sekarang" dipindah ke node kosong.
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	Coop.save_on_leave = false

	# Input: P1 keyboard + gamepad milik P1.
	var p1 := PlayerInput.create(0, PlayerInput.DEVICE_KEYBOARD, 3)
	check(p1.owns_event(_pad(3)) and not p1.owns_event(_pad(2)) and p1.owns_event(InputEventKey.new()), "P1 owns keyboard and its own gamepad only")
	check(p1.uses_mouse() and p1.device_name().contains("Gamepad 4"), "P1 keeps mouse aim with extra pad")
	var guest := PlayerInput.create(1, 2)
	check(guest.owns_event(_pad(2)) and not guest.owns_event(_pad(3)), "guest pad input stays separate")
	Coop.p1_pad = -1

	# Save v21: daftar karakter co-op.
	GameState.new_game()
	var a := GameState.new_coop_character()
	a.player_name = "Sari"
	a.stamina = 37
	var b := GameState.new_coop_character()
	b.player_name = "Bima"
	GameState.seat_players([b])
	check(GameState.players.size() == 2 and GameState.players[1] == b and b.index == 1, "seat_players puts chosen character at P2")
	check(GameState.available_coop_characters().size() == 1 and GameState.available_coop_characters()[0] == a, "only characters not playing are available")
	var data: Dictionary = JSON.parse_string(JSON.stringify(SaveManager._build_save_data()))
	check(int(data.version) >= 21 and data.coop_players.size() == 2 and data.coop_players[0].id == a.character_id, "roster serialized with ids")
	check(SaveManager._is_valid_save(data), "v21 save is valid")
	SaveManager._apply_save(data)
	check(GameState.players.size() == 1 and GameState.coop_roster.size() == 2, "load starts solo with full roster")
	check(GameState.coop_roster[0].player_name == "Sari" and GameState.coop_roster[0].stamina == 37 and GameState.coop_roster[0].character_id == a.character_id, "roster character restored")
	var legacy: Dictionary = data.duplicate(true)
	legacy.version = 20
	legacy.coop_players[0].erase("id")
	legacy.coop_players[1].erase("id")
	check(SaveManager._is_valid_save(legacy), "v20 save still valid")
	SaveManager._apply_save(legacy)
	check(GameState.coop_roster.size() == 2 and not GameState.coop_roster[0].character_id.is_empty() and GameState.coop_roster[0].character_id != GameState.coop_roster[1].character_id, "old co-op players get new unique ids")
	check(GameState.delete_coop_character(GameState.coop_roster[1]) and GameState.coop_roster.size() == 1, "delete co-op character")

	# Drop-in dari main sendiri.
	GameState.next_spawn_position = Vector2(700, 300)
	GameState.has_spawn_point = true
	DayCycle.is_running = true
	get_tree().change_scene_to_file("res://scenes/world/farm.tscn")
	await _wait(1.0)
	var solo_body := get_tree().get_first_node_in_group("player") as Node2D
	check(solo_body != null and not Coop.active, "solo farm loaded")
	var start_pos := solo_body.global_position if solo_body != null else Vector2.ZERO
	check(Coop.block_reason(true).is_empty(), "joining allowed in solo farm: '%s'" % Coop.block_reason(true))
	# Start pertama di gamepad (P1 belum memakai keyboard) = gamepad P1, bukan pemain baru.
	Coop.p1_pad = -1
	await _send(_pad(7, JOY_BUTTON_START))
	check(Coop.p1_pad == 7 and not Coop.is_switching(), "first gamepad becomes P1's own pad")
	# Start pad P1 membuka tas (jeda solo); tutup dulu sebelum menguji pemain baru.
	var bag := get_tree().current_scene.find_child("UIInventory", true, false)
	if bag != null:
		await _wait_until(func() -> bool: return bag.visible and get_tree().paused, 3.0)
		if bag.visible:
			bag.toggle()
		await _wait_until(func() -> bool: return not get_tree().paused, 3.0)
	check(not get_tree().paused, "P1 bag closed before join test")
	await _send(_pad(8, JOY_BUTTON_START))
	check(Coop.has_pending_join() and not get_tree().paused, "Start on another pad opens join pane without pausing")
	check(not InputMap.event_is_action(_stick(8), &"move_left") and InputMap.event_is_action(_stick(7), &"move_left"), "joiner's stick does not move solo P1, P1's pad still does")
	await _send(_pad(8, JOY_BUTTON_B))
	await _wait(0.2)
	check(not Coop.is_switching() and not get_tree().paused and not Coop.active, "B cancels join pane")
	check(InputMap.event_is_action(_stick(8), &"move_left"), "solo input accepts all pads again after cancel")
	await _send(_pad(8, JOY_BUTTON_START))
	check(Coop.has_pending_join(), "join pane opens again")
	var f2 := InputEventKey.new()
	f2.physical_keycode = KEY_F2
	f2.pressed = true
	await _send(f2)
	await _wait(0.2)
	check(not Coop.has_pending_join() and not Coop.active, "F2 cancels pending join")
	# Numpad: menu -> pilih karakter pertama (Sari) dengan 1.
	var sari := GameState.coop_roster[0]
	solo_body = get_tree().get_first_node_in_group("player") as Node2D
	start_pos = solo_body.global_position if solo_body != null else Vector2.ZERO
	Coop.request_join(PlayerInput.DEVICE_NUMPAD)
	await _wait(0.2)
	await _send(_numpad(KEY_KP_1))
	await _wait_until(_settled.bind(2))
	note("STATE active=%s root=%s count=%d switching=%s scene=%s" % [Coop.active, Coop.has_root(), Coop.player_count(), Coop.is_switching(), get_tree().current_scene])
	if Coop.has_pending_join():
		note("PENDING chosen=%s reason='%s' paused=%s wait='%s'" % [Coop._join_pane._data != null, Coop.block_reason(true), get_tree().paused, Coop._join_pane._wait_label.text])
	check(Coop.has_root() and Coop.player_count() == 2, "co-op root built with 2 players")
	if Coop.has_root():
		check(Coop.root.area_path_of(0).to_lower().contains("farm.tscn"), "P1 stays in Farm")
		check(Coop.root.position_of(0).distance_to(start_pos) < 24.0, "P1 keeps position (%s vs %s)" % [Coop.root.position_of(0), start_pos])
		check(Coop.root.position_of(1).distance_to(start_pos) < 40.0, "P2 spawns next to P1")
		check(GameState.players[1] == sari and Coop.root.body_of(1).data == sari, "P2 plays the chosen character")
		check(Coop.get_input(0).extra_pad == 7 and Coop.get_input(0).owns_event(_pad(7)), "P1 keeps its gamepad in co-op")
	await _wait(1.0)
	if Coop.has_root():
		note("POS before 3rd join (+1s): %s" % [Coop.root.position_of(0)])
	var third := GameState.new_coop_character(false)
	var root_before: Node = Coop.root
	check(Coop.try_join(5, third).is_empty(), "third player can join right away")
	await _wait_until(_settled.bind(3))
	check(Coop.player_count() == 3 and GameState.coop_roster.has(third), "third player joins mid co-op")
	if not Coop.has_root():
		note("COOP DROP-IN failures=%d (stopped early)" % failures)
		get_tree().quit(1)
		return
	note("POS after 3rd join: %s" % [Coop.root.position_of(0)])
	check(Coop.root == root_before and Coop.root.body_of(2) != null and Coop.root.body_of(2).data == third, "third player added without rebuilding screens")
	Coop.leave(1)
	await _wait(0.2)
	await _wait_until(_settled.bind(2))
	check(Coop.player_count() == 2 and GameState.players[1] == third and Coop.devices[1] == 5, "guest leaves, others re-indexed")
	if Coop.has_root():
		note("POS after 1st leave: %s" % [Coop.root.position_of(0)])
	Coop.leave(1)
	await _wait(0.2)
	await _wait_until(_settled.bind(1))
	var back := get_tree().get_first_node_in_group("player") as Node2D
	check(not Coop.active and back != null and get_tree().current_scene.scene_file_path.to_lower().contains("farm.tscn"), "last guest leaves: back to solo Farm")
	if back != null:
		check(back.global_position.distance_to(start_pos) < 24.0, "solo P1 keeps position after co-op (%s)" % back.global_position)
	check(GameState.coop_roster.size() == 2 and GameState.players.size() == 1, "roster keeps both guests")

	note("COOP DROP-IN failures=%d" % failures)
	await _wait(1.0)
	get_tree().quit(1 if failures > 0 else 0)
