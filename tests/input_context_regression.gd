extends Node2D

## GDD 4.3 Kontrol & Konteks Input: router PlayerInput, konteks per barang yang dipegang,
## tidak ada tombol bentrok dalam satu konteks, gamepad A = interaksi atau lompat, lompat ganda,
## tebar benih di udara, lock-on, prompt tombol dinamis, dan atur ulang tombol yang tersimpan.
## File user://input_bindings.cfg pemain dicadangkan dan dikembalikan setelah tes.

var failures := 0
var _saved_bindings := ""
var _had_bindings := false

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _process(_delta: float) -> void:
	if get_tree().paused:
		get_tree().paused = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DayCycle.is_running = false
	_backup_bindings()
	PlayerInput.reset_bindings()
	await get_tree().process_frame
	_test_no_conflicts()
	GameState.new_game()
	var rig := (load("res://scenes/player/Player.tscn") as PackedScene).instantiate()
	add_child(rig)
	var player := rig.get_node("CharacterBody2D") as Player
	await get_tree().process_frame
	player.global_position = Vector2(400, 300)
	await get_tree().create_timer(0.5).timeout
	await _test_contexts(player)
	await _test_jump(player)
	await _test_gamepad_a(player)
	await _test_seed_scatter(player)
	await _test_exclusions(player)
	await _test_lock_on(player)
	_test_prompts(player)
	_test_remap()
	rig.queue_free()
	_restore_bindings()
	print("INPUT CONTEXT REGRESSION COMPLETE: failures=%d" % failures)
	await get_tree().create_timer(30.0).timeout
	get_tree().quit(1 if failures > 0 else 0)

# ── Bantuan ─────────────────────────────────────────────────────────

func _backup_bindings() -> void:
	_had_bindings = FileAccess.file_exists(InputLayout.OVERRIDE_PATH)
	if _had_bindings:
		_saved_bindings = FileAccess.get_file_as_string(InputLayout.OVERRIDE_PATH)

func _restore_bindings() -> void:
	if _had_bindings:
		var f := FileAccess.open(InputLayout.OVERRIDE_PATH, FileAccess.WRITE)
		f.store_string(_saved_bindings)
		f.close()
	elif FileAccess.file_exists(InputLayout.OVERRIDE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(InputLayout.OVERRIDE_PATH))
	# Muat ulang pilihan pemain yang asli.
	PlayerInput._overrides_loaded = false
	PlayerInput._rows_cache.clear()
	PlayerInput.rebuild_all()

func _hold(player: Player, item_id: String) -> bool:
	var data := player.data
	data.hotbar_page = 0
	var item: ItemData = GameState._resolve_item(item_id) if not item_id.is_empty() else null
	data.inventory[0] = {"item": item, "count": 20} if item != null else null
	player.tool_controller.select_tool(0, false)
	return item != null or item_id.is_empty()

func _key(code: Key, pressed: bool = true) -> void:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.keycode = code
	k.pressed = pressed
	Input.parse_input_event(k)

func _tap_key(code: Key) -> void:
	# Ditahan beberapa frame supaya _process (just_pressed) dan _unhandled_input sama-sama melihatnya.
	_key(code, true)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	_key(code, false)
	await get_tree().physics_frame

func _joy(button: JoyButton, pressed: bool = true) -> void:
	var b := InputEventJoypadButton.new()
	b.button_index = button
	b.pressed = pressed
	Input.parse_input_event(b)

func _wait_until(condition: Callable, timeout: float) -> bool:
	var waited := 0.0
	while not condition.call() and waited < timeout:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	return condition.call()

func _idle(player: Player) -> void:
	await _wait_until(func(): return player.state_machine.current_state is IdleState and not player.animation_controller.item_gesture_playing, 3.0)

# ── Tes ─────────────────────────────────────────────────────────────

## Dalam satu konteks, satu tombol hanya punya satu aksi (kecuali A = interaksi/lompat).
func _test_no_conflicts() -> void:
	var clashes: Array[String] = []
	for ctx in InputLayout.CONTEXT_NAMES:
		for kind in ["kb", "pad"]:
			var owner := {}
			for row in PlayerInput.rows():
				for b in row[kind]:
					if (int(b[1]) & ctx) == 0:
						continue
					var prev: String = owner.get(b[0], "")
					if not prev.is_empty() and prev != row["action"] and not PlayerInput._shares_by_design(prev, row["action"]):
						clashes.append("%s %s: %s vs %s" % [InputLayout.CONTEXT_NAMES[ctx], InputLayout.spec_label(b[0]), prev, row["action"]])
					owner[b[0]] = row["action"]
	check(clashes.is_empty(), "tidak ada tombol bentrok per konteks %s" % [clashes])

