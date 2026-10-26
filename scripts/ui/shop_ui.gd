class_name ShopUI
extends CanvasLayer

const ServiceTheme = preload("res://scripts/ui/farm_service_theme.gd")

@export var presentation_scene: PackedScene = preload("res://scenes/ui/shop_book.tscn")
@export var catalog_card_scene: PackedScene = preload("res://scenes/ui/shop_catalog_row.tscn")
@export var inventory_slot_scene: PackedScene = preload("res://scenes/ui/shop_inventory_slot.tscn")
@export var design_size := Vector2(1280, 720)
@export var card_normal: StyleBox = preload("res://resources/ui/shop_card_normal.tres")
@export var card_selected: StyleBox = preload("res://resources/ui/shop_card_selected.tres")

## Presentasi toko diedit di scenes/ui/shop_book.tscn.
## Script hanya mengikat data, navigasi halaman, dan transaksi.

const DEFAULT_SHOP := "res://resources/shop/general_store.tres"
const FONT := preload("res://resources/ui/readable_font.tres")
const TEX_INVENTORY := preload("res://assets/farm_rpg/ui/inventory/inventory.png")
const TEX_BANNER := preload("res://assets/farm_rpg/ui/Banner.png")
const TEX_CLOSE := preload("res://resources/ui/btn_close_x.tres")
const TEX_CLOSE_PRESSED := preload("res://resources/ui/btn_close_x_pressed.tres")
const TEX_SILHOUETTE := preload("res://assets/farm_rpg/Character/PNG/Portrait.png")

## Item yang merupakan upgrade tas — dibeli sekali, menaikkan bag_level.
const BAG_UPGRADES := {
	"backpack_medium": 1,   # unlock bag_level 1 (24 slot)
	"backpack_large": 2,    # unlock bag_level 2 (36 slot)
}

## Shift+klik membeli sebanyak ini sekaligus (seperti Stardew).
const BUY_SHIFT_AMOUNT := 5
const INVENTORY_COLUMNS := 6
const SLOT_SIZE := 26

const COLOR_TEXT := Color(0.36, 0.2, 0.15)
const COLOR_TEXT_LIGHT := Color(0.36, 0.2, 0.15)
const COLOR_PRICE_BAD := Color(0.75, 0.2, 0.2)
const COLOR_OWNED := Color(0.25, 0.55, 0.25)

var shop_data: ShopData
## Pemain yang membuka toko (diisi ShopCounter). Kosong = P1.
var player: Player
var data: PlayerData:
	get: return player.data if is_instance_valid(player) else GameState.p1()
## Baris yang dipilih pemain tanpa mouse (gamepad / numpad di co-op).
var _pad_index := -1

var _dialog_label: Control
var _money_label: Label
var _list: Container
var _inv_grid: GridContainer
var _inv_hint: Label
## Satu entri per baris barang: {"item": ItemData, "panel": PanelContainer, "name": Label, "price": Label}
var _rows: Array[Dictionary] = []
var _hovered_row: PanelContainer
var current_season_filter: String = "all"
var _filter_buttons: Dictionary = {}
var _quantity: SpinBox
var _purchase_button: Button
var _purchase_summary: Label
var _selected_item: ItemData
var _closed := false
var _catalog_page := 0
var _inventory_page := 0
var _catalog_page_label: Label
var _inventory_page_label: Label
var _detail_icon: TextureRect
var _detail_name: Label
var _empty: Label
var _catalog_previous: Button
var _catalog_next: Button

func _ready() -> void:
	layer = ServiceTheme.LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	if shop_data == null:
		shop_data = load(DEFAULT_SHOP) as ShopData

	if DayCycle and DayCycle.has_method("get_current_season"):
		current_season_filter = DayCycle.get_current_season()

	_build_ui()
	_build_rows()
	_refresh()

	GameState.money_changed.connect(_on_money_changed)
	GameState.inventory_changed.connect(_on_inventory_changed)
	Coop.set_menu_open(player, true)
	if not _owner_input().uses_mouse():
		_move_pad_cursor(1)

# ── Membangun UI ────────────────────────────────────────────────────

