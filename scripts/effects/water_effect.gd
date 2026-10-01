class_name WaterEffect
extends ActionEffect


func apply(
	player: Player,
	cell: Vector2i
) -> void:
	FarmManager.water(cell)
