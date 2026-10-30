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
@onready var detail_desc: Control = %DetailDesc
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
@export_range(1.0, 2.0) var inventory_scale := 1.5

const TEX_TAB_NORMAL := preload("res://assets/ui/inventory_top_tab_normal.svg")
const TEX_TAB_ACTIVE := preload("res://assets/ui/inventory_top_tab_active.svg")
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

## Buang item: node scene untuk pilihan jumlah dan tombol aksi.
var _drop_dialog: DropItemDialogScript
var _drop_slot_index: int = -1
var _consume_button: Button
var _consume_dialog: ConfirmationDialog
var _consume_slot := -1
var _consume_id := ""
var _btn_drop: Button
var _tip_label: Label
## Mode jual (dibuka dari Shipping Bin): kotak jumlah menjual, bukan membuang.
var _sell_mode: bool = false
var _rpg_menu: Control
var _top_tabs: Array[TextureButton] = []
var _menu_buttons: Dictionary = {}
var _status_panel: PanelContainer
var _status_text: Control
var _btn_hotbar: Button
var _collection_panel: PanelContainer
var _btn_sort: Button
var _equipment_panel: PanelContainer
var _controls_panel: PanelContainer
var _settings_panel: PanelContainer
var _crafting_panel: PanelContainer
## Tab Keahlian (Role & EXP, GDD 13).
var _skill_tree: Control
var _relationship_ui: Control

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

	if is_instance_valid(hover_tooltip):
		hover_tooltip.hide()

	get_viewport().size_changed.connect(_resize_inventory)
	_resize_inventory()
	_setup_top_tabs()
	_setup_right_ribbons()
	_setup_pagination()
	_setup_close_button()
	_create_slots()
	_setup_drop_ui()
	_setup_daya_ui()
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
	_menu_buttons = {"Tas": tab_book, "Status": %TabStatus, "Equipment": %TabEquipment, "Crafting": %TabCrafting, "Keahlian": %TabSkills, "NPC": %TabNPC, "Koleksi": tab_collection}
	_top_tabs.assign([tab_book, %TabStatus, %TabEquipment, %TabCrafting, %TabSkills, %TabNPC, tab_collection, tab_gear, %TabControls])
	for index in _top_tabs.size():
		_top_tabs[index].position.x = index * 38
	for tab in _top_tabs:
		_setup_tab_hover(tab, tab.tooltip_text)
	%TabStatus.pressed.connect(_show_status)
	%TabEquipment.pressed.connect(_show_equipment)
	%TabCrafting.pressed.connect(_show_crafting)
	%TabSkills.pressed.connect(_show_skills)
	%TabNPC.pressed.connect(_show_relationships)
	_controls_panel = %ControlsPage
	%TabControls.pressed.connect(_show_controls)
	_settings_panel = %SettingsPage
	_status_panel = %StatusPage
	_status_text = _status_panel.get_node("%StatusText")
	_equipment_panel = %EquipmentPage
	_crafting_panel = %CraftingPage
	_collection_panel = %CollectionPage
	_skill_tree = %SkillTreePage
	_relationship_ui = %RelationshipPage
	for page in [_equipment_panel, _crafting_panel, _skill_tree, _relationship_ui, _settings_panel, _controls_panel]:
		page.inventory_ui = self
	_btn_sort = %SortButton
	_btn_sort.pressed.connect(_sort_bag)
	_btn_hotbar = %HotbarButton
	_btn_hotbar.pressed.connect(_activate_hotbar_item)
	_update_hotbar_button()
	_update_menu_highlight()


