class_name HoeEffect
extends ActionEffect

func _init() -> void:
	stamina_cost = 4

func apply(
	player: Player,
	cell: Vector2i
) -> void:
	if GameState.stamina < stamina_cost:
		Notify.say("Terlalu lelah! Istirahatlah.")
		return
	if FarmManager.hoe(cell):
		GameState.spend_stamina(stamina_cost)
		Juice.play(&"hoe", Juice.cell_center(player, cell))
