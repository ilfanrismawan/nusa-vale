extends CanvasLayer

## Dasar mini game sihir (GDD "Menara Penyihir & Mini Game Sihir"): panel buku di tengah layar
## dengan papan gambar (board) yang digambar sendiri oleh turunan lewat _draw_board().
## Hanya pemain pemilik yang dikunci (co-op: pemain lain tetap bebas; solo: game dijeda lewat
## Coop.set_menu_open). Selesai -> sinyal finished(success). Batal (tombol B/Esc) = gagal tanpa
## biaya (cancelled = true), pemanggil yang memutuskan akibatnya.

signal finished(success: bool)

const ServiceTheme = preload("res://scripts/ui/farm_service_theme.gd")
const BOARD_SIZE := Vector2(380, 240)
const RESULT_SECONDS := 1.1
const GOOD := Color(0.55, 1.0, 0.7)
const BAD := Color(1.0, 0.45, 0.45)
const MAGIC_INK := Color(0.42, 0.25, 0.62)

var player: Player
var title := "Sihir"
## true bila pemain membatalkan sendiri.
var cancelled := false

var board: Control
var _title_label: Label
var _hint_label: Label
var _status_label: Label
var _done := false
var _result := -1.0
var _flash := 0.0
var _flash_color := Color.WHITE


func _ready() -> void:
	layer = ServiceTheme.LAYER + 1
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Coop.set_menu_open(player, true)
	_start()


func _build() -> void:
	var root := Control.new()
	root.theme = ServiceTheme.make_theme()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.1, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	_title_label = Label.new()
	_title_label.text = title
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", MAGIC_INK)
	box.add_child(_title_label)
	board = Control.new()
	board.custom_minimum_size = BOARD_SIZE
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.clip_contents = true
	board.draw.connect(_on_board_draw)
	board.gui_input.connect(_on_board_gui_input)
	box.add_child(board)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 18)
	box.add_child(_status_label)
	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(BOARD_SIZE.x, 0)
	_hint_label.add_theme_font_size_override("font_size", 14)
	box.add_child(_hint_label)


func input() -> PlayerInput:
	return player.input if is_instance_valid(player) else PlayerInput.solo()


func set_status(text: String, color: Color = ServiceTheme.INK) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)


func set_hint(text: String) -> void:
	_hint_label.text = text


func flash(color: Color) -> void:
	_flash = 1.0
	_flash_color = color


func is_done() -> bool:
	return _done


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 3.0)
	if _done:
		_result -= delta
		if _result <= 0.0:
			_close()
		board.queue_redraw()
		return
	_tick(delta)
	board.queue_redraw()


func _input(event: InputEvent) -> void:
	if _done or not Coop.accepts_event(player, event):
		return
	if input().is_event(event, &"ui_cancel"):
		cancelled = true
		finish(false, "Dibatalkan.")
		get_viewport().set_input_as_handled()
		return
	if _handle_input(event):
		get_viewport().set_input_as_handled()


func _on_board_gui_input(event: InputEvent) -> void:
	if _done or not Coop.accepts_event(player, event):
		return
	_board_pointer(event)


func _on_board_draw() -> void:
	board.draw_rect(Rect2(Vector2.ZERO, BOARD_SIZE), Color(0.1, 0.06, 0.16, 0.92))
	_draw_board(board)
	if _flash > 0.0:
		board.draw_rect(Rect2(Vector2.ZERO, BOARD_SIZE), Color(_flash_color, 0.25 * _flash))


## Selesaikan mini game; hasil ditampilkan sebentar lalu panel tertutup.
func finish(success: bool, text: String = "") -> void:
	if _done:
		return
	_done = true
	_result = RESULT_SECONDS if not cancelled else 0.2
	set_status(text if not text.is_empty() else ("Berhasil!" if success else "Gagal..."), GOOD if success else BAD)
	flash(GOOD if success else BAD)
	play(&"sparkle" if success else &"escape")
	finished.emit(success)


func _close() -> void:
	set_process(false)
	set_process_input(false)
	Coop.set_menu_open(player, false)
	queue_free()


func _exit_tree() -> void:
	if not _done or _result > 0.0:
		Coop.set_menu_open(player, false)


# ── Diisi turunan ───────────────────────────────────────────────────

func _start() -> void:
	pass


func _tick(_delta: float) -> void:
	pass


## Tombol/keyboard/gamepad. true = event dipakai.
func _handle_input(_event: InputEvent) -> bool:
	return false


## Mouse di dalam papan (posisi lokal papan).
func _board_pointer(_event: InputEvent) -> void:
	pass


func _draw_board(_canvas: Control) -> void:
	pass


# ── Alat bantu gambar ───────────────────────────────────────────────

static func draw_glow_circle(canvas: Control, center: Vector2, radius: float, color: Color) -> void:
	for i in 4:
		var k := 1.0 - i / 4.0
		canvas.draw_circle(center, radius * (1.0 + i * 0.35), Color(color, color.a * 0.18 * k))
	canvas.draw_circle(center, radius, color)


static func draw_icon(canvas: Control, item: ItemData, center: Vector2, size: float) -> void:
	if item == null or item.icon == null:
		canvas.draw_circle(center, size * 0.3, Color(0.8, 0.8, 0.9))
		return
	canvas.draw_texture_rect(item.icon, Rect2(center - Vector2.ONE * size * 0.5, Vector2.ONE * size), false)


## Efek suara/umpan balik Juice di posisi pemain.
func play(preset: StringName) -> void:
	if is_instance_valid(player):
		Juice.play(preset, player.global_position)
