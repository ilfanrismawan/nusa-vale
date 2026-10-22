extends CanvasLayer

@export var card_scene: PackedScene = preload("res://scenes/ui/cooking_recipe_card.tscn")
@export var equipment_tab_scene: PackedScene = preload("res://scenes/ui/cooking_equipment_tab.tscn")
@export var ingredient_scene: PackedScene = preload("res://scenes/ui/cooking_ingredient_line.tscn")
@export_file("*.tres") var catalog_path := "res://resources/cooking/data/cooking_catalog.tres"
@export var design_size := Vector2(1920, 1080)

var player: Player
var equipment_data: CookingEquipmentData
var available_equipment: Array[CookingEquipmentData] = []
var _closed := false
var _refresh_pending := false
var _initialized := false
var _selected: RecipeData
var _filters: Array[CookingEquipmentData] = []
var _filter_index := 0
var _sort_mode := 0

@onready var _panel: Control = $Panel
@onready var _rows: GridContainer = %Rows
@onready var _status: Label = %StatusLabel
var _debug_panel: VBoxContainer
@onready var _debug_toggle: Button = %DebugToggle

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 70
	%CloseButton.pressed.connect(_close)
	%PreviousTab.pressed.connect(_cycle_filter.bind(-1))
	%NextTab.pressed.connect(_cycle_filter.bind(1))
	%SortButton.pressed.connect(_cycle_sort)
	%ActionButton.pressed.connect(_selected_action)
	_debug_toggle.visible = false
	if OS.has_feature("editor") and OS.is_debug_build():
		var debug_scene = load("res://scenes/ui/cooking_debug_panel.tscn")
		if debug_scene != null:
			_debug_panel = debug_scene.instantiate()
			$Panel/Layout/DebugWindow/DebugScroll.add_child(_debug_panel)
			_debug_panel.bind(self)
			_debug_toggle.visible = _debug_panel.is_enabled()
			_debug_toggle.toggled.connect(_toggle_debug)
	get_viewport().size_changed.connect(_resize)
	_resize()
	_build_tabs()
	if is_instance_valid(player) and player.data != null:
		_initialize_after_owner_ready()
	else:
		call_deferred("_initialize_after_owner_ready")

func _initialize_after_owner_ready() -> void:
	if _closed or _initialized:
		return
	if not is_instance_valid(player) or player.data == null:
		call_deferred("_initialize_after_owner_ready")
		return
	_initialized = true
	Coop.set_menu_open(player, true)
	GameState.inventory_changed.connect(_queue_refresh)
	GameState.money_changed.connect(_money_changed)
	_refresh()

func _resize() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var fit := minf(viewport_size.x / design_size.x, viewport_size.y / design_size.y)
	_panel.scale = Vector2.ONE * fit
	_panel.position = (viewport_size - design_size * fit) * 0.5

func _build_tabs() -> void:
	_filters.append(null)
	var catalog := load(catalog_path) as CookingCatalog
	if catalog != null:
		_filters.append_array(catalog.equipment)
	for index in _filters.size():
		var equipment := _filters[index]
		var tab := equipment_tab_scene.instantiate() as Button
		%EquipmentTabs.add_child(tab)
		if equipment != null:
			tab.get_node("Icon").texture = equipment.display_icon()
		tab.get_node("Caption").text = equipment.item.display_name if equipment != null else "All"
		tab.tooltip_text = equipment.item.display_name if equipment != null else "Semua resep"
		tab.pressed.connect(_set_filter.bind(index))
	_update_tabs()

func _set_filter(index: int) -> void:
	_filter_index = posmod(index, _filters.size())
	_update_tabs()
	_refresh()
	%EquipmentScroll.ensure_control_visible(%EquipmentTabs.get_child(_filter_index))

func _cycle_filter(direction: int) -> void:
	_set_filter(_filter_index + direction)

func _update_tabs() -> void:
	for index in %EquipmentTabs.get_child_count():
		var tab := %EquipmentTabs.get_child(index) as Button
		tab.set_pressed_no_signal(index == _filter_index)
		tab.get_node("Caption").visible = index == _filter_index
		tab.get_node("Icon").modulate = Color.WHITE if index == _filter_index else Color(0.6, 0.6, 0.6)

func _cycle_sort() -> void:
	_sort_mode = (_sort_mode + 1) % 3
	%SortButton.text = ["≡↓ Default", "≡↓ Nama", "≡↓ Siap masak"][_sort_mode]
	_refresh()

func _toggle_debug(open: bool) -> void:
	if _debug_panel == null or not _debug_panel.is_enabled():
		return
	%DebugWindow.visible = open
	_debug_panel.visible = open
	$Panel/Layout/Scroll.visible = not open

func _money_changed(_money: int) -> void:
	_queue_refresh()

func _queue_refresh() -> void:
	if _refresh_pending or _closed:
		return
	_refresh_pending = true
	_refresh.call_deferred()

func _can_cook(recipe: RecipeData) -> bool:
	if not recipe.is_valid_recipe() or not CookingManager.knows(player.data, recipe.id) or not recipe.missing_equipment(available_equipment).is_empty():
		return false
	for ingredient in recipe.ingredients:
		if player.data.get_item_count(ingredient) < recipe.ingredients[ingredient]:
			return false
	return true

