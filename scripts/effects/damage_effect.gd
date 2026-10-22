class_name DamageEffect
extends ActionEffect

@export var target_group: StringName = &"choppable"

func apply(player: Player, cell: Vector2i) -> void:
	var action: ActionData = player.tool_controller.action_state.action
	
	if action == null:
		return
		
	var tool_data: ToolData = action.tool_data
	
	if tool_data == null:
		push_warning("DamageEffect: ToolData tidak ditemukan.")
		return
	
	# Perk Miner (stamina/kekuatan beliung) dan Lumberjack (damage kapak), GDD 13.
	var stamina_cost := SkillSystem.tool_cost(player.data, tool_data, tool_data.stamina_cost)
	var damage := SkillSystem.tool_damage(player.data, tool_data, tool_data.damage)
	
	if player.data.stamina < stamina_cost:
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
		player.data.spend_stamina(stamina_cost)
		if target_group == &"mineable":
			# Beliung menghantam batu terdengar musuh di sekitar (GDD 8.2-B2).
			Perception.noise(player, player.global_position, Perception.RULES.mine_noise_radius, player)
