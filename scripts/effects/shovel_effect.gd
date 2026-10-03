class_name ShovelEffect
extends ActionEffect

func apply(_player: Player, cell: Vector2i) -> void:
	FarmManager.shovel(cell)
