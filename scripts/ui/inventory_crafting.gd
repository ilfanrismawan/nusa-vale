extends PanelContainer

const FONT = preload("res://assets/fonts/m5x7.ttf")
const GROUPS := ["Semua", "Equipment", "Amunisi", "Bangunan"]
const INK := Color("50321f")
const GREEN := Color("356444")
const RED := Color("983f30")
var inventory_ui: CanvasLayer
var _selected: CraftingRecipe
var _group := "Semua"
var _list: GridContainer
var _recipe_buttons: Array[Button] = []
var _filters: Array[Button] = []
var _icon: TextureRect
var _title: Label
var _description: Label
var _summary: Label
var _materials: VBoxContainer
var _quantity: SpinBox
var _craft_button: Button
var _message: Label

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var ui_theme := Theme.new()
	ui_theme.default_font = FONT
	ui_theme.default_font_size = 16
	ui_theme.set_color("font_color", "Label", INK)
	theme = ui_theme
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var canvas := Control.new()
	add_child(canvas)
	var catalog := _paper(canvas, Rect2(0, 0, 194, 248), Color("ecd1a0"))
	var detail := _paper(canvas, Rect2(214, 0, 206, 248), Color("f3dfb8"))
	var spine := ColorRect.new()
	spine.color = Color("b5874f", 0.4)
	_place(canvas, spine, Rect2(203, 6, 2, 236))
	spine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var heading := _label("RESEP CRAFTING", 20)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(catalog, heading, Rect2(6, 4, 182, 22))
	for i in GROUPS.size():
		var button := _button("Perlengkapan" if GROUPS[i] == "Equipment" else GROUPS[i])
		button.toggle_mode = true
		button.pressed.connect(_select_group.bind(GROUPS[i]))
		_place(catalog, button, Rect2(10 + (i % 2) * 88, 29 + (i / 2) * 24, 84, 22))
		_filters.append(button)
	_summary = _label("", 14)
	_place(catalog, _summary, Rect2(10, 77, 174, 16))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_place(catalog, scroll, Rect2(10, 96, 174, 132))
	_list = GridContainer.new()
	_list.columns = 4
	_list.add_theme_constant_override("h_separation", 4)
	_list.add_theme_constant_override("v_separation", 4)
	scroll.add_child(_list)
	var hint := _label("Pilih ikon untuk melihat resep", 12)
	_place(catalog, hint, Rect2(10, 231, 178, 14))
	var hero := _paper(detail, Rect2(8, 8, 190, 54), Color("dfba7d"))
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_place(hero, _icon, Rect2(6, 4, 46, 46))
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = _label("", 18)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(hero, _title, Rect2(58, 4, 126, 46))
	_description = _label("", 14)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.max_lines_visible = 2
	_description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_place(detail, _description, Rect2(10, 66, 186, 30))
	_place(detail, _label("BAHAN", 16), Rect2(10, 99, 80, 18))
	var counts := _label("PUNYA / BUTUH", 12)
	counts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(detail, counts, Rect2(94, 100, 102, 16))
	var ingredients_scroll := ScrollContainer.new()
	ingredients_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_place(detail, ingredients_scroll, Rect2(10, 120, 186, 52))
	_materials = VBoxContainer.new()
	_materials.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_materials.add_theme_constant_override("separation", 3)
	ingredients_scroll.add_child(_materials)
	_quantity = SpinBox.new()
	_quantity.min_value = 1
	_quantity.max_value = CraftingSystem.MAX_BATCHES
	_quantity.step = 1
	_quantity.value = 1
	_quantity.tooltip_text = "Jumlah kali resep dibuat."
	_quantity.value_changed.connect(func(_value: float): _refresh_detail())
	_place(detail, _quantity, Rect2(10, 179, 58, 26))
	_quantity.get_line_edit().add_theme_color_override("font_color", INK)
	_quantity.get_line_edit().add_theme_stylebox_override("normal", _style(Color("fff0ce"), Color("b5874f")))
	_craft_button = _button("Buat", true)
	_craft_button.pressed.connect(_craft)
	_place(detail, _craft_button, Rect2(74, 179, 122, 26))
	_message = _label("", 14)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(detail, _message, Rect2(10, 210, 186, 32))
	refresh()

func _place(parent: Control, child: Control, rect: Rect2) -> void:
	parent.add_child(child)
	child.position = rect.position
	child.size = rect.size

func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(2)
	return style

func _paper(parent: Control, rect: Rect2, fill: Color) -> Panel:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _style(fill, Color("b5874f")))
	_place(parent, panel, rect)
	return panel

