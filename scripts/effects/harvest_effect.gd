class_name HarvestEffect
extends ActionEffect

func apply(
	_player: Player,
	cell: Vector2i
) -> void:
	var data: Dictionary = FarmManager.get_cell_data(cell)
	if data.is_empty() or data.get("crop") == null:
		return
	if not FarmManager.harvest(cell):
		Notify.say("Belum ada tanaman matang")