func _build_ui() -> void:
	var book := presentation_scene.instantiate()
	add_child(book)
	var main: Control = book.get_node("Book")
	_list = book.get_node("Book/Stock")
	_inv_grid = book.get_node("Book/Inventory")
	_dialog_label = book.get_node("Book/Description")
	_money_label = book.get_node("Book/Money")
	_inv_hint = book.get_node("Book/InventoryHint")
	_quantity = book.get_node("Book/Quantity")
	_purchase_button = book.get_node("Book/Buy")
	_purchase_summary = book.get_node("Book/Summary")
	_catalog_page_label = book.get_node("Book/CatalogPage")
	_inventory_page_label = book.get_node("Book/InventoryPage")
	_detail_icon = book.get_node("Book/SelectedIcon")
	_detail_name = book.get_node("Book/SelectedName")
	_empty = book.get_node("Book/Empty")
	_catalog_previous = book.get_node("Book/CatalogPrevious")
	_catalog_next = book.get_node("Book/CatalogNext")
	book.get_node("Book/Title").text = shop_data.shop_name
	book.get_node("Book/Keeper").text = shop_data.keeper_name
	book.get_node("Book/Greeting").text = shop_data.greeting
	var portrait: TextureRect = book.get_node("Book/Portrait")
	if shop_data.portrait != null:
		portrait.texture = ServiceTheme.portrait(shop_data.portrait)
	_inv_hint.text = "Tas · klik jual 1, Shift+klik jual setumpuk" if shop_data.buys_items else "Isi tas · toko ini tidak menerima penjualan"
	for button in book.get_node("Book/Filters").get_children():
		var id: String = button.get_meta("season")
		_filter_buttons[id] = button
		button.pressed.connect(_on_season_tab_pressed.bind(id))
	book.get_node("Book/Close").pressed.connect(close_shop)
	book.get_node("Book/CatalogPrevious").pressed.connect(_change_catalog_page.bind(-1))
	book.get_node("Book/CatalogNext").pressed.connect(_change_catalog_page.bind(1))
	book.get_node("Book/InventoryPrevious").pressed.connect(_change_inventory_page.bind(-1))
	book.get_node("Book/InventoryNext").pressed.connect(_change_inventory_page.bind(1))
	_quantity.value_changed.connect(func(_value: float): _refresh_purchase())
	_purchase_button.pressed.connect(_purchase_selected)
	var fit := func():
		var view := get_viewport().get_visible_rect().size
		main.scale = Vector2.ONE * minf(view.x / design_size.x, view.y / design_size.y)
		main.position = ((view - design_size * main.scale) / 2).floor()
	get_viewport().size_changed.connect(fit)
	main.tree_exiting.connect(func():
		if get_viewport().size_changed.is_connected(fit):
			get_viewport().size_changed.disconnect(fit), CONNECT_ONE_SHOT)
	fit.call()
	_show_greeting()

func _matches_filter(item: ItemData) -> bool:
	if current_season_filter == "all": return true
	if current_season_filter == "other": return item.season.is_empty() or item.season == "all"
	return item.season == current_season_filter

func _change_catalog_page(direction: int) -> void:
	_catalog_page += direction
	_refresh_rows()

func _change_inventory_page(direction: int) -> void:
	_inventory_page = wrapi(_inventory_page + direction, 0, maxi(1, ceili(data.bag_size / 12.0)))
	_refresh_inventory()

func _build_rows() -> void:
	for item in SkillSystem.shop_stock(data, shop_data):
		if item == null or item.buy_price <= 0:
			continue
		var panel: PanelContainer = catalog_card_scene.instantiate()
		var icon: TextureRect = panel.get_node("Row/Icon")
		icon.texture = item.icon
		var name_label: Label = panel.get_node("Row/Name")
		name_label.text = item.display_name
		var price_label: Label = panel.get_node("Row/Price")
		panel.gui_input.connect(_on_row_input.bind(item))
		panel.mouse_entered.connect(_on_row_hover.bind(panel, item))
		panel.mouse_exited.connect(_on_row_unhover.bind(panel))
		_list.add_child(panel)
		_rows.append({"item": item, "panel": panel, "name": name_label, "price": price_label})

# ── Refresh ─────────────────────────────────────────────────────────

func _refresh() -> void:
	_money_label.text = "%s G" % _format_money(GameState.money)
	_refresh_rows()
	_refresh_inventory()
	_refresh_purchase()

