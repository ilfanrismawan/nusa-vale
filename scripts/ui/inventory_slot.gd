extends TextureRect
class_name InventorySlotUI

signal slot_clicked(slot_index: int, button_index: int)

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

## ── Drag and Drop Support ──────────────────────────────────────────────────
func _get_drag_data(_at_position: Vector2) -> Variant:
	if slot_index < 0 or slot_index >= GameState.inventory.size():
		return null
	var slot_data = GameState.inventory[slot_index]
	if slot_data == null or slot_data.get("item") == null:
		return null

	var item: ItemData = slot_data["item"]
	var count: int = slot_data.get("count", 1)

	# Buat preview item mengambang di bawah kursor
	var preview_root := Control.new()
	preview_root.z_index = 100

	var preview_icon := TextureRect.new()
	preview_icon.texture = item.icon
	preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_icon.size = Vector2(24, 24)
	preview_icon.position = Vector2(-12, -12) # Terpusat di kursor
	preview_icon.modulate = Color(1.1, 1.1, 1.1, 0.9)
	preview_root.add_child(preview_icon)

	if count > 1:
		var lbl := Label.new()
		lbl.text = str(count)
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.position = Vector2(0, 0)
		preview_root.add_child(lbl)

	set_drag_preview(preview_root)

	return {
		"type": "inventory_slot",
		"from_index": slot_index,
		"item": item,
		"count": count
	}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("type") == "inventory_slot"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	var from_idx: int = data.get("from_index", -1)
	var to_idx: int = slot_index
	if from_idx != -1 and from_idx != to_idx:
		GameState.swap_slots(from_idx, to_idx)
