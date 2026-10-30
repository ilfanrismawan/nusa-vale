extends CanvasLayer

## Menu drop-in co-op (GDD 4.14), hanya dikendalikan perangkat pemain yang bergabung.
## Mode bergabung: pilih karakter co-op save ini yang sedang tidak dimainkan, buat Karakter
## Baru (layar kustomisasi), atau Batal. X = hapus karakter (tekan dua kali). Mode ini tampil
## di dalam CoopJoinPane (petak layar pemain baru) sementara pemain lain tetap bermain.
## Mode keluar (leave_mode): konfirmasi "Keluar dari co-op?".
## Gamepad: D-pad/stik atas-bawah, A pilih, B batal, X hapus. Numpad uji: 8/2 atau 5, 1, titik, 0.

signal chosen(data: PlayerData)
signal confirmed
signal cancelled

const CREATOR_SCENE := "res://scenes/ui/character_creator_ui.tscn"
const STICK_THRESHOLD := 0.6

@export_group("Tampilan")
@export var row_scene: PackedScene = preload("res://scenes/ui/coop_join_row.tscn")
@export var leave_mode := false
## Pane menyediakan blur di viewport dunia, bukan di viewport UI transparan ini.
@export var embedded_in_pane := false
@export_group("Teks")
@export var join_title := "Pilih Karakter"
@export var leave_title := "Keluar dari Co-op?"
@export var new_character_text := "+ Karakter Baru"
@export var join_action_text := "Gunakan Karakter"

var device: int = PlayerInput.DEVICE_NUMPAD
var player_number: int = 2
var player_name := ""

## Daftar karakter, karakter baru, atau konfirmasi keluar.
var _entries: Array[Dictionary] = []
var _rows: Array[Button] = []
var _selected := 0
var _delete_armed := false
var _stick_ready := true
var _done := false
@onready var _hint: Label = %Hint
@onready var _list: VBoxContainer = %Entries
@onready var _panel: Control = $UI

func _ready() -> void:
	get_viewport().size_changed.connect(_refresh)
	%Backdrop.visible = not embedded_in_pane
	%Header.text = "PEMAIN %d / %s" % [player_number, "CO-OP" if leave_mode else "BERGABUNG"]
	%Title.text = leave_title if leave_mode else join_title
	if leave_mode:
		var display_name := player_name if not player_name.is_empty() else "P%d" % player_number
		%Subtitle.text = "Progres %s disimpan. Layar pemain lain akan disusun ulang." % display_name
		%SharedInfo.text = ""
		%Action.hide()
		$UI.list_height = 112.0
	_rebuild_entries()

func _rebuild_entries() -> void:
	_entries.clear()
	if leave_mode:
		# Tetap bermain adalah pilihan awal yang aman.
		_entries.append({"label": "Tetap Bermain", "kind": "cancel"})
		_entries.append({"label": "Keluar dari Co-op", "kind": "yes"})
	else:
		for data in GameState.available_coop_characters():
			var name_text := data.player_name if not data.player_name.strip_edges().is_empty() else "Tanpa nama"
			_entries.append({"label": name_text, "kind": "character", "data": data})
		var full := not GameState.can_create_coop_character()
		_entries.append({"label": new_character_text + (" (penuh)" if full else ""), "kind": "new", "disabled": full})
	_selected = clampi(_selected, 0, _entries.size() - 1)
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_rows.clear()
	for entry in _entries:
		var row := row_scene.instantiate() as Button
		_list.add_child(row)
		_rows.append(row)
	_refresh()

func _refresh() -> void:
	for i in _entries.size():
		var entry := _entries[i]
		var row := _rows[i]
		row.text = str(entry["label"])
		row.disabled = entry.get("disabled", false)
		row.theme_type_variation = &"SelectedRow" if i == _selected else &""
		if i == _selected and _delete_armed:
			row.theme_type_variation = &"DangerRow"
	var selected := _entries[_selected]
	var action := join_action_text if selected["kind"] == "character" else "Buat Karakter Baru"
	var accept_key := "1" if device == PlayerInput.DEVICE_NUMPAD else "A"
	var cancel_key := "titik" if device == PlayerInput.DEVICE_NUMPAD else "B"
	var delete_key := "0" if device == PlayerInput.DEVICE_NUMPAD else "X"
	%Action.text = "%s  %s" % [accept_key, action]
	%Action.disabled = selected.get("disabled", false)
	var compact: bool = get_viewport().get_visible_rect().size.y < $UI.compact_height
	var hint := "%s: pilih   %s: batal" % [accept_key, cancel_key]
	if not compact:
		hint = "Atas / Bawah: pilih   " + hint
	if _delete_armed:
		hint = "Tekan %s lagi untuk menghapus permanen. %s: batal." % [delete_key, cancel_key]
		%Action.text = "%s  Batalkan Penghapusan" % accept_key
	elif not leave_mode and selected["kind"] == "character":
		hint += ("   " if compact else "\n") + "%s: hapus karakter" % delete_key
	_hint.text = hint
	$UI.reflow()
	_scroll_selected.call_deferred()

func _scroll_selected() -> void:
	# Daftar bisa dibangun ulang (hapus karakter) sebelum deferred call berjalan.
	if _done or _rows.is_empty() or _selected >= _rows.size():
		return
	var row := _rows[_selected]
	if is_instance_valid(row) and _list.is_ancestor_of(row):
		%Scroll.ensure_control_visible(row)

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
