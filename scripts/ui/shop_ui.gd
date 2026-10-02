class_name ShopUI
extends CanvasLayer

const STOCK := [
	{"item_id": "seed_strawberry", "price": 15} 
]

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
	box.custom_minimum_size = Vector2(220, 0)
	panel.add_child(box)
	
	var title := Label.new()
	title.text = "Toko Bibit"
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
		child.free()
	for entry in STOCK:
		var item: ItemData = load("res://resources/item_data/%s.tres" % entry["item_id"])
		if item == null:
			continue
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s %d G" % [item.display_name, entry["price"]]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var btn := Button.new()
		btn.text = "Beli"
		btn.disabled = GameState.money < entry["price"]
		btn.pressed.connect(_buy.bind(entry["item_id"], entry["price"]))
		row.add_child(label)
		row.add_child(btn)
		_list.add_child(row)

func _buy(item_id: String, _price: int) -> void:
	if not GameState.buy_item(item_id, 1):
		print("Tidak bisa membeli.")
		
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		close_shop()
		get_viewport().set_input_as_handled()
		
func close_shop() -> void:
	get_tree().paused = false
	queue_free()
