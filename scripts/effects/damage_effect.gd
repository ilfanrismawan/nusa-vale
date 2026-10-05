class_name DamageEffect
extends ActionEffect

@export var target_group: StringName = &"choppable"

func apply(player: Player, cell: Vector2i) -> void:
	var action: ActionData = player.tool_controller.current_tool
	
	if action == null:
		return
		
	var tool_data: ToolData = action.tool_data
	
	if tool_data == null:
		push_warning("DamageEffect: ToolData tidak ditemukan.")
		return
	
	var stamina_cost := tool_data.stamina_cost
	var damage := tool_data.damage
	
	if GameState.stamina < stamina_cost:
		Notify.say("Terlalu lelah! Istirahatlah.")
		return
		
	var hit := false
	
	match target_group:
		&"mineable":
			hit = FarmManager.mine(player, cell, damage)
		&"choppable":
			hit = FarmManager.chop(player, cell, damage)
		_:
			hit = FarmManager.hit_world(player, cell, target_group, damage)
	if hit:
		GameState.spend_stamina(stamina_cost)
