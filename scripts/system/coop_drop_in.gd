extends Node

## Pendengar drop-in co-op (dibuat autoload Coop, anak terakhir root supaya menerima _input
## sebelum scene). GDD 4.14:
## - Gamepad yang belum dipakai menekan Start saat bermain -> Coop.request_join (menu pilih karakter).
## - Main sendiri: gamepad pertama yang dipakai P1 (tombol selain Start, atau Start bila P1 belum
##   menyentuh keyboard/mouse) menjadi milik P1, jadi Start-nya tetap membuka tas.
## - Pemain tamu menahan Start HOLD_LEAVE detik -> konfirmasi keluar dari co-op.
## - Debug/editor: F2 menambah atau mengeluarkan pemain uji numpad.

const HOLD_LEAVE := 1.5

var _seen_keyboard := false
## index pemain -> lama Start ditahan (detik)
var _hold: Dictionary = {}
var _leave_menu: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_to_front.call_deferred()

## Scene baru ditambahkan sebagai anak terakhir root; pindahkan pendengar ke belakangnya lagi.
func _on_node_added(node: Node) -> void:
	if node != self and node.get_parent() == get_tree().root:
		_to_front.call_deferred()

func _to_front() -> void:
	var root := get_tree().root
	if get_parent() == root and get_index() != root.get_child_count() - 1:
		root.move_child(self, -1)


func _input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_seen_keyboard = true
		if event is InputEventKey and not event.echo and event.physical_keycode == KEY_F2 and OS.is_debug_build():
			_toggle_numpad_guest()
		return
	if not (event is InputEventJoypadButton) or not event.pressed:
		return
	var device: int = event.device
	if Coop.is_switching() or Coop.device_in_use(device):
		return
	var start: bool = event.button_index == JOY_BUTTON_START
	if not Coop.has_root() and Coop.p1_pad < 0 and (not start or not _seen_keyboard):
		# Gamepad ini yang dipakai P1 main sendiri.
		Coop.p1_pad = device
		return
	if start and Coop.in_game():
		get_viewport().set_input_as_handled()
		Coop.request_join(device)

func _toggle_numpad_guest() -> void:
	if not Coop.in_game():
		return
	var index := Coop.devices.find(PlayerInput.DEVICE_NUMPAD) if Coop.active else -1
	if index > 0:
		Coop.leave(index)
	else:
		Coop.request_join(PlayerInput.DEVICE_NUMPAD)


func _process(delta: float) -> void:
	if not Coop.has_root() or Coop.is_switching() or is_instance_valid(_leave_menu):
		_hold.clear()
		return
	for i in range(1, Coop.player_count()):
		var device: int = Coop.devices[i]
		var held := false
		if device >= 0:
			held = Input.is_joy_button_pressed(device, JOY_BUTTON_START)
		elif device == PlayerInput.DEVICE_NUMPAD:
			held = Input.is_physical_key_pressed(KEY_KP_MULTIPLY)
		if not held:
			_hold.erase(i)
			continue
		_hold[i] = float(_hold.get(i, 0.0)) + delta
		if _hold[i] >= HOLD_LEAVE:
			_hold.clear()
			_ask_leave(i)
			return

func _ask_leave(index: int) -> void:
	var body := Coop.root.body_of(index) as Player
	if not is_instance_valid(body):
		return
	var view := Coop.view_of(body)
	# Tekan Start membuka tas; tahan Start = keluar, jadi tutup tasnya dulu.
	var bag := view.get_node_or_null("UIInventory") if view != null else null
	if bag != null and bag.visible and bag.has_method("toggle"):
		bag.toggle()
	var menu = Coop.JOIN_MENU.new()
	menu.leave_mode = true
	menu.device = Coop.devices[index]
	menu.player_number = index + 1
	menu.player_name = body.data.player_name
	body.set_input_locked(&"coop_leave", true)
	menu.confirmed.connect(func(): Coop.leave(index))
	menu.tree_exited.connect(func():
		if is_instance_valid(body):
			body.set_input_locked(&"coop_leave", false))
	_leave_menu = menu
	(view if view != null else get_tree().root).add_child(menu)

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected and device == Coop.p1_pad and not Coop.active:
		Coop.p1_pad = -1
