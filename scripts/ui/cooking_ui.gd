extends CanvasLayer
const ServiceTheme = preload("res://scripts/ui/farm_service_theme.gd")
var player: Player
var _rows: VBoxContainer
var _status: Label
var _closed := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = ServiceTheme.LAYER
	var panel := PanelContainer.new()
	add_child(panel)
	var layout := VBoxContainer.new()
	panel.add_child(layout)
	var title := Label.new()
	title.text = "DAPUR WARUNG MAKAN\nBahan dari tasmu · Resep dipelajari per pemain"
	layout.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 270
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_status)
	var close_button := Button.new()
	close_button.text = "Tutup"
	close_button.pressed.connect(_close)
	layout.add_child(close_button)
	ServiceTheme.mount(self, panel, Vector2(580, 400))
	Coop.set_menu_open(player, true)
	GameState.inventory_changed.connect(_refresh)
	GameState.money_changed.connect(_money_changed)
	_refresh()

func _money_changed(_money: int) -> void:
	_refresh()

func _refresh() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for id in CookingManager.RECIPES:
		var recipe: Dictionary = CookingManager.RECIPES[id]
		var item := GameState._resolve_item(id)
		var row := VBoxContainer.new()
		_rows.add_child(row)
		var info := Label.new()
		info.text = "%s · +%d stamina%s" % [recipe.name, item.stamina_restore, " · Laju +15% / 60 detik" if item.speed_buff_seconds > 0 else ""]
		row.add_child(info)
		var ingredients := Label.new()
		var text: PackedStringArray = []
		var enough := true
		for ingredient in recipe.ingredients:
			var count := player.data.get_item_count(ingredient)
			var required := int(recipe.ingredients[ingredient])
			text.append("%s %d/%d" % [GameState._resolve_item(ingredient).display_name, count, required])
			enough = enough and count >= required
		ingredients.text = " · ".join(text)
		row.add_child(ingredients)
		var button := Button.new()
		button.icon = item.icon
		if CookingManager.knows(player.data, id):
			button.text = "Masak satu"
			button.disabled = not enough
			button.pressed.connect(_act.bind(id, false))
		else:
			button.text = "Beli buku resep · %d G" % int(recipe.book)
			button.disabled = GameState.money < int(recipe.book)
			button.pressed.connect(_act.bind(id, true))
		row.add_child(button)

func _act(id: String, learn: bool) -> void:
	var result := CookingManager.learn(player.data, id) if learn else CookingManager.cook(player.data, id)
	_refresh()
	_status.text = result.message

func _input(event: InputEvent) -> void:
	if player.input.is_event(event, &"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	if _closed:
		return
	_closed = true
	Coop.set_menu_open(player, false)
	queue_free()

func _exit_tree() -> void:
	if not _closed and is_instance_valid(player):
		Coop.set_menu_open(player, false)