func _on_season_tab_pressed(season_id: String) -> void:
	current_season_filter = season_id
	_catalog_page = 0
	_pad_index = -1
	_selected_item = null
	_refresh_rows()
	_refresh_purchase()
	_show_greeting()

func _update_season_tab_styles() -> void:
	for id in _filter_buttons:
		var btn: Button = _filter_buttons[id]
		btn.set_pressed_no_signal(id == current_season_filter)

func _refresh_rows() -> void:
	_update_season_tab_styles()
	var count := 0
	for row in _rows:
		if _matches_filter(row["item"]): count += 1
	var pages := maxi(1, ceili(count / 6.0))
	_empty.visible = count == 0
	_catalog_previous.disabled = pages <= 1
	_catalog_next.disabled = pages <= 1
	_catalog_page = wrapi(_catalog_page, 0, pages)
	_catalog_page_label.text = "%d / %d" % [_catalog_page + 1, pages]
	var matched := 0
	for row in _rows:
		var item: ItemData = row["item"]
		var matches := _matches_filter(item)
		row["panel"].visible = matches and matched / 6 == _catalog_page
		if matches: matched += 1
		if not row["panel"].visible: continue
		var price_label: Label = row["price"]
		var status := _bag_status(item)
		var hovered: bool = row["panel"] == _hovered_row
		hovered = hovered or item == _selected_item
		row["panel"].add_theme_stylebox_override("panel", _row_style(hovered))
		row["name"].add_theme_color_override("font_color", COLOR_TEXT_LIGHT if hovered else COLOR_TEXT)
		if status == "owned":
			price_label.text = "Sudah dimiliki"
			price_label.add_theme_color_override("font_color", COLOR_OWNED)
			row["panel"].modulate = Color(1, 1, 1, 0.6)
		elif status == "locked":
			price_label.text = "Terkunci"
			price_label.add_theme_color_override("font_color", COLOR_TEXT_LIGHT if hovered else COLOR_TEXT)
			row["panel"].modulate = Color(1, 1, 1, 0.6)
		else:
			price_label.text = "%s G" % _format_money(_unit_price(item, 1))
			var affordable := GameState.money >= _unit_price(item, 1)
			if affordable:
				price_label.add_theme_color_override("font_color", COLOR_TEXT_LIGHT if hovered else COLOR_TEXT)
			else:
				price_label.add_theme_color_override("font_color", COLOR_PRICE_BAD)
			row["panel"].modulate = Color.WHITE if affordable else Color(1, 1, 1, 0.75)

func _refresh_inventory() -> void:
	for child in _inv_grid.get_children():
		_inv_grid.remove_child(child)
		child.queue_free()
	_inventory_page_label.text = "%d / %d" % [_inventory_page + 1, maxi(1, ceili(data.bag_size / 12.0))]
	for i in range(_inventory_page * 12, mini(data.bag_size, (_inventory_page + 1) * 12)):
		_inv_grid.add_child(_make_slot(i))

func _make_slot(index: int) -> PanelContainer:
	var slot_panel: PanelContainer = inventory_slot_scene.instantiate()
	var slot = data.inventory[index]
	if slot == null: return slot_panel
	var item: ItemData = slot["item"]
	slot_panel.get_node("Icon").texture = item.icon
	var count: int = slot["count"]
	slot_panel.get_node("Count").text = str(count) if count > 1 else ""
	if shop_data.buys_items and not _can_sell(item):
		slot_panel.modulate = Color(1, 1, 1, 0.45)

	slot_panel.gui_input.connect(_on_slot_input.bind(index))
	slot_panel.mouse_entered.connect(_on_slot_hover.bind(index))
	slot_panel.mouse_exited.connect(_show_greeting)
	return slot_panel

# ── Input baris & slot ──────────────────────────────────────────────

func _on_row_input(event: InputEvent, item: ItemData) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_selected_item = item
		_quantity.value = BUY_SHIFT_AMOUNT if mb.shift_pressed and not _single_purchase(item) else 1
		_refresh_purchase()
		_refresh_rows()
		_show_greeting()
		get_viewport().set_input_as_handled()

