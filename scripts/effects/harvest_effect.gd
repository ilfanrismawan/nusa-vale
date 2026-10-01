class_name HarvestEffect
extends ActionEffect

func apply(
	player: Player,
	cell: Vector2i
) -> void:
	var success := FarmManager.harvest(cell)
	if success:
		print("Berhasil panen!")
	else:
		print("Tidak ada tanaman matang di sini")
