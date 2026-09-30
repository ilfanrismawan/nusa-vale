class_name RunState
extends MoveState

@export var walk_state: State

func _init() -> void:
	animation_name = &"Run"
	

func _get_switch_state() -> State:
	return null if Input.is_action_pressed(run_input) else walk_state
