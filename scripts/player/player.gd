class_name Player
extends CharacterBody2D

@export var speed: float = 30.0

@onready var animation_controller: AnimationController = $AnimationController
@onready var state_machine: StateMachine = $StateMachine
@onready var base_layer_ground: TileMapLayer = get_node_or_null("../../BaseLayerGround")

@onready var hotbar_ui = $"../HotbarUi"
@onready var hud_ui = $"../HUD"
@onready var ui_inventory = $"../UIInventory"
@onready var settings_menu = $"../SettingsMenu"
@onready var tool_controller: ToolController = $ToolController

@onready var tile_cursor: CanvasItem = get_node_or_null("TileCursor")

var facing_direction := Vector2.DOWN

const INTERACTION_DISTANCE := 32.0

const FEET_OFFSET := Vector2(0, 8)
const ACTION_DISTANCE := 16.0
const MAX_ACTION_DISTANCE := 28.0

func _ready() -> void:
	hotbar_ui.show()
	hud_ui.show()

	hotbar_ui.slot_selected.connect(func(index: int): tool_controller.select_tool(index))
	tool_controller.tool_changed.connect(func(_a): hotbar_ui.highlight_slot(tool_controller.current_index))

	hotbar_ui.refresh.call_deferred()
	
	state_machine.initialize(self, animation_controller)
	
	if GameState.has_spawn_point:
		global_position = GameState.next_spawn_position
		GameState.has_spawn_point = false
		
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("interact"):
		_try_interact()
	_update_tile_cursor()
	
func _physics_process(delta: float) -> void:
	state_machine.physics_update(delta)
	
func _try_interact() -> void:
	var target := _find_interactable()
	if target == null:
		return
		
	if target.has_method("interact")		:
		target.interact()

func _find_interactable() -> Node:
	var space_state := get_world_2d().direct_space_state
	if space_state == null:
		return null
	
	var origin := global_position + FEET_OFFSET
	var direction := facing_direction.normalized()
	var target_position := origin + (direction * INTERACTION_DISTANCE)
	var query := PhysicsPointQueryParameters2D.new()		
	
	query.position = target_position
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 0xFFFFFFFF
	
	var results := space_state.intersect_point(query, 16)
	
	for result in results:
		var collider = result.get("collider")
		if collider == null:
			continue
		
		if collider.has_method("interact"):
			return collider
		
		var parent: Node = collider.get_parent()
		
		if parent != null:
			if parent.has_method("interact"):
				return parent	
			
	return null
	
func _update_tile_cursor() -> void:
	if not is_instance_valid(tile_cursor):
		return
		
	if base_layer_ground == null:
		tile_cursor.visible = false
		return
		
	var target_cell := get_target_cell()
	var cell_center_world := base_layer_ground.to_global(base_layer_ground.map_to_local(target_cell))
	tile_cursor.global_position = cell_center_world - Vector2(8,8)
	tile_cursor.visible = true
	
func get_input_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func update_facing_direction(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	
	var new_facing: Vector2
	if abs(direction.x) > abs(direction.y):
		new_facing = Vector2(sign(direction.x), 0)
	else:
		new_facing = Vector2(0, sign(direction.y))
	
	if new_facing == facing_direction:
		return
	
	facing_direction = new_facing
	animation_controller.set_direction(facing_direction)

func world_to_cell(world_position: Vector2) -> Vector2i:
	if base_layer_ground == null:
		return Vector2i.ZERO
	return base_layer_ground.local_to_map(base_layer_ground.to_local(world_position))

func get_target_world_position() -> Vector2:
	if base_layer_ground == null:
		return global_position
	
	var cell := get_target_cell()
	
	return base_layer_ground.to_global(
		base_layer_ground.map_to_local(cell)
	)
	
func get_player_cell() -> Vector2i:
	if base_layer_ground == null:
		return Vector2i.ZERO
	var foot_position: Vector2 = global_position + FEET_OFFSET
	return base_layer_ground.local_to_map(
		base_layer_ground.to_local(foot_position)
	)

func get_target_cell() -> Vector2i:
	if base_layer_ground == null:
		return Vector2i.ZERO
	
	var mouse_world_pos := get_global_mouse_position()
	var foot_position := global_position + FEET_OFFSET
	var dist_to_mouse := foot_position.distance_to(mouse_world_pos)
	
	if dist_to_mouse <= MAX_ACTION_DISTANCE and dist_to_mouse > 4.0:
		var dir := (mouse_world_pos - foot_position).normalized()
		update_facing_direction(dir)
		return base_layer_ground.local_to_map(base_layer_ground.to_local(mouse_world_pos))
	
	return get_player_cell() + Vector2i(facing_direction)
	
