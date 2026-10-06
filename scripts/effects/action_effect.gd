class_name ActionEffect
extends Resource

@export var stamina_cost: int = 0

func apply(
	_player: Player,
	_cell: Vector2i
) -> void:
	push_warning(
		"ActionEffect.apply() dipanggil langsung. "
		+ "Gunakan class turunan seperti DamageEffect, "
		+ "HarvestEffect, atau SeedEffect."
	)
