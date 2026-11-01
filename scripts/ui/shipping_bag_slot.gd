class_name ShippingBagSlot
extends Button
## Satu slot tas di buku Shipping Bin. Visual di scenes/ui/shipping_bag_slot.tscn.

## Klik kanan: titip langsung 1 buah dari slot ini.
signal right_clicked

## Warna ikon barang yang tidak bisa dijual (alat, Biji Daya, harga 0).
@export var unsellable_tint := Color(1, 1, 1, 0.35)

## Indeks slot di tas pemain; -1 = slot kosong / di luar halaman.
var bag_index := -1

@onready var _icon: TextureRect = $Icon
@onready var _count: Label = $Count
@onready var _selected: Control = $Selected

func show_item(index: int, item: ItemData, count: int, sellable: bool) -> void:
	bag_index = index
	_icon.texture = item.icon if item != null else null
	_icon.modulate = Color.WHITE if sellable else unsellable_tint
	_count.text = str(count) if count > 1 else ""
	tooltip_text = "%s x%d" % [item.display_name, count] if item != null else ""

func clear_item(index: int = -1) -> void:
	bag_index = index
	_icon.texture = null
	_count.text = ""
	tooltip_text = ""
	set_selected(false)

func set_selected(on: bool) -> void:
	_selected.visible = on

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		right_clicked.emit()
