class_name HoeEffect
extends ActionEffect

@export var stamina_cost: int = 4

func apply(
	player: Player,
	cell: Vector2i
) -> void:
	if not GameState.spend_stamina(stamina_cost):
		Notify.say("Terlalu lelah! Istirahatlah.")
		return
	FarmManager.hoe(cell)
