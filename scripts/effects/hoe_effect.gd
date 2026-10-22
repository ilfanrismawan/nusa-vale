class_name HoeEffect
extends ActionEffect

func _init() -> void:
	stamina_cost = 4

func apply(player: Player, cell: Vector2i) -> void:
	var cost := cost_for(player)
	if player.data.stamina < cost:
		return
	var worked := false
	for target in cells_for(player, cell):
		if FarmManager.hoe(target):
			worked = true
			SkillSystem.gain(player.data, &"farmer", SkillSystem.RULES.hoe_exp)
			Juice.play(&"hoe", Juice.cell_center(player, target))
	if worked:
		player.data.spend_stamina(cost)