func _refresh_purchase() -> void:
	if _purchase_button == null: return
	if _selected_item == null:
		_purchase_summary.text = "Pilih barang, lalu tentukan jumlah."
		_purchase_button.disabled = true
		_quantity.editable = false
		_purchase_button.text = "Pilih barang dahulu"
		return
	var item := _selected_item
	var bag_upgrade := _single_purchase(item)
	_quantity.editable = not bag_upgrade
	if bag_upgrade: _quantity.value = 1
	var count := int(_quantity.value)
	var total := _unit_price(item, count) * count
	var available := _bag_status(item).is_empty() and GameState.money >= total and ((bag_upgrade and item.vehicle == null) or _can_fit(item, count))
	_purchase_summary.text = "%d barang · Total %s G" % [count, _format_money(total)]
	if not available:
		var status := _bag_status(item)
		_purchase_summary.text += "\n" + ("Sudah dimiliki" if status == "owned" else "Persyaratan belum terpenuhi" if status == "locked" else "Uang kurang" if GameState.money < total else "Tas penuh")
	_purchase_button.text = "Beli · %s G" % _format_money(total)
	_purchase_button.disabled = not available

func _purchase_selected() -> void:
	if _selected_item == null or _purchase_button.disabled: return
	_buy(_selected_item, int(_quantity.value))
	_refresh_purchase()

func _on_row_hover(panel: PanelContainer, item: ItemData) -> void:
	_hovered_row = panel
	panel.add_theme_stylebox_override("panel", _row_style(true))
	for row in _rows:
		if row["panel"] == panel:
			row["name"].add_theme_color_override("font_color", COLOR_TEXT_LIGHT)
	var season_tag := ""
	match item.season:
		"spring": season_tag = " (Musim Semi)"
		"summer": season_tag = " (Musim Panas)"
		"fall": season_tag = " (Musim Gugur)"
		"winter": season_tag = " (Musim Dingin)"
	var text := "%s\n%s" % [season_tag.strip_edges(), item.description] if not season_tag.is_empty() else item.description
	if not BAG_UPGRADES.has(item.item_id):
		text += "\n\nKlik untuk memilih. Atur jumlah, lalu tekan Beli."
	_dialog_label.text = text
	_show_detail_item(item)

func _on_row_unhover(panel: PanelContainer) -> void:
	if _hovered_row == panel:
		_hovered_row = null
	panel.add_theme_stylebox_override("panel", _row_style(false))
	for row in _rows:
		if row["panel"] == panel:
			row["name"].remove_theme_color_override("font_color")
	_refresh_rows()
	_refresh_purchase()
	_show_greeting()

func _on_slot_input(event: InputEvent, index: int) -> void:
	if not shop_data.buys_items:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_sell(index, mb.shift_pressed)
		get_viewport().set_input_as_handled()

func _on_slot_hover(index: int) -> void:
	var slot = data.inventory[index]
	if slot == null:
		_show_greeting()
		return
	var item: ItemData = slot["item"]
	var text := item.description
	if shop_data.buys_items:
		if _can_sell(item):
			text += "\n\nJual: %s G" % _format_money(SkillSystem.sell_price(data, item, false))
		else:
			text += "\n\nTidak bisa dijual."
	_dialog_label.text = text
	_show_detail_item(item)

func _show_greeting() -> void:
	_dialog_label.text = _selected_item.description if _selected_item != null else shop_data.greeting
	_show_detail_item(_selected_item)

func _show_detail_item(item: ItemData) -> void:
	_detail_icon.texture = item.icon if item != null else null
	_detail_name.text = item.display_name if item != null else "Pilih kebutuhanmu"

# ── Transaksi ───────────────────────────────────────────────────────

func _buy(item: ItemData, amount: int) -> void:
	if BAG_UPGRADES.has(item.item_id):
		_buy_bag_upgrade(item)
		return
	if not item.requires_item_id.is_empty():
		_buy_trade_in(item)
		return
	if item.vehicle != null:
		match _bag_status(item):
			"owned":
				Notify.say("%s sudah dimiliki." % item.display_name)
				return
			"locked":
				Notify.say("%s belum bisa dibeli." % item.display_name)
				return
		amount = 1
	# Shift+klik: beli sebanyak yang terjangkau (maks. amount)
	amount = mini(amount, floori(float(GameState.money) / float(_unit_price(item, amount))))
	if amount <= 0:
		Notify.say("Uang tidak cukup!")
		return
	if not _can_fit(item, amount):
		Notify.say("Tas penuh!")
		return
	var unit := _unit_price(item, amount)
	if data.buy_item(item.item_id, amount, unit):
		Notify.say("Membeli %s x%d" % [item.display_name, amount])
		_merchant_exp(unit * amount)

