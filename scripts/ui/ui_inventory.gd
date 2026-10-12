extends CanvasLayer

## ── Node References ─────────────────────────────────────────────────────────
@onready var dimmer: ColorRect = %Dimmer
@onready var book_root: Control = %BookRoot

# Top Tabs
@onready var tab_book: TextureButton = %TabBook
@onready var tab_gear: TextureButton = %TabGear
@onready var tab_collection: TextureButton = %TabKoleksi

# Right Ribbons
@onready var ribbon_red: TextureButton = %RibbonRed
@onready var ribbon_blue: TextureButton = %RibbonBlue
@onready var ribbon_green: TextureButton = %RibbonGreen
@onready var ribbon_orange: TextureButton = %RibbonOrange
@onready var ribbon_tan: TextureButton = %RibbonTan
@onready var ribbon_fish: TextureButton = %RibbonFish
@onready var ribbon_forage: TextureButton = %RibbonForage

# Left Page (Slots & Slider & Pagination)
@onready var slot_grid: GridContainer = %SlotGrid
@onready var btn_prev_page: Button = %BtnPrevPage
@onready var btn_next_page: Button = %BtnNextPage
@onready var page_label: Label = %PageLabel
@onready var handle: TextureRect = %Handle
@onready var capacity_label: Label = %CapacityLabel

# Right Page (Detail Preview & Info)
@onready var detail_icon: TextureRect = %DetailIcon
@onready var badge_count: Label = %BadgeCount
@onready var badge_hotbar: Label = %BadgeHotbar
@onready var detail_title: Label = %DetailTitle
@onready var detail_sub: Label = %DetailSub
@onready var detail_desc: Label = %DetailDesc
@onready var gold_label: Label = %GoldLabel
@onready var price_label: Label = %PriceLabel

# Floating Hover Tooltip
@onready var hover_tooltip: PanelContainer = %HoverTooltip
@onready var tooltip_title: Label = %TooltipTitle
@onready var tooltip_category: Label = %TooltipCategory
@onready var tooltip_hotbar: Label = %TooltipHotbar
@onready var tooltip_price: Label = %TooltipPrice

# Close Button
@onready var btn_close: TextureButton = %BtnClose

## ── Configuration & Resources ───────────────────────────────────────────────
@export var slot_scene: PackedScene = preload("res://scenes/ui/inventory_slot.tscn")

const TEX_TAB_NORMAL := preload("res://resources/ui/tab_top_normal.tres")
const TEX_TAB_ACTIVE := preload("res://resources/ui/tab_top_active.tres")
const TEX_RIBBON := preload("res://resources/ui/ribbon_category.svg")
const TEX_RIBBON_ACTIVE := preload("res://resources/ui/ribbon_category_active.svg")

const SLOTS_PER_PAGE: int = 12
const HUD = preload("res://scenes/ui/hud.gd")
const DropItemDialogScript = preload("res://scripts/ui/drop_item_dialog.gd")
## TOTAL_PAGES dihitung dinamis dari bag_size
var total_pages: int:
	get: return ceili(float(data.bag_size) / float(SLOTS_PER_PAGE))

var _slots: Array[InventorySlotUI] = []
var current_category: ItemData.Category = ItemData.Category.ALL
var current_page: int = 0
var _selected_slot_index: int = -1
var _hovered_slot_index: int = -1

## Buang item: kotak pilihan jumlah + tombol "Buang" di panel kanan (dibuat lewat kode).
var _drop_dialog: DropItemDialogScript
var _drop_slot_index: int = -1
var _btn_drop: Button
var _tip_label: Label
## Mode jual (dibuka dari Shipping Bin): kotak jumlah menjual, bukan membuang.
var _sell_mode: bool = false
var _rpg_menu: Control
var _top_tabs: Array[TextureButton] = []
var _menu_buttons: Dictionary = {}
var _status_panel: PanelContainer
var _status_text: Label
var _btn_hotbar: Button
var _collection_panel: PanelContainer
var _btn_sort: Button
var _equipment_panel: PanelContainer
var _crafting_panel: PanelContainer

## Pemain pemilik UI ini (diisi Player). Kosong = P1.
var player: Player
var data: PlayerData:
	get: return player.data if is_instance_valid(player) else GameState.p1()

## Input pemilik UI: co-op hanya bereaksi pada perangkat pemain ini.
func _owner_input() -> PlayerInput:
	return player.input if is_instance_valid(player) else PlayerInput.solo()

# Slider bounds in 1x scale
const HANDLE_MIN_X: float = 4.0
const HANDLE_MAX_X: float = 52.0

## ── Lifecycle ───────────────────────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	# Stat dan perbandingan tier tetap muat dalam bingkai buku.
	if detail_desc != null:
		var box := detail_desc.get_parent()
		var position := detail_desc.get_index()
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		box.add_child(scroll)
		box.move_child(scroll, position)
		detail_desc.reparent(scroll)
		detail_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if is_instance_valid(hover_tooltip):
		hover_tooltip.hide()

	_setup_top_tabs()
	_setup_right_ribbons()
	_setup_pagination()
	_setup_close_button()
	_create_slots()
	_setup_drop_ui()
	_setup_rpg_menus()

	if GameState:
		GameState.inventory_changed.connect(refresh_inventory)
		GameState.money_changed.connect(_on_money_changed)
		GameState.bag_upgraded.connect(_on_bag_upgraded)

	refresh_inventory()
	_clear_item_detail()


