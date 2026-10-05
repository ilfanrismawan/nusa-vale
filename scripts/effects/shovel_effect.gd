class_name ShovelEffect
extends ActionEffect

func _init() -> void:
	stamina_cost = 4

func apply(_player: Player, cell: Vector2i) -> void:
	if GameState.stamina < stamina_cost:
		Notify.say("Terlalu lelah! Istirahatlah.")
		return
	if FarmManager.shovel(cell):
		GameState.spend_stamina(stamina_cost)
