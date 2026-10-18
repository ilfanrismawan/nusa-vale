extends Node

## Tata letak gamepad mengikuti Stardew Valley (GDD 9.1): A interaksi, X alat, B/Start tas,
## Y tab Crafting, LB/RB slot (di tas: ganti tab), RT tahan lari, LT tangkis.

var failures := 0
var ui: CanvasLayer

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func has_button(action: StringName, button: JoyButton) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and e.button_index == button:
			return true
	return false

func has_axis(action: StringName, axis: JoyAxis) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadMotion and e.axis == axis:
			return true
	return false

func press(button: JoyButton) -> void:
	for pressed in [true, false]:
		var b := InputEventJoypadButton.new()
		b.button_index = button
		b.pressed = pressed
		get_viewport().push_input(b, true)
		await get_tree().process_frame

func trigger(axis: JoyAxis, value: float) -> void:
	var m := InputEventJoypadMotion.new()
	m.axis = axis
	m.axis_value = value
	Input.parse_input_event(m)
	await get_tree().process_frame

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DayCycle.is_running = false
	PlayerInput.solo()
	check(has_button(&"interact", JOY_BUTTON_A) and has_button(&"ui_accept", JOY_BUTTON_A), "A = interaksi / konfirmasi")
	check(has_button(&"use_tool", JOY_BUTTON_X) and not has_axis(&"use_tool", JOY_AXIS_TRIGGER_RIGHT), "X = pakai alat, RT tidak lagi memakai alat")
	check(has_button(&"inventory", JOY_BUTTON_B) and has_button(&"inventory", JOY_BUTTON_START) and has_button(&"ui_cancel", JOY_BUTTON_B), "B dan Start = tas, B juga batal")
	check(has_button(&"crafting_menu", JOY_BUTTON_Y), "Y = tab Crafting")
	check(has_button(&"tool_prev", JOY_BUTTON_LEFT_SHOULDER) and has_button(&"tool_next", JOY_BUTTON_RIGHT_SHOULDER), "LB/RB = slot sebelumnya/berikutnya")
	check(has_axis(&"run", JOY_AXIS_TRIGGER_RIGHT) and not has_button(&"run", JOY_BUTTON_B), "RT = lari, B tidak lagi lari")
	check(has_axis(&"guard", JOY_AXIS_TRIGGER_LEFT), "LT = tangkis")
	check(has_button(&"cycle_hotbar", JOY_BUTTON_BACK) and has_button(&"weapon_art", JOY_BUTTON_LEFT_STICK) and has_button(&"sort_inventory", JOY_BUTTON_RIGHT_STICK), "Back hotbar, L3 weapon art, R3 rapikan")

	await trigger(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	check(Input.is_action_pressed(&"run"), "RT ditahan = aksi lari aktif")
	await trigger(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	check(not Input.is_action_pressed(&"run"), "RT dilepas = berhenti lari")

	ui = load("res://scenes/ui/ui_inventory.tscn").instantiate()
	ui.name = "UIInventory"
	add_child(ui)
	await get_tree().process_frame
	await press(JOY_BUTTON_Y)
	check(ui.visible and ui._crafting_panel.visible, "Y membuka tas langsung di tab Crafting")
	await press(JOY_BUTTON_RIGHT_SHOULDER)
	check(ui._collection_panel.visible and not ui._crafting_panel.visible, "RB di tas pindah ke tab kanan (Koleksi)")
	await press(JOY_BUTTON_RIGHT_SHOULDER)
	check(ui.book_root.get_node("LeftPage").visible and not ui._collection_panel.visible and not ui._status_panel.visible, "RB dari tab terakhir kembali ke tab Tas (Pengaturan dilewati)")
	await press(JOY_BUTTON_LEFT_SHOULDER)
	check(ui._collection_panel.visible, "LB di tas pindah ke tab kiri")
	await press(JOY_BUTTON_B)
	check(not ui.visible, "B menutup tas")
	await press(JOY_BUTTON_START)
	check(ui.visible and not ui._crafting_panel.visible, "Start membuka tas di halaman tas")
	await press(JOY_BUTTON_Y)
	check(ui.visible and ui._crafting_panel.visible, "Y saat tas terbuka pindah ke Crafting")
	await press(JOY_BUTTON_Y)
	check(not ui.visible, "Y lagi menutup tas")
	await press(JOY_BUTTON_B)
	check(ui.visible, "B saat tas tertutup membuka tas (seperti Stardew)")
	await press(JOY_BUTTON_B)
	check(not ui.visible and not get_tree().paused, "B menutup tas dan game berjalan lagi")

	var settings: SettingsMenu = load("res://scenes/ui/settings_menu.tscn").instantiate()
	settings.name = "SettingsMenu"
	add_child(settings)
	await get_tree().process_frame
	var grid: GridContainer = settings.get_node("%ControlsGrid")
	var texts: Array[String] = []
	for child in grid.get_children():
		if not child.is_queued_for_deletion():
			texts.append((child as Label).text)
	check(grid.columns == 3 and texts.slice(0, 3) == ["Aksi", "Keyboard + Mouse", "Gamepad"], "Halaman Kontrol punya kolom Aksi, Keyboard + Mouse, Gamepad")
	var row := texts.find("Tas / menu")
	check(row >= 0 and texts[row + 2] == "B / Start", "Baris tas menampilkan gamepad B / Start")
	row = texts.find("Crafting")
	check(row >= 0 and texts[row + 2] == "Y", "Baris Crafting menampilkan gamepad Y")
	row = texts.find("Interaksi")
	check(row >= 0 and texts[row + 2] == "A", "Baris Interaksi menampilkan gamepad A")
	settings._open()
	settings._select_page(1)
	await get_tree().process_frame
	await get_tree().process_frame
	var page: Control = settings.get_node("%ControlsPage")
	print("Lebar tabel kontrol %d px, halaman %d px" % [grid.get_combined_minimum_size().x, page.size.x])
	check(grid.get_combined_minimum_size().x <= page.size.x + 1.0, "Tabel kontrol muat di lebar halaman Pengaturan")
	settings._close()
	print("GAMEPAD INPUT REGRESSION COMPLETE: failures=%d" % failures)
	await get_tree().create_timer(60.0).timeout
	get_tree().quit(1 if failures else 0)