## Menu tambahan menggunakan font dan warna buku inventory.
func _setup_rpg_menus() -> void:
	_rpg_menu = %TopTabsContainer
	_menu_buttons["Tas"] = tab_book
	var additions := [["Status", "Status", preload("res://resources/ui/icon_tab_person.tres")]]
	for entry in additions:
		var button := _rpg_menu.get_node("Tab" + entry[1]) as TextureButton
		button.texture_normal = TEX_TAB_NORMAL
		var icon := button.get_node("Icon") as TextureRect
		icon.texture = entry[2]
		_menu_buttons[entry[0]] = button
		_setup_tab_hover(button, entry[0])
	_menu_buttons["Koleksi"] = tab_collection
	var equipment_tab := TextureButton.new()
	equipment_tab.name = "TabEquipment"
	equipment_tab.texture_normal = TEX_TAB_NORMAL
	var equipment_icon := TextureRect.new()
	equipment_icon.name = "Icon"
	equipment_icon.texture = preload("res://resources/ui/icon_tab_sword.tres")
	equipment_tab.add_child(equipment_icon)
	_rpg_menu.add_child(equipment_tab)
	_menu_buttons["Equipment"] = equipment_tab
	equipment_tab.pressed.connect(_show_equipment)
	_setup_tab_hover(equipment_tab, "Senjata dan armor yang sedang dipakai")
	var crafting_tab := TextureButton.new()
	crafting_tab.name = "TabCrafting"
	crafting_tab.texture_normal = TEX_TAB_NORMAL
	var crafting_icon := TextureRect.new()
	crafting_icon.name = "Icon"
	crafting_icon.texture = preload("res://resources/icons/icon_pickaxe_wood.tres")
	crafting_tab.add_child(crafting_icon)
	_rpg_menu.add_child(crafting_tab)
	_menu_buttons["Crafting"] = crafting_tab
	crafting_tab.pressed.connect(_show_crafting)
	_setup_tab_hover(crafting_tab, "Buat perlengkapan dari bahan dalam tas")
	_top_tabs.assign([tab_book, _menu_buttons["Status"], equipment_tab, crafting_tab, tab_collection, tab_gear])
	var titles := ["Tas", "Status", "Equipment", "Crafting", "Koleksi", "Pengaturan"]
	var widths := [50.0, 56.0, 78.0, 68.0, 62.0, 90.0]
	var tab_x := 0.0
	for i in range(_top_tabs.size()):
		var tab_width: float = widths[i]
		_style_top_tab(_top_tabs[i], titles[i], tab_x, tab_width)
		tab_x += tab_width + 4.0
	_menu_buttons["Status"].pressed.connect(_show_status)
	_btn_sort = _make_menu_button("Rapikan Tas")
	_btn_sort.pressed.connect(_sort_bag)
	_btn_sort.tooltip_text = "Gabungkan tumpukan dan urutkan item menurut kategori."
	var bag_actions := book_root.get_node("LeftPage/LeftBottomPanel/Margin/VBox")
	bag_actions.add_child(_btn_sort)
	bag_actions.move_child(_btn_sort, 1)

	_status_panel = PanelContainer.new()
	_status_panel.position = Vector2(28, 20)
	_status_panel.size = Vector2(420, 248)
	_status_panel.add_theme_stylebox_override("panel", _drop_button_style(Color(0.18, 0.12, 0.08, 1)))
	book_root.add_child(_status_panel)
	var margin := MarginContainer.new()
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	_status_panel.add_child(margin)
	_status_text = Label.new()
	_status_text.add_theme_font_override("font", DropItemDialogScript.FONT)
	_status_text.add_theme_font_size_override("font_size", 20)
	_status_text.add_theme_color_override("font_color", DropItemDialogScript.COLOR_TEXT)
	_status_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(_status_text)
	_status_panel.hide()
	_collection_panel = preload("res://scripts/ui/inventory_collection.gd").new()
	_collection_panel.position = Vector2(28, 20)
	_collection_panel.size = Vector2(420, 248)
	book_root.add_child(_collection_panel)
	_collection_panel.hide()
	_equipment_panel = preload("res://scripts/ui/inventory_equipment.gd").new()
	_equipment_panel.inventory_ui = self
	_equipment_panel.position = Vector2(28, 20)
	_equipment_panel.size = Vector2(420, 248)
	book_root.add_child(_equipment_panel)
	_equipment_panel.hide()
	_crafting_panel = preload("res://scripts/ui/inventory_crafting.gd").new()
	_crafting_panel.inventory_ui = self
	_crafting_panel.position = Vector2(28, 20)
	_crafting_panel.size = Vector2(420, 248)
	book_root.add_child(_crafting_panel)
	_crafting_panel.hide()

	var action_row := HBoxContainer.new()
	_btn_drop.get_parent().add_child(action_row)
	_btn_drop.reparent(action_row)
	_btn_drop.text = "Buang"
	_btn_drop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_hotbar = _make_menu_button("Hotbar")
	_btn_hotbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_hotbar.tooltip_text = "Tampilkan halaman hotbar yang memuat item terpilih."
	_btn_hotbar.pressed.connect(_activate_hotbar_item)
	action_row.add_child(_btn_hotbar)
	_update_hotbar_button()
	_update_menu_highlight()


