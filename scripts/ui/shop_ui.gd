class_name ShopUI
extends CanvasLayer

## UI toko gaya Stardew Valley, dibangun lewat kode (tanpa .tscn).
## Kiri: potret penjaga, kotak dialog/deskripsi, uang.
## Kanan: daftar barang (scroll) + grid tas pemain untuk menjual.

const DEFAULT_SHOP := "res://resources/shop/general_store.tres"
const FONT := preload("res://assets/fonts/m5x7.ttf")
const TEX_INVENTORY := preload("res://assets/farm_rpg/ui/inventory/inventory.png")
const TEX_BANNER := preload("res://assets/farm_rpg/ui/inventory/Banner.png")
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
const INVENTORY_COLUMNS := 12
const SLOT_SIZE := 26

const COLOR_TEXT := Color(0.36, 0.2, 0.15)
const COLOR_TEXT_LIGHT := Color(0.97, 0.88, 0.78)
const COLOR_PRICE_BAD := Color(0.75, 0.2, 0.2)
const COLOR_OWNED := Color(0.25, 0.55, 0.25)

var shop_data: ShopData
## Pemain yang membuka toko (diisi ShopCounter). Kosong = P1.
var player: Player
var data: PlayerData:
	get: return player.data if is_instance_valid(player) else GameState.p1()
## Baris yang dipilih pemain tanpa mouse (gamepad / numpad di co-op).
var _pad_index := -1

var _dialog_label: Label
var _money_label: Label
var _list: VBoxContainer
var _inv_grid: GridContainer
var _inv_hint: Label
## Satu entri per baris barang: {"item": ItemData, "panel": PanelContainer, "name": Label, "price": Label}
var _rows: Array[Dictionary] = []
var _hovered_row: PanelContainer
var current_season_filter: String = "all"
var _filter_buttons: Dictionary = {}

func _ready() -> void:
	layer = 20
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
	var ui_theme := Theme.new()
	ui_theme.default_font = FONT
	ui_theme.default_font_size = 16
	ui_theme.set_color("font_color", "Label", COLOR_TEXT)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.theme = ui_theme
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	dim.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 8)
	center.add_child(main)

	main.add_child(_build_left_column())
	main.add_child(_build_right_column())

func _build_left_column() -> VBoxContainer:
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(150, 0)
	left.add_theme_constant_override("separation", 6)

	# Potret penjaga
	var portrait_panel := PanelContainer.new()
	portrait_panel.add_theme_stylebox_override("panel", _style(TEX_INVENTORY, Rect2(7, 9, 18, 18), 4, 6))
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(96, 96)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if shop_data.portrait != null:
		portrait.texture = shop_data.portrait
	else:
		# Siluet sementara sampai ada potret NPC
		var atlas := AtlasTexture.new()
		atlas.atlas = TEX_SILHOUETTE
		atlas.region = Rect2(0, 0, 32, 32)
		portrait.texture = atlas
		portrait.modulate = Color(0.15, 0.08, 0.06, 0.85)
	portrait_panel.add_child(portrait)
	left.add_child(portrait_panel)

	# Nama penjaga
	var name_panel := PanelContainer.new()
	name_panel.add_theme_stylebox_override("panel", _row_style(false))
	var name_label := Label.new()
	name_label.text = shop_data.keeper_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_panel.add_child(name_label)
	left.add_child(name_panel)

	# Kotak dialog / deskripsi barang
	var dialog := PanelContainer.new()
	dialog.custom_minimum_size = Vector2(150, 110)
	dialog.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog.add_theme_stylebox_override("panel", _style(TEX_BANNER, Rect2(0, 0, 48, 48), 8, 10))
	_dialog_label = Label.new()
	_dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_label.custom_minimum_size = Vector2(126, 0)
	_dialog_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	dialog.add_child(_dialog_label)
	left.add_child(dialog)

	# Uang
	var money_panel := PanelContainer.new()
	money_panel.add_theme_stylebox_override("panel", _row_style(true))
	_money_label = Label.new()
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_money_label.add_theme_color_override("font_color", COLOR_TEXT_LIGHT)
	money_panel.add_child(_money_label)
	left.add_child(money_panel)

	_show_greeting()
	return left

