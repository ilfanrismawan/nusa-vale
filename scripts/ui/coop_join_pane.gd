extends CanvasLayer

## Panel drop-in co-op (GDD 4.14): pemain yang bergabung memilih atau membuat karakter di
## petak layarnya sendiri (tempat layarnya nanti muncul) sementara pemain lain tetap bermain.
## Game tidak dijeda. Menu dan layar kustomisasi ada di SubViewport sendiri; hanya event
## perangkat pemain ini yang masuk (CoopDropIn -> Coop.forward_join_event -> forward), jadi
## keyboard/mouse/gamepad pemain lain tetap ke game. Setelah karakter dipilih, panel
## menunggu sampai pemain bisa dimunculkan (mis. P1 sedang membuka menu, transisi, gua).
## Batal: B di menu/saat menunggu, atau F2 dari P1 (Coop.cancel_join).

signal closed(joined: bool)

const JOIN_MENU := preload("res://scenes/ui/coop_join_menu.tscn")
## Garis pemisah antar layar, sama dengan CoopRoot.GAP.
const GAP := 2
const RETRY_TIME := 0.25
## Batal otomatis bila game tidak berjalan selama ini (kembali ke main menu). Lebih dari
## satu frame supaya pergantian scene saat P1 lewat pintu tidak ikut membatalkan.
const LEAVE_GAME_TIME := 1.0
const NUMPAD_KEYS: Array[Key] = [
	KEY_KP_0, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9,
	KEY_KP_ENTER, KEY_KP_PERIOD, KEY_KP_MULTIPLY,
]


var device: int = PlayerInput.DEVICE_NUMPAD
var player_number: int = 2

@onready var _container: SubViewportContainer = $JoinPane
@onready var _view: SubViewport = $JoinPane/Screen
@onready var _wait_panel: Control = $JoinPane/Screen/WaitLayer/WaitPanel
@onready var _wait_label: Label = _wait_panel.get_node("%Reason")
## Karakter yang dipilih; null = masih di menu.
var _data: PlayerData
var _joined := false
var _retry := 0.0
var _out_of_game := 0.0


func _ready() -> void:
	_view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var menu = JOIN_MENU.instantiate()
	menu.embedded_in_pane = true
	menu.device = device
	menu.player_number = player_number
	menu.chosen.connect(_on_chosen)
	menu.cancelled.connect(cancel)
	_view.add_child(menu)
	_wait_panel.get_node("%Action").pressed.connect(cancel)

	get_viewport().size_changed.connect(_layout)
	_layout()

func _exit_tree() -> void:
	closed.emit(_joined)


## Petak tempat layar pemain ini akan muncul (sama dengan susunan CoopRoot._layout).
func _layout() -> void:
	var size_px := get_viewport().get_visible_rect().size
	var half := ((size_px - Vector2(GAP, GAP)) * 0.5).floor()
	var right_x := half.x + GAP
	var bottom_y := half.y + GAP
	var rect := Rect2(Vector2.ZERO, size_px)
	if player_number == 2:
		rect = Rect2(right_x, 0, size_px.x - right_x, size_px.y)
	elif player_number >= 3:
		var i := player_number - 1
		var x := 0.0 if i % 2 == 0 else right_x
		var y := 0.0 if i < 2 else bottom_y
		var w := half.x if i % 2 == 0 else size_px.x - right_x
		var h := half.y if i < 2 else size_px.y - bottom_y
		rect = Rect2(x, y, w, h)
	_container.position = rect.position
	_container.size = rect.size
	$Backdrop.position = rect.position
	$Backdrop.size = rect.size

# ── Input (hanya perangkat pemain ini, dari Coop.forward_join_event) ──

func owns_event(event: InputEvent) -> bool:
	if device >= 0:
		return (event is InputEventJoypadButton or event is InputEventJoypadMotion) and event.device == device
	if device == PlayerInput.DEVICE_NUMPAD and event is InputEventKey:
		return NUMPAD_KEYS.has(event.physical_keycode)
	return false

func forward(event: InputEvent) -> void:
	if _joined:
		return
	if _data != null:
		# Sudah memilih, menunggu dimunculkan: B / titik numpad = batal.
		if _is_cancel(event):
			cancel()
		return
	_view.push_input(event, true)

func _is_cancel(event: InputEvent) -> bool:
	if event is InputEventJoypadButton and event.pressed:
		return event.button_index == JOY_BUTTON_B or event.button_index == JOY_BUTTON_BACK
	if event is InputEventKey and event.pressed and not event.echo:
		return event.physical_keycode == KEY_KP_PERIOD
	return false


# ── Bergabung ───────────────────────────────────────────────────────

func _on_chosen(data: PlayerData) -> void:
	_data = data
	_wait_panel.show()
	_show_wait("Memunculkan...")
	_try_join()

func _process(delta: float) -> void:
	if _joined:
		return
	if not Coop.in_game():
		_out_of_game += delta
		if _out_of_game >= LEAVE_GAME_TIME:
			# P1 kembali ke main menu.
			cancel()
		return
	_out_of_game = 0.0
	if _data == null:
		return
	_retry -= delta
	if _retry > 0.0:
		return
	_try_join()

func _try_join() -> void:
	_retry = RETRY_TIME
	var reason := Coop.try_join(device, _data)
	if reason.is_empty():
		_joined = true
		queue_free()
		return
	_show_wait(reason)

func _show_wait(reason: String) -> void:
	var cancel_key := "titik numpad" if device == PlayerInput.DEVICE_NUMPAD else "B"
	var display_name := _data.player_name if _data != null and not _data.player_name.strip_edges().is_empty() else "P%d" % player_number
	_wait_panel.get_node("%Header").text = "PEMAIN %d / BERGABUNG" % player_number
	_wait_panel.get_node("%Title").text = "%s Siap Bergabung" % display_name
	_wait_label.text = reason
	_wait_panel.get_node("%Action").text = "%s  Batalkan Bergabung" % cancel_key
	_wait_panel.reflow()

## Batalkan bergabung (B pemain ini, F2 P1, atau game tidak lagi berjalan).
func cancel() -> void:
	if _joined or is_queued_for_deletion():
		return
	if Coop.in_game():
		Notify.say("P%d batal bergabung." % player_number)
	queue_free()
