class_name ToolController
extends Node

signal tool_changed(action: ActionData)

@export var actions: Array[ActionData] = []

@onready var player: Player = get_parent()
@onready var state_machine: StateMachine = $"../StateMachine"
@onready var action_state: ActionState = $"../StateMachine/ActionState"

var current_index: int = 0

var current_tool: ActionData:
	get:
		if actions.is_empty():
			return null
		return actions[current_index]
		
func _ready() -> void:
	action_state.action_performed.connect(_on_action_performed)
	
	if not actions.is_empty():
		tool_changed.emit(current_tool)
	
func _unhandled_input(event: InputEvent) -> void:
	if actions.is_empty():
		return
		
	if event.is_action_pressed("use_tool"):
		use_action(current_tool)
	
	if event.is_action_pressed("tool_next"):
		switch_tool(1)
	elif event.is_action_pressed("tool_prev"):
		switch_tool(-1)
	
	for i in range(mini(actions.size(), 5)):
		if event.is_action_pressed("slot_%d" % (i + 1)):
			select_tool(i)
			return

func switch_tool(direction: int) -> void:
	var new_index := wrapi(current_index + direction, 0 , actions.size())
	select_tool(new_index)

func select_tool(index: int) -> void:
	if index < 0 or index >= actions.size():
		return
	
	if index == current_index:
		return
	
	current_index = index
	tool_changed.emit(current_tool)
	print("Tool aktif: ", current_tool.display_name)
	
func use_action(action: ActionData) -> void:
	if state_machine.current_state == action_state:
		return
	action_state.start(action, player.get_target_cell())
	state_machine.change_state(action_state)

func _on_action_performed(action: ActionData, cell: Vector2i) -> void:
	if action.effect:
		action.effect.apply(player, cell)
				
