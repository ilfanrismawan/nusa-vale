class_name Player
extends CharacterBody2D

@export var speed: float = 30.0

@onready var animation_controller: AnimationController = $AnimationController
@onready var state_machine: StateMachine = $StateMachine
@onready var base_layer_ground: TileMapLayer = get_node_or_null("../../BaseLayerGround")

@onready var hotbar_ui = $"../HotbarUi"
@onready var tool_ctrl = $ToolController

var facing_direction := Vector2.DOWN

const FEET_OFFSET := Vector2(0, 8)
const ACTION_DISTANCE := 16.0


func _ready() -> void:
	hotbar_ui.setup.call_deferred(tool_ctrl.actions)
	hotbar_ui.slot_clicked.connect(func(index: int): tool_ctrl.select_tool(index))
	tool_ctrl.tool_changed.connect(func(a):
		hotbar_ui.highlight_slot(tool_ctrl.current_index))
	
	state_machine.initialize(self, animation_controller)
	
	if GameState.has_spawn_point:
		global_position = GameState.next_spawn_position
		GameState.has_spawn_point = false
		
	
func _physics_process(delta: float) -> void:
	state_machine.physics_update(delta)
	
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
	print("[%d] facing -> %s" % [Time.get_ticks_msec(), facing_direction])
	animation_controller.set_direction(facing_direction)

func world_to_cell(world_position: Vector2) -> Vector2i:
	if base_layer_ground == null:
		return Vector2i.ZERO
	return base_layer_ground.local_to_map(base_layer_ground.to_local(world_position))
 
func get_player_cell() -> Vector2i:
	if base_layer_ground == null:
		return Vector2i.ZERO
	var foot_position: Vector2 = global_position + FEET_OFFSET
	return base_layer_ground.local_to_map(
		base_layer_ground.to_local(foot_position)
	)

func get_target_cell() -> Vector2i:
	return get_player_cell() + Vector2i(facing_direction)
