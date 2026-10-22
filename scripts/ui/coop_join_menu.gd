extends CanvasLayer

## Menu drop-in co-op (GDD 4.14), hanya dikendalikan perangkat pemain yang bergabung.
## Mode bergabung: pilih karakter co-op save ini yang sedang tidak dimainkan, buat Karakter
## Baru (layar kustomisasi), atau Batal. X = hapus karakter (tekan dua kali).
## Mode keluar (leave_mode): konfirmasi "Keluar dari co-op?".
## Gamepad: D-pad/stik atas-bawah, A pilih, B batal, X hapus. Numpad uji: 8/2 atau 5, 1, titik, 0.

signal chosen(data: PlayerData)
signal confirmed
signal cancelled

const FONT: Font = preload("res://resources/ui/readable_font.tres")
const CREATOR_SCENE := "res://scenes/ui/character_creator_ui.tscn"
const COLOR_TEXT := Color8(249, 230, 207)
const COLOR_DIM := Color(0.97, 0.88, 0.78, 0.45)
const COLOR_SELECTED := Color8(140, 214, 120)
const COLOR_DANGER := Color8(232, 120, 104)
const COLOR_PANEL := Color(0.13, 0.07, 0.11, 0.94)
const STICK_THRESHOLD := 0.6

var device: int = PlayerInput.DEVICE_NUMPAD
var player_number: int = 2
var leave_mode := false
var player_name := ""

## [{"label": String, "kind": "character"/"new"/"cancel"/"yes", "data": PlayerData, "disabled": bool}]
var _entries: Array[Dictionary] = []
var _labels: Array[Label] = []
var _selected := 0
var _delete_armed := false
var _stick_ready := true
var _hint: Label
var _list: VBoxContainer
var _panel: Control
var _done := false


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_rebuild_entries()