func _label(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(value: String, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = value
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color("fff1cf") if primary else INK)
	button.add_theme_color_override("font_hover_color", Color("fff1cf") if primary else INK)
	button.add_theme_color_override("font_pressed_color", Color("fff1cf") if primary else INK)
	button.add_theme_color_override("font_disabled_color", Color("8e785e"))
	button.add_theme_stylebox_override("normal", _style(Color("51774a") if primary else Color("eed5a6"), Color("916334")))
	button.add_theme_stylebox_override("hover", _style(Color("668e55") if primary else Color("ffe8b7"), Color("9e6a32")))
	button.add_theme_stylebox_override("pressed", _style(Color("426b43") if primary else Color("dcb374"), Color("674527")))
	button.add_theme_stylebox_override("disabled", _style(Color("d6c2a3"), Color("b19a78")))
	var focus := _style(Color.TRANSPARENT, Color("fff1cf"))
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	return button

func _select_group(group: String) -> void:
	_group = group
	refresh()

func _select_recipe(recipe: CraftingRecipe) -> void:
	_selected = recipe
	for i in _recipe_buttons.size():
		_recipe_buttons[i].set_pressed_no_signal(_recipe_buttons[i].get_meta("recipe") == recipe)
	_refresh_detail()

func refresh() -> void:
	if not is_instance_valid(_list):
		return
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_recipe_buttons.clear()
	var recipes: Array[CraftingRecipe] = []
	for recipe in CraftingSystem.CATALOG.recipes:
		if _group == "Semua" or recipe.group == _group:
			recipes.append(recipe)
	if not recipes.has(_selected):
		_selected = recipes[0] if not recipes.is_empty() else null
	for i in _filters.size():
		_filters[i].set_pressed_no_signal(GROUPS[i] == _group)
	var ready_count := 0
	for recipe in recipes:
		var item := GameState._resolve_item(recipe.output_item_id)
		var ready: bool = CraftingSystem.preview(inventory_ui.data, recipe)["ok"]
		ready_count += int(ready)
		var button := _button("")
		button.custom_minimum_size = Vector2(38, 40)
		button.icon = item.icon
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 28)
		button.toggle_mode = true
		button.button_pressed = recipe == _selected
		button.set_meta("recipe", recipe)
		button.tooltip_text = "%s — hasil x%d\n%s" % [item.display_name, recipe.output_amount, "Siap dibuat" if ready else "Bahan kurang atau tas penuh"]
		button.pressed.connect(_select_recipe.bind(recipe))
		_list.add_child(button)
		var badge := _label(str(recipe.output_amount), 12)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_place(button, badge, Rect2(20, 26, 15, 12))
		if ready:
			var dot := ColorRect.new()
			dot.color = GREEN
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_place(button, dot, Rect2(4, 4, 4, 4))
		_recipe_buttons.append(button)
	_summary.text = "%d resep  /  %d siap dibuat" % [recipes.size(), ready_count]
	_refresh_detail()

func _refresh_detail() -> void:
	if not is_instance_valid(_materials):
		return
	for child in _materials.get_children():
		_materials.remove_child(child)
		child.queue_free()
	if _selected == null:
		_craft_button.disabled = true
		_title.text = "Belum ada resep."
		return
	var data: PlayerData = inventory_ui.data
	var batches := int(_quantity.value)
	var item := GameState._resolve_item(_selected.output_item_id)
	_icon.texture = item.icon
	_title.text = "%s\nHasil x%d" % [item.display_name, _selected.output_amount * batches]
	_description.text = item.description
	_description.tooltip_text = item.description
	for id in _selected.ingredients:
		var material := GameState._resolve_item(id)
		var have := data.get_item_count(id)
		var need: int = _selected.ingredients[id] * batches
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 22
		row.add_theme_constant_override("separation", 4)
		_materials.add_child(row)
		var icon := TextureRect.new()
		icon.texture = material.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(20, 20)
		row.add_child(icon)
		var name_label := _label(material.display_name, 14)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		row.add_child(name_label)
		var amount := _label("%d / %d" % [have, need], 14)
		amount.add_theme_color_override("font_color", GREEN if have >= need else RED)
		row.add_child(amount)
		row.tooltip_text = "%s: %d / %d" % [material.display_name, have, need]
	var plan := CraftingSystem.preview(data, _selected, batches)
	_craft_button.disabled = not plan["ok"]
	_craft_button.text = "Buat x%d" % batches
	_message.text = plan["message"]
	_message.add_theme_color_override("font_color", GREEN if plan["ok"] else RED)

func _craft() -> void:
	var result := CraftingSystem.craft(inventory_ui.data, _selected, int(_quantity.value))
	refresh()
	_message.text = result["message"]
	_message.add_theme_color_override("font_color", GREEN if result["ok"] else RED)
	if result["ok"]:
		Notify.say(result["message"])