func _style_top_tab(tab: TextureButton, title: String, tab_x: float, tab_width: float) -> void:
	tab.ignore_texture_size = true
	tab.stretch_mode = TextureButton.STRETCH_SCALE
	tab.custom_minimum_size = Vector2(tab_width, 58)
	tab.size = Vector2(tab_width, 58)
	tab.position = Vector2(tab_x, 8)
	tab.mouse_filter = Control.MOUSE_FILTER_STOP
	tab.focus_mode = Control.FOCUS_ALL
	tab.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color(1, 0.94, 0.64)
	focus.set_border_width_all(2)
	tab.add_theme_stylebox_override("focus", focus)
	var icon := tab.get_node("Icon") as TextureRect
	icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	icon.position = Vector2((tab_width - 24.0) / 2.0, 8)
	icon.size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.name = "TabLabel"
	label.text = title
	label.position = Vector2(2, 32)
	label.size = Vector2(tab_width - 4.0, 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", DropItemDialogScript.FONT)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.24, 0.12, 0.08))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab.add_child(label)


func _make_menu_button(title: String) -> Button:
	var button := Button.new()
	button.text = title
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_theme_font_override("font", DropItemDialogScript.FONT)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", DropItemDialogScript.COLOR_TEXT)
	button.add_theme_stylebox_override("normal", _drop_button_style(Color(0.24, 0.16, 0.1, 1)))
	button.add_theme_stylebox_override("hover", _drop_button_style(Color(0.42, 0.29, 0.15, 1)))
	button.add_theme_stylebox_override("pressed", _drop_button_style(Color(0.52, 0.35, 0.16, 1)))
	return button


func _show_bag_page() -> void:
	if not is_instance_valid(_status_panel):
		return
	_status_panel.hide()
	_equipment_panel.hide()
	_collection_panel.hide()
	_crafting_panel.hide()
	book_root.get_node("LeftPage").show()
	book_root.get_node("RightPage").show()
	book_root.get_node("RightRibbonsContainer").show()
	_update_menu_highlight()


func _show_status() -> void:
	if _drop_dialog_open():
		return
	_hide_tooltip()
	_clear_item_detail()
	_collection_panel.hide()
	_equipment_panel.hide()
	_crafting_panel.hide()
	book_root.get_node("LeftPage").hide()
	book_root.get_node("RightPage").hide()
	book_root.get_node("RightRibbonsContainer").hide()
	_status_panel.show()
	_highlight_top_tab(null)
	_update_status()
	_update_menu_highlight()


func _update_status() -> void:
	if not is_instance_valid(_status_text):
		return
	var used := 0
	var value := 0
	for i in range(data.bag_size):
		var item := _slot_item(i)
		if item != null:
			used += 1
			if item.category != ItemData.Category.TOOL:
				value += item.sell_price * int(data.inventory[i].get("count", 1))
	var name_text := data.player_name if not data.player_name.is_empty() else "Petani P%d" % (data.index + 1)
	_status_text.text = "STATUS PETANI\n%s\n\nStamina: %d / %d\nTas: %d / %d slot\nUang: %s G\nNilai jual isi tas: %s G\n\nHari %d - %s" % [name_text, data.stamina, PlayerData.MAX_STAMINA, used, data.bag_size, HUD.format_money(GameState.money), HUD.format_money(value), DayCycle.current_day, DayCycle.get_season_display_name()]


func _update_menu_highlight() -> void:
	var active: TextureButton = tab_book
	if is_instance_valid(_status_panel) and _status_panel.visible:
		active = _menu_buttons["Status"]
	elif is_instance_valid(_collection_panel) and _collection_panel.visible:
		active = tab_collection
	elif is_instance_valid(_equipment_panel) and _equipment_panel.visible:
		active = _menu_buttons["Equipment"]
	elif is_instance_valid(_crafting_panel) and _crafting_panel.visible:
		active = _menu_buttons["Crafting"]
	_highlight_top_tab(active)


func _show_collection() -> void:
	if _drop_dialog_open():
		return
	_hide_tooltip()
	_clear_item_detail()
	_status_panel.hide()
	_equipment_panel.hide()
	_crafting_panel.hide()
	book_root.get_node("LeftPage").hide()
	book_root.get_node("RightPage").hide()
	book_root.get_node("RightRibbonsContainer").hide()
	_collection_panel.show()
	_collection_panel.refresh()
	_update_menu_highlight()


func _show_equipment() -> void:
	if _drop_dialog_open():
		return
	_hide_tooltip()
	_clear_item_detail()
	_status_panel.hide()
	_collection_panel.hide()
	_crafting_panel.hide()
	for path in ["LeftPage", "RightPage", "RightRibbonsContainer"]:
		book_root.get_node(path).hide()
	_equipment_panel.show()
	_equipment_panel.refresh()
	_update_menu_highlight()


func _show_crafting() -> void:
	if _drop_dialog_open():
		return
	_hide_tooltip()
	_clear_item_detail()
	for panel in [_status_panel, _equipment_panel, _collection_panel]:
		panel.hide()
	for path in ["LeftPage", "RightPage", "RightRibbonsContainer"]:
		book_root.get_node(path).hide()
	_crafting_panel.show()
	_crafting_panel.refresh()
	_update_menu_highlight()


func _sort_bag() -> void:
	if _drop_dialog_open():
		return
	_hide_tooltip()
	_clear_item_detail()
	_show_bag_page()
	current_page = 0
	data.sort_inventory()
	refresh_inventory()
	Notify.say("Tas dirapikan: tumpukan digabung dan item diurutkan.")


func _update_hotbar_button() -> void:
	if not is_instance_valid(_btn_hotbar):
		return
	_btn_hotbar.visible = _slot_item(_selected_slot_index) != null and not _sell_mode
	_btn_hotbar.disabled = _drop_dialog_open()
	if _btn_hotbar.visible and is_instance_valid(_tip_label):
		_tip_label.hide()


func _activate_hotbar_item() -> void:
	if _drop_dialog_open() or _slot_item(_selected_slot_index) == null:
		return
	data.hotbar_page = floori(float(_selected_slot_index) / 8.0)
	GameState.inventory_changed.emit()
	Notify.say("Item tersedia di hotbar slot %d." % ((_selected_slot_index % 8) + 1))


## ── Top Tabs Setup ──────────────────────────────────────────────────────────
func _setup_top_tabs() -> void:
	_top_tabs.assign([tab_book, tab_collection, tab_gear])
	if tab_book:
		tab_book.pressed.connect(func(): _set_category(ItemData.Category.ALL, tab_book))
		_setup_tab_hover(tab_book, "Semua Item")
	tab_collection.pressed.connect(_show_collection)
	_setup_tab_hover(tab_collection, "Ensiklopedia penemuan: ikan, hasil hutan, tanaman, dan mineral")
	if tab_gear:
		tab_gear.pressed.connect(_on_gear_pressed)
		_setup_tab_hover(tab_gear, "Buka pengaturan layar, audio, dan permainan")

	_highlight_top_tab(tab_book)


func _setup_tab_hover(tab: TextureButton, hover_hint: String) -> void:
	tab.tooltip_text = hover_hint
	tab.mouse_entered.connect(func():
		if tab.texture_normal != TEX_TAB_ACTIVE:
			tab.position.y = 4.0
		tab.modulate = Color(1.15, 1.1, 1.0)
	)
	tab.mouse_exited.connect(func():
		if tab.texture_normal != TEX_TAB_ACTIVE:
			tab.position.y = 8.0
		tab.modulate = Color.WHITE
		_hide_tooltip()
	)


func _on_gear_pressed() -> void:
	if _drop_dialog_open():
		return
	if Coop.active and data.index != 0:
		detail_desc.text = "Pengaturan bersama hanya dapat dibuka P1."
		Notify.say("Pengaturan bersama hanya dapat dibuka P1.")
		return
	_hide_tooltip()
	var settings = get_parent().get_node_or_null("SettingsMenu")
	if settings:
		# Inventory berada di layer 35; pengaturan harus muncul di atas buku.
		settings.layer = maxi(settings.layer, layer + 1)
		settings.toggle()


func _set_category(cat: ItemData.Category, active_tab: TextureButton = null) -> void:
	if _drop_dialog_open():
		return
	_show_bag_page()
	current_category = cat
	_highlight_top_tab(active_tab)
	_highlight_ribbon(_ribbon_for(cat))
	refresh_inventory()
	_clear_item_detail()
	_update_menu_highlight()


func _highlight_top_tab(active_tab: TextureButton) -> void:
	for t in _top_tabs:
		if is_instance_valid(t):
			if t == active_tab:
				t.position.y = 0.0 # Menonjol ke atas
				t.texture_normal = TEX_TAB_ACTIVE
			else:
				t.position.y = 8.0
				t.texture_normal = TEX_TAB_NORMAL


## ── Right Ribbons Setup ─────────────────────────────────────────────────────
func _setup_right_ribbons() -> void:
	var ribbon_data := [
		{"btn": ribbon_red, "cat": ItemData.Category.ALL, "title": "Semua Item", "tag": "Kategori Utama"},
		{"btn": ribbon_blue, "cat": ItemData.Category.SEED, "title": "Bibit Tanaman", "tag": "Pertanian"},
		{"btn": ribbon_green, "cat": ItemData.Category.CROP, "title": "Hasil Panen", "tag": "Produk Kebun"},
		{"btn": ribbon_orange, "cat": ItemData.Category.MATERIAL, "title": "Material & Bahan", "tag": "Kayu & Batu"},
		{"btn": ribbon_tan, "cat": ItemData.Category.TOOL, "title": "Peralatan Kerja", "tag": "Alat Petani"},
		{"btn": ribbon_fish, "cat": ItemData.Category.FISH, "title": "Ikan", "tag": "Isi Tas"},
		{"btn": ribbon_forage, "cat": ItemData.Category.FORAGE, "title": "Hasil Hutan", "tag": "Isi Tas"},
	]
	var short_titles := ["Semua", "Bibit", "Panen", "Bahan", "Alat", "Ikan", "Hutan"]
	var colors := [Color("b55c49"), Color("70964d"), Color("d39237"), Color("9a7965"), Color("b49b76"), Color("5c91aa"), Color("698561")]
	var rail: Control = %RightRibbonsContainer
	rail.mouse_filter = Control.MOUSE_FILTER_PASS
	var heading := Label.new()
	heading.text = "FILTER TAS"
	heading.position = Vector2(16, -18)
	heading.add_theme_font_override("font", DropItemDialogScript.FONT)
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", Color("efd09a"))
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.add_child(heading)
	var icons := [preload("res://resources/ui/icon_tab_book.tres"), preload("res://resources/icons/icon_seed_carrot.tres"), preload("res://resources/icons/icon_carrot.tres"), preload("res://resources/icons/icon_stone.tres"), preload("res://resources/ui/icon_tab_sword.tres"), preload("res://resources/icons/icon_catfish.tres"), preload("res://resources/icons/icon_common_mushroom.tres")]
	for i in range(ribbon_data.size()):
		var ribbon: TextureButton = ribbon_data[i]["btn"]
		ribbon.position = Vector2(0, i * 34)
		ribbon.custom_minimum_size = Vector2(120, 30)
		ribbon.size = Vector2(120, 30)
		ribbon.texture_normal = TEX_RIBBON
		ribbon.texture_hover = TEX_RIBBON_ACTIVE
		ribbon.texture_pressed = TEX_RIBBON_ACTIVE
		ribbon.texture_focused = TEX_RIBBON_ACTIVE
		ribbon.focus_mode = Control.FOCUS_ALL
		ribbon.mouse_filter = Control.MOUSE_FILTER_STOP
		ribbon.tooltip_text = ribbon_data[i]["title"] + " — filter isi tas\nAngka menunjukkan jumlah slot terisi."
		ribbon.stretch_mode = TextureButton.STRETCH_SCALE
		var accent := ColorRect.new()
		accent.color = colors[i]
		accent.position = Vector2(2, 5)
		accent.size = Vector2(3, 20)
		accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ribbon.add_child(accent)
		var icon := ribbon.get_node("Icon") as TextureRect
		icon.texture = icons[i]
		icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		icon.position = Vector2(10, 7)
		icon.size = Vector2(16, 16)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := Label.new()
		label.name = "CategoryLabel"
		label.text = short_titles[i]
		label.position = Vector2(32, 5)
		label.size = Vector2(53, 20)
		label.add_theme_font_override("font", DropItemDialogScript.FONT)
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(0.23, 0.12, 0.08))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ribbon.add_child(label)
		var count := Label.new()
		count.name = "SlotCount"
		count.position = Vector2(85, 5)
		count.size = Vector2(22, 20)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.add_theme_font_override("font", DropItemDialogScript.FONT)
		count.add_theme_font_size_override("font_size", 16)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ribbon.add_child(count)

	for data in ribbon_data:
		var btn: TextureButton = data["btn"]
		var cat: ItemData.Category = data["cat"]
		if is_instance_valid(btn):
			btn.pressed.connect(func(): _on_ribbon_selected(cat, btn))
			btn.mouse_entered.connect(func():
				btn.position.x = 6.0
				_style_ribbon_text(btn, true)
			)
			btn.mouse_exited.connect(func():
				if current_category != cat:
					btn.position.x = 0.0
					_style_ribbon_text(btn, btn.has_focus())
				_hide_tooltip()
			)
			btn.focus_entered.connect(func(): _style_ribbon_text(btn, true))
			btn.focus_exited.connect(func(): _style_ribbon_text(btn, current_category == cat))
	_highlight_ribbon(_ribbon_for(current_category))


