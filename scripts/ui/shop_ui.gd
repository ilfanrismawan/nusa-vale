class_name ShopUI
extends CanvasLayer

const STOCK := [
	{"item_id": "seed_strawberry", "price": 15},
	{"item_id": "seed_carrot", "price": 25},
]

## Item yang merupakan upgrade tas — penanganan khusus saat dibeli
const BAG_UPGRADES := {
	"backpack_medium": 1,   # unlock bag_level 1 (24 slot)
	"backpack_large": 2,    # unlock bag_level 2 (36 slot)
}

var _money_label: Label
var _list: VBoxContainer

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var ui_theme := Theme.new()
	ui_theme.default_font = preload("res://assets/fonts/m5x7.ttf")
	ui_theme.default_font_size = 16
	dim.theme = ui_theme
	
	var center := CenterContainer.new()
	dim.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var panel := PanelContainer.new()
	center.add_child(panel)
	
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(280, 0)
	panel.add_child(box)
	
	var title := Label.new()
	title.text = "Toko"
	box.add_child(title)
	
	_money_label = Label.new()
	box.add_child(_money_label)
	
	_list = VBoxContainer.new()
	box.add_child(_list)
	
	var close_btn := Button.new()
	close_btn.text = "Tutup (Esc)"
	close_btn.pressed.connect(close_shop)
	box.add_child(close_btn)
	
	GameState.money_changed.connect(_on_money_changed)
	_refresh()
	get_tree().paused = true
	
func _on_money_changed(_amount: int) -> void:
	_refresh()

func _refresh() -> void:
	_money_label.text = "Uang: %d G" % GameState.money
	for child in _list.get_children():
		child.queue_free()

	# ── Item biasa ──────────────────────────────────────────────────
	for entry in STOCK:
		var item: ItemData = load("res://resources/item_data/%s.tres" % entry["item_id"])
		if item == null:
			continue
		var price: int = entry.get("price", item.buy_price)
		if price <= 0:
			price = item.buy_price
		var row := _make_row(item.display_name, price, func(): _buy(entry["item_id"], price))
		_list.add_child(row)

	# ── Upgrade Tas ─────────────────────────────────────────────────
	var sep := HSeparator.new()
	_list.add_child(sep)
	var bag_title := Label.new()
	bag_title.text = "── Upgrade Tas ──"
	bag_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list.add_child(bag_title)

	var bag_entries := [
		{"item_id": "backpack_medium", "price": 2000, "level": 1, "label": "Ransel (24 slot)"},
		{"item_id": "backpack_large",  "price": 10000, "level": 2, "label": "Ransel Besar (36 slot)"},
	]
	for entry in bag_entries:
		var req_level: int = entry["level"]
		var row: HBoxContainer
		if GameState.bag_level >= req_level:
			# Sudah dimiliki — tampilkan status saja
			row = _make_row(entry["label"], 0, Callable(), "✓ Sudah dimiliki")
		elif GameState.bag_level < req_level - 1:
			# Belum bisa dibeli (level sebelumnya belum diupgrade)
			row = _make_row(entry["label"], entry["price"], Callable(), "Beli upgrade sebelumnya dulu")
		else:
			# Bisa dibeli
			row = _make_row(entry["label"], entry["price"],
				func(): _buy_bag_upgrade(entry["item_id"], entry["price"], req_level))
		_list.add_child(row)

func _make_row(label_text: String, price: int, on_buy: Callable, status: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	var price_str := " — %d G" % price if price > 0 else ""
	label.text = label_text + price_str
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	if status != "":
		var lbl := Label.new()
		lbl.text = status
		lbl.modulate = Color(0.6, 0.9, 0.6) if status.begins_with("✓") else Color(0.7, 0.7, 0.7)
		row.add_child(lbl)
	elif on_buy.is_valid():
		var btn := Button.new()
		btn.text = "Beli"
		btn.disabled = GameState.money < price
		btn.pressed.connect(on_buy)
		row.add_child(btn)
	return row

func _buy(item_id: String, price: int) -> void:
	if not GameState.buy_item(item_id, 1):
		print("Tidak bisa membeli.")
	_refresh()
		
func _buy_bag_upgrade(item_id: String, price: int, req_level: int) -> void:
	if GameState.bag_level >= req_level:
		Notify.say("Tas sudah di-upgrade!")
		return
	if not GameState.spend_money(price):
		Notify.say("Uang tidak cukup!")
		return
	GameState.upgrade_bag()
	_refresh()
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		close_shop()
		get_viewport().set_input_as_handled()
		
func close_shop() -> void:
	get_tree().paused = false
	queue_free()
