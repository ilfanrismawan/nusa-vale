extends CanvasLayer

## Lobby co-op lokal (dibuka dari Main Menu).
## P1 selalu keyboard + mouse. Pemain lain bergabung dengan menekan A / Start di gamepad,
## keluar dengan B. Enter / Start / tombol Mulai memulai saat ada minimal 2 pemain.
## Debug build: F2 menambah/menghapus pemain uji di numpad (tanpa gamepad).

signal start_requested(devices: Array[int])
signal closed

@export_group("Teks Lobi")
@export var joined_text := "%d / %d pemain bergabung"
@export var ready_text := "Siap bermain"
@export var waiting_text := "Menunggu pemain"
@export var join_text := "Tekan A / Start di gamepad"

var _devices: Array[int] = [PlayerInput.DEVICE_KEYBOARD]
var _slot_labels: Array[Label] = []
var _slot_status: Array[Label] = []
var _slot_panels: Array[PanelContainer] = []
@onready var _count: Label = %PlayerCount
@onready var _hint: Label = %SessionHint
@onready var _btn_start: Button = %StartButton

func _ready() -> void:
	for card in %PlayerGrid.get_children():
		_slot_panels.append(card)
		_slot_labels.append(card.get_node("Content/Device"))
		_slot_status.append(card.get_node("Content/Status"))
	_refresh()
	%BackButton.grab_focus()

func _refresh() -> void:
	_count.text = joined_text % [_devices.size(), Coop.MAX_PLAYERS]
	for i in _slot_labels.size():
		var label := _slot_labels[i]
		_slot_panels[i].theme_type_variation = &"JoinedCard" if i < _devices.size() else &"EmptyCard"
		if i < _devices.size():
			var input := PlayerInput.new()
			input.device = _devices[i]
			label.text = input.device_name()
			label.theme_type_variation = &"ReadyLabel"
			_slot_status[i].text = ready_text
			_slot_status[i].theme_type_variation = &"ReadyLabel"
		else:
			label.text = join_text
			label.theme_type_variation = &"WaitingLabel"
			_slot_status[i].text = waiting_text
			_slot_status[i].theme_type_variation = &"WaitingLabel"

	var slot := SaveManager.current_slot
	var save_text := ("Slot %d: melanjutkan save." % slot) if SaveManager.has_save() else ("Slot %d kosong: mulai game baru." % slot)
	var hint := "%s\nA / Start: bergabung  •  B: keluar  •  Enter / Start: mulai  •  Esc: kembali" % save_text
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
