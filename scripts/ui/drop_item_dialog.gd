class_name DropItemDialog
extends PanelContainer
## Kotak "Buang Item" / "Jual Item" di tas: pilih 1, jumlah tertentu, atau semua.
## Dibangun lewat kode (tidak ada .tscn). Dipakai ui_inventory.gd (buang, dan jual di Shipping Bin).

signal confirmed(amount: int)
signal cancelled

const FONT := preload("res://resources/ui/readable_font.tres")
const HUD = preload("res://scenes/ui/hud.gd")
const COLOR_TEXT := Color(0.95, 0.85, 0.55, 1.0)
const COLOR_DIM := Color(0.85, 0.75, 0.6, 1.0)
## Shift + tombol -/+ (atau scroll) mengubah jumlah sebanyak ini.
const BIG_STEP := 10

var amount: int = 1
var max_amount: int = 1
## Kata kerja di judul dan tombol ("Buang" / "Jual").
var verb: String = "Buang"
## Harga per item; > 0 menampilkan total uang (mode jual).
var unit_price: int = 0

var _icon: TextureRect
var _title: Label
var _amount_label: Label
var _btn_minus: Button
var _btn_plus: Button
var _btn_drop: Button
var _price_label: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 70
	custom_minimum_size = Vector2(176, 0)
	add_theme_stylebox_override("panel", _panel_style())

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	vbox.add_child(head)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(16, 16)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	head.add_child(_icon)
	_title = _label("", COLOR_TEXT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(_title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	vbox.add_child(row)
	_btn_minus = _button("-", func(): _step(-1))
	row.add_child(_btn_minus)
	_amount_label = _label("1", COLOR_TEXT)
	_amount_label.custom_minimum_size = Vector2(48, 0)
	_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_amount_label)
	_btn_plus = _button("+", func(): _step(1))
	row.add_child(_btn_plus)

	_price_label = _label("", COLOR_TEXT)
	_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_price_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 4)
	vbox.add_child(buttons)
	buttons.add_child(_button("1", func(): confirmed.emit(1)))
	_btn_drop = _button("Buang", func(): confirmed.emit(amount))
	buttons.add_child(_btn_drop)
	buttons.add_child(_button("Semua", func(): confirmed.emit(max_amount)))
	buttons.add_child(_button("Batal", func(): cancelled.emit()))

	var hint := _label("Scroll / Shift = ubah cepat", COLOR_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)


## Buka untuk satu tumpukan item. Jumlah awal 1.
## p_unit_price > 0 menampilkan total harga (dipakai saat menjual).
func open_for(item: ItemData, count: int, p_verb: String = "Buang", p_unit_price: int = 0) -> void:
	max_amount = maxi(1, count)
	amount = 1
	verb = p_verb
	unit_price = p_unit_price
	_icon.texture = item.icon
	var item_name: String = item.display_name if item.display_name != "" else item.item_id
	_title.text = "%s %s?" % [verb, item_name]
	_refresh()
	show()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_step(1)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_step(-1)
			accept_event()


func _step(direction: int) -> void:
	var step := BIG_STEP if Input.is_key_pressed(KEY_SHIFT) else 1
	amount = clampi(amount + direction * step, 1, max_amount)
	_refresh()


func _refresh() -> void:
	_amount_label.text = "%d / %d" % [amount, max_amount]
	_btn_minus.disabled = amount <= 1
	_btn_plus.disabled = amount >= max_amount
	_btn_drop.text = "%s %d" % [verb, amount]
	_price_label.visible = unit_price > 0
	_price_label.text = "= %s G" % HUD.format_money(unit_price * amount)


func _label(text: String, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _button(text: String, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	btn.custom_minimum_size = Vector2(18, 16)
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", COLOR_TEXT)
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.45, 0.35, 1.0))
	btn.add_theme_stylebox_override("normal", _button_style(Color(0.35, 0.2, 0.12, 0.9), Color(0.6, 0.4, 0.25)))
	btn.add_theme_stylebox_override("hover", _button_style(Color(0.5, 0.3, 0.18, 0.95), Color(0.9, 0.7, 0.3)))
	btn.add_theme_stylebox_override("pressed", _button_style(Color(0.25, 0.14, 0.08, 1.0), Color(0.9, 0.7, 0.3)))
	btn.add_theme_stylebox_override("disabled", _button_style(Color(0.3, 0.2, 0.14, 0.6), Color(0.45, 0.32, 0.22)))
	btn.pressed.connect(on_press)
	return btn


func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 0
	sb.content_margin_bottom = 1
	return sb


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.11, 0.06, 0.96)
	sb.border_color = Color(0.9, 0.7, 0.3, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	return sb
