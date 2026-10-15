class_name NPCDialogUI
extends CanvasLayer

const ServiceTheme = preload("res://scripts/ui/farm_service_theme.gd")

## UI Kotak Dialog Interaktif untuk NPC Desa Nusa Vale.
## Menampilkan potret NPC, nama, peran/gelar, dan teks dialog bertahap.
## Mendukung navigasi tombol (E / Spasi / Enter / Klik) dan pembatalan (Esc).

signal finished

const FONT := preload("res://resources/ui/readable_font.tres")
const TEX_INVENTORY := preload("res://assets/farm_rpg/ui/inventory/inventory.png")
const TEX_BANNER := preload("res://assets/farm_rpg/ui/inventory/Banner.png")
const TEX_CLOSE := preload("res://resources/ui/btn_close_x.tres")
const TEX_CLOSE_PRESSED := preload("res://resources/ui/btn_close_x_pressed.tres")

const COLOR_NAME := Color(0.36, 0.2, 0.15)
const COLOR_ROLE := Color(0.55, 0.35, 0.22)
const COLOR_TEXT := Color(0.2, 0.15, 0.12)
const COLOR_HINT := Color(0.45, 0.42, 0.38)

var player: Player
var npc_name: String = "Warga Desa"
var role_title: String = ""
var portrait_texture: Texture2D
var lines: PackedStringArray = []

var _current_line_idx: int = 0
var _text_label: Label
var _name_label: Label
var _role_label: Label
var _page_hint_label: Label
var _portrait_rect: TextureRect
var _next_button: Button
var _closed := false
var _menu_open := false

func _ready() -> void:
	layer = ServiceTheme.LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_show_current_line()
	if not _closed and is_instance_valid(player):
		Coop.set_menu_open(player, true)
		_menu_open = true

func _input(event: InputEvent) -> void:
	if _closed:
		return
	var input := player.input if is_instance_valid(player) else PlayerInput.solo()
	
	if input.is_event(event, &"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
		return

	if input.is_event(event, &"interact") or input.is_event(event, &"ui_accept"):
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

	if _text_label != null:
		_text_label.text = lines[_current_line_idx]
	if _next_button != null:
		_next_button.text = "Selesai" if _current_line_idx == lines.size() - 1 else "Lanjut ›"

	if _page_hint_label != null:
		if lines.size() > 1:
			_page_hint_label.text = "[E / Spasi] Lanjut (%d/%d)" % [_current_line_idx + 1, lines.size()]
		else:
			_page_hint_label.text = "[E / Spasi / Esc] Selesai"

func _close() -> void:
	if _closed:
		return
	_closed = true
	set_process_input(false)
	hide()
	if _menu_open and is_instance_valid(player):
		Coop.set_menu_open(player, false)
	_menu_open = false
	finished.emit()
	queue_free()

func _exit_tree() -> void:
	if _menu_open and is_instance_valid(player):
		Coop.set_menu_open(player, false)
	_menu_open = false

func _build_ui() -> void:
	var ui_theme := ServiceTheme.make_theme()

	var root_control := Control.new()
	root_control.theme = ui_theme
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	# Dialog box container diletakkan di bagian bawah layar
	var margin_container := MarginContainer.new()
	root_control.add_child(margin_container)
	margin_container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	margin_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	margin_container.offset_bottom = -18
	margin_container.add_theme_constant_override("margin_left", 36)
	margin_container.add_theme_constant_override("margin_right", 36)
	margin_container.add_theme_constant_override("margin_bottom", 18)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(minf(520, get_viewport().get_visible_rect().size.x - 72), 120)
	panel.add_theme_stylebox_override("panel", ServiceTheme.dialogue())
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	margin_container.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	panel.add_child(hbox)

	# Kolom Kiri: Portrait Frame
	var portrait_panel := PanelContainer.new()
	portrait_panel.custom_minimum_size = Vector2(80, 80)
	portrait_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait_panel.add_theme_stylebox_override("panel", _style(TEX_INVENTORY, Rect2(7, 9, 18, 18), 4, 4))
	hbox.add_child(portrait_panel)

	_portrait_rect = TextureRect.new()
	_portrait_rect.custom_minimum_size = Vector2(72, 72)
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if portrait_texture != null:
		_portrait_rect.texture = ServiceTheme.portrait(portrait_texture)
	portrait_panel.add_child(_portrait_rect)

	# Kolom Kanan: Nama, Title, Dialog Text, Navigasi
	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(content_vbox)

	# Header Bar (Nama + Tombol Tutup)
	var header_hbox := HBoxContainer.new()
	header_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_child(header_hbox)

	var name_vbox := VBoxContainer.new()
	name_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_vbox.add_theme_constant_override("separation", 8)
	header_hbox.add_child(name_vbox)

	_name_label = Label.new()
	_name_label.text = npc_name
	_name_label.add_theme_color_override("font_color", COLOR_NAME)
	_name_label.add_theme_font_size_override("font_size", 18)
	name_vbox.add_child(_name_label)

	if not role_title.is_empty():
		_role_label = Label.new()
		_role_label.text = role_title
		_role_label.add_theme_color_override("font_color", COLOR_ROLE)
		_role_label.add_theme_font_size_override("font_size", 14)
		name_vbox.add_child(_role_label)

	var close_btn := TextureButton.new()
	close_btn.texture_normal = TEX_CLOSE
	close_btn.texture_pressed = TEX_CLOSE_PRESSED
	close_btn.pressed.connect(_close)
	header_hbox.add_child(close_btn)

	# Text Dialog Body
	var body_panel := PanelContainer.new()
	body_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_panel.add_theme_stylebox_override("panel", ServiceTheme.texture_style(ServiceTheme.DIALOG, Rect2(0, 48, 48, 48), 3, 8))
	content_vbox.add_child(body_panel)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.add_theme_color_override("font_color", COLOR_TEXT)
	_text_label.add_theme_font_size_override("font_size", 16)
	body_panel.add_child(_text_label)

	# Footer / Hint Lanjut
	var footer_hbox := HBoxContainer.new()
	footer_hbox.alignment = BoxContainer.ALIGNMENT_END
	content_vbox.add_child(footer_hbox)

	_page_hint_label = Label.new()
	_page_hint_label.add_theme_color_override("font_color", COLOR_HINT)
	_page_hint_label.add_theme_font_size_override("font_size", 13)
	footer_hbox.add_child(_page_hint_label)

	var next_btn := Button.new()
	_next_button = next_btn
	next_btn.text = " Lanjut > "
	next_btn.focus_mode = Control.FOCUS_NONE
	next_btn.pressed.connect(_advance_dialog)
	footer_hbox.add_child(next_btn)

func _style(tex: Texture2D, region: Rect2, tex_margin: int, content_margin: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.region_rect = region
	sb.set_texture_margin_all(tex_margin)
	sb.set_content_margin_all(content_margin)
	return sb
