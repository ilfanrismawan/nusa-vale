extends CanvasLayer

## Lobby co-op lokal (dibuka dari Main Menu).
## P1 selalu keyboard + mouse. Pemain lain bergabung dengan menekan A / Start di gamepad,
## keluar dengan B. Enter / Start / tombol Mulai memulai saat ada minimal 2 pemain.
## Debug build: F2 menambah/menghapus pemain uji di numpad (tanpa gamepad).

signal start_requested(devices: Array[int])
signal closed

const FONT: Font = preload("res://resources/ui/readable_font.tres")
const COLOR_TEXT := Color8(249, 230, 207)
const COLOR_DIM := Color(0.97, 0.88, 0.78, 0.45)
const COLOR_JOINED := Color8(140, 214, 120)
const COLOR_PANEL := Color(0.13, 0.07, 0.11, 0.92)

var _devices: Array[int] = [PlayerInput.DEVICE_KEYBOARD]
var _slot_labels: Array[Label] = []
var _hint: Label
var _btn_start: Button


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_refresh()


func _build_ui() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font = FONT
	ui_theme.default_font_size = 16

	var root := Control.new()
	root.theme = ui_theme
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = Color8(232, 183, 120)
	style.set_border_width_all(2)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(360, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var title := _label("Co-op Lokal", 32, COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := _label("Uang bersama. Tas, stamina, dan layar masing-masing.", 16, COLOR_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	for i in Coop.MAX_PLAYERS:
		var slot := _label("", 16, COLOR_TEXT)
		box.add_child(slot)
		_slot_labels.append(slot)

	_hint = _label("", 16, COLOR_DIM)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_hint)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)

	_btn_start = Button.new()
	_btn_start.text = "Mulai"
	_btn_start.custom_minimum_size = Vector2(110, 26)
	_btn_start.pressed.connect(_try_start)
	buttons.add_child(_btn_start)

	var back := Button.new()
	back.text = "Kembali"
	back.custom_minimum_size = Vector2(110, 26)
	back.pressed.connect(_close)
	buttons.add_child(back)

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _refresh() -> void:
	for i in _slot_labels.size():
		var label := _slot_labels[i]
		if i < _devices.size():
			var input := PlayerInput.new()
			input.device = _devices[i]
			label.text = "P%d  %s" % [i + 1, input.device_name()]
			label.add_theme_color_override("font_color", COLOR_JOINED)
		else:
			label.text = "P%d  tekan A / Start di gamepad untuk ikut" % (i + 1)
			label.add_theme_color_override("font_color", COLOR_DIM)

	var slot := SaveManager.current_slot
	var save_text := ("Slot %d: melanjutkan save." % slot) if SaveManager.has_save() else ("Slot %d kosong: mulai game baru." % slot)
	var hint := "%s\nB di gamepad = keluar dari lobby." % save_text
	if OS.has_feature("editor"):
		hint += "\nUji tanpa gamepad: F2 tambah pemain numpad (8456 jalan, 0 alat, 1 interaksi)."
	if Input.get_connected_joypads().is_empty():
		hint += "\nBelum ada gamepad tersambung."
	_hint.text = hint
	_btn_start.disabled = _devices.size() < 2


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		var device: int = event.device
		var joined := _devices.has(device)
		match event.button_index:
			JOY_BUTTON_A:
				if not joined:
					_join(device)
			JOY_BUTTON_START:
				if joined:
					_try_start()
				else:
					_join(device)
			JOY_BUTTON_B:
				if joined:
					_leave(device)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F2:
				if OS.has_feature("editor"):
					if _devices.has(PlayerInput.DEVICE_NUMPAD):
						_leave(PlayerInput.DEVICE_NUMPAD)
					else:
						_join(PlayerInput.DEVICE_NUMPAD)
			KEY_ENTER, KEY_KP_ENTER:
				_try_start()
			KEY_ESCAPE:
				_close()
			_:
				return
		get_viewport().set_input_as_handled()

func _join(device: int) -> void:
	if _devices.size() >= Coop.MAX_PLAYERS or _devices.has(device):
		return
	_devices.append(device)
	_refresh()

func _leave(device: int) -> void:
	if device == PlayerInput.DEVICE_KEYBOARD:
		return
	_devices.erase(device)
	_refresh()

func _try_start() -> void:
	if _devices.size() < 2:
		Notify.say("Butuh minimal 2 pemain untuk co-op.")
		return
	start_requested.emit(_devices.duplicate())
	queue_free()

func _close() -> void:
	closed.emit()
	queue_free()