func _buy_bag_upgrade(item: ItemData) -> void:
	match _bag_status(item):
		"owned":
			Notify.say("Tas sudah di-upgrade!")
			return
		"locked":
			Notify.say("Beli upgrade tas sebelumnya dulu.")
			return
	var price := _unit_price(item, 1)
	if not GameState.spend_money(price):
		Notify.say("Uang tidak cukup!")
		return
	data.upgrade_bag()
	_merchant_exp(price)

## Jaring serangga tier berikutnya (GDD 7): butuh jaring sebelumnya di tas, lalu ditukar di slot yang sama.
func _buy_trade_in(item: ItemData) -> void:
	match _bag_status(item):
		"owned":
			Notify.say("%s sudah dimiliki." % item.display_name)
			return
		"locked":
			var needed := GameState._resolve_item(item.requires_item_id)
			Notify.say("Butuh %s di tas untuk membeli ini." % (needed.display_name if needed else item.requires_item_id))
			return
	var price := _unit_price(item, 1)
	if not GameState.spend_money(price):
		Notify.say("Uang tidak cukup!")
		return
	if not data.replace_tool(item.requires_item_id, item.item_id):
		GameState.add_money(price)
		return
	_merchant_exp(price)
	Notify.say("%s ditukar dengan %s!" % [GameState._resolve_item(item.requires_item_id).display_name, item.display_name])

func _sell(index: int, whole_stack: bool) -> void:
	var slot = data.inventory[index]
	if slot == null:
		return
	var item: ItemData = slot["item"]
	if not _can_sell(item):
		Notify.say("Barang ini tidak bisa dijual.")
		return
	var amount: int = slot["count"] if whole_stack else 1
	var earned := SkillSystem.sell_price(data, item, false) * amount
	data.remove_item_at(index, amount)
	GameState.add_money(earned)
	_merchant_exp(earned)
	Notify.say("Terjual %s x%d +%s G" % [item.display_name, amount, _format_money(earned)])

## Harga beli per unit setelah perk Merchant (GDD 13): diskon toko, grosir bibit, diskon upgrade tas.
func _unit_price(item: ItemData, count: int) -> int:
	if BAG_UPGRADES.has(item.item_id):
		return SkillSystem.facility_price(data, item.buy_price)
	return SkillSystem.buy_price(data, item, count, item.buy_price)

func _merchant_exp(gold: int) -> void:
	SkillSystem.gain_from_value(data, &"merchant", gold, SkillSystem.RULES.shop_gold_per_exp, SkillSystem.RULES.shop_exp_max)

func _can_sell(item: ItemData) -> bool:
	return item.sell_price > 0 and not item.is_tool()

## "owned" / "locked" / "" (bisa dibeli). Untuk upgrade tas dan barang tukar-tambah (requires_item_id).
func _bag_status(item: ItemData) -> String:
	if item.vehicle != null:
		if not Vehicles.is_unlocked(item.vehicle, data):
			return "locked"
		return "owned" if data.has_item(item.item_id) else ""
	if not item.requires_item_id.is_empty():
		return _trade_in_status(item)
	if not BAG_UPGRADES.has(item.item_id):
		return ""
	var req_level: int = BAG_UPGRADES[item.item_id]
	if data.bag_level >= req_level:
		return "owned"
	if data.bag_level < req_level - 1:
		return "locked"
	return ""

## "owned" bila tas sudah berisi alat sejenis dengan tier sama atau lebih tinggi,
## "locked" bila item syaratnya (tier sebelumnya) belum ada di tas.
func _trade_in_status(item: ItemData) -> String:
	var wanted := item.action_data.tool_data if item.action_data != null else null
	for i in data.bag_size:
		var slot = data.inventory[i]
		if slot == null:
			continue
		var owned: ItemData = slot["item"]
		if owned.item_id == item.item_id:
			return "owned"
		var tool := owned.action_data.tool_data if owned.action_data != null else null
		if wanted != null and tool != null and tool.tool_type == wanted.tool_type and int(tool.tier) > int(wanted.tier):
			return "owned"
	return "" if data.has_item(item.requires_item_id) else "locked"

