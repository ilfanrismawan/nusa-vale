extends CanvasLayer

signal slot_selected(index: int)

@onready var slot_container: HBoxContainer = $"MarginContainer/HudBg/InnerMargin/HBoxContainer"

const HOTBAR_SLOTS := 8
const SLOT_SCENE = preload("res://scenes/ui/inventory_slot.tscn")

var _slots: Array[InventorySlotUI] = []
var active_index: int = 0
var _hovered_index: int = -1

func _ready() -> void:
	_build_slots()
	GameState.inventory_changed.connect(refresh)
	await get_tree().process_frame
	refresh()

func _build_slots() -> void:
	for child in slot_container.get_children():
		child.queue_free()
	_slots.clear()

	for i in HOTBAR_SLOTS:
		var slot_ui: InventorySlotUI = SLOT_SCENE.instantiate()
		slot_ui.slot_index = i
		slot_ui.slot_clicked.connect(_on_slot_clicked)
		slot_ui.slot_hovered.connect(_on_slot_hovered)
		slot_ui.slot_unhovered.connect(_on_slot_unhovered)
		
		# Allow hotbar slots to be slightly larger if desired, but default is fine
		slot_container.add_child(slot_ui)
		_slots.append(slot_ui)

	highlight_slot(0)

func refresh() -> void:
	var offset := GameState.hotbar_page * 8
	for i in HOTBAR_SLOTS:
		var global_idx = offset + i
		# Jika index melampaui bag_size yang aktif, anggap kosong
		var slot_data = null
		if global_idx < GameState.bag_size:
			slot_data = GameState.inventory[global_idx]
			
		if slot_data != null and slot_data.get("item") != null:
			_slots[i].set_item(slot_data["item"], slot_data["count"])
		else:
			_slots[i].clear()

func _select(index: int) -> void:
	active_index = index
	highlight_slot(index)
	slot_selected.emit(index)

func highlight_slot(index: int) -> void:
	active_index = index
	for i in _slots.size():
		_slots[i].set_selected(i == active_index)

func _on_slot_clicked(index: int, button: int) -> void:
	if button == MOUSE_BUTTON_LEFT:
		_select(index)

func _on_slot_hovered(index: int, _slot_ui: InventorySlotUI) -> void:
	_hovered_index = index

func _on_slot_unhovered(index: int, _slot_ui: InventorySlotUI) -> void:
	if _hovered_index == index:
		_hovered_index = -1

func get_active_item() -> ItemData:
	var global_idx = GameState.hotbar_page * 8 + active_index
	if global_idx < 0 or global_idx >= GameState.bag_size:
		return null
	var slot = GameState.inventory[global_idx]
	if slot == null:
		return null
	return slot["item"]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_hotbar") and not event.is_echo():
		GameState.cycle_hotbar()
		get_viewport().set_input_as_handled()
		return
		
	if event.is_action_pressed("sort_inventory") and not event.is_echo():
		GameState.sort_inventory()
		get_viewport().set_input_as_handled()
		return
		
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_select(wrapi(active_index - 1, 0, HOTBAR_SLOTS))
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_select(wrapi(active_index + 1, 0, HOTBAR_SLOTS))
			get_viewport().set_input_as_handled()
