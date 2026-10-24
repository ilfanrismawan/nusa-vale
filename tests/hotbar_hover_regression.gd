extends Node

func _ready() -> void:
	var slot := load("res://scenes/ui/inventory_slot.tscn").instantiate() as InventorySlotUI
	add_child(slot)
	var hotbar = load("res://scenes/ui/hotbar_ui.tscn").instantiate()
	slot.tooltip_scene = hotbar.tooltip_scene
	var card := slot._make_custom_tooltip("Nama item panjang\nDetail kemampuan yang tidak perlu menutupi layar") as Control
	add_child(card)
	assert(card.get_node("Margin/Content/Name").text == "Nama item panjang")
	assert(card.get_node("Margin/Content/Name").max_lines_visible == 2)
	assert(card.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	slot.tooltip_scene = null
	assert(slot._make_custom_tooltip("Item tas") == null)
	card.free()
	slot.free()
	add_child(hotbar)
	await get_tree().process_frame
	await get_tree().process_frame
	var input := PlayerInput.solo()
	input.push_context(self, InputLayout.FIELD)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = hotbar._slots[2].get_global_rect().get_center()
	assert(hotbar.contains_pointer(click.position))
	assert(not input.is_event(click, &"use_tool"), "Hotbar click must not use an item")
	input.note_event(click)
	assert(input._hotbar_mouse_buttons.has(MOUSE_BUTTON_LEFT))
	Input.parse_input_event(click.duplicate())
	Input.flush_buffered_events()
	assert(not input.pressed(&"use_tool"), "Polling must ignore a held hotbar click")
	assert(not input.just_pressed(&"use_tool"))
	hotbar._slots[2]._gui_input(click)
	assert(hotbar.active_index == 2, "Hotbar click must still select the slot")
	# Menyeret keluar tidak mengubah pemilik tekanan menjadi dunia.
	var drag := InputEventMouseMotion.new()
	drag.position = Vector2.ZERO
	input.note_event(drag)
	assert(input._hotbar_mouse_buttons.has(MOUSE_BUTTON_LEFT))
	assert(not input.pressed(&"use_tool"), "Dragging out must not activate the item")
	click.pressed = false
	Input.parse_input_event(click.duplicate())
	Input.flush_buffered_events()
	click.pressed = true
	click.position = Vector2.ZERO
	assert(input.is_event(click, &"use_tool"), "Fresh world click must still use the item")
	input.note_event(click)
	assert(not input._hotbar_mouse_buttons.has(MOUSE_BUTTON_LEFT))
	Input.parse_input_event(click.duplicate())
	Input.flush_buffered_events()
	assert(input.pressed(&"use_tool"), "Polling must allow a fresh world click")
	click.pressed = false
	Input.parse_input_event(click.duplicate())
	Input.flush_buffered_events()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_RIGHT
	click.position = hotbar._slots[2].get_global_rect().get_center()
	assert(not input.is_event(click, &"interact"), "Hotbar right-click must not interact")
	input.pop_context(self)
	hotbar.free()
	print("HOTBAR HOVER REGRESSION PASS")
	get_tree().quit()
