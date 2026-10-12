class_name ShovelEffect
extends ActionEffect

func _init() -> void:
	stamina_cost = 4

func apply(player: Player, cell: Vector2i) -> void:
	var cost := cost_for(player)
	if player.data.stamina < cost:
		return
	var tool := active_tool(player)
	var worked := false
	for target in cells_for(player, cell):
		var pos := Juice.cell_center(player, target)
		var spot := _dig_spot_at(player, target, pos)
		var dug := false
		if spot != null:
			dug = spot.dig(tool.dig_bonus_chance if tool != null else 0.0)
		if dug or FarmManager.shovel(target):
			worked = true
			Juice.play(&"hoe", pos)
	if worked:
		player.data.spend_stamina(cost)

func _dig_spot_at(player: Player, cell: Vector2i, pos: Vector2) -> DigSpot:
	for node in player.get_tree().get_nodes_in_group(&"dig_spot"):
		if not is_instance_valid(node) or not node is DigSpot:
			continue
		if node.get_world_2d() != player.get_world_2d():
			continue
		var ground: Vector2 = node.ground_position()
		if player.world_to_cell(ground) == cell or ground.distance_to(pos) <= 8.0:
			return node
	return null
