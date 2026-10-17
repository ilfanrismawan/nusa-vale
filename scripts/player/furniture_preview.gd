extends Node2D
## Per-player furniture ghost. Uses only drawing nodes: never adds physics or interaction.
var player: Player
var facing: int = 1
var _item_id := ""
var _definition: SeatDefinition
var _sprite: Sprite2D
var _hint: Label
var _placement_finished := false

func finish_placement() -> void:
	_placement_finished = true
	hide()

func restart_placement() -> void:
	_placement_finished = false

func can_place() -> bool:
	var item: ItemData = player.tool_controller.current_item
	return not _placement_finished and item != null and item.placeable and item.seat_definition != null and not player.is_input_locked() and player.base_layer_ground != null

func _ready() -> void:
	z_index = 20
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_hint = Label.new()
	_hint.add_theme_font_override("font", preload("res://assets/fonts/m5x7.ttf"))
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 3)
	_hint.position = Vector2(-48, 12)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

func _process(_delta: float) -> void:
	var item: ItemData = player.tool_controller.current_item
	visible = can_place()
	if not visible:
		return
	if _item_id != item.item_id:
		_item_id = item.item_id
		_definition = item.seat_definition
		facing = 1
	var pose := _definition.pose_for(facing)
	_sprite.texture = _definition.texture
	_sprite.region_enabled = true
	_sprite.region_rect = pose.region
	_sprite.offset = pose.sprite_offset
	var cell := player.get_target_cell()
	var ground := player.base_layer_ground
	global_position = ground.to_global(ground.map_to_local(cell)) + Vector2(item.placement_size - Vector2i.ONE) * 8
	var result := StructureManager.check_furniture_placement(player, item, cell)
	_sprite.modulate = Color(0.5, 1, 0.6, 0.65) if result.ok else Color(1, 0.35, 0.35, 0.65)

func _input(event: InputEvent) -> void:
	# R must be handled before HotbarUi's unhandled "sort_inventory" action.
	if not can_place() or not player.input.uses_mouse() or not player.input.owns_event(event):
		return
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_R or event.keycode == KEY_R):
		var item: ItemData = player.tool_controller.current_item
		if _item_id != item.item_id:
			_item_id = item.item_id
			_definition = item.seat_definition
			facing = 1
		facing = _definition.next_facing(facing)
		get_viewport().set_input_as_handled()