func _style_ribbon_text(ribbon: TextureButton, selected: bool) -> void:
	var color := Color("fff0c9") if selected else Color("41271e")
	for path in ["CategoryLabel", "SlotCount"]:
		ribbon.get_node(path).add_theme_color_override("font_color", color)


func _on_ribbon_selected(cat: ItemData.Category, _active_ribbon: TextureButton) -> void:
	if _drop_dialog_open():
		return
	_set_category(cat)


func _ribbon_for(cat: ItemData.Category) -> TextureButton:
	match cat:
		ItemData.Category.ALL: return ribbon_red
		ItemData.Category.SEED: return ribbon_blue
		ItemData.Category.CROP: return ribbon_green
		ItemData.Category.MATERIAL: return ribbon_orange
		ItemData.Category.TOOL: return ribbon_tan
		ItemData.Category.FISH: return ribbon_fish
		ItemData.Category.FORAGE: return ribbon_forage
	return null


func _highlight_ribbon(active_ribbon: TextureButton) -> void:
	var ribbons: Array[TextureButton] = [ribbon_red, ribbon_blue, ribbon_green, ribbon_orange, ribbon_tan, ribbon_fish, ribbon_forage]
	for r in ribbons:
		if is_instance_valid(r):
			if r == active_ribbon:
				r.position.x = 6.0 # Geser keluar ke kanan
				r.texture_normal = TEX_RIBBON_ACTIVE
			else:
				r.position.x = 0.0
				r.texture_normal = TEX_RIBBON
			r.modulate = Color.WHITE
			_style_ribbon_text(r, r == active_ribbon or r.has_focus())


