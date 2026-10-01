class_name ShovelEffect
extends ActionEffect

func apply(player: Player, cell: Vector2i) -> void:
	if not FarmManager.farm_data.has(cell):
		print("Tidak ada tanah di sini")
		return
	
	var data:Dictionary = FarmManager.farm_data[cell]
	
	if data["crop"] != null:
		print("Ada tanaman di sini, tidak bisa digali!")
		return
	
	FarmManager.soil_layer.erase_cell(cell)
	FarmManager.watered_layer.erase_cell(cell)
	
	FarmManager.farm_data.erase(cell)
	print("Tanah dihapus: ", cell)
