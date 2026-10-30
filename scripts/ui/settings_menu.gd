extends CanvasLayer
class_name SettingsMenu

@onready var dimmer: ColorRect = %Dimmer
@onready var window_mode_option: OptionButton = %WindowModeOption
@onready var resolution_option: OptionButton = %ResolutionOption
@onready var vsync_check: CheckBox = %VsyncCheck
@onready var master_slider: HSlider = %MasterSlider
@onready var master_label: Label = %MasterLabel
@onready var btn_close: Button = %BtnClose
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var music_label: Label = %MusicLabel
@onready var sfx_label: Label = %SfxLabel
var _pages: Array[Control] = []
var _page_buttons: Array[Button] = []
var _exit_dialog: ConfirmationDialog
var _exit_to_desktop := false
var _slot_menu: SaveSlotMenu
var _initializing := true

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(640, 360),
	Vector2i(960, 540),
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]

const CONFIG_PATH := "user://settings.cfg"
const HOUSE_SCENE := "res://scenes/world/interior/interior_house.tscn"
const LOAD_SPAWN := Vector2(304.0, 147.0)

## Satu jalur Simpan/Muat pada halaman Permainan.
## Disembunyikan di Main Menu lewat set_save_buttons_visible(false).
var _save_row: HBoxContainer
var _btn_save: Button
var _btn_load: Button
var _coop_row: HBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_setup_ui()
	load_settings()
	_initializing = false