func _build_right_column() -> VBoxContainer:
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)

	# Panel daftar barang
	var shop_panel := PanelContainer.new()
	shop_panel.custom_minimum_size = Vector2(470, 0)
	shop_panel.add_theme_stylebox_override("panel", _panel_style())
	var shop_box := VBoxContainer.new()
	shop_box.add_theme_constant_override("separation", 4)
	shop_panel.add_child(shop_box)

	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = shop_data.shop_name
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := TextureButton.new()
	close_btn.texture_normal = TEX_CLOSE
	close_btn.texture_pressed = TEX_CLOSE_PRESSED
	close_btn.ignore_texture_size = true
	close_btn.stretch_mode = TextureButton.STRETCH_SCALE
	close_btn.custom_minimum_size = Vector2(16, 16)
	close_btn.tooltip_text = "Tutup (Esc)"
	close_btn.pressed.connect(close_shop)
	header.add_child(close_btn)
	shop_box.add_child(header)

	var filter_bar := HBoxContainer.new()
	filter_bar.add_theme_constant_override("separation", 4)
	var tabs := [
		{"id": "all", "label": "Semua"},
		{"id": "spring", "label": "Musim Semi"},
		{"id": "summer", "label": "Musim Panas"},
		{"id": "fall", "label": "Musim Gugur"},
		{"id": "other", "label": "Lainnya"}
	]
	for t in tabs:
		var btn := Button.new()
		btn.text = t["label"]
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.pressed.connect(_on_season_tab_pressed.bind(t["id"]))
		filter_bar.add_child(btn)
		_filter_buttons[t["id"]] = btn
	shop_box.add_child(filter_bar)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 170)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shop_box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 3)
	scroll.add_child(_list)

	right.add_child(shop_panel)

	# Panel tas pemain
	var inv_panel := PanelContainer.new()
	inv_panel.add_theme_stylebox_override("panel", _panel_style())
	var inv_box := VBoxContainer.new()
	inv_box.add_theme_constant_override("separation", 4)
	inv_panel.add_child(inv_box)
	_inv_hint = Label.new()
	_inv_hint.text = "Tas - klik untuk jual, Shift+klik jual setumpuk" if shop_data.buys_items else "Tas"
	inv_box.add_child(_inv_hint)
	_inv_grid = GridContainer.new()
	_inv_grid.columns = INVENTORY_COLUMNS
	_inv_grid.add_theme_constant_override("h_separation", 2)
	_inv_grid.add_theme_constant_override("v_separation", 2)
	inv_box.add_child(_inv_grid)
	right.add_child(inv_panel)

	return right

func _build_rows() -> void:
	for item in shop_data.stock:
		if item == null or item.buy_price <= 0:
			continue
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.add_theme_stylebox_override("panel", _row_style(false))

		var hbox := HBoxContainer.new()
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_theme_constant_override("separation", 8)
		panel.add_child(hbox)

		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = item.icon
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(icon)

		var name_label := Label.new()
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.text = item.display_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(name_label)

		var price_label := Label.new()
		price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(price_label)

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

func _on_season_tab_pressed(season_id: String) -> void:
	current_season_filter = season_id
	_refresh_rows()

func _update_season_tab_styles() -> void:
	for id in _filter_buttons:
		var btn: Button = _filter_buttons[id]
		if id == current_season_filter:
			btn.modulate = Color(1.3, 1.2, 0.7, 1.0)
		else:
			btn.modulate = Color(0.8, 0.8, 0.8, 0.9)

func _refresh_rows() -> void:
	_update_season_tab_styles()
	for row in _rows:
		var item: ItemData = row["item"]
		var is_visible := true
		if current_season_filter == "all":
			is_visible = true
		elif current_season_filter == "other":
			is_visible = (item.season == "" or item.season == "all")
		else:
			is_visible = (item.season == current_season_filter)

		row["panel"].visible = is_visible
		if not is_visible:
			continue

		var price_label: Label = row["price"]
		var status := _bag_status(item)
		var hovered: bool = row["panel"] == _hovered_row
		if status == "owned":
			price_label.text = "Sudah dimiliki"
			price_label.add_theme_color_override("font_color", COLOR_OWNED)
			row["panel"].modulate = Color(1, 1, 1, 0.6)
		elif status == "locked":
			price_label.text = "Terkunci"
			price_label.add_theme_color_override("font_color", COLOR_TEXT_LIGHT if hovered else COLOR_TEXT)
			row["panel"].modulate = Color(1, 1, 1, 0.6)
		else:
			price_label.text = "%s G" % _format_money(item.buy_price)
			var affordable := GameState.money >= item.buy_price
			if affordable:
				price_label.add_theme_color_override("font_color", COLOR_TEXT_LIGHT if hovered else COLOR_TEXT)
			else:
				price_label.add_theme_color_override("font_color", COLOR_PRICE_BAD)
			row["panel"].modulate = Color.WHITE if affordable else Color(1, 1, 1, 0.75)

func _refresh_inventory() -> void:
	for child in _inv_grid.get_children():
		child.queue_free()
	for i in data.bag_size:
		_inv_grid.add_child(_make_slot(i))