func _refresh() -> void:
	_refresh_pending = false
	if _closed or not _initialized or not is_instance_valid(player) or player.data == null:
		return
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var recipes: Array[RecipeData] = []
	var filter := _filters[_filter_index] if not _filters.is_empty() else null
	for recipe in CookingManager.all_recipes():
		if recipe == null or (equipment_data != null and not equipment_data.supports(recipe)) or (filter != null and not filter.supports(recipe)):
			continue
		recipes.append(recipe)
	if _sort_mode == 1:
		recipes.sort_custom(func(first: RecipeData, second: RecipeData): return first.display_name.naturalnocasecmp_to(second.display_name) < 0)
	elif _sort_mode == 2:
		recipes.sort_custom(func(first: RecipeData, second: RecipeData):
			if _can_cook(first) != _can_cook(second):
				return _can_cook(first)
			return first.display_name.naturalnocasecmp_to(second.display_name) < 0)
	if not recipes.has(_selected):
		_selected = recipes[0] if not recipes.is_empty() else null
	for recipe in recipes:
		var card := card_scene.instantiate() as Button
		_rows.add_child(card)
		card.get_node("Icon").texture = recipe.display_icon()
		card.get_node("Name").text = recipe.display_name
		card.get_node("Effect").visible = recipe.result_item() != null and not recipe.result_item().food_effects.is_empty()
		card.tooltip_text = recipe.display_name
		card.set_meta("recipe", recipe)
		card.pressed.connect(_select.bind(recipe))
		card.focus_entered.connect(_select.bind(recipe))
	_update_selection()

func _select(recipe: RecipeData) -> void:
	_selected = recipe
	_update_selection()

func _update_selection() -> void:
	for card in _rows.get_children():
		var selected: bool = card.get_meta("recipe") == _selected
		card.set_pressed_no_signal(selected)
		card.get_node("Name").add_theme_color_override("font_color", Color("45301a") if selected else Color("f8f3ec"))
	%DetailContent.visible = _selected != null
	%ActionButton.visible = _selected != null
	%EmptyLabel.visible = _selected == null
	if _selected == null:
		return
	%Preview.texture = _selected.display_icon()
	%RecipeName.text = _selected.display_name
	var names: PackedStringArray = []
	for equipment in _selected.required_equipment:
		if equipment != null and equipment.item != null:
			names.append(equipment.item.display_name)
	%Method.text = names[0] if not names.is_empty() else ""
	%Method.tooltip_text = "Alat wajib: " + " · ".join(names)
	var known := CookingManager.knows(player.data, _selected.id)
	%NewBadge.visible = not known
	var item := _selected.result_item()
	%Description.text = item.description if item != null else ""
	%Stats.text = "ϟ  +%d stamina     ×%d hasil" % [item.stamina_restore if item != null else 0, _selected.output_count]
	%Buff.text = item.food_summary() if item != null else ""
	for child in %Requirements.get_children():
		%Requirements.remove_child(child)
		child.queue_free()
	for ingredient in _selected.ingredients:
		var ingredient_item := GameState._resolve_item(ingredient)
		var count := player.data.get_item_count(ingredient)
		var required := int(_selected.ingredients[ingredient])
		_add_requirement(ingredient_item.icon if ingredient_item != null else null, ingredient_item.display_name if ingredient_item != null else ingredient, "%d / %d" % [count, required], count >= required)
	for equipment in _selected.required_equipment:
		if equipment != null and equipment.item != null:
			var installed := false
			for available in available_equipment:
				if available != null and available.id == equipment.id:
					installed = true
			_add_requirement(equipment.display_icon(), equipment.item.display_name, "✓" if installed else "−", installed)
	%ActionButton.text = "Masak ×%d" % _selected.output_count if known else "Pelajari resep · %d G" % _selected.book_price
	%ActionButton.disabled = not _can_cook(_selected) if known else GameState.money < _selected.book_price or not _selected.is_valid_recipe()
	%ActionButton.tooltip_text = "Bahan dan semua alat wajib tersedia. Alat tidak dikonsumsi."

func _add_requirement(icon: Texture2D, caption: String, amount: String, enough: bool) -> void:
	var line := ingredient_scene.instantiate()
	%Requirements.add_child(line)
	line.get_node("Layout/Icon").texture = icon
	line.get_node("Layout/Name").text = caption
	line.get_node("Layout/Count").text = amount
	line.get_node("Layout/Count").modulate = Color("74866a") if enough else Color("c0614e")

func _selected_action() -> void:
	if _selected != null:
		_act(_selected.id, not CookingManager.knows(player.data, _selected.id))

func _act(id: String, learn: bool) -> void:
	var recipe := CookingManager.get_recipe(id)
	if recipe == null or (equipment_data != null and not equipment_data.supports(recipe)):
		_status.text = "Resep tidak tersedia pada peralatan ini."
		return
	var result := CookingManager.learn(player.data, id) if learn else CookingManager.cook(player.data, id, available_equipment)
	_queue_refresh()
	_status.text = result.message

func _input(event: InputEvent) -> void:
	if player.input.is_event(event, &"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
	elif event is InputEventKey and event.pressed and not event.echo and player.input.uses_mouse() and not _debug_toggle.button_pressed:
		match event.physical_keycode:
			KEY_Q: _cycle_filter(-1)
			KEY_R: _cycle_filter(1)
			KEY_TAB: _cycle_sort()
			_: return
		get_viewport().set_input_as_handled()

func _close() -> void:
	if _closed:
		return
	_closed = true
	Coop.set_menu_open(player, false)
	queue_free()

func _exit_tree() -> void:
	if not _closed and is_instance_valid(player):
		Coop.set_menu_open(player, false)
