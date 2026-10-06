extends CanvasLayer

## ── Node References ─────────────────────────────────────────────────────────
@onready var dimmer: ColorRect = %Dimmer
@onready var book_root: Control = %BookRoot

# Top Tabs
@onready var tab_swords: TextureButton = %TabSwords
@onready var tab_book: TextureButton = %TabBook
@onready var tab_gear: TextureButton = %TabGear
@onready var tab_save: TextureButton = %TabSave

# Right Ribbons
@onready var ribbon_red: TextureButton = %RibbonRed
@onready var ribbon_blue: TextureButton = %RibbonBlue
@onready var ribbon_green: TextureButton = %RibbonGreen
@onready var ribbon_orange: TextureButton = %RibbonOrange
@onready var ribbon_tan: TextureButton = %RibbonTan

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

const SLOTS_PER_PAGE: int = 12
## TOTAL_PAGES dihitung dinamis dari bag_size
var total_pages: int:
	get: return ceili(float(GameState.bag_size) / float(SLOTS_PER_PAGE))

var _slots: Array[InventorySlotUI] = []
var current_category: ItemData.Category = ItemData.Category.ALL
var current_page: int = 0
var _selected_slot_index: int = -1
var _hovered_slot_index: int = -1

# Slider bounds in 1x scale
const HANDLE_MIN_X: float = 4.0
const HANDLE_MAX_X: float = 52.0

## ── Lifecycle ───────────────────────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

	if is_instance_valid(hover_tooltip):
		hover_tooltip.hide()

	_setup_top_tabs()
	_setup_right_ribbons()
	_setup_pagination()
	_setup_close_button()
	_create_slots()

	if GameState:
		GameState.inventory_changed.connect(refresh_inventory)
		GameState.money_changed.connect(_on_money_changed)
		GameState.bag_upgraded.connect(_on_bag_upgraded)

	refresh_inventory()
	_clear_item_detail()


## ── Top Tabs Setup ──────────────────────────────────────────────────────────
func _setup_top_tabs() -> void:
	if tab_swords:
		tab_swords.pressed.connect(func(): _set_category(ItemData.Category.TOOL, tab_swords))
		_setup_tab_hover(tab_swords, "Peralatan & Senjata")
	if tab_book:
		tab_book.pressed.connect(func(): _set_category(ItemData.Category.ALL, tab_book))
		_setup_tab_hover(tab_book, "Semua Item")
	if tab_gear:
		tab_gear.pressed.connect(_on_gear_pressed)
		_setup_tab_hover(tab_gear, "Pengaturan Game")
	if tab_save:
		tab_save.pressed.connect(_on_save_pressed)
		_setup_tab_hover(tab_save, "Simpan Permainan")

	_highlight_top_tab(tab_book)


func _setup_tab_hover(tab: TextureButton, hover_hint: String) -> void:
	tab.mouse_entered.connect(func():
		if tab.texture_normal != TEX_TAB_ACTIVE:
			tab.position.y = 4.0 # Angkat sedikit saat di-hover
		_show_simple_tooltip(tab.global_position + Vector2(0, -36), hover_hint, "[Menu Tab]")
	)
	tab.mouse_exited.connect(func():
		if tab.texture_normal != TEX_TAB_ACTIVE:
			tab.position.y = 8.0
		_hide_tooltip()
	)


func _on_gear_pressed() -> void:
	_hide_tooltip()
	var settings = get_parent().get_node_or_null("SettingsMenu")
	if settings:
		settings.toggle()


func _on_save_pressed() -> void:
	_hide_tooltip()
	if SaveManager:
		SaveManager.save_game()
		if detail_desc:
			detail_desc.text = "✓ Permainan berhasil disimpan (Hari %d, %02d:%02d)!" % [
				DayCycle.current_day,
				DayCycle.hour,
				DayCycle.minute
			]
		if is_instance_valid(tab_save):
			var tw := create_tween()
			tw.tween_property(tab_save, "position:y", 0.0, 0.1)
			tw.tween_property(tab_save, "position:y", 8.0, 0.1)


func _set_category(cat: ItemData.Category, active_tab: TextureButton = null) -> void:
	current_category = cat
	if active_tab:
		_highlight_top_tab(active_tab)
	refresh_inventory()
	_clear_item_detail()


