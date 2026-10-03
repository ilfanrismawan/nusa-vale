extends CanvasLayer

## ── Node References ─────────────────────────────────────────────────────────
@onready var dimmer: ColorRect = %Dimmer
@onready var book_root: Control = %BookRoot

@onready var tab_all: TextureButton = %TabAll
@onready var tab_seed: TextureButton = %TabSeed
@onready var tab_crop: TextureButton = %TabCrop
@onready var tab_tool: TextureButton = %TabTool

@onready var slot_grid: GridContainer = %SlotGrid
@onready var handle: TextureRect = %Handle
@onready var capacity_label: Label = %CapacityLabel

@onready var detail_icon: TextureRect = %DetailIcon
@onready var detail_title: Label = %DetailTitle
@onready var detail_sub: Label = %DetailSub
@onready var detail_desc: Label = %DetailDesc

@onready var btn_close: TextureButton = %BtnClose
@onready var equipment_grid: GridContainer = %EquipmentGrid

## ── Configuration ──────────────────────────────────────────────────────────
@export var slot_scene: PackedScene = preload("res://scenes/ui/inventory_slot.tscn")

var _slots: Array[InventorySlotUI] = []
var _displayed: Array = []
var current_category: ItemData.Category = ItemData.Category.ALL
var _selected_slot_index: int = -1

# Track slider bounds (horizontal movement range in pixel)
const HANDLE_MIN_X: float = 2.0
const HANDLE_MAX_X: float = 40.0

## ── Lifecycle ───────────────────────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

	_setup_tabs()
	_setup_close_button()
	_setup_equipment_slots()
	_create_slots()

	if GameState:
		GameState.inventory_changed.connect(refresh_inventory)

	refresh_inventory()
	_clear_item_detail()


## ── Tabs Setup ──────────────────────────────────────────────────────────────
func _setup_tabs() -> void:
	if tab_all:
		tab_all.pressed.connect(func(): _set_category(ItemData.Category.ALL, tab_all))
	if tab_seed:
		tab_seed.pressed.connect(func(): _set_category(ItemData.Category.SEED, tab_seed))
	if tab_crop:
		tab_crop.pressed.connect(func(): _set_category(ItemData.Category.CROP, tab_crop))
	if tab_tool:
		tab_tool.pressed.connect(func(): _set_category(ItemData.Category.TOOL, tab_tool))

	_highlight_tab(tab_all)


func _set_category(cat: ItemData.Category, active_tab: TextureButton) -> void:
	current_category = cat
	_highlight_tab(active_tab)
	refresh_inventory()
	_clear_item_detail()


func _highlight_tab(active_tab: TextureButton) -> void:
	var tabs: Array[TextureButton] = [tab_all, tab_seed, tab_crop, tab_tool]
	for t in tabs:
		if is_instance_valid(t):
			if t == active_tab:
				t.position.x = -3.0 # Menonjol keluar lebih jauh saat aktif
				t.modulate = Color(1.1, 1.1, 1.1, 1.0)
			else:
				t.position.x = 0.0
				t.modulate = Color(0.85, 0.85, 0.85, 0.9)


## ── Close Button ────────────────────────────────────────────────────────────
func _setup_close_button() -> void:
	if btn_close:
		btn_close.pressed.connect(_close)


## ── Equipment Slots Interaction ─────────────────────────────────────────────
func _setup_equipment_slots() -> void:
	if not equipment_grid:
		return
	var equip_names := [
		"Topi / Helm",
		"Baju / Armor",
		"Celana / Jubah",
		"Tas Punggung",
		"Sepatu / Boots",
		"Ramuan / Potion",
		"Cincin Perlindungan",
		"Jimat Keberuntungan"
	]
	var children = equipment_grid.get_children()
	for i in range(children.size()):
		var slot_node = children[i]
		if slot_node is Control:
			var slot_name = equip_names[i] if i < equip_names.size() else "Perlengkapan"
			slot_node.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.pressed:
					_display_equipment_detail(slot_name)
			)


func _display_equipment_detail(equip_name: String) -> void:
	if detail_icon:
		detail_icon.texture = null
		detail_icon.hide()
	if detail_title:
		detail_title.text = equip_name
	if detail_sub:
		detail_sub.text = "[Slot Perlengkapan]"
	if detail_desc:
		detail_desc.text = "Slot untuk mengenakan %s.\nStatus: Kosong." % equip_name


## ── Input Handling ──────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") and not event.is_echo():
		var settings = get_parent().get_node_or_null("SettingsMenu")
		if settings and settings.visible:
			return
		if get_tree().paused and not visible:
			return
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel") and not event.is_echo():
		_close()
		get_viewport().set_input_as_handled()


## ── Open / Close ────────────────────────────────────────────────────────────
func toggle() -> void:
	if visible:
		_close()
	else:
		_open()


func _open() -> void:
	refresh_inventory()
	_clear_item_detail()
	show()
	get_tree().paused = true


func _close() -> void:
	hide()
	get_tree().paused = false


