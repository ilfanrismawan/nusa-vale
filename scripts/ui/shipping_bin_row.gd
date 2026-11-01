class_name ShippingBinRow
extends PanelContainer
## Satu baris "Kotak Kiriman" (barang yang sudah dititip hari ini).
## Visual di scenes/ui/shipping_bin_row.tscn.

signal take_back_pressed(index: int)

const HUD = preload("res://scenes/ui/hud.gd")

## Indeks baris di GameState.shipping.pending.
var index := -1

@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name
@onready var _qty: Label = %Qty
@onready var _subtotal: Label = %Subtotal
@onready var _take_back: Button = %TakeBack
@onready var _locked: Label = %Locked

func _ready() -> void:
	_take_back.pressed.connect(func(): take_back_pressed.emit(index))

## row = {id, name, price, count, ...}; striped = latar selang-seling.
func setup(row: Dictionary, row_index: int, item: ItemData, striped: bool, can_take_back: bool) -> void:
	index = row_index
	theme_type_variation = &"ShipRowAlt" if striped else &"ShipRow"
	_icon.texture = item.icon if item != null else null
	_name.text = str(row.get("name", row.get("id", "")))
	_qty.text = "x%d" % int(row.count)
	_subtotal.text = "%s G" % HUD.format_money(int(row.price) * int(row.count))
	_take_back.visible = can_take_back
	_locked.visible = not can_take_back

func take_back_button() -> Button:
	return _take_back
