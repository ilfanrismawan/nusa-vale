extends CanvasLayer

## ── Node references ──────────────────────────────────────────────
@onready var dimmer: ColorRect = $Dimmer
@onready var book_bg: TextureRect = $Dimmer/BookBg
@onready var slot_grid: GridContainer = $Dimmer/BookBg/PageMargin/PageContent/SlotGrid
@onready var title_label: Label = $Dimmer/BookBg/PageMargin/PageContent/TitleBar/TitleLabel
@onready var capacity_label: Label = $Dimmer/BookBg/PageMargin/PageContent/Footer/CapacityLabel

## ── Config ───────────────────────────────────────────────────────
@export var slot_scene: PackedScene = preload("res://scenes/ui/inventory_slot.tscn")

const GRID_COLUMNS := 4
var _slots: Array[InventorySlotUI] = []

## ── Lifecycle ────────────────────────────────────────────────────
func _ready() -> void:
	hide()
	_create_slots()
	if GameState:
		GameState.inventory_changed.connect(refresh_inventory)
	refresh_inventory()

## ── Input ────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel") and not event.is_echo():
		_close()
		get_viewport().set_input_as_handled()

## ── Toggle ───────────────────────────────────────────────────────
func toggle() -> void:
	if visible:
		_close()
	else:
		_open()

func _open() -> void:
	refresh_inventory()
	show()

func _close() -> void:
	hide()

## ── Slot Management ──────────────────────────────────────────────
func _create_slots() -> void:
	if not slot_grid or not slot_scene:
		return
	for child in slot_grid.get_children():
		child.queue_free()
	_slots.clear()

	for i in range(GameState.INVENTORY_SIZE):
		var slot: InventorySlotUI = slot_scene.instantiate()
		slot.slot_index = i
		
		slot.slot_clicked.connect(_on_slot_clicked)
		
		slot_grid.add_child(slot)
		_slots.append(slot)

func _on_slot_clicked(index: int, button: int) -> void:
	print("Slot diklik: ", index, " Tombol: ", button)
	
func refresh_inventory() -> void:
	if not is_instance_valid(slot_grid):
		return

	var used_count := 0
	for i in range(mini(_slots.size(), GameState.INVENTORY_SIZE)):
		var slot_data = GameState.inventory[i]
		if slot_data != null:
			_slots[i].set_item(slot_data["item"], slot_data["count"])
			used_count += 1
		else:
			_slots[i].clear()

	# Update capacity label
	if is_instance_valid(capacity_label):
		capacity_label.text = "%d/%d" % [used_count, GameState.INVENTORY_SIZE]