func _setup_ui() -> void:
	_pages.assign([%Cards, %ControlsPage, %GamePage])
	_page_buttons.assign([%BtnGeneral, %BtnControls, %BtnGame])
	for i in range(_page_buttons.size()):
		_page_buttons[i].pressed.connect(_select_page.bind(i))
	_select_page(0)
	_setup_controls()
	%BtnMainMenu.pressed.connect(_confirm_exit.bind(false))
	%BtnQuit.pressed.connect(_confirm_exit.bind(true))
	_exit_dialog = ConfirmationDialog.new()
	_exit_dialog.title = "Konfirmasi Keluar"
	_exit_dialog.ok_button_text = "Keluar"
	_exit_dialog.cancel_button_text = "Batal"
	_exit_dialog.confirmed.connect(_perform_exit)
	add_child(_exit_dialog)
	for bus_name in [&"Music", &"SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, &"Master")
	for slider in [music_slider, sfx_slider]:
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = 1.0
	music_slider.value_changed.connect(_on_bus_volume_changed.bind(&"Music", music_label))
	sfx_slider.value_changed.connect(_on_bus_volume_changed.bind(&"SFX", sfx_label))
	# Window modes
	window_mode_option.clear()
	window_mode_option.add_item("Jendela", 0)
	window_mode_option.add_item("Layar penuh", 1)
	window_mode_option.add_item("Tanpa bingkai", 2)
	window_mode_option.item_selected.connect(_on_window_mode_selected)

	# Resolutions
	resolution_option.clear()
	for res in RESOLUTIONS:
		var label := "%d x %d" % [res.x, res.y]
		if res.y == 360:
			label += " (360p)"
		elif res.y == 720:
			label += " (HD)"
		elif res.y == 1080:
			label += " (FHD)"
		elif res.y == 1440:
			label += " (2K)"
		resolution_option.add_item(label)
	resolution_option.item_selected.connect(_on_resolution_selected)

	# VSync
	vsync_check.toggled.connect(_on_vsync_toggled)

	# Master volume slider
	master_slider.min_value = 0.0
	master_slider.max_value = 1.0
	master_slider.step = 0.05
	var current_vol: float = db_to_linear(AudioServer.get_bus_volume_db(0))
	master_slider.value = current_vol
	_update_volume_label(current_vol)
	master_slider.value_changed.connect(_on_volume_changed)

	# Close button
	btn_close.pressed.connect(_close)
	_add_save_buttons()

	_sync_current_settings()

func _add_save_buttons() -> void:
	_save_row = HBoxContainer.new()
	_save_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_save_row.add_theme_constant_override("separation", 8)
	_btn_save = _make_save_button("Simpan Game", _on_save_pressed)
	_btn_load = _make_save_button("Muat Game", _on_load_pressed)
	_save_row.add_child(_btn_save)
	_save_row.add_child(_btn_load)
	var content: VBoxContainer = %SaveActions
	content.add_child(_save_row)
	# Co-op drop-in (GDD 4.14): P1 bisa mengeluarkan pemain tamu dari sini.
	_coop_row = HBoxContainer.new()
	_coop_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_coop_row.add_theme_constant_override("separation", 8)
	_coop_row.visible = false
	content.add_child(_coop_row)

func _refresh_coop_buttons() -> void:
	if _coop_row == null:
		return
	for child in _coop_row.get_children():
		child.queue_free()
	_coop_row.visible = Coop.active and Coop.player_count() > 1
	if not _coop_row.visible:
		return
	for i in range(1, Coop.player_count()):
		var data := GameState.get_player(i)
		var who := data.player_name if not data.player_name.is_empty() else "P%d" % (i + 1)
		var button := _make_save_button("Keluarkan %s" % who, func():
			_close()
			Coop.leave(i))
		button.tooltip_text = "P%d keluar dari co-op; datanya disimpan. Pemain tamu juga bisa menahan Start." % (i + 1)
		_coop_row.add_child(button)

func _make_save_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.texture_filter = btn_close.texture_filter
	button.custom_minimum_size = Vector2(100, 28)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override("font", btn_close.get_theme_font("font"))
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(callback)
	return button

func set_save_buttons_visible(value: bool) -> void:
	if _save_row:
		_save_row.visible = value
		%SaveActions.get_parent().get_node("GameHeading").visible = value
		%SaveActions.get_parent().get_node("SaveHint").visible = value
		%BtnMainMenu.visible = value
		%GamePage.get_node("ExitHint").visible = value

func _open_slot_menu(slot_mode: SaveSlotMenu.Mode) -> SaveSlotMenu:
	var menu := load("res://scenes/ui/save_slot_menu.tscn").instantiate() as SaveSlotMenu
	menu.mode = slot_mode
	menu.confirm_load = true
	menu.show_active = true
	add_child(menu)
	_slot_menu = menu
	menu.closed.connect(func(): _slot_menu = null)
	return menu

func _on_save_pressed() -> void:
	_open_slot_menu(SaveSlotMenu.Mode.SAVE)

func _on_load_pressed() -> void:
	var previous_slot := SaveManager.current_slot
	var menu := _open_slot_menu(SaveSlotMenu.Mode.LOAD)
	menu.slot_chosen.connect(_load_slot.bind(previous_slot))

## Muat dari menu pause: pemain bangun di rumah, sama seperti "Muat Game" di menu utama.
func _load_slot(_slot: int, previous_slot: int) -> void:
	if not SaveManager.load_game():
		SaveManager.select_slot(previous_slot)
		Notify.say("Gagal memuat save.")
		return
	hide()
	PauseManager.set_requested(false)
	GameState.next_spawn_position = LOAD_SPAWN
	GameState.has_spawn_point = true
	DayCycle.is_running = true
	get_tree().change_scene_to_file(HOUSE_SCENE)

func save_settings() -> void:
	# Sinyal kontrol saat setup tidak boleh menimpa konfigurasi sebelum dibaca.
	if _initializing:
		return
	var config := ConfigFile.new()
	var mode_idx := window_mode_option.selected
	config.set_value("display", "window_mode", mode_idx)
	
	var win = get_window()
	var cur_size = win.size
	var res_idx = resolution_option.selected
	if res_idx >= 0 and res_idx < RESOLUTIONS.size():
		cur_size = RESOLUTIONS[res_idx]
	config.set_value("display", "res_x", cur_size.x)
	config.set_value("display", "res_y", cur_size.y)
	config.set_value("display", "vsync", vsync_check.button_pressed)
	config.set_value("audio", "master_volume", master_slider.value)
	config.set_value("audio", "music_volume", music_slider.value)
	config.set_value("audio", "sfx_volume", sfx_slider.value)
	# File ini ditulis ulang utuh: bawa juga aksesibilitas horor (GDD 4.1).
	if GameState.horror != null:
		GameState.horror.write_accessibility(config)
	config.save(CONFIG_PATH)

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	
	var mode: int = config.get_value("display", "window_mode", 0)
	var res_x: int = int(config.get_value("display", "res_x", 1280))
	var res_y: int = int(config.get_value("display", "res_y", 720))
	var requested_size := Vector2i(res_x, res_y)
	if requested_size.x < 640 or requested_size.y < 360 or requested_size.x > 3840 or requested_size.y > 2160:
		requested_size = Vector2i(1280, 720)
	var vsync: bool = config.get_value("display", "vsync", true)
	var volume: float = config.get_value("audio", "master_volume", 1.0)
	
	# Audio
	AudioServer.set_bus_volume_db(0, linear_to_db(volume))
	master_slider.value = volume
	_update_volume_label(volume)
	music_slider.value = config.get_value("audio", "music_volume", 1.0)
	sfx_slider.value = config.get_value("audio", "sfx_volume", 1.0)
	_on_bus_volume_changed(music_slider.value, &"Music", music_label)
	_on_bus_volume_changed(sfx_slider.value, &"SFX", sfx_label)
	
	# VSync
	vsync_check.button_pressed = vsync
	_on_vsync_toggled(vsync)
	
	# Mode & Resolution
	for i in RESOLUTIONS.size():
		if RESOLUTIONS[i] == requested_size:
			resolution_option.select(i)
			break
	if mode == 1 or mode == 2:
		_on_window_mode_selected(mode)
	else:
		_apply_resolution(requested_size)

func _sync_current_settings() -> void:
	var win = get_window()
	if win.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		window_mode_option.select(1)
		resolution_option.disabled = true
	elif win.mode == Window.MODE_FULLSCREEN:
		window_mode_option.select(2)
		resolution_option.disabled = true
	else:
		window_mode_option.select(0)
		resolution_option.disabled = false

	var current_size = win.size
	for i in range(RESOLUTIONS.size()):
		if RESOLUTIONS[i].x == current_size.x and RESOLUTIONS[i].y == current_size.y:
			resolution_option.select(i)
			break

	var vsync_mode = DisplayServer.window_get_vsync_mode()
	vsync_check.button_pressed = (vsync_mode != DisplayServer.VSYNC_DISABLED)

func _on_window_mode_selected(index: int) -> void:
	print("[Settings] Mengubah mode layar ke: ", index)
	var win = get_window()
	match index:
		0: # Windowed
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			win.mode = Window.MODE_WINDOWED
			resolution_option.disabled = false
			var res_idx = resolution_option.selected
			if res_idx >= 0 and res_idx < RESOLUTIONS.size():
				_apply_resolution(RESOLUTIONS[res_idx])
			else:
				_apply_resolution(Vector2i(640, 360))
		1: # Fullscreen
			win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
			resolution_option.disabled = true
		2: # Borderless Fullscreen
			win.mode = Window.MODE_FULLSCREEN
			resolution_option.disabled = true
	window_mode_option.select(index)
	save_settings()

func _on_resolution_selected(index: int) -> void:
	if index >= 0 and index < RESOLUTIONS.size():
		_apply_resolution(RESOLUTIONS[index])
	save_settings()

func _apply_resolution(new_size: Vector2i) -> void:
	new_size.x = clampi(new_size.x, 640, 3840)
	new_size.y = clampi(new_size.y, 360, 2160)
	print("[Settings] Mengubah resolusi ke: ", new_size)
	var win := get_window()
	if win.mode != Window.MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		win.mode = Window.MODE_WINDOWED
	# Apply once through the Window API; mixing DisplayServer and Window writes
	# caused the old resolution choice to be overwritten on some displays.
	win.size = new_size
	for i in RESOLUTIONS.size():
		if RESOLUTIONS[i] == new_size:
			resolution_option.select(i)
			break
	var screen_size := DisplayServer.screen_get_size()
	var center_pos := Vector2i(maxi(0, (screen_size.x - new_size.x) / 2), maxi(0, (screen_size.y - new_size.y) / 2))
	win.position = center_pos
	window_mode_option.select(0)
	resolution_option.disabled = false

func _on_vsync_toggled(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	save_settings()

func _on_volume_changed(val: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(val))
	_update_volume_label(val)
	save_settings()

func _on_bus_volume_changed(value: float, bus_name: StringName, label: Label) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(bus, value <= 0.0)
	label.text = "%d%%" % roundi(value * 100)
	save_settings()

func _select_page(index: int) -> void:
	for i in range(_pages.size()):
		_pages[i].visible = i == index
		_page_buttons[i].set_pressed_no_signal(i == index)

const COLOR_CONTROLS_HEADER := Color(0.95, 0.78, 0.45)
const COLOR_CONTROLS_GROUP := Color(0.7, 0.85, 1.0)
## Batas waktu menunggu tombol baru (gamepad tidak punya tombol batal yang aman).
const CAPTURE_TIMEOUT := 6.0
const GROUP_TITLES := {
	"Lapangan": "Lapangan (seperti Stardew Valley)",
	"Lompat": "Lompat (seperti Grand Bazaar)",
	"Combat": "Combat, pegang senjata (seperti soulslike)",
}
## Lebar kolom halaman Kontrol (panel Pengaturan 560 px).
const CONTROLS_LABEL_WIDTH := 190.0
const CONTROLS_BUTTON_WIDTH := 135.0

## Tombol yang sedang menunggu input baru: {row_id, kind, button}. Kosong = tidak menunggu.
var _capture := {}
var _capture_time := 0.0

## Halaman Kontrol (GDD 4.3): satu baris per aksi dari InputLayout, dikelompokkan per konteks.
## Klik tombol di kolom Keyboard + Mouse atau Gamepad, lalu tekan tombol baru. Tombol yang
## sudah dipakai aksi lain di konteks yang sama ditukar. Disimpan di user://input_bindings.cfg.
func _setup_controls() -> void:
	PlayerInput.ensure_combat_actions()
	_capture = {}
	var grid: GridContainer = %ControlsGrid
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var hints := CheckBox.new()
	hints.text = "Tampilkan"
	hints.button_pressed = ActionHints.is_enabled()
	hints.toggled.connect(func(on: bool): ActionHints.set_enabled(on))
	var reset := Button.new()
	reset.text = "Kembalikan"
	reset.tooltip_text = "Kembalikan semua tombol ke bawaan"
	reset.pressed.connect(_on_reset_controls)
	_add_controls_label("Petunjuk tombol di layar")
	grid.add_child(hints)
	_add_controls_label("")
	_add_controls_label("Semua tombol ke bawaan")
	_add_controls_label("")
	grid.add_child(reset)
	_add_controls_row(["Aksi", "Keyboard + Mouse", "Gamepad"], true)
	var group := ""
	for row in PlayerInput.rows():
		if not row["show"]:
			continue
		if row["group"] != group:
			group = row["group"]
			_add_controls_label(GROUP_TITLES.get(group, group), COLOR_CONTROLS_GROUP)
			_add_controls_label("")
			_add_controls_label("")
		_add_controls_label(row["label"])
		for kind in ["kb", "pad"]:
			var button := Button.new()
			button.custom_minimum_size = Vector2(CONTROLS_BUTTON_WIDTH, 0)
			button.clip_text = true
			button.text = _binding_text(row, kind)
			button.tooltip_text = button.text
			button.add_theme_font_size_override("font_size", 16)
			button.pressed.connect(_begin_capture.bind(row["id"], kind, button))
			grid.add_child(button)
	_add_controls_row(["Berjalan (gamepad)", "-", "Stik kiri (selalu)"])
	_add_controls_row(["Ganti target lock-on", "-", "Stik kanan"])
	_add_controls_row(["Co-op", "Satu pengaturan untuk semua gamepad", ""])

func _add_controls_row(texts: Array, header: bool = false) -> void:
	for text in texts:
		_add_controls_label(text, COLOR_CONTROLS_HEADER if header else Color.TRANSPARENT)

func _add_controls_label(text: String, color: Color = Color.TRANSPARENT) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	# Teks panjang dibungkus supaya tabel muat di panel tanpa geser ke samping.
	var first_column: bool = %ControlsGrid.get_child_count() % 3 == 0
	label.custom_minimum_size = Vector2(CONTROLS_LABEL_WIDTH if first_column else CONTROLS_BUTTON_WIDTH, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if color.a > 0.0:
		label.add_theme_color_override("font_color", color)
	%ControlsGrid.add_child(label)

func _binding_text(row: Dictionary, kind: String) -> String:
	var labels: Array[String] = []
	for b in row[kind]:
		labels.append(InputLayout.spec_label(b[0]))
	return " / ".join(labels) if not labels.is_empty() else "-"

func _begin_capture(row_id: String, kind: String, button: Button) -> void:
	_cancel_capture()
	_capture = {"row_id": row_id, "kind": kind, "button": button}
	_capture_time = CAPTURE_TIMEOUT
	button.text = "Tekan tombol..." if kind == "kb" else "Tekan tombol gamepad..."

func _cancel_capture() -> void:
	if _capture.is_empty():
		return
	var button: Button = _capture["button"]
	var row := _row_by_id(_capture["row_id"])
	if is_instance_valid(button) and not row.is_empty():
		button.text = _binding_text(row, _capture["kind"])
	_capture = {}

func _row_by_id(row_id: String) -> Dictionary:
	for row in PlayerInput.rows():
		if row["id"] == row_id:
			return row
	return {}

func _process(delta: float) -> void:
	if _capture.is_empty():
		return
	_capture_time -= delta
	if _capture_time <= 0.0 or not visible:
		_cancel_capture()

## Input saat menunggu tombol baru. true = event dipakai.
func _capture_input(event: InputEvent) -> bool:
	if _capture.is_empty():
		return false
	var kind: String = _capture["kind"]
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		_cancel_capture()
		return true
	var spec := InputLayout.from_event(event)
	if spec.is_empty() or InputLayout.is_pad_spec(spec) != (kind == "pad"):
		# Abaikan gerakan mouse/stik dan perangkat lain, tetapi jangan biarkan sampai ke menu.
		return event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton
	_apply_binding(_capture["row_id"], kind, spec)
	_capture = {}
	_setup_controls.call_deferred()
	return true

## Tombol baru jadi tombol utama baris itu; tombol lain baris itu tetap. Aksi lain di konteks
## yang sama yang memakai tombol ini menerima tombol utama lama (ditukar).
func _apply_binding(row_id: String, kind: String, spec: String) -> void:
	var row := _row_by_id(row_id)
	if row.is_empty():
		return
	var specs: Array[String] = []
	for b in row[kind]:
		specs.append(b[0])
	var old: String = specs[0] if not specs.is_empty() else ""
	if old == spec:
		return
	for other in PlayerInput.conflicts(row_id, spec):
		var theirs: Array[String] = []
		for b in other[kind]:
			if b[0] == spec:
				if not old.is_empty():
					theirs.append(old)
			elif not theirs.has(b[0]):
				theirs.append(b[0])
		PlayerInput.set_binding(other["id"], kind, theirs)
		Notify.say("Tombol ditukar: %s sekarang %s" % [other["label"], InputLayout.spec_label(old) if not old.is_empty() else "tanpa tombol"])
	if specs.has(spec):
		# Sudah tombol kedua baris ini: jadikan utama, tombol lama tetap.
		specs.erase(spec)
		specs.insert(0, spec)
	elif specs.is_empty():
		specs.append(spec)
	else:
		specs[0] = spec
	PlayerInput.set_binding(row_id, kind, specs)

func _on_reset_controls() -> void:
	PlayerInput.reset_bindings()
	_setup_controls.call_deferred()

func _confirm_exit(to_desktop: bool) -> void:
	_exit_to_desktop = to_desktop
	_exit_dialog.title = "Keluar Game" if to_desktop else "Kembali ke Menu Utama"
	_exit_dialog.dialog_text = "Progres setelah simpan terakhir akan hilang.\nSimpan lewat halaman Permainan sebelum keluar."
	if not _save_row.visible:
		_exit_dialog.dialog_text = "Tutup Nusa Vale?"
	_exit_dialog.popup_centered(Vector2i(400, 140))

func _perform_exit() -> void:
	save_settings()
	DayCycle.is_running = false
	PauseManager.set_requested(false)
	if _exit_to_desktop:
		get_tree().quit()
	else:
		Coop.stop()
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _update_volume_label(val: float) -> void:
	master_label.text = "%d%%" % int(val * 100)

func toggle() -> void:
	if visible:
		_close()
	else:
		_open()

func _open() -> void:
	_sync_current_settings()
	# Co-op: area dan pemain diatur CoopRoot, jadi muat save hanya dari menu utama.
	if _btn_load:
		_btn_load.disabled = Coop.active
		_btn_load.tooltip_text = "Saat co-op, muat save dari menu utama." if Coop.active else ""
	_refresh_coop_buttons()
	show()
	_select_page(0)
	var inventory_node := get_parent().get_node_or_null("UIInventory")
	btn_close.text = "Kembali ke Tas" if inventory_node != null and inventory_node.visible else "Kembali"
	PauseManager.set_requested(not Coop.active)
	if Coop.active and inventory_node != null:
		Coop.set_menu_open(inventory_node.player, true)

func _close() -> void:
	save_settings()
	hide()
	# Kembali ke buku inventory tetap menjeda permainan solo.
	var inventory_node := get_parent().get_node_or_null("UIInventory")
	PauseManager.set_requested(not Coop.active and inventory_node != null and inventory_node.visible)
	if Coop.active and inventory_node != null:
		Coop.set_menu_open(inventory_node.player, inventory_node.visible)

func _toggle_fullscreen() -> void:
	var cur = DisplayServer.window_get_mode()
	if cur == DisplayServer.WINDOW_MODE_FULLSCREEN or cur == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		_on_window_mode_selected(0)
	else:
		_on_window_mode_selected(1)

func _input(event: InputEvent) -> void:
	if visible and _capture_input(event):
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(_slot_menu) or (is_instance_valid(_exit_dialog) and _exit_dialog.visible):
		return
	# Co-op: hanya P1 yang membuka menu pengaturan/pause.
	if not Coop.is_p1_event(event):
		return
	# F11 / Alt+Enter, diatur di Input Map (toggle_fullscreen).
	if event.is_action_pressed("toggle_fullscreen") and not event.is_echo():
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if not visible:
			var inventory_node = get_parent().get_node_or_null("UIInventory")
			if inventory_node:
				return
			if get_tree().paused:
				return
		toggle()
		get_viewport().set_input_as_handled()