func _make_slot(index: int) -> PanelContainer:
	var slot_panel := PanelContainer.new()
	slot_panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot_panel.add_theme_stylebox_override("panel", _style(TEX_INVENTORY, Rect2(7, 41, 18, 18), 4, 3))
	slot_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var slot = data.inventory[index]
	if slot == null:
		return slot_panel
	var item: ItemData = slot["item"]

	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = item.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot_panel.add_child(icon)

	var count: int = slot["count"]
	if count > 1:
		var count_label := Label.new()
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_label.text = str(count)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count_label.add_theme_color_override("font_color", Color.WHITE)
		count_label.add_theme_color_override("font_outline_color", Color.BLACK)
		count_label.add_theme_constant_override("outline_size", 4)
		slot_panel.add_child(count_label)

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
		var amount := BUY_SHIFT_AMOUNT if mb.shift_pressed else 1
		_buy(item, amount)
		get_viewport().set_input_as_handled()

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
	var text := "%s%s\n%s" % [item.display_name, season_tag, item.description]
	if not BAG_UPGRADES.has(item.item_id):
		text += "\n\nShift+klik: beli %d" % BUY_SHIFT_AMOUNT
	_dialog_label.text = text

func _on_row_unhover(panel: PanelContainer) -> void:
	if _hovered_row == panel:
		_hovered_row = null
	panel.add_theme_stylebox_override("panel", _row_style(false))
	for row in _rows:
		if row["panel"] == panel:
			row["name"].remove_theme_color_override("font_color")
	_refresh_rows()
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
	var text := "%s\n%s" % [item.display_name, item.description]
	if shop_data.buys_items:
		if _can_sell(item):
			text += "\n\nJual: %s G" % _format_money(item.sell_price)
		else:
			text += "\n\nTidak bisa dijual."
	_dialog_label.text = text

func _show_greeting() -> void:
	_dialog_label.text = shop_data.greeting

# ── Transaksi ───────────────────────────────────────────────────────

func _buy(item: ItemData, amount: int) -> void:
	if BAG_UPGRADES.has(item.item_id):
		_buy_bag_upgrade(item)
		return
	# Shift+klik: beli sebanyak yang terjangkau (maks. amount)
	amount = mini(amount, floori(float(GameState.money) / float(item.buy_price)))
	if amount <= 0:
		Notify.say("Uang tidak cukup!")
		return
	if not _can_fit(item, amount):
		Notify.say("Tas penuh!")
		return
	if data.buy_item(item.item_id, amount):
		Notify.say("Membeli %s x%d" % [item.display_name, amount])

func _buy_bag_upgrade(item: ItemData) -> void:
	match _bag_status(item):
		"owned":
			Notify.say("Tas sudah di-upgrade!")
			return
		"locked":
			Notify.say("Beli upgrade tas sebelumnya dulu.")
			return
	if not GameState.spend_money(item.buy_price):
		Notify.say("Uang tidak cukup!")
		return
	data.upgrade_bag()

func _sell(index: int, whole_stack: bool) -> void:
	var slot = data.inventory[index]
	if slot == null:
		return
	var item: ItemData = slot["item"]
	if not _can_sell(item):
		Notify.say("Barang ini tidak bisa dijual.")
		return
	var amount: int = slot["count"] if whole_stack else 1
	var earned := item.sell_price * amount
	data.remove_item_at(index, amount)
	GameState.add_money(earned)
	Notify.say("Terjual %s x%d +%s G" % [item.display_name, amount, _format_money(earned)])

func _can_sell(item: ItemData) -> bool:
	return item.sell_price > 0 and not item.is_tool()

## "owned" / "locked" / "" (bisa dibeli). Hanya relevan untuk upgrade tas.
func _bag_status(item: ItemData) -> String:
	if not BAG_UPGRADES.has(item.item_id):
		return ""
	var req_level: int = BAG_UPGRADES[item.item_id]
	if data.bag_level >= req_level:
		return "owned"
	if data.bag_level < req_level - 1:
		return "locked"
	return ""

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

func _on_inventory_changed() -> void:
	_refresh_rows()
	_refresh_inventory()

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

func _row_style(dark: bool) -> StyleBoxTexture:
	var region := Rect2(5, 145, 38, 15) if dark else Rect2(5, 113, 38, 15)
	var sb := _style(TEX_BANNER, region, 5, 4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	return sb

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
			_buy(row["item"], 1)
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
		if _rows[index]["panel"].visible:
			break
	if not old.is_empty():
		_on_row_unhover(old["panel"])
	_pad_index = index
	var row := _pad_row()
	_on_row_hover(row["panel"], row["item"])
	var scroll := row["panel"].get_parent().get_parent() as ScrollContainer
	if scroll != null:
		scroll.ensure_control_visible(row["panel"])

func close_shop() -> void:
	Coop.set_menu_open(player, false)
	queue_free()