## ── Pagination Setup ────────────────────────────────────────────────────────
func _setup_pagination() -> void:
	if btn_prev_page:
		btn_prev_page.pressed.connect(_prev_page)
	if btn_next_page:
		btn_next_page.pressed.connect(_next_page)


func _prev_page() -> void:
	if current_page > 0:
		current_page -= 1
		refresh_inventory()


func _next_page() -> void:
	if current_page < total_pages - 1:
		current_page += 1
		refresh_inventory()


## ── Close Button ────────────────────────────────────────────────────────────
func _setup_close_button() -> void:
	if btn_close:
		btn_close.pressed.connect(_close)


## ── Input Handling ──────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if StructureManager.has_menu(data.index):
		return
	# Selama menu pengaturan (tab gear) terbuka, Esc menutup menu itu dulu, bukan tas.
	var settings = get_parent().get_node_or_null("SettingsMenu")
	if settings and settings.visible:
		return
	var input := _owner_input()
	# Esc menutup dialog buang lebih dulu sebelum menutup tas.
	if visible and _drop_dialog_open() and input.is_event(event, &"ui_cancel"):
		_close_drop_dialog()
		get_viewport().set_input_as_handled()
	elif input.is_event(event, &"inventory") or (not visible and input.is_event(event, &"ui_cancel")):
		if get_tree().paused and not visible:
			return
		# Co-op: jangan buka tas saat pemain ini sedang di toko/pindah area/tidur.
		if not visible and is_instance_valid(player) and player.is_input_locked():
			return
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and input.is_event(event, &"ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
	elif visible and event is InputEventMouseButton and event.pressed and input.uses_mouse():
		if (_status_panel.visible or _collection_panel.visible or _equipment_panel.visible or _crafting_panel.visible):
			return
		# Scroll mouse wheel untuk navigasi halaman tas
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_prev_page()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_next_page()
			get_viewport().set_input_as_handled()


## ── Open / Close ────────────────────────────────────────────────────────────
func toggle() -> void:
	if visible:
		_close()
	else:
		_open()


func _open() -> void:
	_show_bag_page()
	tab_gear.tooltip_text = "Pengaturan bersama hanya dapat dibuka P1." if Coop.active and data.index != 0 else "Buka pengaturan layar, audio, kontrol, dan permainan"
	refresh_inventory()
	_clear_item_detail()
	_hide_tooltip()
	show()
	Coop.set_menu_open(player, true)


## Dibuka Shipping Bin: tas dalam mode jual (pilih item + jumlah yang dijual).
func open_sell_mode() -> void:
	if visible:
		_close()
	_sell_mode = true
	_open()


func _close() -> void:
	_close_drop_dialog()
	_sell_mode = false
	_hide_tooltip()
	hide()
	Coop.set_menu_open(player, false)


## ── Inventory Slots Creation ────────────────────────────────────────────────
func _create_slots() -> void:
	if not slot_grid or not slot_scene:
		return

	for child in slot_grid.get_children():
		child.queue_free()
	_slots.clear()

	# Buat 12 slot grid untuk halaman yang sedang aktif
	for i in range(SLOTS_PER_PAGE):
		var slot: InventorySlotUI = slot_scene.instantiate()
		slot.slot_index = i
		slot.owner_ui = self
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.slot_hovered.connect(_on_slot_hovered)
		slot.slot_unhovered.connect(_on_slot_unhovered)
		slot.slot_swapped.connect(_on_slot_swapped)
		slot_grid.add_child(slot)
		_slots.append(slot)


## ── Hover Visual & Tooltip Handling ─────────────────────────────────────────
func _on_slot_hovered(global_idx: int, slot_ui: InventorySlotUI) -> void:
	_hovered_slot_index = global_idx

	if global_idx < 0 or global_idx >= data.inventory.size():
		_hide_tooltip()
		return

	var slot_data = data.inventory[global_idx]
	if slot_data != null and slot_data.get("item") != null:
		var item: ItemData = slot_data["item"]
		var count: int = slot_data.get("count", 1)

		# Tampilkan Floating Hover Tooltip
		_show_item_tooltip(slot_ui.global_position, item, count, global_idx)

		# Perbarui juga pratinjau halaman kanan secara real-time saat diarahkan kursor
		_display_item_detail(item, count, global_idx)
	else:
		_hide_tooltip()


func _on_slot_unhovered(global_idx: int, _slot_ui: InventorySlotUI) -> void:
	if _hovered_slot_index == global_idx:
		_hovered_slot_index = -1
		_hide_tooltip()

		# Kembalikan pratinjau halaman kanan ke item yang sedang diklik (atau bersihkan jika tidak ada)
		if _selected_slot_index >= 0 and _selected_slot_index < data.inventory.size():
			var sel = data.inventory[_selected_slot_index]
			if sel != null and sel.get("item") != null:
				_display_item_detail(sel["item"], sel["count"], _selected_slot_index)
			else:
				_clear_item_detail()
		else:
			_clear_item_detail()


func _show_item_tooltip(slot_pos: Vector2, item: ItemData, count: int, slot_idx: int) -> void:
	if not is_instance_valid(hover_tooltip):
		return

	var display_title: String = item.display_name if item.display_name != "" else item.item_id
	if count > 1:
		display_title += " (x%d)" % count
	tooltip_title.text = display_title

	# Kategori & status hotbar
	var is_tool := (item.category == ItemData.Category.TOOL)
	var cat_str := ""
	match item.category:
		ItemData.Category.SEED: cat_str = "Bibit Tanaman"
		ItemData.Category.CROP: cat_str = "Hasil Panen"
		ItemData.Category.TOOL: cat_str = "Peralatan Kebun"
		ItemData.Category.MATERIAL: cat_str = "Material Bangunan"
		ItemData.Category.FISH: cat_str = "Ikan"
		ItemData.Category.FORAGE: cat_str = "Hasil Hutan"
		ItemData.Category.EQUIPMENT: cat_str = "Equipment"
		ItemData.Category.BUILDING: cat_str = "Bangunan / Tempatkan dari hotbar"
		_: cat_str = "Item Tas"

	tooltip_category.text = "[%s]" % cat_str

	var is_in_hotbar = (data.hotbar_page * 8) <= slot_idx and slot_idx < ((data.hotbar_page + 1) * 8)
	if is_in_hotbar:
		var hud_idx = (slot_idx % 8) + 1
		tooltip_hotbar.text = "Hotbar #%d (tombol %d)" % [hud_idx, hud_idx]
		tooltip_hotbar.modulate = Color(0.4, 0.85, 0.4, 1.0)
		tooltip_hotbar.show()
	else:
		tooltip_hotbar.text = "Di Tas Penyimpanan"
		tooltip_hotbar.modulate = Color(0.7, 0.7, 0.7, 0.9)
		tooltip_hotbar.show()

	if is_tool:
		tooltip_price.text = (item.action_data.tool_data.ability_text().get_slice("\n", 0) + "\nKlik untuk stat & upgrade") if item.action_data != null and item.action_data.tool_data != null else "Alat (tidak dijual)"
		tooltip_price.modulate = Color(1.0, 0.85, 0.45, 1.0)
		tooltip_price.show()
	elif item.sell_price > 0:
		tooltip_price.text = "Harga jual: %s G" % HUD.format_money(item.sell_price)
		tooltip_price.modulate = Color(1.0, 0.85, 0.45, 1.0)
		tooltip_price.show()
	else:
		tooltip_price.hide()

	# Posisikan tooltip di sebelah kanan/atas slot, pastikan aman dari tepi layar
	hover_tooltip.show()
	var target_pos := slot_pos + Vector2(44, -10)
	var vp_size := get_viewport().get_visible_rect().size
	if target_pos.x + 150 > vp_size.x:
		target_pos.x = slot_pos.x - 160
	if target_pos.y + 70 > vp_size.y:
		target_pos.y = vp_size.y - 80
	if target_pos.y < 10:
		target_pos.y = 10

	hover_tooltip.global_position = target_pos


func _show_simple_tooltip(pos: Vector2, title_text: String, cat_text: String) -> void:
	if not is_instance_valid(hover_tooltip):
		return
	tooltip_title.text = title_text
	tooltip_category.text = cat_text
	tooltip_hotbar.hide()
	tooltip_price.hide()
	hover_tooltip.show()

	var vp_size := get_viewport().get_visible_rect().size
	var target_pos := pos
	if target_pos.x + 140 > vp_size.x:
		target_pos.x = vp_size.x - 150
	if target_pos.y < 10:
		target_pos.y = 10
	hover_tooltip.global_position = target_pos


func _hide_tooltip() -> void:
	if is_instance_valid(hover_tooltip):
		hover_tooltip.hide()


## ── Click & Selection Handling ──────────────────────────────────────────────
func _on_slot_clicked(index: int, button: int) -> void:
	if _drop_dialog_open():
		return
	if button == MOUSE_BUTTON_RIGHT:
		_open_drop_dialog(index)
		return
	if button != MOUSE_BUTTON_LEFT:
		return

	var global_idx := index
	if global_idx < 0 or global_idx >= data.bag_size:
		return

	# Jika belum ada slot yang dipilih
	if _selected_slot_index == -1:
		var slot_data = data.inventory[global_idx]
		if slot_data != null and slot_data.get("item") != null:
			_select_slot(global_idx)
		else:
			_clear_item_detail()
		return

	# Jika mengklik slot yang sama persis -> batalkan seleksi
	if global_idx == _selected_slot_index:
		_clear_item_detail()
		return

	# Jika mengklik slot berbeda -> tukar posisi item (swap)!
	var from_idx := _selected_slot_index
	data.swap_slots(from_idx, global_idx)

	# Pilih slot baru jika terisi
	var new_slot = data.inventory[global_idx]
	if new_slot != null and new_slot.get("item") != null:
		_select_slot(global_idx)
	else:
		_clear_item_detail()


## Setelah tarik-lepas, pilihan pindah ke slot tujuan. Kalau tidak, klik berikutnya
## menukar lagi slot asal (yang tadi tertekan saat mulai menarik) dengan slot yang diklik.
func _on_slot_swapped(_from_idx: int, to_idx: int) -> void:
	if _slot_item(to_idx) != null:
		_select_slot(to_idx)
	else:
		_clear_item_detail()


func _select_slot(global_idx: int) -> void:
	_selected_slot_index = global_idx

	# Perbarui status visual slot
	for i in range(_slots.size()):
		var slot_global := current_page * SLOTS_PER_PAGE + i
		_slots[i].set_selected(slot_global == global_idx)

	var slot_data = data.inventory[global_idx] if global_idx >= 0 and global_idx < data.inventory.size() else null
	if slot_data != null and slot_data.get("item") != null:
		_display_item_detail(slot_data["item"], slot_data["count"], global_idx)
	else:
		_clear_item_detail()
	_update_drop_button()
	_update_hotbar_button()


func _display_item_detail(item: ItemData, count: int, slot_idx: int = -1) -> void:
	if detail_icon:
		detail_icon.texture = item.icon
		detail_icon.show()

	if badge_count:
		badge_count.text = "x%d" % count
	if badge_hotbar:
		if (data.hotbar_page * 8) <= slot_idx and slot_idx < ((data.hotbar_page + 1) * 8):
			var hud_slot_idx = (slot_idx % 8) + 1
			badge_hotbar.text = "Hotbar #%d" % hud_slot_idx
			badge_hotbar.modulate = Color(0.25, 0.6, 0.25, 1.0)
		else:
			badge_hotbar.text = "Di Tas Penyimpanan"
			badge_hotbar.modulate = Color(0.55, 0.38, 0.2, 1.0)

	if detail_title:
		detail_title.text = item.display_name if item.display_name != "" else item.item_id

	if detail_sub:
		var cat_name := "Item Umum"
		match item.category:
			ItemData.Category.SEED: cat_name = "Bibit Tanaman"
			ItemData.Category.CROP: cat_name = "Hasil Panen"
			ItemData.Category.TOOL: cat_name = "Peralatan"
			ItemData.Category.MATERIAL: cat_name = "Bahan"
			ItemData.Category.FISH: cat_name = "Ikan"
			ItemData.Category.FORAGE: cat_name = "Hasil Hutan"
			ItemData.Category.EQUIPMENT: cat_name = "Equipment"
			ItemData.Category.BUILDING: cat_name = "Bangunan"
		detail_sub.text = "[%s]" % cat_name

	if detail_desc:
		var text := item.description
		if text.is_empty():
			if item.category == ItemData.Category.TOOL:
				text = "Gunakan peralatan ini dengan klik kiri saat berada di dekat objek kerja."
			else:
				text = "Item berharga dari perkebunan Nusa Vale."
		if item.action_data != null and item.action_data.tool_data != null:
			var tool := item.action_data.tool_data
			text = tool.ability_text()
			if tool.tool_type == ToolData.ToolType.WATERING_CAN:
				text += "\nSisa air: %d/%d" % [mini(data.watering_water, tool.water_capacity), tool.water_capacity]
			var upgrade := ToolUpgradeManager.get_upgrade_data(item.item_id)
			if not upgrade.is_empty():
				var next := load("res://resources/tool_data/%s.tres" % upgrade["next"]) as ToolData
				text += "\n\nUpgrade: %s (%d G + material)\n%s" % [next.display_name, upgrade["cost"], next.ability_text()]
			else:
				text += "\nTier maksimal."
		detail_desc.text = text

	if price_label:
		if item.category == ItemData.Category.TOOL:
			price_label.text = "Alat"
		elif item.sell_price > 0:
			price_label.text = "Jual %s G" % HUD.format_money(item.sell_price)
		else:
			price_label.text = "Tidak Dijual"


func _clear_item_detail() -> void:
	_selected_slot_index = -1
	for s in _slots:
		s.set_selected(false)

	if detail_icon:
		detail_icon.texture = null
		detail_icon.hide()
	if badge_count:
		badge_count.text = "--"
	if badge_hotbar:
		badge_hotbar.text = "Slot Kosong"
		badge_hotbar.modulate = Color(0.5, 0.4, 0.3)
	if detail_title:
		detail_title.text = "Detail Item"
	if detail_sub:
		detail_sub.text = "Arahkan kursor ke slot"
	if detail_desc:
		if _sell_mode:
			detail_desc.text = "Shipping Bin: klik kanan item untuk memilih jumlah yang dijual."
		else:
			detail_desc.text = "Nama, fungsi, dan harga jual item tampil di sini."
	if price_label:
		price_label.text = ""
	_update_drop_button()
	_update_hotbar_button()


## ── Refresh Inventory & Slider ──────────────────────────────────────────────
func refresh_inventory() -> void:
	if not is_instance_valid(slot_grid):
		return

	# Tampilkan slot untuk halaman saat ini
	for i in range(_slots.size()):
		var global_idx := current_page * SLOTS_PER_PAGE + i
		_slots[i].slot_index = global_idx

		if global_idx >= data.bag_size:
			_slots[i].clear()
			_slots[i].modulate = Color(1, 1, 1, 0.25)
			_slots[i].set_selected(false)
			continue

		var slot_data = data.inventory[global_idx]
		if slot_data != null and slot_data.get("item") != null:
			var item: ItemData = slot_data["item"]
			var count: int = slot_data.get("count", 1)
			_slots[i].set_item(item, count)
			_slots[i].tooltip_text = ""

			# Redupkan jika tidak sesuai filter kategori
			if current_category == ItemData.Category.ALL or item.category == current_category:
				_slots[i].modulate = Color.WHITE
			else:
				_slots[i].modulate = Color(0.4, 0.4, 0.4, 0.45)
		else:
			_slots[i].clear()
			_slots[i].modulate = Color.WHITE

		_slots[i].set_selected(global_idx == _selected_slot_index)

	# Update nomor halaman
	if is_instance_valid(page_label):
		page_label.text = "Halaman %d / %d" % [current_page + 1, total_pages]
	if is_instance_valid(btn_prev_page):
		btn_prev_page.disabled = (current_page == 0)
	if is_instance_valid(btn_next_page):
		btn_next_page.disabled = (current_page >= total_pages - 1)

	# Hitung total item terisi di inventory (hanya dalam bag_size aktif)
	var total_used := 0
	for i in data.bag_size:
		var slot_data = data.inventory[i]
		if slot_data != null and slot_data.get("item") != null:
			total_used += 1

	# Update kapasitas dan posisi slider handle
	if is_instance_valid(capacity_label):
		capacity_label.text = "%d / %d" % [total_used, data.bag_size]

	if is_instance_valid(handle):
		var ratio: float = float(total_used) / float(maxi(1, data.bag_size))
		var target_x: float = lerpf(HANDLE_MIN_X, HANDLE_MAX_X, clampf(ratio, 0.0, 1.0))
		handle.position.x = target_x

	# Update jumlah uang
	if is_instance_valid(gold_label) and GameState:
		gold_label.text = "Uang: %s G" % HUD.format_money(GameState.money)

	# Update detail slot jika ada yang sedang dipilih
	if _selected_slot_index >= 0 and _selected_slot_index < data.inventory.size():
		var sel = data.inventory[_selected_slot_index]
		if sel != null and sel.get("item") != null:
			_display_item_detail(sel["item"], sel["count"], _selected_slot_index)
		else:
			_clear_item_detail()
	_update_hotbar_button()
	_update_status()
	for cat in [ItemData.Category.ALL, ItemData.Category.SEED, ItemData.Category.CROP, ItemData.Category.MATERIAL, ItemData.Category.TOOL, ItemData.Category.FISH, ItemData.Category.FORAGE]:
		var ribbon := _ribbon_for(cat)
		var used := 0
		for index in data.bag_size:
			var item := _slot_item(index)
			if item != null and (cat == ItemData.Category.ALL or item.category == cat):
				used += 1
		ribbon.get_node("SlotCount").text = str(used)
	if is_instance_valid(_equipment_panel) and _equipment_panel.visible:
		_equipment_panel.refresh()
	if is_instance_valid(_crafting_panel) and _crafting_panel.visible:
		_crafting_panel.refresh()


func _on_money_changed(new_amount: int) -> void:
	if is_instance_valid(gold_label):
		gold_label.text = "Uang: %s G" % HUD.format_money(new_amount)

func _on_bag_upgraded(_new_size: int) -> void:
	# Jika halaman saat ini melebihi total halaman baru, reset ke halaman terakhir
	if current_page >= total_pages:
		current_page = total_pages - 1
	refresh_inventory()


## ── Buang Item ──────────────────────────────────────────────────────────────
func _setup_drop_ui() -> void:
	_drop_dialog = DropItemDialogScript.new()
	_drop_dialog.hide()
	_drop_dialog.confirmed.connect(_on_drop_confirmed)
	_drop_dialog.cancelled.connect(_close_drop_dialog)
	add_child(_drop_dialog)

	# Tombol "Buang" menggantikan teks tip di kotak bawah halaman kanan saat item dipilih.
	_tip_label = book_root.get_node_or_null("RightPage/BottomActionBox/Margin/VBox/TipLabel") as Label if book_root else null
	_btn_drop = Button.new()
	_btn_drop.text = "Buang item (klik kanan)"
	_btn_drop.focus_mode = Control.FOCUS_NONE
	_btn_drop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_btn_drop.add_theme_font_override("font", DropItemDialogScript.FONT)
	_btn_drop.add_theme_font_size_override("font_size", 16)
	_btn_drop.add_theme_color_override("font_color", DropItemDialogScript.COLOR_TEXT)
	_btn_drop.add_theme_stylebox_override("normal", _drop_button_style(Color(0.45, 0.16, 0.1, 0.9)))
	_btn_drop.add_theme_stylebox_override("hover", _drop_button_style(Color(0.6, 0.22, 0.12, 0.95)))
	_btn_drop.add_theme_stylebox_override("pressed", _drop_button_style(Color(0.35, 0.12, 0.08, 1.0)))
	_btn_drop.pressed.connect(func(): _open_drop_dialog(_selected_slot_index))
	_btn_drop.hide()
	if _tip_label:
		_tip_label.get_parent().add_child(_btn_drop)
	else:
		add_child(_btn_drop)


func _drop_button_style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = Color(0.9, 0.7, 0.3, 1.0)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_bottom = 1
	return sb


## Alat tidak bisa dibuang/dijual (supaya alat awal tidak hilang). Mode jual: harus punya sell_price.
func _can_drop(item: ItemData) -> bool:
	if item == null or item.category == ItemData.Category.TOOL or item.is_tool():
		return false
	return item.sell_price > 0 if _sell_mode else true


func _slot_item(global_idx: int) -> ItemData:
	if global_idx < 0 or global_idx >= data.bag_size or global_idx >= data.inventory.size():
		return null
	var slot_data = data.inventory[global_idx]
	if slot_data == null:
		return null
	return slot_data.get("item")


func _update_drop_button() -> void:
	if not is_instance_valid(_btn_drop):
		return
	var show_drop := _can_drop(_slot_item(_selected_slot_index))
	_btn_drop.text = "Jual" if _sell_mode else "Buang"
	_btn_drop.visible = show_drop
	if is_instance_valid(_tip_label):
		_tip_label.visible = not show_drop


func _drop_dialog_open() -> bool:
	return is_instance_valid(_drop_dialog) and _drop_dialog.visible


func _open_drop_dialog(global_idx: int) -> void:
	var item := _slot_item(global_idx)
	if item == null:
		return
	if not _can_drop(item):
		if _sell_mode:
			Notify.say("Barang ini tidak bisa dijual.")
		else:
			Notify.say("Alat tidak bisa dibuang.")
		return
	_hide_tooltip()
	_drop_slot_index = global_idx
	var count := int(data.inventory[global_idx].get("count", 1))
	if _sell_mode:
		_drop_dialog.open_for(item, count, "Jual", item.sell_price)
	else:
		_drop_dialog.open_for(item, count)
	# Tengah layar pemain ini, setelah ukuran kotak dihitung.
	_drop_dialog.reset_size()
	var vp_size := get_viewport().get_visible_rect().size
	_drop_dialog.position = ((vp_size - _drop_dialog.size) * 0.5).floor()


func _close_drop_dialog() -> void:
	_drop_slot_index = -1
	if is_instance_valid(_drop_dialog):
		_drop_dialog.hide()


func _on_drop_confirmed(amount: int) -> void:
	var idx := _drop_slot_index
	_close_drop_dialog()
	if _sell_mode:
		sell_from_slot(idx, amount)
	else:
		drop_from_slot(idx, amount)


## Keluarkan item dari slot tas lalu jatuhkan di depan pemain sebagai ItemPickup.
## Barang tidak hilang: bisa dipungut lagi dengan berjalan menjauh lalu melewatinya.
func drop_from_slot(global_idx: int, amount: int) -> bool:
	var item := _slot_item(global_idx)
	if not _can_drop(item):
		return false
	var count: int = int(data.inventory[global_idx].get("count", 1))
	var take := clampi(amount, 1, count)
	if not is_instance_valid(player):
		return false
	if not data.remove_item_at(global_idx, take):
		return false
	ItemPickup.drop_from(player, item.item_id, take, item.icon)
	var item_name: String = item.display_name if item.display_name != "" else item.item_id
	Notify.say("Membuang %d %s" % [take, item_name])
	return true


## Jual sebagian tumpukan lewat Shipping Bin; uang masuk ke uang bersama.
func sell_from_slot(global_idx: int, amount: int) -> bool:
	var item := _slot_item(global_idx)
	if item == null or item.sell_price <= 0 or item.is_tool():
		return false
	var count: int = int(data.inventory[global_idx].get("count", 1))
	var take := clampi(amount, 1, count)
	if not data.remove_item_at(global_idx, take):
		return false
	var earned := item.sell_price * take
	GameState.add_money(earned)
	var item_name: String = item.display_name if item.display_name != "" else item.item_id
	Notify.say("Terjual %s x%d +%s G" % [item_name, take, HUD.format_money(earned)])
	return true
