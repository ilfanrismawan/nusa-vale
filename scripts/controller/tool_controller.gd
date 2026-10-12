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
		var item := current_item
		return item.action_data if item != null else null


var current_item: ItemData:
	get:
		var data := player.data
		var global_idx = data.hotbar_page * 8 + current_index
		if global_idx < 0 or global_idx >= data.bag_size:
			return null
		
		var slot = data.inventory[global_idx]
		if slot == null:
			return null
			
		return slot["item"]


func _ready() -> void:
	action_state.action_performed.connect(_on_action_performed)
	GameState.inventory_changed.connect(func(): tool_changed.emit(current_tool))
	tool_changed.emit(current_tool)


func _unhandled_input(event: InputEvent) -> void:
	# Co-op: setiap pemain hanya bereaksi pada perangkatnya sendiri (PlayerInput).
	if player.is_input_locked():
		return
	if state_machine.current_state == action_state or state_machine.current_state == fishing_state:
		return
	var input := player.input
	if input.is_event(event, &"use_tool"):
		player.bind_context()
		if current_item != null and current_item.placeable:
			var result := StructureManager.place(player, player.data.hotbar_page * 8 + current_index, player.get_target_cell())
			Notify.say(result["message"])
			get_viewport().set_input_as_handled()
		elif current_tool != null:
			use_action(current_tool)
		elif current_item != null:
			player.ui_inventory.drop_from_slot(player.data.hotbar_page * 8 + current_index, 1)
			get_viewport().set_input_as_handled()
		elif _can_hand_harvest():
			use_action(HAND_HARVEST)
			
		return

	if input.is_event(event, &"tool_next"):
		switch_tool(1)
		return
		
	elif input.is_event(event, &"tool_prev"):
		switch_tool(-1)
		return

	for i in range(8):
		if input.is_event(event, StringName("slot_%d" % (i + 1))):
			select_tool(i)
			return


func switch_tool(direction: int) -> void:
	var new_index: int = wrapi(current_index + direction, 0, 8)
	select_tool(new_index)


func select_tool(index: int, preview: bool = true) -> void:
	if index < 0 or index >= 8:
		return
	current_index = index
	player._sync_carried_item()
	var item: ItemData = current_item
	tool_changed.emit(current_tool)
	if preview:
		player.show_tool_preview(item)
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
	
	if action.effect is WaterEffect and action.effect.try_refill(player, player.get_target_cell(), action.tool_data):
		return
	var stamina_cost: int = _get_stamina_cost(action)
	
	if action.effect:
		if action.tool_data != null:
			stamina_cost = action.tool_data.stamina_cost
		else:
			stamina_cost = action.effect.stamina_cost
			
		if player.data.stamina < stamina_cost:
			Notify.say("Terlalu lelah! Istirahatlah.")
			return
			
	action_state.start(action, player.get_target_cell())
	player._clear_pickup_visual()
	state_machine.change_state(action_state)

func _start_fishing(action: ActionData) -> void:
	# Stamina dicek di sini, tetapi baru dipotong saat kail jatuh di air (FishingState).
	var stamina_cost: int = _get_stamina_cost(action)
	if player.data.stamina < stamina_cost:
		Notify.say("Terlalu lelah! Istirahatlah.")
		return
	fishing_state.start(action.tool_data as RodData, stamina_cost)
	player._clear_pickup_visual()
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
	# Efek dipanggil dari sinyal animasi; pastikan GameState/FarmManager menunjuk pemain ini.
	player.bind_context()
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
