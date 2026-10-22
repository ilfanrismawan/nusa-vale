class_name NPCDialogUI
extends CanvasLayer

signal finished

@export var design_size := Vector2(1280, 720)
@export var next_text := "Lanjut ›"
@export var finish_text := "Selesai"
## Kosong = dibuat dari tombol pemain (keyboard atau gamepad, ikut tombol yang diatur ulang).
@export var controls_hint := ""

var player: Player
var npc_name := "Warga Desa"
var social_npc_id := ""
var _gift_button: Button
var _gift_slot := -1
var role_title := ""
var portrait_texture: Texture2D
var portrait_expressions: Dictionary = {}
var line_expressions: PackedStringArray = []
var default_expression: String = "neutral"
var lines: PackedStringArray = []
var _current_line_idx := 0
var _closed := false
var _menu_open := false
var completed := false
var allow_gifts := true
var award_friendship := true

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
	%Hint.text = controls_hint if not controls_hint.is_empty() else _default_hint()
	if is_instance_valid(player):
		# Konteks Dialog: tombol lompat/serang tidak aktif selama bicara.
		player.input.push_context(self, InputLayout.DIALOGUE)
	_next_button.pressed.connect(_advance_dialog)
	%Close.pressed.connect(_close)
	if is_instance_valid(player) and NPCSocialService.known(social_npc_id):
		if award_friendship:
			NPCSocialService.talk(player.data, social_npc_id)
		if allow_gifts:
			_gift_slot = player.data.hotbar_page * 8 + player.tool_controller.current_index
			_gift_button = Button.new()
			_gift_button.position = Vector2(160, 180)
			_gift_button.size = Vector2(535, 40)
			_gift_button.focus_mode = Control.FOCUS_NONE
			_gift_button.pressed.connect(_give_gift)
			$Design/Dialogue.add_child(_gift_button)
			_update_social()
	get_viewport().size_changed.connect(_resize)
	_resize()
	_show_current_line()
	if not _closed and is_instance_valid(player):
		Coop.set_menu_open(player, true)
		_menu_open = true

func _default_hint() -> String:
	var ctx := InputLayout.DIALOGUE
	return "%s · Lanjut    %s · Tutup" % [InputPrompt.key_text(&"interact", player, ctx, 1), InputPrompt.key_text(&"ui_cancel", player, ctx)]

func _resize() -> void:
	var view := get_viewport().get_visible_rect().size
	var fit := minf(view.x / design_size.x, view.y / design_size.y)
	$Design.scale = Vector2.ONE * fit
	$Design.position = (view - design_size * fit) * 0.5

func _input(event: InputEvent) -> void:
	if _closed:
		return
	var input := player.input if is_instance_valid(player) else PlayerInput.solo()
	if _gift_button != null and input.is_event(event, &"crafting_menu") and event.is_pressed() and not event.is_echo():
		get_viewport().set_input_as_handled()
		_give_gift()
		return
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
		completed = true
		_close()
	else:
		_show_current_line()

func _show_current_line() -> void:
	if lines.is_empty():
		_close()
		return
	_text_label.text = lines[_current_line_idx]
	var expression := default_expression
	if _current_line_idx < line_expressions.size():
		expression = line_expressions[_current_line_idx]
	set_expression(expression)
	_next_button.text = finish_text if _current_line_idx == lines.size() - 1 else next_text
	_page_hint_label.text = "%d / %d" % [_current_line_idx + 1, lines.size()]
	%TextScroll.scroll_vertical = 0

func set_expression(expression: String) -> void:
	var texture: Texture2D = portrait_expressions.get(expression) as Texture2D
	if texture == null:
		texture = portrait_expressions.get("neutral") as Texture2D
	if texture == null:
		texture = portrait_texture
	_portrait_rect.texture = FarmServiceTheme.portrait(texture)

func _update_social() -> void:
	_role_label.text = (role_title + " · " if not role_title.is_empty() else "") + NPCSocialService.summary(player.data, social_npc_id)
	_role_label.show()
	var slot: Variant = player.data.inventory[_gift_slot] if _gift_slot >= 0 and _gift_slot < player.data.bag_size else null
	_gift_button.disabled = slot == null
	_gift_button.text = "Hadiah 1× %s · Klik / %s" % [slot.item.display_name, InputPrompt.key_text(&"crafting_menu", player, InputLayout.DIALOGUE)] if slot != null else "Pilih barang hadiah di hotbar sebelum bicara"

func _give_gift() -> void:
	if _closed or _gift_button == null or not is_instance_valid(player):
		return
	var result := NPCSocialService.give(player.data, social_npc_id, _gift_slot)
	_update_social()
	_text_label.text = result.message
	if result.ok:
		set_expression(str(result.get("expression", "happy" if int(result.points) > 0 else "annoyed")))

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
	if is_instance_valid(player):
		player.input.pop_context(self)
	if _menu_open and is_instance_valid(player):
		Coop.set_menu_open(player, false)
	_menu_open = false

func _exit_tree() -> void:
	_release_menu()
	if not _closed:
		_closed = true
		finished.emit()
