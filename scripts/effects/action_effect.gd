class_name ActionEffect
extends Resource

@export var stamina_cost: int = 0

func active_tool(player: Player) -> ToolData:
	var action := player.tool_controller.action_state.action
	if action == null:
		action = player.tool_controller.current_tool
	return action.tool_data if action != null else null

func cost_for(player: Player) -> int:
	var tool := active_tool(player)
	var cost := maxi(tool.stamina_cost if tool != null else stamina_cost, 0)
	# Perk Farmer/Miner memotong stamina alat (GDD 13).
	return SkillSystem.tool_cost(player.data, tool, cost)

func cells_for(player: Player, cell: Vector2i) -> Array[Vector2i]:
	var tool := active_tool(player)
	var facing := player.tool_controller.action_state.target_facing
	return tool.get_cells(cell, facing) if tool != null else [cell]

func apply(
	_player: Player,
	_cell: Vector2i
) -> void:
	push_warning(
		"ActionEffect.apply() dipanggil langsung. "
		+ "Gunakan class turunan seperti DamageEffect, "
		+ "HarvestEffect, atau SeedEffect."
	)