func _show_bag_page() -> void:
	if not is_instance_valid(_status_panel):
		return
	_status_panel.hide()
	_equipment_panel.hide()
	_collection_panel.hide()
	_crafting_panel.hide()
	_skill_tree.hide()
	_relationship_ui.hide()
	_settings_panel.hide()
	_controls_panel.hide()
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
	_skill_tree.hide()
	_relationship_ui.hide()
	_settings_panel.hide()
	_controls_panel.hide()
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
	_status_text.text = "%s\n\nHP: %d / %d\nStamina: %d / %d\nDEF: %d\nTas: %d / %d slot\nUang: %s G\nNilai jual isi tas: %s G\n\nHari %d - %s" % [name_text, data.hp, data.max_hp, data.stamina, data.max_stamina, Combat.player_defense(data), used, data.bag_size, HUD.format_money(GameState.money), HUD.format_money(value), DayCycle.current_day, DayCycle.get_season_display_name()]
	var levels: PackedStringArray = []
	for role in SkillSystem.roles():
		levels.append("%s · Lv %d\n%d EXP" % [role.title, data.skills.level(role.role_id), data.skills.get_points(role.role_id)])
	_status_panel.get_node("%RoleLevels").text = "\n\n".join(levels)


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
	elif is_instance_valid(_skill_tree) and _skill_tree.visible:
		active = _menu_buttons["Keahlian"]
	if is_instance_valid(_relationship_ui) and _relationship_ui.visible:
		active = _menu_buttons["NPC"]
	if is_instance_valid(_settings_panel) and _settings_panel.visible:
		active = tab_gear
	if is_instance_valid(_controls_panel) and _controls_panel.visible:
		active = %TabControls
	_highlight_top_tab(active)


func _show_collection() -> void:
	if _drop_dialog_open():
		return
	_hide_tooltip()
	_clear_item_detail()
	_status_panel.hide()
	_equipment_panel.hide()
	_crafting_panel.hide()
	_skill_tree.hide()
	_relationship_ui.hide()
	_settings_panel.hide()
	_controls_panel.hide()
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
	_skill_tree.hide()
	_relationship_ui.hide()
	_settings_panel.hide()
	_controls_panel.hide()
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
	for panel in [_status_panel, _equipment_panel, _collection_panel, _skill_tree, _relationship_ui, _settings_panel, _controls_panel]:
		panel.hide()
	for path in ["LeftPage", "RightPage", "RightRibbonsContainer"]:
		book_root.get_node(path).hide()
	_crafting_panel.show()
	_crafting_panel.refresh()
	_update_menu_highlight()


func _show_relationships() -> void:
	_show_embedded_page(_relationship_ui)


func _show_controls() -> void:
	if Coop.active and data.index != 0:
		Notify.say("Pengaturan kontrol bersama hanya dapat dibuka P1.")
		return
	_show_embedded_page(_controls_panel)


func _show_skills() -> void:
	_show_embedded_page(_skill_tree)


func _show_embedded_page(page: Control) -> void:
	if _drop_dialog_open():
		return
	_hide_tooltip()
	_clear_item_detail()
	for panel in [_status_panel, _equipment_panel, _collection_panel, _crafting_panel, _skill_tree, _relationship_ui, _settings_panel, _controls_panel]:
		panel.hide()
	for path in ["LeftPage", "RightPage", "RightRibbonsContainer"]:
		book_root.get_node(path).hide()
	page.show()
	page.refresh()
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
	if tab.has_meta("compact_tab_hover"):
		return
	tab.set_meta("compact_tab_hover", true)
	tab.mouse_entered.connect(func():
		_layout_top_tab(tab, tab.texture_normal == TEX_TAB_ACTIVE, true)
		tab.modulate = Color(1.08, 1.05, 1.0))
	tab.mouse_exited.connect(func():
		_layout_top_tab(tab, tab.texture_normal == TEX_TAB_ACTIVE)
		tab.modulate = Color.WHITE
		_hide_tooltip())

func _layout_top_tab(tab: TextureButton, active: bool, hovered := false) -> void:
	var top := 0.0 if active else (3.0 if hovered else 6.0)
	tab.position.y = top
	tab.size = Vector2(38, 42 - top)
	tab.z_index = 1 if active else 0


