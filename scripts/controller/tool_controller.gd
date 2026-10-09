class_name ToolController
extends Node

signal tool_changed(action: ActionData)

@onready var player: Player = get_parent()
@onready var state_machine: StateMachine = $"../StateMachine"
@onready var action_state: ActionState = $"../StateMachine/ActionState"
@onready var fishing_state: FishingState = $"../StateMachine/FishingState"

const HAND_HARVEST: ActionData = preload("res://resources/action_data/hand_harvest.tres")

var current_index: int = 0


var current_tool: ActionData:
	get:
		var global_idx = GameState.hotbar_page * 8 + current_index
		if global_idx < 0 or global_idx >= GameState.bag_size:
			return null
			
		var slot = GameState.inventory[global_idx]
		if slot == null:
			return null
			
		var item: ItemData = slot["item"]
		if item == null:
			return null
			
		return item.action_data


var current_item: ItemData:
	get:
		var global_idx = GameState.hotbar_page * 8 + current_index
		if global_idx < 0 or global_idx >= GameState.bag_size:
			return null
		
		var slot = GameState.inventory[global_idx] 
		if slot == null:
			return null
			
		return slot["item"]


func _ready() -> void:
	action_state.action_performed.connect(_on_action_performed)
	GameState.inventory_changed.connect(func(): tool_changed.emit(current_tool))
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
		return
		
	elif event.is_action_pressed("tool_prev"):
		switch_tool(-1)
		return

	for i in range(8):
		var action_name:String = "slot_%d" % (i + 1)
		
		if InputMap.has_action(action_name) and event.is_action_pressed(action_name):
			select_tool(i)
			return


func switch_tool(direction: int) -> void:
	var new_index: int = wrapi(current_index + direction, 0, 8)
	select_tool(new_index)


func select_tool(index: int) -> void:
	if index < 0 or index >= 8:
		return
	current_index = index
	var item: ItemData = current_item
	tool_changed.emit(current_tool)
	if item != null:
		print("Slot aktif [%d]: %s" % [index, item.display_name])
	else:
		print("Slot aktif [%d]: kosong" % index)
	debug_current_tool()


func use_action(action: ActionData) -> void:
	if action == null:
		return
	if state_machine.current_state == action_state:
		return
	if state_machine.current_state == fishing_state:
		return
	if action.effect is FishingEffect:
		_start_fishing(action)
		return
	if player.base_layer_ground == null:
		Notify.say("Tidak bisa pakai alat di sini")
		return
	
	var stamina_cost: int = _get_stamina_cost(action)
	
	if action.effect:
		if action.tool_data != null:
			stamina_cost = action.tool_data.stamina_cost
		else:
			stamina_cost = action.effect.stamina_cost
			
		if GameState.stamina < stamina_cost:
			Notify.say("Terlalu lelah! Istirahatlah.")
			return
			
	action_state.start(action, player.get_target_cell())
	state_machine.change_state(action_state)

func _start_fishing(action: ActionData) -> void:
	var spot := FishingManager.find_spot(player)
	if spot == null:
		Notify.say("Tidak ada air disini.")
		return
	if not GameState.spend_stamina(action.effect.stamina_cost):
		Notify.say("Terlalu lelah! Istirahatlah.")
		return
	fishing_state.start(spot)
	state_machine.change_state(fishing_state)
	
func _get_stamina_cost(action: ActionData) -> int:
	if action == null:
		return 0
	if action.tool_data != null:
		return maxi(action.tool_data.stamina_cost, 0)
		
	if action.effect != null:
		return maxi(action.effect.stamina_cost, 0)
		
	return 0
	
func _can_hand_harvest() -> bool:
	if player.base_layer_ground == null:
		return false
	return FarmManager.can_harvest(player.get_target_cell())


func _on_action_performed(action: ActionData, cell: Vector2i) -> void:
	if action == null:
		return
	if action.effect == null:
		return
	action.effect.apply(player, cell)
	
# DEBUGGING
func debug_current_tool() -> void:
	print("")
	print("========== TOOL DEBUG ==========")

	var item: ItemData = current_item

	if item == null:
		print("Item: NULL")
		print("================================")
		return

	print("Item ID       : ", item.item_id)
	print("Display Name  : ", item.display_name)
	print("Is Tool       : ", item.is_tool())

	if item.action_data == null:
		print("ActionData    : NULL")
		print("================================")
		return

	var action: ActionData = item.action_data

	print("ActionData    : OK")
	print("Action Name   : ", action.display_name)
	print("Animation     : ", action.animation_name)
	print("Input Action  : ", action.input_action)

	if action.effect == null:
		print("Effect        : NULL")
	else:
		print("Effect        : ", action.effect.get_class())

	if action.tool_data == null:
		print("ToolData      : NULL")
		print("================================")
		return

	var tool: ToolData = action.tool_data

	print("ToolData      : OK")
	print("Tool ID       : ", tool.tool_id)
	print("Tool Type     : ", tool.tool_type)
	print("Tier          : ", tool.tier)
	print("Damage        : ", tool.damage)
	print("Stamina Cost  : ", tool.stamina_cost)
	print("Action Speed  : ", tool.action_speed)
	print("Area Size     : ", tool.area_size)

	print("================================")
	print("")
