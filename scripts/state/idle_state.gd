class_name IdleState
extends State

@export var move_state: State

func _init() -> void:
	animation_name = &"Idle"
	
func physics_update(_delta: float) -> void:
	player.velocity =  Vector2.ZERO

	if player.get_input_vector() != Vector2.ZERO:
		transitioned.emit(move_state)