func _on_gear_pressed() -> void:
	if _drop_dialog_open():
		return
	# Co-op P2-P4: halaman ini hanya menampilkan setelan pribadi (Skala UI).
	_show_embedded_page(_settings_panel)


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
	for tab in _top_tabs:
		if is_instance_valid(tab):
			var active := tab == active_tab
			tab.texture_normal = TEX_TAB_ACTIVE if active else TEX_TAB_NORMAL
			tab.modulate = Color.WHITE
			_layout_top_tab(tab, active)


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
	var settings_page: PanelContainer = _controls_panel if is_instance_valid(_controls_panel) and _controls_panel.visible else _settings_panel
	if visible and is_instance_valid(settings_page) and settings_page.visible:
		if settings_page.capture_input(event):
			get_viewport().set_input_as_handled()
			return
		var backend: SettingsMenu = settings_page._backend
		if backend != null and (is_instance_valid(backend._slot_menu) or backend._exit_dialog.visible):
			return

	if StructureManager.has_menu(data.index):
		return
	# Selama menu pengaturan (tab gear) terbuka, Esc menutup menu itu dulu, bukan tas.
	var settings = get_parent().get_node_or_null("SettingsMenu")
	if settings and settings.visible:
		return
	var input := _owner_input()
	if visible and _relationship_ui.visible and _relationship_ui._detail_open and input.is_event(event, &"ui_cancel"):
		_relationship_ui._show_residents()
		get_viewport().set_input_as_handled()
		return
	if visible and _relationship_ui.visible and _relationship_ui.get_node("%Search").has_focus() and input.is_event(event, &"inventory"):
		return
	if is_instance_valid(_consume_dialog) and _consume_dialog.visible:
		if input.is_event(event, &"ui_cancel") or input.is_event(event, &"inventory"):
			_consume_dialog.hide()
			get_viewport().set_input_as_handled()
		return
	# Esc menutup dialog buang lebih dulu sebelum menutup tas.
	if visible and _drop_dialog_open() and input.is_event(event, &"ui_cancel"):
		_close_drop_dialog()
		get_viewport().set_input_as_handled()
	elif input.is_event(event, &"crafting_menu"):
		# Y gamepad (seperti Stardew Valley): buka tas langsung di tab Crafting.
		if visible and _crafting_panel.visible:
			_close()
		elif visible:
			_show_crafting()
		elif _can_open_now():
			_open()
			_show_crafting()
		else:
			return
		get_viewport().set_input_as_handled()
	elif visible and event is InputEventJoypadButton and not _drop_dialog_open() \
			and (input.is_event(event, &"tool_prev") or input.is_event(event, &"tool_next")):
		# LB/RB di dalam tas berpindah tab, seperti menu Stardew Valley.
		_cycle_tab(-1 if input.is_event(event, &"tool_prev") else 1)
		get_viewport().set_input_as_handled()
	elif input.is_event(event, &"inventory") or (not visible and input.is_event(event, &"ui_cancel")):
		if not visible and not _can_open_now():
			return
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and input.is_event(event, &"ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()



## ── Open / Close ────────────────────────────────────────────────────────────
## Tas boleh dibuka: game tidak dijeda, dan (co-op) pemain ini tidak sedang di toko/pindah area/tidur.
func _can_open_now() -> bool:
	if get_tree().paused:
		return false
	return not (is_instance_valid(player) and player.is_input_locked())


## Pindah halaman buku; tab Kontrol hanya untuk P1 saat co-op (Setelan P2-P4 = skala UI saja).
func _cycle_tab(step: int) -> void:
	var tabs: Array[TextureButton] = []
	for t in _top_tabs:
		if is_instance_valid(t) and (t != %TabControls or not Coop.active or data.index == 0):
			tabs.append(t)
	if tabs.is_empty():
		return
	var current: TextureButton = tab_book
	if _status_panel.visible:
		current = _menu_buttons["Status"]
	elif _collection_panel.visible:
		current = tab_collection
	elif _equipment_panel.visible:
		current = _menu_buttons["Equipment"]
	elif _crafting_panel.visible:
		current = _menu_buttons["Crafting"]
	elif _skill_tree.visible:
		current = _menu_buttons["Keahlian"]
	if _relationship_ui.visible:
		current = _menu_buttons["NPC"]
	if _settings_panel.visible:
		current = tab_gear
	if _controls_panel.visible:
		current = %TabControls
	var idx := maxi(tabs.find(current), 0)
	tabs[posmod(idx + step, tabs.size())].pressed.emit()

func toggle() -> void:
	if visible:
		_close()
	else:
		_open()


func _open() -> void:
	_show_bag_page()
	tab_gear.tooltip_text = "Atur skala UI layarmu (setelan bersama hanya P1)" if Coop.active and data.index != 0 else "Buka pengaturan layar, audio, dan permainan"
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
	_skill_tree.hide()
	_relationship_ui.hide()
	_settings_panel.hide()
	_controls_panel.hide()
	if is_instance_valid(_consume_dialog):
		_consume_dialog.hide()
	_close_drop_dialog()
	_sell_mode = false
	_hide_tooltip()
	hide()
	Coop.set_menu_open(player, false)


## ── Inventory Slots Creation ────────────────────────────────────────────────
func _create_slots() -> void:
	_slots.clear()
	for i in slot_grid.get_child_count():
		var slot := slot_grid.get_child(i) as InventorySlotUI
		slot.slot_index = i
		slot.owner_ui = self
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.slot_hovered.connect(_on_slot_hovered)
		slot.slot_unhovered.connect(_on_slot_unhovered)
		slot.slot_swapped.connect(_on_slot_swapped)
		_slots.append(slot)


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
		var right_item := _slot_item(index) if not _sell_mode else null
		if right_item != null and right_item.is_edible() and is_instance_valid(player):
			_eat_from_slot(index)
		else:
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
			ItemData.Category.FOOD: cat_name = "Makanan"
		detail_sub.text = "[%s]" % cat_name

	if detail_desc:
		var text := item.description
		if item.is_edible():
			text += "\n" + item.food_summary() + "\nKlik kanan: makan"
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
			detail_desc.text = "Shipping Bin: klik kanan untuk menitipkan barang. Uang diterima setelah tidur."
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

	_update_drop_button()
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
	if is_instance_valid(_skill_tree) and _skill_tree.visible:
		_skill_tree.refresh()


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
	_drop_dialog = %DropDialog
	_drop_dialog.confirmed.connect(_on_drop_confirmed)
	_drop_dialog.cancelled.connect(_close_drop_dialog)
	_tip_label = get_node_or_null("%TipLabel")
	_btn_drop = %DropButton
	_btn_drop.pressed.connect(func(): _open_drop_dialog(_selected_slot_index))


## Alat tidak bisa dibuang/dijual (supaya alat awal tidak hilang). Mode jual: harus punya sell_price.
func _can_drop(item: ItemData) -> bool:
	if item != null and item.item_id.begins_with("biji_daya_"):
		return false
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
	if is_instance_valid(_consume_button):
		var selected := _slot_item(_selected_slot_index)
		_consume_button.visible = not _sell_mode and selected != null and selected.item_id.begins_with("biji_daya_")
	var show_drop := _can_drop(_slot_item(_selected_slot_index))
	_btn_drop.text = "Titip" if _sell_mode else "Buang"
	_btn_drop.visible = show_drop
	if is_instance_valid(_tip_label):
		_tip_label.visible = not show_drop


## Klik kanan slot makanan: makan satu. Efek makan dimainkan pada pemain di balik buku tas,
## slotnya sendiri ikut memantul.
func _eat_from_slot(global_idx: int) -> void:
	if not FoodEating.eat(player, global_idx).ok:
		return
	refresh_inventory()
	if global_idx == _selected_slot_index and _slot_item(global_idx) == null:
		_clear_item_detail()
	for slot in _slots:
		if slot.slot_index != global_idx:
			continue
		slot.pivot_offset = slot.size * 0.5
		slot.scale = Vector2(1.18, 0.86)
		var tw := slot.create_tween()
		tw.tween_property(slot, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		break


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
		_drop_dialog.open_for(item, count, "Titip", item.sell_price)
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


## Titip sebagian tumpukan; pembayaran masuk ke uang bersama pada hari berikutnya.
func sell_from_slot(global_idx: int, amount: int) -> bool:
	var item := _slot_item(global_idx)
	if item == null or item.sell_price <= 0 or item.is_tool():
		return false
	var count: int = int(data.inventory[global_idx].get("count", 1))
	var take := clampi(amount, 1, count)
	if not data.remove_item_at(global_idx, take):
		return false
	var earned := SkillSystem.sell_price(data, item, true) * take
	GameState.shipping.deposit(item, take, data)
	var item_name: String = item.display_name if item.display_name != "" else item.item_id
	Notify.say("Dititipkan %s x%d (%s G). Dibayar setelah tidur." % [item_name, take, HUD.format_money(earned)])
	return true


func _setup_daya_ui() -> void:
	_consume_dialog = %ConsumeDialog
	_consume_dialog.confirmed.connect(_consume_daya)
	_consume_button = %ConsumeButton
	_consume_button.pressed.connect(func():
		var item := _slot_item(_selected_slot_index)
		if item == null or not item.item_id.begins_with("biji_daya_"):
			return
		_consume_slot = _selected_slot_index
		_consume_id = item.item_id.trim_prefix("biji_daya_")
		_consume_dialog.popup_centered())

func _consume_daya() -> void:
	var entry: Variant = data.inventory[_consume_slot] if _consume_slot >= 0 and _consume_slot < data.bag_size else null
	var icon: Texture2D = entry.item.icon if entry is Dictionary and entry.get("item") is ItemData else null
	if not visible or _sell_mode or not GameState.daya.consume(data, _consume_slot, _consume_id):
		return
	_close()
	if is_instance_valid(player):
		var glow := Node2D.new()
		glow.scale = Vector2(0.6, 0.6)
		player.add_child(glow)
		player.set_input_locked(&"daya", true)
		var seed := Sprite2D.new()
		seed.texture = icon
		seed.position = Vector2(0, -18)
		glow.add_child(seed)
		for direction in [-1, 1]:
			var root := Line2D.new()
			root.width = 2.0
			root.default_color = Color("ffe6a0")
			root.points = PackedVector2Array([Vector2(0, -10), Vector2(direction * 6, -17), Vector2(direction * 3, -24), Vector2(direction * 10, -30)])
			glow.add_child(root)
		var tween := glow.create_tween()
		tween.tween_property(glow, "scale", Vector2.ONE, 0.65)
		tween.parallel().tween_property(glow, "modulate:a", 0.0, 0.85)
		tween.tween_callback(func():
			if is_instance_valid(player):
				player.set_input_locked(&"daya", false)
			glow.queue_free())


func _resize_inventory() -> void:
	var view := get_viewport().get_visible_rect().size
	# Include the category ribbons and top tabs when fitting split-screen viewports.
	var fit := minf(inventory_scale, minf((view.x - 24.0) / 620.0, (view.y - 24.0) / 420.0))
	# Skala bulat (1.5x/1x) bila hampir muat, supaya piksel buku tetap rata di split screen.
	for step in [inventory_scale, 1.0]:
		if fit < step and fit >= step - 0.05:
			fit = step
			break
	book_root.scale = Vector2.ONE * maxf(0.1, fit)
