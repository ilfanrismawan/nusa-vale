extends CanvasLayer

signal slot_selected(index: int)

@onready var slot_container: HBoxContainer = $"MarginContainer/HBoxContainer"

const HOTBAR_SLOTS := 8
const SLOT_SIZE := 32

var _frames: Array[Panel] = []
var _icons: Array[TextureRect] = []
var _counts: Array[Label] = []
var active_index: int = 0
var _hovered_index: int = -1
var _tooltip: PanelContainer
var _tooltip_label: Label


## Subclass Panel untuk mendukung Drag and Drop di setiap slot Hotbar
class HotbarSlotPanel extends Panel:
	var slot_index: int = 0

	func _get_drag_data(_at_position: Vector2) -> Variant:
		var slot_data = GameState.inventory[slot_index] if slot_index < GameState.inventory.size() else null
		if slot_data == null or slot_data.get("item") == null:
			return null

		var item: ItemData = slot_data["item"]
		var count: int = slot_data.get("count", 1)

		var preview_root := Control.new()
		preview_root.z_index = 100

		var preview_icon := TextureRect.new()
		preview_icon.texture = item.icon
		preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		preview_icon.size = Vector2(28, 28)
		preview_icon.position = Vector2(-14, -14)
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


func _ready() -> void:
	_build_slots()
	GameState.inventory_changed.connect(refresh)
	# Tunggu satu frame agar semua _ready() selesai, lalu refresh
	await get_tree().process_frame
	refresh()


func _build_slots() -> void:
	for child in slot_container.get_children():
		child.queue_free()
	_frames.clear()
	_icons.clear()
	_counts.clear()

	for i in HOTBAR_SLOTS:
		var frame := HotbarSlotPanel.new()
		frame.slot_index = i
		frame.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.15, 0.85)
		style.set_border_width_all(2)
		style.border_color = Color(0.3, 0.3, 0.35)
		style.set_corner_radius_all(4)
		frame.add_theme_stylebox_override("panel", style)
		frame.mouse_filter = Control.MOUSE_FILTER_STOP

		var slot_idx := i
		frame.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_LEFT:
					_select(slot_idx)
		)

		frame.mouse_entered.connect(func(): _on_slot_hovered(slot_idx))
		frame.mouse_exited.connect(func(): _on_slot_unhovered(slot_idx))

		var tex := TextureRect.new()
		tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.add_child(tex)

		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(lbl)

		slot_container.add_child(frame)
		_frames.append(frame)
		_icons.append(tex)
		_counts.append(lbl)

	_create_tooltip()
	highlight_slot(0)


func refresh() -> void:
	for i in HOTBAR_SLOTS:
		var slot_data = GameState.inventory[i] if i < GameState.inventory.size() else null
		if slot_data != null and slot_data.get("item") != null:
			_icons[i].texture = slot_data["item"].icon
			_icons[i].show()
			var cnt: int = slot_data["count"]
			_counts[i].text = str(cnt) if cnt > 1 else ""
			_counts[i].visible = cnt > 1
		else:
			_icons[i].texture = null
			_icons[i].hide()
			_counts[i].text = ""
			_counts[i].hide()


func _select(index: int) -> void:
	active_index = index
	highlight_slot(index)
	slot_selected.emit(index)


func highlight_slot(index: int) -> void:
	active_index = index
	_update_slot_borders()


func _update_slot_borders() -> void:
	for i in _frames.size():
		var style: StyleBoxFlat = _frames[i].get_theme_stylebox("panel")
		if style == null:
			continue
		if i == active_index:
			style.border_color = Color(1.0, 0.85, 0.2)
			style.set_border_width_all(3)
		elif i == _hovered_index:
			style.border_color = Color(0.9, 0.75, 0.4)
			style.set_border_width_all(2)
		else:
			style.border_color = Color(0.3, 0.3, 0.35)
			style.set_border_width_all(2)


func _create_tooltip() -> void:
	if _tooltip != null:
		return
	_tooltip = PanelContainer.new()
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.z_index = 50
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.06, 0.92)
	style.set_border_width_all(2)
	style.border_color = Color(0.85, 0.65, 0.25)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	_tooltip.add_theme_stylebox_override("panel", style)

	_tooltip_label = Label.new()
	_tooltip_label.add_theme_font_override("font", preload("res://assets/fonts/m5x7.ttf"))
	_tooltip_label.add_theme_font_size_override("font_size", 14)
	_tooltip_label.modulate = Color(1.0, 0.95, 0.75)
	_tooltip.add_child(_tooltip_label)
	_tooltip.hide()
	add_child(_tooltip)


func _on_slot_hovered(index: int) -> void:
	_hovered_index = index
	_update_slot_borders()

	var slot_data = GameState.inventory[index] if index < GameState.inventory.size() else null
	if slot_data != null and slot_data.get("item") != null:
		var item: ItemData = slot_data["item"]
		var count: int = slot_data.get("count", 1)
		var text := item.display_name if item.display_name != "" else item.item_id
		if count > 1:
			text += " x%d" % count
		text += " (%d)" % (index + 1)
		_tooltip_label.text = text

		if is_instance_valid(_frames[index]):
			var frame_pos = _frames[index].global_position
			_tooltip.global_position = Vector2(frame_pos.x - 10, frame_pos.y - 28)
			_tooltip.show()
	else:
		_tooltip.hide()


func _on_slot_unhovered(index: int) -> void:
	if _hovered_index == index:
		_hovered_index = -1
		_update_slot_borders()
		if is_instance_valid(_tooltip):
			_tooltip.hide()


func get_active_item() -> ItemData:
	if active_index < 0 or active_index >= GameState.inventory.size():
		return null
	var slot = GameState.inventory[active_index]
	if slot == null:
		return null
	return slot["item"]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_select(wrapi(active_index - 1, 0, HOTBAR_SLOTS))
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_select(wrapi(active_index + 1, 0, HOTBAR_SLOTS))
			get_viewport().set_input_as_handled()