func _test_contexts(player: Player) -> void:
	var input := player.input
	_hold(player, "")
	check(input.context() == InputLayout.FIELD, "tangan kosong = konteks Lapangan")
	check(_hold(player, "sword_wood") and input.context() == InputLayout.MELEE, "pedang = combat jarak dekat")
	check(_hold(player, "bow_wood") and input.context() == InputLayout.RANGED, "busur = combat jarak jauh")
	check(_hold(player, "staff_wood") and input.context() == InputLayout.RANGED, "tongkat = combat jarak jauh")
	var owner := Node.new()
	add_child(owner)
	input.push_context(owner, InputLayout.DIALOGUE)
	check(input.context() == InputLayout.DIALOGUE, "UI bisa mendorong konteks Dialog")
	owner.free()
	check(input.context() == InputLayout.RANGED, "konteks UI lepas saat pemiliknya hilang")
	player.set_input_locked(&"menu", true)
	check(input.context() == InputLayout.MENU, "menu terbuka = konteks Menu")
	player.set_input_locked(&"menu", false)
	_hold(player, "")
	await get_tree().physics_frame

func _test_jump(player: Player) -> void:
	_hold(player, "")
	await _idle(player)
	await _tap_key(KEY_SPACE)
	check(player.is_jumping() and player.input.context() == InputLayout.AIR, "Spasi = lompat, konteks Di udara")
	await get_tree().create_timer(0.12).timeout
	await _tap_key(KEY_SPACE)
	check(player.tool_controller.jump_state.double_used, "Spasi di udara = lompat ganda")
	check(await _wait_until(func(): return not player.is_jumping(), 2.0), "mendarat setelah lompat ganda")
	await _idle(player)
	_hold(player, "sword_wood")
	await _tap_key(KEY_SPACE)
	check(not player.is_jumping(), "memegang pedang: Spasi tidak melompat (Spasi = roll)")
	await _idle(player)
	_hold(player, "")

func _test_gamepad_a(player: Player) -> void:
	_hold(player, "")
	await _idle(player)
	_joy(JOY_BUTTON_A, true)
	await get_tree().physics_frame
	_joy(JOY_BUTTON_A, false)
	check(await _wait_until(func(): return player.is_jumping(), 0.3), "gamepad A tanpa objek di dekat = lompat")
	await _wait_until(func(): return not player.is_jumping(), 2.0)
	await _idle(player)
	# Objek yang memakai A di frame yang sama (forage, NPC) menandai interaksi: tidak melompat.
	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_A
	press.pressed = true
	get_viewport().push_input(press)
	player.mark_interacted()
	await get_tree().physics_frame
	_joy(JOY_BUTTON_A, false)
	await get_tree().create_timer(0.25).timeout
	check(not player.is_jumping(), "gamepad A dipakai interaksi = tidak melompat")
	await _idle(player)

func _test_seed_scatter(player: Player) -> void:
	var seed_id := "seed_beet"
	if not _hold(player, seed_id):
		check(false, "item benih %s ada" % seed_id)
		return
	check(EquipmentContext.is_seed(player.tool_controller.current_item), "benih dikenali EquipmentContext")
	check(player.input.context() == InputLayout.FIELD, "memegang benih = Lapangan")
	await _idle(player)
	check(player.try_jump(), "lompat sambil memegang benih")
	await get_tree().physics_frame
	await _tap_key(KEY_C)
	check(player.tool_controller.jump_state.scatter_item != null, "pakai alat di udara = benih ditebar saat mendarat")
	check(await _wait_until(func(): return not player.is_jumping(), 2.0), "mendarat setelah tebar benih")
	check(player.tool_controller.jump_state.scatter_item == null, "antrean tebar benih dibersihkan setelah mendarat")
	await _idle(player)
	_hold(player, "")

func _test_exclusions(player: Player) -> void:
	var input := player.input
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.keycode = KEY_SPACE
	space.pressed = true
	_hold(player, "")
	check(not input.is_event(space, &"ui_accept"), "Lapangan: Spasi bukan ui_accept (Spasi = lompat)")
	var owner := Node.new()
	add_child(owner)
	input.push_context(owner, InputLayout.MENU)
	check(input.is_event(space, &"ui_accept"), "Menu: Spasi tetap konfirmasi")
	owner.free()
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_B
	b.pressed = true
	_hold(player, "sword_wood")
	check(not input.is_event(b, &"ui_cancel") and not input.is_event(b, &"inventory") and input.is_event(b, &"run"), "Combat: B = roll/lari, bukan batal atau tas")
	_hold(player, "")
	check(input.is_event(b, &"inventory"), "Lapangan: B = tas")
	var rmb := InputEventMouseButton.new()
	rmb.button_index = MOUSE_BUTTON_RIGHT
	rmb.pressed = true
	check(input.is_event(rmb, &"interact") and not input.is_event(rmb, &"guard"), "Lapangan: klik kanan = interaksi")
	_hold(player, "sword_wood")
	check(input.is_event(rmb, &"guard") and not input.is_event(rmb, &"interact") and not input.is_event(rmb, &"aim"), "Pedang: klik kanan = tangkis")
	_hold(player, "bow_wood")
	check(input.is_event(rmb, &"aim") and not input.is_event(rmb, &"guard"), "Busur: klik kanan = bidik")
	_hold(player, "")
	await get_tree().physics_frame

