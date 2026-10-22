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
	hotbar.free()
	print("HOTBAR HOVER REGRESSION PASS")
	get_tree().quit()