## Dibeli satu per satu: upgrade tas, tukar-tambah jaring, kendaraan (GDD 10).
func _single_purchase(item: ItemData) -> bool:
	return BAG_UPGRADES.has(item.item_id) or not item.requires_item_id.is_empty() or item.vehicle != null

## Cek ruang di tas aktif sebelum membeli, supaya uang tidak terpotong sia-sia.
func _can_fit(item: ItemData, amount: int) -> bool:
	var per_slot: int = item.max_stack if item.stackable else 1
	var space := 0
	for i in data.bag_size:
		var slot = data.inventory[i]
		if slot == null:
			space += per_slot
		elif item.stackable and slot["item"].item_id == item.item_id:
			space += item.max_stack - int(slot["count"])
		if space >= amount:
			return true
	return false

# ── Signal ──────────────────────────────────────────────────────────

func _on_money_changed(_amount: int) -> void:
	_money_label.text = "%s G" % _format_money(GameState.money)
	_refresh_rows()
	_refresh_purchase()

func _on_inventory_changed() -> void:
	_refresh_rows()
	_refresh_inventory()
	_refresh_purchase()

# ── Helper gaya ─────────────────────────────────────────────────────

func _style(tex: Texture2D, region: Rect2, tex_margin: int, content_margin: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.region_rect = region
	sb.set_texture_margin_all(tex_margin)
	sb.set_content_margin_all(content_margin)
	return sb

func _panel_style() -> StyleBoxTexture:
	return _style(TEX_INVENTORY, Rect2(0, 64, 48, 48), 8, 10)

func _row_style(dark: bool) -> StyleBox:
	return card_selected if dark else card_normal

func _format_money(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "." + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out

# ── Tutup ───────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	var input := _owner_input()
	if input.is_event(event, &"ui_cancel"):
		close_shop()
		get_viewport().set_input_as_handled()
	elif not input.uses_mouse() and (input.is_event(event, &"ui_accept") or input.is_event(event, &"use_tool")):
		var row := _pad_row()
		if not row.is_empty():
			if _selected_item == row["item"]:
				_purchase_selected()
			else:
				_selected_item = row["item"]
				_quantity.value = 1
				_refresh_purchase()
		get_viewport().set_input_as_handled()

## Atas/bawah memilih barang untuk pemain tanpa mouse (A = beli 1, B = tutup).
func _process(_delta: float) -> void:
	var input := _owner_input()
	if input.uses_mouse():
		return
	if input.just_pressed(&"move_down"):
		_move_pad_cursor(1)
	elif input.just_pressed(&"move_up"):
		_move_pad_cursor(-1)
	elif input.just_pressed(&"move_right") and _quantity.editable:
		_quantity.value += 1
	elif input.just_pressed(&"move_left") and _quantity.editable:
		_quantity.value -= 1

func _owner_input() -> PlayerInput:
	return player.input if is_instance_valid(player) else PlayerInput.solo()

func _pad_row() -> Dictionary:
	if _pad_index < 0 or _pad_index >= _rows.size():
		return {}
	return _rows[_pad_index]

func _move_pad_cursor(step: int) -> void:
	if _rows.is_empty():
		return
	var old := _pad_row()
	var index := _pad_index
	for i in _rows.size():
		index = wrapi(index + step, 0, _rows.size())
		if _matches_filter(_rows[index]["item"]):
			break
	if not old.is_empty():
		_on_row_unhover(old["panel"])
	_pad_index = index
	var row := _pad_row()
	_on_row_hover(row["panel"], row["item"])
	_selected_item = row["item"]
	_quantity.value = 1
	_refresh_purchase()
	_refresh_rows()
	var matched := 0
	for entry in _rows:
		if not _matches_filter(entry["item"]): continue
		if entry == row: break
		matched += 1
	_catalog_page = matched / 6
	_refresh_rows()

func close_shop() -> void:
	if _closed: return
	_closed = true
	hide()
	set_process_input(false)
	Coop.set_menu_open(player, false)
	queue_free()

func _exit_tree() -> void:
	if not _closed: Coop.set_menu_open(player, false)
