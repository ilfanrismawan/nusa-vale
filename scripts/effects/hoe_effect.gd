class_name HoeEffect
extends ActionEffect

func apply(
	player: Player,
	cell: Vector2i
) -> void:
	FarmManager.hoe(cell)
