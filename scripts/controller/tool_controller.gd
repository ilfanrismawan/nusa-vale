class_name ToolController
extends Node

@export var actions: Array[ActionData] = []

@onready var player: Player = get_parent()
@onready var state_machine: StateMachine = $"../StateMachine"
@onready var action_state: ActionState = $"../StateMachine/ActionState"

func _ready() -> void:
	print("ToolController ready, jumlah actions: ", actions.size())
	action_state.action_performed.connect(_on_action_performed)
	
func _unhandled_input(event: InputEvent) -> void:
	for action in actions:
		if event.is_action_pressed(action.input_action):
			print("Action ditekan: ", action.input_action)
			use_action(action)
			return

func use_action(action: ActionData) -> void:
	print("use_action, state sekarang: ", state_machine.current_state)
	if state_machine.current_state == action_state:
		return
	action_state.start(action, player.get_target_cell())
	state_machine.change_state(action_state)

func _on_action_performed(action: ActionData, cell: Vector2i) -> void:
	if action.effect:
		action.effect.apply(player, cell)
				
