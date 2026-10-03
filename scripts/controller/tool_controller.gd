class_name ToolController
extends Node

signal tool_changed(action: ActionData)

@onready var player: Player = get_parent()
@onready var state_machine: StateMachine = $"../StateMachine"
@onready var action_state: ActionState = $"../StateMachine/ActionState"

const HAND_HARVEST: ActionData = preload("res://resources/action_data/hand_harvest.tres")

var current_index: int = 0


## Kembalikan ActionData dari item yang sedang aktif di hotbar
var current_tool: ActionData:
	get:
		var slot = GameState.inventory[current_index] if current_index < GameState.inventory.size() else null
		if slot == null:
			return null
		var item: ItemData = slot["item"]
		if item == null:
			return null
		return item.action_data


## Kembalikan ItemData dari slot aktif
var current_item: ItemData:
	get:
		var slot = GameState.inventory[current_index] if current_index < GameState.inventory.size() else null
		if slot == null:
			return null
		return slot["item"]


func _ready() -> void:
	action_state.action_performed.connect(_on_action_performed)
	tool_changed.emit(current_tool)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("use_tool"):
		if current_tool != null:
			use_action(current_tool)
		elif _can_hand_harvest():
			use_action(HAND_HARVEST)
		return

	if event.is_action_pressed("tool_next"):
		switch_tool(1)
	elif event.is_action_pressed("tool_prev"):
		switch_tool(-1)

	for i in 8:
		var action_name := "slot_%d" % (i + 1)
		if InputMap.has_action(action_name) and event.is_action_pressed(action_name):
			select_tool(i)
			return


func switch_tool(direction: int) -> void:
	var new_index := wrapi(current_index + direction, 0, 8)
	select_tool(new_index)


func select_tool(index: int) -> void:
	if index < 0 or index >= 8:
		return
	current_index = index
	tool_changed.emit(current_tool)
	var item = current_item
	if item:
		print("Slot aktif [%d]: %s" % [index, item.display_name])
	else:
		print("Slot aktif [%d]: kosong" % index)


func use_action(action: ActionData) -> void:
	if action == null:
		return
	if state_machine.current_state == action_state:
		return
	if player.base_layer_ground == null:
		Notify.say("Tidak bisa pakai alat di sini")
		return
	action_state.start(action, player.get_target_cell())
	state_machine.change_state(action_state)


func _can_hand_harvest() -> bool:
	if player.base_layer_ground == null:
		return false
	return FarmManager.can_harvest(player.get_target_cell())


func _on_action_performed(action: ActionData, cell: Vector2i) -> void:
	if action.effect:
		action.effect.apply(player, cell)