func _build_ui() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font = FONT
	ui_theme.default_font_size = 16

	_panel = Control.new()
	_panel.theme = ui_theme
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(dim)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)

	var box_panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = Color8(232, 183, 120)
	style.set_border_width_all(2)
	style.set_content_margin_all(14)
	box_panel.add_theme_stylebox_override("panel", style)
	box_panel.custom_minimum_size = Vector2(320, 0)
	center.add_child(box_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box_panel.add_child(box)

	var title_text := ("Keluar dari co-op?" if leave_mode else "P%d bergabung" % player_number)
	var title := _label(title_text, 32, COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub_text := ""
	if leave_mode:
		sub_text = "%s keluar, datanya disimpan. Layar lain digabung ulang." % (player_name if not player_name.is_empty() else "P%d" % player_number)
	else:
		sub_text = "Pilih karakter co-op di save ini, atau buat baru."
	var sub := _label(sub_text, 16, COLOR_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(300, 0)
	box.add_child(sub)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	box.add_child(_list)

	_hint = _label("", 16, COLOR_DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(300, 0)
	box.add_child(_hint)

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _rebuild_entries() -> void:
	_entries.clear()
	if leave_mode:
		_entries.append({"label": "Ya, keluar", "kind": "yes"})
		_entries.append({"label": "Batal", "kind": "cancel"})
	else:
		for data in GameState.available_coop_characters():
			var name_text := data.player_name if not data.player_name.strip_edges().is_empty() else "Tanpa nama"
			_entries.append({"label": name_text, "kind": "character", "data": data})
		var full := not GameState.can_create_coop_character()
		_entries.append({"label": "+ Karakter Baru" + (" (penuh)" if full else ""), "kind": "new", "disabled": full})
		_entries.append({"label": "Batal", "kind": "cancel"})
	_selected = clampi(_selected, 0, _entries.size() - 1)
	for child in _list.get_children():
		child.queue_free()
	_labels.clear()
	for entry in _entries:
		var label := _label("", 16, COLOR_TEXT)
		_list.add_child(label)
		_labels.append(label)
	_refresh()

func _refresh() -> void:
	for i in _entries.size():
		var entry := _entries[i]
		var label := _labels[i]
		var selected := i == _selected
		label.text = ("> " if selected else "   ") + str(entry["label"])
		var color := COLOR_SELECTED if selected else COLOR_TEXT
		if entry.get("disabled", false):
			color = COLOR_DIM
		if selected and _delete_armed:
			color = COLOR_DANGER
		label.add_theme_color_override("font_color", color)
	var hint := "A pilih   B batal"
	if not leave_mode:
		if _delete_armed:
			hint = "Tekan X lagi untuk menghapus karakter ini selamanya."
		elif _entries[_selected]["kind"] == "character":
			hint = "A pilih   X hapus   B batal"
		if device == PlayerInput.DEVICE_NUMPAD:
			hint += "\n(Numpad: 8/5 pindah, 1 pilih, 0 hapus, titik batal)"
	_hint.text = hint


# ── Input (hanya perangkat pemain ini) ──────────────────────────────

func _input(event: InputEvent) -> void:
	if _done or not _panel.visible:
		return
	var action := _action_of(event)
	if action.is_empty():
		return
	get_viewport().set_input_as_handled()
	match action:
		"up":
			_move(-1)
		"down":
			_move(1)
		"accept":
			_accept()
		"cancel":
			_cancel()
		"delete":
			_delete()

func _action_of(event: InputEvent) -> String:
	if device >= 0:
		if event is InputEventJoypadButton and event.device == device and event.pressed:
			match event.button_index:
				JOY_BUTTON_DPAD_UP: return "up"
				JOY_BUTTON_DPAD_DOWN: return "down"
				JOY_BUTTON_A, JOY_BUTTON_START: return "accept"
				JOY_BUTTON_B, JOY_BUTTON_BACK: return "cancel"
				JOY_BUTTON_X: return "delete"
		elif event is InputEventJoypadMotion and event.device == device and event.axis == JOY_AXIS_LEFT_Y:
			if absf(event.axis_value) < 0.3:
				_stick_ready = true
			elif _stick_ready and absf(event.axis_value) >= STICK_THRESHOLD:
				_stick_ready = false
				return "down" if event.axis_value > 0.0 else "up"
		return ""
	if device == PlayerInput.DEVICE_NUMPAD and event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_KP_8: return "up"
			KEY_KP_5, KEY_KP_2: return "down"
			KEY_KP_1, KEY_KP_ENTER: return "accept"
			KEY_KP_PERIOD: return "cancel"
			KEY_KP_0: return "delete"
	return ""

func _move(step: int) -> void:
	_delete_armed = false
	_selected = wrapi(_selected + step, 0, _entries.size())
	_refresh()

func _accept() -> void:
	var entry := _entries[_selected]
	if entry.get("disabled", false):
		return
	if _delete_armed:
		_delete_armed = false
		_refresh()
		return
	match entry["kind"]:
		"yes":
			_finish()
			confirmed.emit()
		"cancel":
			_cancel()
		"character":
			_finish()
			chosen.emit(entry["data"])
		"new":
			_open_creator()

func _cancel() -> void:
	if _delete_armed:
		_delete_armed = false
		_refresh()
		return
	_finish()
	cancelled.emit()

func _delete() -> void:
	if leave_mode or _entries[_selected]["kind"] != "character":
		return
	if not _delete_armed:
		_delete_armed = true
		_refresh()
		return
	_delete_armed = false
	var data: PlayerData = _entries[_selected]["data"]
	if GameState.delete_coop_character(data):
		Notify.say("Karakter co-op %s dihapus." % data.player_name)
	_rebuild_entries()

func _finish() -> void:
	_done = true
	queue_free()


# ── Karakter baru ───────────────────────────────────────────────────

func _open_creator() -> void:
	var data := GameState.new_coop_character(false)
	data.player_name = "Pemain %d" % player_number
	var creator := load(CREATOR_SCENE).instantiate() as CharacterCreatorUI
	creator.guest = true
	creator.ask_name = true
	creator.allow_cancel = true
	creator.pause_game = false
	creator.target_data = data
	creator.finished.connect(func(_look: CharacterAppearance):
		_finish()
		chosen.emit(data))
	creator.cancelled.connect(func(): _panel.show())
	_panel.hide()
	get_parent().add_child(creator)
