class_name Player
extends CharacterBody2D

@export var speed: float = 30.0

@onready var animation_controller: AnimationController = $AnimationController
@onready var state_machine: StateMachine = $StateMachine
@onready var base_layer_ground: TileMapLayer = $"../../BaseLayerGround"

var facing_direction := Vector2.DOWN

func _ready() -> void:
	state_machine.initialize(self, animation_controller)
	
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
	return base_layer_ground.local_to_map(base_layer_ground.to_local(world_position))
 
func get_player_cell() -> Vector2i:
	return base_layer_ground.local_to_map(
		base_layer_ground.to_local(global_position)
	)

func get_target_cell() -> Vector2i:
	var player_cell := get_player_cell()
	return player_cell + Vector2i(facing_direction)