func _highlight_top_tab(active_tab: TextureButton) -> void:
	var tabs: Array[TextureButton] = [tab_swords, tab_book, tab_gear, tab_save]
	for t in tabs:
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
		{"btn": ribbon_tan, "cat": ItemData.Category.TOOL, "title": "Peralatan Kerja", "tag": "Alat Petani"}
	]

	for data in ribbon_data:
		var btn: TextureButton = data["btn"]
		var cat: ItemData.Category = data["cat"]
		var r_title: String = data["title"]
		var r_tag: String = data["tag"]
		if is_instance_valid(btn):
			btn.pressed.connect(func(): _on_ribbon_selected(cat, btn))
			btn.mouse_entered.connect(func():
				btn.position.x = 6.0
				_show_simple_tooltip(btn.global_position + Vector2(60, 0), r_title, "[%s]" % r_tag)
			)
			btn.mouse_exited.connect(func():
				if current_category != cat:
					btn.position.x = 0.0
				_hide_tooltip()
			)


func _on_ribbon_selected(cat: ItemData.Category, active_ribbon: TextureButton) -> void:
	current_category = cat
	_highlight_ribbon(active_ribbon)
	refresh_inventory()
	_clear_item_detail()


func _highlight_ribbon(active_ribbon: TextureButton) -> void:
	var ribbons: Array[TextureButton] = [ribbon_red, ribbon_blue, ribbon_green, ribbon_orange, ribbon_tan]
	for r in ribbons:
		if is_instance_valid(r):
			if r == active_ribbon:
				r.position.x = 6.0 # Geser keluar ke kanan
				r.modulate = Color(1.15, 1.15, 1.15, 1.0)
			else:
				r.position.x = 0.0
				r.modulate = Color(0.9, 0.9, 0.9, 0.95)


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
	elif visible and event is InputEventMouseButton and event.pressed:
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
	refresh_inventory()
	_clear_item_detail()
	_hide_tooltip()
	show()
	get_tree().paused = true


func _close() -> void:
	_hide_tooltip()
	hide()
	get_tree().paused = false


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
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.slot_hovered.connect(_on_slot_hovered)
		slot.slot_unhovered.connect(_on_slot_unhovered)
		slot_grid.add_child(slot)
		_slots.append(slot)


## ── Hover Visual & Tooltip Handling ─────────────────────────────────────────
func _on_slot_hovered(global_idx: int, slot_ui: InventorySlotUI) -> void:
	_hovered_slot_index = global_idx

	if global_idx < 0 or global_idx >= GameState.inventory.size():
		_hide_tooltip()
		return

	var slot_data = GameState.inventory[global_idx]
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
		if _selected_slot_index >= 0 and _selected_slot_index < GameState.inventory.size():
			var sel = GameState.inventory[_selected_slot_index]
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
		_: cat_str = "Item Tas"

	tooltip_category.text = "[%s]" % cat_str

	var is_in_hotbar = (GameState.hotbar_page * 8) <= slot_idx and slot_idx < ((GameState.hotbar_page + 1) * 8)
	if is_in_hotbar:
		var hud_idx = (slot_idx % 8) + 1
		tooltip_hotbar.text = "HUD Slot #%d (Tekan'%d')" % [hud_idx, hud_idx]
		tooltip_hotbar.modulate = Color(0.4, 0.85, 0.4, 1.0)
		tooltip_hotbar.show()
	else:
		tooltip_hotbar.text = "Di Tas Penyimpanan"
		tooltip_hotbar.modulate = Color(0.7, 0.7, 0.7, 0.9)
		tooltip_hotbar.show()

	if is_tool:
		tooltip_price.text = "Alat Utama Kebun (Tidak Dijual)"
		tooltip_price.modulate = Color(1.0, 0.85, 0.45, 1.0)
		tooltip_price.show()
	elif item.sell_price > 0:
		tooltip_price.text = "Harga Jual: %d G per buah" % item.sell_price
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
	if button != MOUSE_BUTTON_LEFT:
		return

	var global_idx := index
	if global_idx < 0 or global_idx >= GameState.INVENTORY_SIZE:
		return

	# Jika belum ada slot yang dipilih
	if _selected_slot_index == -1:
		var slot_data = GameState.inventory[global_idx]
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
	GameState.swap_slots(from_idx, global_idx)

	# Pilih slot baru jika terisi
	var new_slot = GameState.inventory[global_idx]
	if new_slot != null and new_slot.get("item") != null:
		_select_slot(global_idx)
	else:
		_clear_item_detail()


func _select_slot(global_idx: int) -> void:
	_selected_slot_index = global_idx

	# Perbarui status visual slot
	for i in range(_slots.size()):
		var slot_global := current_page * SLOTS_PER_PAGE + i
		_slots[i].set_selected(slot_global == global_idx)

	var slot_data = GameState.inventory[global_idx] if global_idx >= 0 and global_idx < GameState.inventory.size() else null
	if slot_data != null and slot_data.get("item") != null:
		_display_item_detail(slot_data["item"], slot_data["count"], global_idx)
	else:
		_clear_item_detail()


