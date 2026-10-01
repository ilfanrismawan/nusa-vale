class_name SeedEffect
extends ActionEffect

@export var crop: CropData
@export var seed_item_id: String = "seed_strawberry"

func apply(player: Player,	cell: Vector2i) -> void:
	if crop == null:
		push_warning("SeedEffect: crop belum di set!")
		return
		
	if not GameState.has_item(seed_item_id, 1):
		print("Tidak ada bibit %s di tas!" %seed_item_id)
		return
	
	var success := FarmManager.plant(cell, crop)
	if success:
		GameState.remove_item(seed_item_id, 1)
		print("Berhasil menanam: %s (Sisa bibit: %d)" % [crop.display_name, GameState.get_item_count(seed_item_id)])
	else:
		print("Tanah belum siap untuk ditanami")
