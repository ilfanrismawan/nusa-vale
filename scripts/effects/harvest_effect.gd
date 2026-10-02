class_name HarvestEffect
extends ActionEffect

func apply(
	_player: Player,
	cell: Vector2i
) -> void:
	if FarmManager.harvest(cell) :
		Notify.say("Panen berhasil!")
	else:
		Notify.say("Belum ada tanaman matang")
