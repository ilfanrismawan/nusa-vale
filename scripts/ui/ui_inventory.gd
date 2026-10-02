extends CanvasLayer

## ── Node references ──────────────────────────────────────────────
@onready var dimmer: ColorRect = %Dimmer
@onready var book_bg: TextureRect = %BookBg
@onready var slot_grid: GridContainer = %SlotGrid
@onready var title_label: Label = %TitleLabel
@onready var capacity_label: Label = %CapacityLabel
@onready var detail_icon: TextureRect = %DetailIcon
@onready var detail_title: Label = %DetailTitle
@onready var detail_desc: Label = %DetailDesc

@onready var category_tabs: HBoxContainer = %CategoryTabs

## ── Config ───────────────────────────────────────────────────────
@export var slot_scene: PackedScene = preload("res://scenes/ui/inventory_slot.tscn")

const GRID_COLUMNS := 4
var _slots: Array[InventorySlotUI] = []

var current_category: ItemData.Category = ItemData.Category.ALL

## ── Lifecycle ────────────────────────────────────────────────────
func _ready() -> void:
	hide()
	_setup_category_tabs()
	_create_slots()
	if GameState:
		GameState.inventory_changed.connect(refresh_inventory)
	refresh_inventory()
	_clear_item_detail()

## ── Menghubungkan Tombol Tab
func _setup_category_tabs() -> void:
	if not category_tabs:
		return
		
	if category_tabs.has_node("BtnAll"):
		category_tabs.get_node("BtnAll").pressed.connect(func(): _set_category(ItemData.Category.ALL))
	if category_tabs.has_node("BtnSeed"):
		category_tabs.get_node("BtnSeed").pressed.connect(func(): _set_category(ItemData.Category.SEED))
	if category_tabs.has_node("BtnCrop"):
		category_tabs.get_node("BtnCrop").pressed.connect(func(): _set_category(ItemData.Category.CROP))
	if category_tabs.has_node("BtnTool"):
		category_tabs.get_node("BtnTool").pressed.connect(func(): _set_category(ItemData.Category.TOOL))

func _set_category(cat: ItemData.Category) -> void:
	current_category = cat		
	refresh_inventory()
			
## ── Input ────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") and not event.is_echo():
		var settings = get_parent().get_node_or_null("SettingsMenu")
		if settings and settings.visible:
			return
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
	_clear_item_detail()
	show()

func _close() -> void:
	hide()

## ── Slot Management & Filter ──────────────────────────────────────────────
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
	if index < 0 or index >= GameState.inventory.size():
		return
	
	var slot_data = GameState.inventory[index]
	if slot_data != null and slot_data.get("item") != null:
		_display_item_detail(slot_data["item"], slot_data["count"])
	else:
		_clear_item_detail()

func _display_item_detail(item: ItemData, count: int) -> void:
	if detail_icon:
		detail_icon.texture = item.icon
		detail_icon.show()
	if detail_title:
		detail_title.text = item.display_name if item.display_name != "" else item.item_id
	if detail_desc:
		detail_desc.text = "%s\nJumlah: %d" % [item.description, count]

func _clear_item_detail() -> void:
	if detail_icon:
		detail_icon.hide()
	if detail_title:
		detail_title.text = "Pilih Item"
	if detail_desc:
		detail_desc.text = "Klik slot untuk detail."
	
func refresh_inventory() -> void:
	if not is_instance_valid(slot_grid):
		return

	var matching_items: Array = []
	for slot_data in GameState.inventory:
		if slot_data != null and slot_data["item"] != null:
			var item: ItemData = slot_data["item"]
			if current_category == ItemData.Category.ALL or item.category == current_category:
				matching_items.append(slot_data)
	
	for i in range (_slots.size()):
		if i < matching_items.size():
			_slots[i].set_item(matching_items[i]["item"], matching_items[i]["count"])
		else:
			_slots[i].clear()

	# Update capacity label
	if is_instance_valid(capacity_label):
		var total_used := 0
		for slot_data in GameState.inventory:
			if slot_data != null:
				total_used += 1
		capacity_label.text = "%d/%d" % [total_used, GameState.INVENTORY_SIZE]
