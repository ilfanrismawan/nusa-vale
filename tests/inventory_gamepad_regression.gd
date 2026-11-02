extends Node

## Grid tas dengan gamepad (GDD 4.3): D-pad memindah kursor slot, kiri/kanan di tepi grid
## pindah halaman, A pilih/tukar, X buka dialog buang (kiri/kanan ±1, atas/bawah ±10, B batal),
## dan kursor hilang begitu pemain kembali memakai mouse.

var failures := 0

func check(value: bool, message: String) -> void:
	if value: print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func press(button: JoyButton) -> void:
	for pressed in [true, false]:
		var b := InputEventJoypadButton.new()
		b.device = 0
		b.button_index = button
		b.pressed = pressed
		Input.parse_input_event(b)
		await get_tree().process_frame
		await get_tree().process_frame

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	var data := GameState.p1()
	data.bag_level = 1
	for i in data.inventory.size():
		data.inventory[i] = null
	data.inventory[0] = {"item": GameState._resolve_item("wood"), "count": 30}
	data.inventory[5] = {"item": GameState._resolve_item("stone"), "count": 4}
	var input := PlayerInput.solo()
	var pad_event := InputEventJoypadButton.new()
	pad_event.button_index = JOY_BUTTON_A
	pad_event.pressed = true
	input.note_event(pad_event)

	var ui = load("res://scenes/ui/ui_inventory.tscn").instantiate()
	ui.name = "UIInventory"
	add_child(ui)
	await get_tree().process_frame
	ui._open()
	await get_tree().process_frame
	check(ui._pad_slot == 0 and ui._pad_slot_ui == ui._slots[0] and ui._slots[0]._is_hovered, "tas dibuka dengan gamepad: kursor di slot pertama")
	check(ui.detail_title.text == GameState._resolve_item("wood").display_name, "detail item di kursor tampil seperti hover mouse")

	await press(JOY_BUTTON_DPAD_RIGHT)
	check(ui._pad_slot == 1 and not ui._slots[0]._is_hovered and ui._slots[1]._is_hovered, "D-pad kanan memindah kursor ke slot berikutnya")
	await press(JOY_BUTTON_DPAD_DOWN)
	check(ui._pad_slot == 5, "D-pad bawah turun satu baris (4 kolom)")
	await press(JOY_BUTTON_DPAD_LEFT)
	await press(JOY_BUTTON_DPAD_UP)
	check(ui._pad_slot == 0, "D-pad kiri dan atas kembali ke slot pertama")
	await press(JOY_BUTTON_DPAD_UP)
	await press(JOY_BUTTON_DPAD_LEFT)
	check(ui._pad_slot == 0 and ui.current_page == 0, "kursor berhenti di tepi atas dan di halaman pertama")

	await press(JOY_BUTTON_A)
	check(ui._selected_slot_index == 0, "A memilih item di kursor")
	await press(JOY_BUTTON_DPAD_RIGHT)
	await press(JOY_BUTTON_DPAD_DOWN)
	await press(JOY_BUTTON_A)
	check(data.inventory[0]["item"].item_id == "stone" and data.inventory[5]["item"].item_id == "wood" and ui._selected_slot_index == 5, "A di slot lain menukar item")

	for i in 2:
		await press(JOY_BUTTON_DPAD_RIGHT)
	check(ui._pad_slot == 7, "kursor sampai kolom terakhir")
	await press(JOY_BUTTON_DPAD_RIGHT)
	check(ui.current_page == 1 and ui._pad_slot == 16, "kanan di tepi grid pindah ke halaman berikutnya")
	await press(JOY_BUTTON_DPAD_LEFT)
	check(ui.current_page == 0 and ui._pad_slot == 7, "kiri di tepi grid kembali ke halaman sebelumnya")
	for i in 2:
		await press(JOY_BUTTON_DPAD_LEFT)
	check(ui._pad_slot == 5, "kursor kembali ke kayu")

	await press(JOY_BUTTON_X)
	check(ui._drop_dialog_open() and ui._drop_dialog.amount == 1, "X membuka dialog buang untuk item di kursor")
	await press(JOY_BUTTON_DPAD_RIGHT)
	check(ui._drop_dialog.amount == 2, "kanan di dialog menambah jumlah 1")
	await press(JOY_BUTTON_DPAD_UP)
	check(ui._drop_dialog.amount == 12, "atas di dialog menambah jumlah 10")
	await press(JOY_BUTTON_DPAD_DOWN)
	await press(JOY_BUTTON_DPAD_LEFT)
	check(ui._drop_dialog.amount == 1 and ui._pad_slot == 5, "bawah/kiri mengurangi jumlah tanpa memindah kursor")
	await press(JOY_BUTTON_B)
	check(not ui._drop_dialog_open() and ui.visible and int(data.inventory[5]["count"]) == 30, "B membatalkan dialog tanpa menutup tas")

	var hold := InputEventJoypadButton.new()
	hold.device = 0
	hold.button_index = JOY_BUTTON_DPAD_RIGHT
	hold.pressed = true
	Input.parse_input_event(hold)
	await get_tree().create_timer(0.6).timeout
	hold = hold.duplicate()
	hold.pressed = false
	Input.parse_input_event(hold)
	await get_tree().process_frame
	check(ui._pad_slot - 5 >= 2, "D-pad ditahan menggeser kursor berulang (geser %d)" % (ui._pad_slot - 5))
	while ui._pad_slot > 5:
		await press(JOY_BUTTON_DPAD_LEFT)
	await press(JOY_BUTTON_DPAD_RIGHT)
	await press(JOY_BUTTON_DPAD_RIGHT)
	await press(JOY_BUTTON_DPAD_RIGHT)
	check(ui.current_page == 1 and ui._pad_slot == 16, "kursor di halaman kedua")
	data.inventory[16] = {"item": GameState._resolve_item("carrot"), "count": 2}
	ui.refresh_inventory()
	await press(JOY_BUTTON_BACK)
	check(data.hotbar_page == 2, "Back menampilkan halaman hotbar berisi item di kursor")

	await press(JOY_BUTTON_Y)
	var crafting = ui._crafting_panel
	check(crafting.visible, "Y membuka tab Crafting")
	await press(JOY_BUTTON_X)
	check(crafting._group == "Equipment", "X di Crafting berganti grup resep")
	var first = crafting._selected
	await press(JOY_BUTTON_DPAD_RIGHT)
	check(crafting._selected != null and crafting._selected != first, "D-pad di Crafting memilih resep berikutnya")
	await press(JOY_BUTTON_A)
	check(crafting.visible and ui.visible, "A di Crafting mencoba membuat tanpa menutup tas")
	ui._show_bag_page()

	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(20, 0)
	input.note_event(mouse)
	await get_tree().process_frame
	check(ui._pad_slot == -1 and ui._pad_slot_ui == null and not ui._slots[4]._is_hovered, "kursor gamepad hilang saat kembali memakai mouse")

	ui._close()
	print("INVENTORY GAMEPAD REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
