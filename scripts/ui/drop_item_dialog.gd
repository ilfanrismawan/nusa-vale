class_name DropItemDialog
extends PanelContainer
## Kotak "Buang Item" / "Jual Item" di tas: pilih 1, jumlah tertentu, atau semua.
## Visual berada di scenes/ui/drop_item_dialog.tscn.

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


func _ready() -> void:
	_icon = %Icon
	_title = %Title
	_amount_label = %AmountLabel
	_btn_minus = %BtnMinus
	_btn_plus = %BtnPlus
	_btn_drop = %BtnDrop
	_price_label = %PriceLabel
	_btn_minus.pressed.connect(_step.bind(-1))
	_btn_plus.pressed.connect(_step.bind(1))
	_btn_drop.pressed.connect(func(): confirmed.emit(amount))
	%One.pressed.connect(func(): confirmed.emit(1))
	%All.pressed.connect(func(): confirmed.emit(max_amount))
	%Cancel.pressed.connect(func(): cancelled.emit())


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