func _test_lock_on(player: Player) -> void:
	_hold(player, "sword_wood")
	await _idle(player)
	player.lock_on.toggle()
	check(not player.lock_on.has_target(), "lock-on tanpa musuh = tidak mengunci")
	var data: EnemyData = (load("res://resources/enemies/slime_green.tres") as EnemyData).duplicate()
	data.contact_damage = false
	data.ai_enabled = false
	var enemy := Enemy.spawn(data, self, player.global_position + Player.FEET_OFFSET + Vector2(-40, 0))
	await get_tree().physics_frame
	player.update_facing_direction(Vector2.RIGHT, true)
	await _tap_key(KEY_Q)
	await get_tree().process_frame
	check(player.lock_on.has_target() and player.lock_on.target == enemy, "Q memegang pedang = kunci musuh terdekat")
	await get_tree().process_frame
	await get_tree().process_frame
	check(player.facing_direction.x < 0.0, "terkunci: pemain menghadap target")
	check(player.aim_vector().x < 0.0, "terkunci: serangan mengarah ke target")
	_hold(player, "")
	await get_tree().process_frame
	await get_tree().process_frame
	check(not player.lock_on.has_target(), "lock-on lepas saat senjata disimpan")
	enemy.queue_free()

func _test_prompts(player: Player) -> void:
	_hold(player, "")
	var kb := InputEventKey.new()
	kb.physical_keycode = KEY_E
	kb.pressed = true
	player.input.note_event(kb)
	check(InputPrompt.key_text(&"interact", player, -1, 1) == "E", "prompt keyboard: interaksi = E")
	var hints := load("res://scenes/ui/action_hints.tscn").instantiate() as ActionHints
	hints.player = player
	add_child(hints)
	var text_kb := hints.build_text()
	check(text_kb.contains("[Spasi] Lompat") and text_kb.contains("[E] Interaksi"), "petunjuk HUD keyboard: %s" % text_kb)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	player.input.note_event(pad)
	check(InputPrompt.key_text(&"interact", player, -1, 1) == "A", "prompt ikut gamepad: interaksi = A")
	var text_pad := hints.build_text()
	check(text_pad.contains("[A] Interaksi / Lompat"), "petunjuk HUD gamepad: %s" % text_pad)
	_hold(player, "sword_wood")
	var text_melee := hints.build_text()
	check(text_melee.contains("[RB] Serang") and text_melee.contains("Roll") and text_melee.contains("[R3] Kunci"), "petunjuk HUD combat gamepad: %s" % text_melee)
	_hold(player, "")
	hints.queue_free()
	player.input.note_event(kb)

func _test_remap() -> void:
	var input := PlayerInput.solo()
	var jump_name := input._name(&"jump", InputLayout.EXPLORE)
	PlayerInput.set_binding("jump#0", "kb", [InputLayout.key(KEY_J)])
	check(input.bindings(&"jump", false, InputLayout.FIELD) == [InputLayout.key(KEY_J)], "atur ulang: lompat keyboard = J")
	var has_j := false
	for e in InputMap.action_get_events(jump_name):
		if e is InputEventKey and e.physical_keycode == KEY_J:
			has_j = true
	check(has_j, "Input Map dibangun ulang dengan tombol baru")
	check(InputLayout.load_overrides().get("jump#0", {}).get("kb", []) == [InputLayout.key(KEY_J)], "tombol baru tersimpan di file")
	PlayerInput._overrides_loaded = false
	PlayerInput._rows_cache.clear()
	check(input.bindings(&"jump", false, InputLayout.FIELD) == [InputLayout.key(KEY_J)], "tombol baru dimuat lagi dari file")
	check(not PlayerInput.conflicts("dodge#0", InputLayout.key(KEY_Q)).is_empty(), "Q untuk roll bentrok dengan lock-on")
	PlayerInput.reset_bindings()
	check(input.bindings(&"jump", false, InputLayout.FIELD) == [InputLayout.key(KEY_SPACE)], "kembalikan ke bawaan: lompat = Spasi")
