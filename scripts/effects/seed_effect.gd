class_name SeedEffect
extends ActionEffect

@export var crop: CropData
@export var seed_item_id: String = "seed_strawberry"

func apply(player: Player, cell: Vector2i) -> void:
	if crop == null:
		push_warning("SeedEffect: crop belum di set!")
		return
		
	if not FarmManager.is_crop_in_season(crop):
		Notify.say("%s tidak bisa ditanam di %s" % [crop.display_name, DayCycle.get_season_display_name()])
		return

	if not GameState.has_item(seed_item_id, 1):
		Notify.say("Bibit habis! Beli di toko")
		return
	
	var success: bool = FarmManager.plant(cell, crop)
	
	if success:
		GameState.remove_item(seed_item_id, 1)
		SkillSystem.gain(player.data, &"farmer", SkillSystem.RULES.plant_exp)
		Juice.play(&"plant", Juice.cell_center(player, cell))
		print("Berhasil menanam: %s (Sisa bibit: %d)" % [crop.display_name, GameState.get_item_count(seed_item_id)])
	else:
		Notify.say("Cangkul tanahnya dulu")