## ── Inventory Slots Creation ────────────────────────────────────────────────
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
	if button != MOUSE_BUTTON_LEFT:
		return

	# Jika belum ada slot yang dipilih
	if _selected_slot_index == -1:
		var slot_data = GameState.inventory[index] if index >= 0 and index < GameState.inventory.size() else null
		if slot_data != null and slot_data.get("item") != null:
			_select_slot(index)
		else:
			_clear_item_detail()
		return

	# Jika mengklik slot yang sama persis -> batalkan seleksi
	if index == _selected_slot_index:
		_clear_item_detail()
		return

	# Jika mengklik slot berbeda -> tukar posisi item (swap)!
	var from_idx := _selected_slot_index
	GameState.swap_slots(from_idx, index)

	# Pilih slot baru jika terisi
	var new_slot = GameState.inventory[index] if index >= 0 and index < GameState.inventory.size() else null
	if new_slot != null and new_slot.get("item") != null:
		_select_slot(index)
	else:
		_clear_item_detail()


func _select_slot(index: int) -> void:
	_selected_slot_index = index
	for i in range(_slots.size()):
		_slots[i].set_selected(i == index)

	var slot_data = GameState.inventory[index] if index >= 0 and index < GameState.inventory.size() else null
	if slot_data != null and slot_data.get("item") != null:
		_display_item_detail(slot_data["item"], slot_data["count"], index)
	else:
		_clear_item_detail()


func _display_item_detail(item: ItemData, count: int, slot_idx: int = -1) -> void:
	if detail_icon:
		detail_icon.texture = item.icon
		detail_icon.show()
	if detail_title:
		detail_title.text = item.display_name if item.display_name != "" else item.item_id
	if detail_sub:
		var cat_name := "Item"
		match item.category:
			ItemData.Category.SEED: cat_name = "Bibit Tanaman"
			ItemData.Category.CROP: cat_name = "Hasil Panen"
			ItemData.Category.TOOL: cat_name = "Peralatan"
			ItemData.Category.MATERIAL: cat_name = "Material"
		
		var hotbar_tag := "  [HUD #%d]" % (slot_idx + 1) if (slot_idx >= 0 and slot_idx < 8) else ""
		detail_sub.text = "%s  •  Qty: %d%s" % [cat_name, count, hotbar_tag]
	if detail_desc:
		var text := item.description
		if text.is_empty():
			text = "Item berharga dari perkebunan Nusa Vale."
		if item.sell_price > 0:
			text += "\nHarga Jual: %d G" % item.sell_price
		detail_desc.text = text


func _clear_item_detail() -> void:
	_selected_slot_index = -1
	for s in _slots:
		s.set_selected(false)

	if detail_icon:
		detail_icon.texture = null
		detail_icon.hide()
	if detail_title:
		detail_title.text = "Pilih Item"
	if detail_sub:
		detail_sub.text = ""
	if detail_desc:
		detail_desc.text = "Klik / drag item di tas untuk memindahkan atau menukar posisi."


## ── Refresh Inventory & Slider ──────────────────────────────────────────────
func refresh_inventory() -> void:
	if not is_instance_valid(slot_grid):
		return

	# Tampilkan seluruh 20 slot secara 1:1 ke GameState.inventory
	for i in _slots.size():
		if i >= GameState.inventory.size():
			_slots[i].clear()
			continue

		var slot_data = GameState.inventory[i]
		if slot_data != null and slot_data.get("item") != null:
			var item: ItemData = slot_data["item"]
			var count: int = slot_data.get("count", 1)
			_slots[i].set_item(item, count)

			# Highlight atau redupkan berdasarkan kategori
			if current_category == ItemData.Category.ALL or item.category == current_category:
				_slots[i].modulate = Color.WHITE
			else:
				_slots[i].modulate = Color(0.35, 0.35, 0.35, 0.4)
		else:
			_slots[i].clear()
			_slots[i].modulate = Color.WHITE

	# Hitung total item unik yang terisi di inventory
	var total_used := 0
	for slot_data in GameState.inventory:
		if slot_data != null and slot_data.get("item") != null:
			total_used += 1

	# Update label kapasitas
	if is_instance_valid(capacity_label):
		capacity_label.text = "%d/%d" % [total_used, GameState.INVENTORY_SIZE]

	# Update posisi slider handle
	if is_instance_valid(handle):
		var ratio: float = float(total_used) / float(maxi(1, GameState.INVENTORY_SIZE))
		var target_x: float = lerpf(HANDLE_MIN_X, HANDLE_MAX_X, clampf(ratio, 0.0, 1.0))
		handle.position.x = target_x

	# Update detail slot yang sedang dipilih
	if _selected_slot_index >= 0 and _selected_slot_index < GameState.inventory.size():
		var sel = GameState.inventory[_selected_slot_index]
		if sel != null and sel.get("item") != null:
			_display_item_detail(sel["item"], sel["count"], _selected_slot_index)
		else:
			_clear_item_detail()
