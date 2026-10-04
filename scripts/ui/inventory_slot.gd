extends TextureRect
class_name InventorySlotUI

signal slot_clicked(slot_index: int, button_index: int)
signal slot_hovered(slot_index: int, slot_ui: InventorySlotUI)
signal slot_unhovered(slot_index: int, slot_ui: InventorySlotUI)

## Preloaded textures for slot states
const TEX_NORMAL := preload("res://resources/ui/slot_normal.tres")
const TEX_SELECTED := preload("res://resources/ui/slot_selected.tres")

@onready var icon: TextureRect = $Icon
@onready var count_label: Label = $CountLabel
@onready var hover_border: Panel = %HoverBorder

var slot_index: int = -1
var _is_selected := false
var _is_hovered := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture = TEX_NORMAL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	custom_minimum_size = Vector2(36, 36)
	pivot_offset = Vector2(18, 18)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	_update_visuals()


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
	_update_visuals()


func _on_mouse_entered() -> void:
	_is_hovered = true
	_update_visuals()
	# Efek zoom pop lembut saat kursor melintas
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "scale", Vector2(1.08, 1.08), 0.08)

	slot_hovered.emit(slot_index, self)


func _on_mouse_exited() -> void:
	_is_hovered = false
	_update_visuals()
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)

	slot_unhovered.emit(slot_index, self)


func _update_visuals() -> void:
	if _is_selected:
		texture = TEX_SELECTED
		if is_instance_valid(hover_border):
			hover_border.show()
	elif _is_hovered:
		texture = TEX_NORMAL
		if is_instance_valid(hover_border):
			hover_border.show()
	else:
		texture = TEX_NORMAL
		if is_instance_valid(hover_border):
			hover_border.hide()


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
	preview_icon.size = Vector2(32, 32)
	preview_icon.position = Vector2(-16, -16) # Terpusat di kursor
	preview_icon.modulate = Color(1.15, 1.15, 1.15, 0.95)
	preview_root.add_child(preview_icon)

	if count > 1:
		var lbl := Label.new()
		lbl.text = str(count)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.position = Vector2(4, 2)
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