func _display_item_detail(item: ItemData, count: int, slot_idx: int = -1) -> void:
	if detail_icon:
		detail_icon.texture = item.icon
		detail_icon.show()

	if badge_count:
		badge_count.text = "Jumlah: %d" % count
	if badge_hotbar:
		if (GameState.hotbar_page * 8) <= slot_idx and slot_idx < ((GameState.hotbar_page + 1) * 8):
			var hud_slot_idx = (slot_idx % 8) + 1
			badge_hotbar.text = "HUD Slot #%d (Tombol %d)" % [hud_slot_idx, hud_slot_idx]
			badge_hotbar.modulate = Color(0.25, 0.6, 0.25, 1.0)
		else:
			badge_hotbar.text = "Di Tas Penyimpanan"
			badge_hotbar.modulate = Color(0.55, 0.38, 0.2, 1.0)

	if detail_title:
		detail_title.text = item.display_name if item.display_name != "" else item.item_id

	if detail_sub:
		var cat_name := "Item Umum"
		match item.category:
			ItemData.Category.SEED: cat_name = "Bibit Tanaman Musim Ini"
			ItemData.Category.CROP: cat_name = "Hasil Panen Perkebunan"
			ItemData.Category.TOOL: cat_name = "Peralatan Bertani Nusa Vale"
			ItemData.Category.MATERIAL: cat_name = "Bahan & Sumber Daya Alam"
		detail_sub.text = "[%s]" % cat_name

	if detail_desc:
		var text := item.description
		if text.is_empty():
			if item.category == ItemData.Category.TOOL:
				text = "Gunakan peralatan ini dengan klik kiri saat berada di dekat objek kerja."
			else:
				text = "Item berharga dari perkebunan Nusa Vale."
		detail_desc.text = text

	if price_label:
		if item.category == ItemData.Category.TOOL:
			price_label.text = "Peralatan Penting"
		elif item.sell_price > 0:
			price_label.text = "Harga Jual: %d G" % item.sell_price
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
		badge_count.text = "Pilih Item"
	if badge_hotbar:
		badge_hotbar.text = "Slot Kosong"
		badge_hotbar.modulate = Color(0.5, 0.4, 0.3)
	if detail_title:
		detail_title.text = "Detail Item & Perkakas"
	if detail_sub:
		detail_sub.text = "Arahkan kursor atau klik slot untuk info"
	if detail_desc:
		detail_desc.text = "Arahkan kursor ke perkakas atau hasil panen untuk melihat nama, fungsi, dan harga jual secara jelas."
	if price_label:
		price_label.text = ""


## ── Refresh Inventory & Slider ──────────────────────────────────────────────
func refresh_inventory() -> void:
	if not is_instance_valid(slot_grid):
		return

	# Tampilkan slot untuk halaman saat ini
	for i in range(_slots.size()):
		var global_idx := current_page * SLOTS_PER_PAGE + i
		_slots[i].slot_index = global_idx

		if global_idx >= GameState.inventory.size():
			_slots[i].clear()
			_slots[i].modulate = Color(1, 1, 1, 0.25)
			_slots[i].set_selected(false)
			continue

		var slot_data = GameState.inventory[global_idx]
		if slot_data != null and slot_data.get("item") != null:
			var item: ItemData = slot_data["item"]
			var count: int = slot_data.get("count", 1)
			_slots[i].set_item(item, count)

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
	for i in GameState.bag_size:
		var slot_data = GameState.inventory[i]
		if slot_data != null and slot_data.get("item") != null:
			total_used += 1

	# Update kapasitas dan posisi slider handle
	if is_instance_valid(capacity_label):
		capacity_label.text = "%d / %d" % [total_used, GameState.bag_size]

	if is_instance_valid(handle):
		var ratio: float = float(total_used) / float(maxi(1, GameState.bag_size))
		var target_x: float = lerpf(HANDLE_MIN_X, HANDLE_MAX_X, clampf(ratio, 0.0, 1.0))
		handle.position.x = target_x

	# Update jumlah uang
	if is_instance_valid(gold_label) and GameState:
		gold_label.text = "Uang: %d G" % GameState.money

	# Update detail slot jika ada yang sedang dipilih
	if _selected_slot_index >= 0 and _selected_slot_index < GameState.inventory.size():
		var sel = GameState.inventory[_selected_slot_index]
		if sel != null and sel.get("item") != null:
			_display_item_detail(sel["item"], sel["count"], _selected_slot_index)
		else:
			_clear_item_detail()


func _on_money_changed(new_amount: int) -> void:
	if is_instance_valid(gold_label):
		gold_label.text = "Uang: %d G" % new_amount

func _on_bag_upgraded(_new_size: int) -> void:
	# Jika halaman saat ini melebihi total halaman baru, reset ke halaman terakhir
	if current_page >= total_pages:
		current_page = total_pages - 1
	refresh_inventory()
