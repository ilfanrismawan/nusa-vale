class_name WaterEffect
extends ActionEffect

func _init() -> void:
	stamina_cost = 2

func apply(
	player: Player,
	cell: Vector2i
) -> void:
	if GameState.stamina < stamina_cost:
		Notify.say("Terlalu lelah! Istirahatlah.")
		return
	if FarmManager.water(cell):
		GameState.spend_stamina(stamina_cost)
