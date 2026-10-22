extends Node

## Tata letak gamepad (GDD 4.3): lapangan seperti Stardew Valley (A interaksi/lompat, X alat,
## B/Start tas, Y tab Crafting, LB/RB slot, RT tahan lari); combat seperti soulslike saat memegang
## senjata (RB serang, RT berat, B roll/lari, LB tangkis, LT art/bidik, R3 lock-on).

var failures := 0
var ui: CanvasLayer

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

## Tombol gamepad aksi `action` di konteks `ctx` (spesifikasi InputLayout, mis. "joy:0").
func pad(action: StringName, ctx: int) -> Array[String]:
	return PlayerInput.solo().bindings(action, true, ctx)

func has_button(action: StringName, button: JoyButton, ctx: int = InputLayout.FIELD) -> bool:
	return pad(action, ctx).has(InputLayout.joy(button))

func has_axis(action: StringName, axis: JoyAxis, ctx: int = InputLayout.FIELD) -> bool:
	return pad(action, ctx).has(InputLayout.axis(axis, 1.0))

func has_ui_button(action: StringName, button: JoyButton) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and e.button_index == button:
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
	var input := PlayerInput.solo()
	var M := InputLayout.MELEE
	var R := InputLayout.RANGED
	check(has_button(&"interact", JOY_BUTTON_A) and has_ui_button(&"ui_accept", JOY_BUTTON_A), "A = interaksi / konfirmasi")
	check(has_button(&"jump", JOY_BUTTON_A) and not has_button(&"jump", JOY_BUTTON_A, M), "A = lompat di lapangan, tidak saat memegang senjata")
	check(has_button(&"use_tool", JOY_BUTTON_X) and not has_axis(&"use_tool", JOY_AXIS_TRIGGER_RIGHT), "X = pakai alat, RT tidak memakai alat")
	check(has_button(&"inventory", JOY_BUTTON_B) and has_button(&"inventory", JOY_BUTTON_START) and has_ui_button(&"ui_cancel", JOY_BUTTON_B), "B dan Start = tas, B juga batal")
	check(has_button(&"crafting_menu", JOY_BUTTON_Y), "Y = tab Crafting")
	check(has_button(&"tool_prev", JOY_BUTTON_LEFT_SHOULDER) and has_button(&"tool_next", JOY_BUTTON_RIGHT_SHOULDER), "LB/RB = slot sebelumnya/berikutnya di lapangan")
	check(has_axis(&"run", JOY_AXIS_TRIGGER_RIGHT) and not has_button(&"run", JOY_BUTTON_B), "Lapangan: RT = lari, B bukan lari")
	check(has_button(&"cycle_hotbar", JOY_BUTTON_BACK) and has_button(&"sort_inventory", JOY_BUTTON_RIGHT_STICK), "Back hotbar, R3 rapikan")
	# Combat (soulslike)
	check(has_button(&"use_tool", JOY_BUTTON_RIGHT_SHOULDER, M) and has_button(&"use_tool", JOY_BUTTON_X, M), "Combat: RB (dan X) = serang ringan")
	check(has_axis(&"heavy_attack", JOY_AXIS_TRIGGER_RIGHT, M) and not has_axis(&"run", JOY_AXIS_TRIGGER_RIGHT, M), "Combat: RT = serangan berat, bukan lari")
	check(has_button(&"run", JOY_BUTTON_B, M) and not has_button(&"inventory", JOY_BUTTON_B, M), "Combat: B = roll/lari, bukan tas")
	check(has_button(&"guard", JOY_BUTTON_LEFT_SHOULDER, M) and not has_button(&"tool_prev", JOY_BUTTON_LEFT_SHOULDER, M), "Combat: LB = tangkis, bukan slot")
	check(has_axis(&"weapon_art", JOY_AXIS_TRIGGER_LEFT, M) and has_button(&"weapon_art", JOY_BUTTON_LEFT_STICK, M), "Pedang: LT / L3 = weapon art")
	check(has_axis(&"aim", JOY_AXIS_TRIGGER_LEFT, R) and not has_axis(&"weapon_art", JOY_AXIS_TRIGGER_LEFT, R), "Busur/tongkat: LT = bidik")
	check(has_button(&"lock_on", JOY_BUTTON_RIGHT_STICK, M) and not has_button(&"sort_inventory", JOY_BUTTON_RIGHT_STICK, M), "Combat: R3 = lock-on, bukan rapikan")
	check(has_button(&"tool_prev", JOY_BUTTON_DPAD_LEFT, M) and has_button(&"tool_next", JOY_BUTTON_DPAD_RIGHT, M), "Combat: D-pad kiri/kanan = ganti slot")

	var run_field := input._name(&"run", InputLayout.EXPLORE)
	await trigger(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	check(Input.is_action_pressed(run_field), "RT ditahan = aksi lari lapangan aktif")
	await trigger(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	check(not Input.is_action_pressed(run_field), "RT dilepas = berhenti lari")

	ui = load("res://scenes/ui/ui_inventory.tscn").instantiate()
	ui.name = "UIInventory"
	add_child(ui)
	await get_tree().process_frame
	await press(JOY_BUTTON_Y)
	check(ui.visible and ui._crafting_panel.visible, "Y membuka tas langsung di tab Crafting")
	await press(JOY_BUTTON_RIGHT_SHOULDER)
	check(ui._skill_tree.visible and not ui._crafting_panel.visible, "RB dari Crafting pindah ke Keahlian dalam buku")
	await press(JOY_BUTTON_RIGHT_SHOULDER)
	check(ui._relationship_ui.visible and not ui._skill_tree.visible, "RB dari Keahlian pindah ke NPC dalam buku")
	await press(JOY_BUTTON_RIGHT_SHOULDER)
	check(ui._collection_panel.visible and not ui._relationship_ui.visible, "RB dari NPC pindah ke Koleksi")
	await press(JOY_BUTTON_RIGHT_SHOULDER)
	check(ui._settings_panel.visible, "RB dari Koleksi membuka halaman Setelan buku")
	await press(JOY_BUTTON_RIGHT_SHOULDER)
	check(ui.book_root.get_node("LeftPage").visible and not ui._settings_panel.visible, "RB dari tab terakhir kembali ke Tas")
	await press(JOY_BUTTON_LEFT_SHOULDER)
	check(ui._settings_panel.visible, "LB dari Tas pindah ke halaman Setelan di sebelah kiri")
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
			texts.append(child.text if child is Label or child is Button else "")
	var header := texts.find("Aksi")
	check(grid.columns == 3 and header >= 0 and header % 3 == 0 and texts.slice(header, header + 3) == ["Aksi", "Keyboard + Mouse", "Gamepad"], "Halaman Kontrol punya kolom Aksi, Keyboard + Mouse, Gamepad")
	var row := texts.find("Tas / menu")
	check(row >= 0 and texts[row + 2] == "B / Start", "Baris tas menampilkan gamepad B / Start")
	row = texts.find("Tas tab Crafting / beri hadiah")
	check(row >= 0 and texts[row + 2] == "Y", "Baris Crafting menampilkan gamepad Y")
	row = texts.find("Interaksi / bicara / periksa")
	check(row >= 0 and texts[row + 1].begins_with("E") and texts[row + 2] == "A", "Baris Interaksi menampilkan E dan gamepad A")
	row = texts.find("Lompat (di udara: lompat ganda)")
	check(row >= 0 and texts[row + 1] == "Spasi" and texts[row + 2] == "A", "Baris Lompat menampilkan Spasi dan gamepad A")
	row = texts.find("Kunci target (lock-on)")
	check(row >= 0 and texts[row + 1].begins_with("Q") and texts[row + 2] == "R3", "Baris lock-on menampilkan Q dan R3")
	settings._open()
	settings._select_page(1)
	await get_tree().process_frame
	await get_tree().process_frame
	var page: Control = settings.get_node("%ControlsPage")
	print("Lebar tabel kontrol %d px, halaman %d px" % [grid.get_combined_minimum_size().x, page.size.x])
	check(grid.get_combined_minimum_size().x <= page.size.x + 1.0, "Tabel kontrol muat di lebar halaman Pengaturan")
	settings._close()
	print("GAMEPAD INPUT REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
