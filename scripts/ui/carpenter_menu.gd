extends CanvasLayer

const Presentation = preload("res://scripts/resources/carpenter_presentation.gd")
signal finished

@export var presentation: Presentation = preload("res://resources/ui/carpenter_presentation.tres")
@export var card_scene: PackedScene = preload("res://scenes/ui/carpenter_building_card.tscn")
@export var material_scene: PackedScene = preload("res://scenes/ui/blacksmith_material_row.tscn")
@export var design_size := Vector2(1600, 900)

var player: Player
var vendor_name := ""
var vendor_portrait: Texture2D
var _selected_id := ""
var _closed := false
var _refresh_pending := false
var _ids: PackedStringArray = []
@onready var _content: GridContainer = %Buildings

func _ready() -> void:
	layer = FarmServiceTheme.LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	%VendorName.text = vendor_name if not vendor_name.is_empty() else presentation.vendor_name
	%Dialog.text = presentation.greeting
	var art := presentation.vendor_art if presentation.vendor_art != null else vendor_portrait
	if art != null:
		%Portrait.texture = FarmServiceTheme.portrait(art)
	%ChooseButton.pressed.connect(_choose_selected)
	%CloseButton.pressed.connect(_close)
	get_viewport().size_changed.connect(_resize)
	GameState.money_changed.connect(_money_changed)
	GameState.inventory_changed.connect(_queue_refresh)
	for id in presentation.building_order:
		if StructureManager.CONSTRUCTION.has(id) and not _ids.has(id):
			_ids.append(id)
	for id in StructureManager.CONSTRUCTION:
		if not _ids.has(id):
			_ids.append(id)
	for id in _ids:
		var item := GameState._resolve_item(id)
		if item == null:
			continue
		var card := card_scene.instantiate() as Button
		_content.add_child(card)
		card.set_meta("id", id)
		card.get_node("Icon").texture = item.icon
		card.get_node("Name").text = item.display_name
		card.get_node("Price").text = "%d G" % int(StructureManager.CONSTRUCTION[id].money)
		card.pressed.connect(_select.bind(id))
		card.focus_entered.connect(_select.bind(id))
	if not _ids.is_empty():
		_selected_id = _ids[0]
	_refresh()
	_resize()
	Coop.set_menu_open(player, true)

func _resize() -> void:
	var view := get_viewport().get_visible_rect().size
	var fit := minf(view.x / design_size.x, view.y / design_size.y)
	$Design.scale = Vector2.ONE * fit
	$Design.position = (view - design_size * fit) * 0.5

func _select(id: String) -> void:
	_selected_id = id
	_refresh()

func _money_changed(_amount: int) -> void:
	_refresh()

func _queue_refresh() -> void:
	if _closed or _refresh_pending:
		return
	_refresh_pending = true
	_refresh.call_deferred()

func _affordable(id: String) -> bool:
	if not is_instance_valid(player) or not StructureManager.CONSTRUCTION.has(id):
		return false
	var quote: Dictionary = StructureManager.CONSTRUCTION[id]
	if GameState.money < int(quote.money):
		return false
	for material in quote.materials:
		if not player.data.has_item(material, int(quote.materials[material])):
			return false
	return true

func _refresh() -> void:
	_refresh_pending = false
	if _closed:
		return
	%Money.text = "● %d G" % GameState.money
	%ChooseButton.disabled = true
	if _selected_id.is_empty():
		return
	var item := GameState._resolve_item(_selected_id)
	var quote: Dictionary = StructureManager.CONSTRUCTION[_selected_id]
	%DetailTitle.text = item.display_name
	%ResultIcon.texture = item.icon
	%Description.text = item.description
	%Footprint.text = "Ukuran · %d × %d petak" % [item.placement_size.x, item.placement_size.y]
	%Cost.text = "● %d G" % int(quote.money)
	%Owner.text = "Bahan dari tas P%d · Uang bersama" % (player.player_index + 1)
	for child in %Materials.get_children():
		%Materials.remove_child(child)
		child.queue_free()
	for id in quote.materials:
		var material := GameState._resolve_item(id)
		var required := int(quote.materials[id])
		var count := player.data.get_item_count(id)
		var row := material_scene.instantiate()
		%Materials.add_child(row)
		row.get_node("Layout/Icon").texture = material.icon if material != null else null
		row.get_node("Layout/Name").text = material.display_name if material != null else str(id)
		row.get_node("Layout/Count").text = "%d / %d" % [count, required]
		row.get_node("Layout/Count").add_theme_color_override("font_color", presentation.enough_color if count >= required else presentation.missing_color)
	%ChooseButton.disabled = not _affordable(_selected_id)
	%Availability.text = presentation.ready_message if not %ChooseButton.disabled else presentation.missing_message
	for card in _content.get_children():
		card.set_pressed_no_signal(card.get_meta("id") == _selected_id)

func _choose_selected() -> void:
	if _affordable(_selected_id):
		_choose(_selected_id)

func _choose(id: String) -> void:
	if _closed or not StructureManager.CONSTRUCTION.has(id):
		return
	_close()
	BuildingPlacement.begin(player, id)

func _input(event: InputEvent) -> void:
	if _closed:
		return
	var input := player.input if is_instance_valid(player) else PlayerInput.solo()
	if input.is_event(event, &"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
	elif input.is_event(event, &"ui_accept"):
		get_viewport().set_input_as_handled()
		_choose_selected()
	elif not input.uses_mouse() and (input.is_event(event, &"move_left") or input.is_event(event, &"move_right") or input.is_event(event, &"move_up") or input.is_event(event, &"move_down")):
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if _closed or not is_instance_valid(player) or player.input.uses_mouse() or _ids.is_empty():
		return
	var direction := 0
	if player.input.just_pressed(&"move_right"): direction = 1
	elif player.input.just_pressed(&"move_left"): direction = -1
	elif player.input.just_pressed(&"move_down"): direction = _content.columns
	elif player.input.just_pressed(&"move_up"): direction = -_content.columns
	if direction != 0:
		_select(_ids[posmod(_ids.find(_selected_id) + direction, _ids.size())])

func _close() -> void:
	if _closed:
		return
	_closed = true
	hide()
	Coop.set_menu_open(player, false)
	finished.emit()
	queue_free()

func _exit_tree() -> void:
	if not _closed and is_instance_valid(player):
		_closed = true
		Coop.set_menu_open(player, false)
		finished.emit()
