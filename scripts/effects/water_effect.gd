class_name WaterEffect
extends ActionEffect

@export var stamina_cost: int = 2

func apply(
	player: Player,
	cell: Vector2i
) -> void:
	if not GameState.spend_stamina(stamina_cost):
		Notify.say("Terlalu lelah! Istirahatlah.")
		return
	FarmManager.water(cell)
