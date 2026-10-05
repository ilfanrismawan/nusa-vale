class_name ChopEffect
extends ActionEffect

@export var damage: int = 1

func _init() -> void:
	stamina_cost = 6

func apply(player: Player, cell: Vector2i) -> void:
	if GameState.stamina < stamina_cost:
		Notify.say("Terlalu lelah! Istirahatlah.")
		return
	if FarmManager.chop(player, cell, damage):
		GameState.spend_stamina(stamina_cost)
