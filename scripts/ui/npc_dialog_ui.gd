class_name NPCDialogUI
extends CanvasLayer

signal finished

@export var design_size := Vector2(1280, 720)
@export var next_text := "Lanjut ›"
@export var finish_text := "Selesai"
@export var controls_hint := "E / Enter · Lanjut    Esc · Tutup"

var player: Player
var npc_name := "Warga Desa"
var role_title := ""
var portrait_texture: Texture2D
var lines: PackedStringArray = []
var _current_line_idx := 0
var _closed := false
var _menu_open := false

@onready var _text_label: Label = %Text
@onready var _name_label: Label = %Speaker
@onready var _role_label: Label = %Role
@onready var _page_hint_label: Label = %Page
@onready var _portrait_rect: TextureRect = %Portrait
@onready var _next_button: Button = %Next

func _ready() -> void:
	layer = FarmServiceTheme.LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_name_label.text = npc_name
	_role_label.text = role_title
	_role_label.visible = not role_title.is_empty()
	_portrait_rect.texture = FarmServiceTheme.portrait(portrait_texture)
	%Hint.text = controls_hint
	_next_button.pressed.connect(_advance_dialog)
	%Close.pressed.connect(_close)
	get_viewport().size_changed.connect(_resize)
	_resize()
	_show_current_line()
	if not _closed and is_instance_valid(player):
		Coop.set_menu_open(player, true)
		_menu_open = true

func _resize() -> void:
	var view := get_viewport().get_visible_rect().size
	var fit := minf(view.x / design_size.x, view.y / design_size.y)
	$Design.scale = Vector2.ONE * fit
	$Design.position = (view - design_size * fit) * 0.5

func _input(event: InputEvent) -> void:
	if _closed:
		return
	var input := player.input if is_instance_valid(player) else PlayerInput.solo()
	if input.is_event(event, &"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
	elif input.is_event(event, &"interact") or input.is_event(event, &"ui_accept"):
		if event.is_pressed() and not event.is_echo():
			get_viewport().set_input_as_handled()
			_advance_dialog()

func _advance_dialog() -> void:
	if _closed:
		return
	_current_line_idx += 1
	if _current_line_idx >= lines.size():
		_close()
	else:
		_show_current_line()

func _show_current_line() -> void:
	if lines.is_empty():
		_close()
		return
	_text_label.text = lines[_current_line_idx]
	_next_button.text = finish_text if _current_line_idx == lines.size() - 1 else next_text
	_page_hint_label.text = "%d / %d" % [_current_line_idx + 1, lines.size()]
	%TextScroll.scroll_vertical = 0

func _close() -> void:
	if _closed:
		return
	_closed = true
	set_process_input(false)
	hide()
	_release_menu()
	finished.emit()
	queue_free()

func _release_menu() -> void:
	if _menu_open and is_instance_valid(player):
		Coop.set_menu_open(player, false)
	_menu_open = false

func _exit_tree() -> void:
	_release_menu()
	if not _closed:
		_closed = true
		finished.emit()
