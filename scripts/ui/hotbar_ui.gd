extends CanvasLayer

signal slot_selected(index: int)

@onready var slot_container: HBoxContainer = $"MarginContainer/HudBg/InnerMargin/HBoxContainer"

const HOTBAR_SLOTS := 8
const SLOT_SCENE = preload("res://scenes/ui/inventory_slot.tscn")
const SKIN_SELECTED: Texture2D = preload("res://resources/ui/hotbar_slot_selected.tres")
const FONT: Font = preload("res://resources/ui/readable_font.tres")
const NUMBER_COLOR := Color8(249, 230, 207)
const OUTLINE_COLOR := Color8(28, 10, 24)
const NAME_HOLD := 1.4 # detik nama item tampil di atas hotbar

var _name_label: Label
var _name_tween: Tween

var _slots: Array[InventorySlotUI] = []
var active_index: int = 0
var _hovered_index: int = -1

## Pemain pemilik UI ini (diisi Player). Kosong = P1.
var player: Player
var data: PlayerData:
	get: return player.data if is_instance_valid(player) else GameState.p1()

## Input pemilik UI: co-op hanya bereaksi pada perangkat pemain ini.
func _owner_input() -> PlayerInput:
	return player.input if is_instance_valid(player) else PlayerInput.solo()

func _ready() -> void:
	add_to_group(&"hotbar_ui")
	_build_name_label()
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
		slot_ui.owner_ui = self
		slot_ui.slot_clicked.connect(_on_slot_clicked)
		slot_ui.slot_hovered.connect(_on_slot_hovered)
		slot_ui.slot_unhovered.connect(_on_slot_unhovered)
		# Bingkai kayu sudah menggambar kotak slot; hanya slot aktif yang diberi latar terang.
		slot_ui.set_skin(null, SKIN_SELECTED)
		slot_container.add_child(slot_ui)
		slot_ui.add_child(_make_number_label(i + 1))
		_slots.append(slot_ui)

	for i in _slots.size():
		_slots[i].set_selected(i == 0)

func _make_number_label(number: int) -> Label:
	var label := Label.new()
	label.text = str(number)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", NUMBER_COLOR)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", 1)
	label.position = Vector2(3, -4)
	label.modulate.a = 0.85
	return label

func _build_name_label() -> void:
	_name_label = Label.new()
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.add_theme_font_override("font", FONT)
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.add_theme_color_override("font_color", NUMBER_COLOR)
	_name_label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	_name_label.add_theme_constant_override("outline_size", 1)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_name_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_name_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_name_label.offset_left = -100.0
	_name_label.offset_right = 100.0
	_name_label.offset_top = -98.0
	_name_label.offset_bottom = -76.0
	_name_label.modulate.a = 0.0
	add_child(_name_label)

## Nama item muncul sebentar di atas hotbar saat slot aktif berganti (seperti Stardew).
func _show_item_name() -> void:
	var item := get_active_item()
	if item == null or _name_label == null:
		return
	_name_label.text = item.display_name
	if _name_tween:
		_name_tween.kill()
	_name_label.modulate.a = 1.0
	_name_tween = create_tween()
	_name_tween.tween_interval(NAME_HOLD)
	_name_tween.tween_property(_name_label, "modulate:a", 0.0, 0.3)

func refresh() -> void:
	var offset := data.hotbar_page * 8
	for i in HOTBAR_SLOTS:
		var global_idx = offset + i
		# Jika index melampaui bag_size yang aktif, anggap kosong
		var slot_data = null
		if global_idx < data.bag_size:
			slot_data = data.inventory[global_idx]
		# Indeks tas sebenarnya (halaman hotbar 2/3), supaya tarik-lepas menukar slot yang benar.
		_slots[i].slot_index = global_idx
			
		if slot_data != null and slot_data.get("item") != null:
			_slots[i].set_item(slot_data["item"], slot_data["count"])
		else:
			_slots[i].clear()

func _select(index: int) -> void:
	highlight_slot(index)
	slot_selected.emit(index)

func highlight_slot(index: int) -> void:
	var changed := index != active_index
	active_index = index
	for i in _slots.size():
		_slots[i].set_selected(i == active_index)
	if changed:
		_show_item_name()

func _on_slot_clicked(index: int, button: int) -> void:
	if button == MOUSE_BUTTON_LEFT:
		_select(index % HOTBAR_SLOTS)

func _on_slot_hovered(index: int, _slot_ui: InventorySlotUI) -> void:
	_hovered_index = index % HOTBAR_SLOTS

func _on_slot_unhovered(index: int, _slot_ui: InventorySlotUI) -> void:
	if _hovered_index == index % HOTBAR_SLOTS:
		_hovered_index = -1

## Posisi tengah (layar) slot hotbar yang berisi item_id, atau null jika tidak ada di halaman ini.
func get_slot_center_for(item_id: String) -> Variant:
	var slot := _slot_for(item_id)
	if slot == null:
		return null
	return slot.get_global_rect().get_center()


## Slot berdenyut sesaat saat item baru masuk (dipanggil oleh Juice).
func pulse_item(item_id: String) -> void:
	var slot := _slot_for(item_id)
	if slot:
		slot.pulse()


func _slot_for(item_id: String) -> InventorySlotUI:
	var offset := data.hotbar_page * 8
	for i in HOTBAR_SLOTS:
		var global_idx := offset + i
		if global_idx >= data.bag_size:
			break
		var slot_data = data.inventory[global_idx]
		if slot_data == null or slot_data.get("item") == null:
			continue
		var item: ItemData = slot_data["item"]
		if item.item_id == item_id:
			return _slots[i]
	return null


func get_active_item() -> ItemData:
	var global_idx = data.hotbar_page * 8 + active_index
	if global_idx < 0 or global_idx >= data.bag_size:
		return null
	var slot = data.inventory[global_idx]
	if slot == null:
		return null
	return slot["item"]

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(player) and player.is_input_locked():
		return
	var input := _owner_input()
	if input.is_event(event, &"cycle_hotbar"):
		data.cycle_hotbar()
		if is_instance_valid(player):
			player.tool_controller.select_tool(active_index)
		get_viewport().set_input_as_handled()
		return
		
	if input.is_event(event, &"sort_inventory"):
		data.sort_inventory()
		get_viewport().set_input_as_handled()
		return
	# Scroll mouse ganti slot ditangani ToolController lewat aksi tool_next/tool_prev.
