class_name RunState
extends MoveState

@export var walk_state: State

## Langkah lari terdengar musuh (GDD 8.2-B2); berjalan biasa tidak bersuara.
var _noise_timer := 0.0

func _init() -> void:
	animation_name = &"Run"
	

func physics_update(delta: float) -> void:
	super.physics_update(delta)
	_noise_timer -= delta
	if _noise_timer <= 0.0 and player.velocity.length() > 1.0:
		_noise_timer = Perception.RULES.run_noise_interval
		Perception.noise(player, player.global_position + Player.FEET_OFFSET, Perception.RULES.run_noise_radius, player)

func _get_switch_state() -> State:
	return null if player.input.pressed(run_input) else walk_state
