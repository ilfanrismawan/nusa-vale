class_name MoveState
extends State

@export var idle_state: State
@export var run_state: State
@export var run_input: StringName = &"run"
@export var speed_multiplier: float = 1

func _init() -> void:
	animation_name = &"Walk"
	
func physics_update(_delta: float) -> void:
	var input_vector := player.get_input_vector()
	
	if input_vector == Vector2.ZERO:
		transitioned.emit(idle_state)
		return
	
	var switch_state := _get_switch_state()
	if switch_state:
		transitioned.emit(switch_state)
		return
	
	player.update_facing_direction(input_vector)
	# Lari (speed_multiplier > 1) melambat saat rasa takut penuh.
	var fear_scale := player.fear_run_multiplier if speed_multiplier > 1.0 else 1.0
	player.velocity = input_vector * player.speed * speed_multiplier * player.data.food_movement_multiplier() * player.combat_speed_scale() * player.mount_speed_multiplier() * fear_scale
	player.move_and_slide()

func _get_switch_state() -> State:
	return run_state if player.input.pressed(run_input) else null
