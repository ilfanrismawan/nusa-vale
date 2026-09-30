class_name StateMachine
extends State

@export var initial_state: State

var current_state: Node

func initialize(player: Player, animation_controller: AnimationController) -> void:
	for child in get_children():
		if child is State:
			child.initialize(player, animation_controller)
			child.transitioned.connect(change_state)
	change_state(initial_state)
	
func physics_update(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func change_state(new_state: State) -> void:
	if new_state == null:
		push_error("change_state(null): ada @export state yang belum diisi di Inspector")
		return
	if current_state == new_state:
		return
	
	if current_state:
		current_state.exit()
	
	current_state = new_state
	
	if current_state:
		current_state.enter()
