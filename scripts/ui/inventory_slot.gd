extends TextureRect
class_name InventorySlotUI

signal slot_clicked(slot_index:int, button_index: int)

## Preloaded textures for slot states
const TEX_NORMAL := preload("res://resources/ui/slot_normal.tres")
const TEX_SELECTED := preload("res://resources/ui/slot_selected.tres")

@onready var icon: TextureRect = $Icon
@onready var count_label: Label = $CountLabel

var slot_index: int = -1
var _is_selected := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture = TEX_NORMAL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_KEEP_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	custom_minimum_size = Vector2(20, 20)

func set_item(item_data: ItemData, amount: int) -> void:
	if item_data and amount > 0:
		icon.texture = item_data.icon
		icon.show()
		count_label.text = str(amount) if amount > 1 else ""
		count_label.visible = amount > 1
	else:
		clear()

func clear() -> void:
	icon.texture = null
	icon.hide()
	count_label.text = ""
	count_label.hide()

func set_selected(selected: bool) -> void:
	_is_selected = selected
	texture = TEX_SELECTED if selected else TEX_NORMAL

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		slot_clicked.emit(slot_index, event.button_index)
