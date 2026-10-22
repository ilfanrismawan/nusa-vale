extends PanelContainer

@export var recipe_scene: PackedScene = preload("res://scenes/ui/inventory_recipe_tile.tscn")
@export var material_scene: PackedScene = preload("res://scenes/ui/inventory_material_row.tscn")

const GROUPS := ["Semua", "Equipment", "Amunisi", "Bangunan", "Furnitur", "Dekorasi", "Bahan"]
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
var _description: Control
var _summary: Label
var _materials: VBoxContainer
var _quantity: SpinBox
var _craft_button: Button
var _message: Label

func _ready() -> void:
	inventory_ui = get_parent().get_parent().get_parent()
	_list = %List
	_icon = %Icon
	_title = %Title
	_description = %Description
	_summary = %Summary
	_materials = %Materials
	_quantity = %Quantity
	_craft_button = %CraftButton
	_message = %Message
	_filters.assign(find_children("Filter*", "Button", true, false))
	for i in _filters.size():
		_filters[i].pressed.connect(_select_group.bind(GROUPS[i]))
	_quantity.value_changed.connect(func(_value: float): _refresh_detail())
	_craft_button.pressed.connect(_craft)
	refresh()

func _select_group(group: String) -> void:
	_group = group
	%RecipePager.current_page = 0
	refresh()

func _select_recipe(recipe: CraftingRecipe) -> void:
	_selected = recipe
	for i in _recipe_buttons.size():
		_recipe_buttons[i].set_pressed_no_signal(_recipe_buttons[i].get_meta("recipe") == recipe)
	_refresh_detail()

func refresh() -> void:
	if not visible or not is_instance_valid(_list):
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
		var button := recipe_scene.instantiate() as Button
		button.icon = item.icon
		button.button_pressed = recipe == _selected
		button.set_meta("recipe", recipe)
		button.tooltip_text = "%s — hasil x%d\n%s" % [item.display_name, recipe.output_amount, "Siap dibuat" if ready else "Bahan kurang atau tas penuh"]
		button.pressed.connect(_select_recipe.bind(recipe))
		_list.add_child(button)
		button.get_node("Amount").text = str(recipe.output_amount)
		button.get_node("Ready").visible = ready
		_recipe_buttons.append(button)
	%RecipePager.refresh()
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
		var row := material_scene.instantiate() as HBoxContainer
		_materials.add_child(row)
		row.get_node("Icon").texture = material.icon
		row.get_node("Name").text = material.display_name
		var amount := row.get_node("Amount") as Label
		amount.text = "%d / %d" % [have, need]
		amount.add_theme_color_override("font_color", GREEN if have >= need else RED)
		row.tooltip_text = "%s: %d / %d" % [material.display_name, have, need]
	%MaterialPager.refresh()
	var plan := CraftingSystem.preview(data, _selected, batches)
	_craft_button.disabled = not plan["ok"]
	_craft_button.text = "Buat x%d" % batches
	_message.text = plan["message"]
	_message.tooltip_text = plan["message"]
	_message.add_theme_color_override("font_color", GREEN if plan["ok"] else RED)

func _craft() -> void:
	var result := CraftingSystem.craft(inventory_ui.data, _selected, int(_quantity.value))
	refresh()
	_message.text = result["message"]
	_message.add_theme_color_override("font_color", GREEN if result["ok"] else RED)
	if result["ok"]:
		Notify.say(result["message"])
