extends Node

signal crop_planted(cell: Vector2i, crop: CropData)
signal crop_harvested(cell, Vector2i, item_id: String, count: int)

var base_layer_ground: TileMapLayer
var soil_layer: TileMapLayer
var watered_layer: TileMapLayer
var crop_layer: TileMapLayer

var farm_data: Dictionary = {}

const TERRAIN_SET_SOIL := 0
const TERRAIN_TILLED := 0

func initialize(world: Node) -> void:
	base_layer_ground = world.get_node("BaseLayerGround")
	watered_layer = world.get_node("WateredLayer")
	soil_layer = world.get_node("SoilLayer")
	crop_layer = world.get_node("Crop")
	
	DayCycle.day_passed.connect(_on_day_passed)
	
	
func hoe(cell: Vector2i) -> void:
	if not is_tile_farmable(cell):
		return
	if farm_data.has(cell):
		return
	soil_layer.set_cells_terrain_connect(
		[cell], TERRAIN_SET_SOIL, TERRAIN_TILLED
	)
	farm_data[cell] = {
		"state": "tilled",
		"crop": null,
		"stage": 0,
		"days_in_stage": 0,
		"watered": false
	}
	print("Tanah dicangkul: ", cell)
	
func plant(cell: Vector2i, crop: CropData) -> bool:
	if not farm_data.has(cell):
		return false
	var data: Dictionary = farm_data[cell]
	if data["state"] != "tilled":
		return false
	
	data["state"] = "planted"
	data["crop"] = crop
	data["stage"] = 0
	data["days_in_stage"] = 0
	data["watered"] = false
	
	_update_crop_tile(cell, crop, 0)
	crop_planted.emit(cell, crop)
	print("Ditanam: %s di %s" % [crop.display_name, cell])
	return true

func water(cell: Vector2i) -> void:
	if not farm_data.has(cell):
		return
	var data:Dictionary = farm_data[cell]
	
	data["watered"] = true
	print("Disiram: ", cell)
	
	watered_layer.set_cells_terrain_connect(
		[cell], TERRAIN_SET_SOIL, 0
	)
	
func harvest(cell: Vector2i) -> bool:
	if not farm_data.has(cell):
		return false
	var data: Dictionary = farm_data[cell]
	if data["crop"] == null:
		return false
	var crop: CropData = data["crop"]
	if not crop.is_harvestable(data["stage"]):
		return false
	
	GameState.add_item(crop.harvest_item_id, crop.harvest_count)
	crop_harvested.emit(cell, crop.harvest_item_id, crop.harvest_count)
	print("Panen: %s x%d" % [crop.harvest_item_id, crop. harvest_count])
	
	crop_layer.erase_cell(cell)
	data["state"] = "tilled"
	data["crop"] = null
	data["stage"] = 0
	data["days_in_stage"] = 0
	data["watered"] = false
	return true
	
func _on_day_passed(_day: int) -> void:
	for cell in farm_data:
		var data: Dictionary = farm_data[cell]
		
		if data["crop"] != null and data["watered"]:
			var crop: CropData = data["crop"]
			var max_stage = crop.get_total_stages() - 1
					
			if data["stage"] < max_stage:
				data["days_in_stage"] += 1
				if data["days_in_stage"] >= crop.days_per_stage:
					data["stage"] += 1
					data["days_in_stage"] = 0
					_update_crop_tile(cell, crop, data["stage"])
					print("%s tumbuh ke stage %d" % [crop.display_name, data["stage"]])
			else:
				print("%s sudah siap panen di %s" % [crop.display_name, cell])
		
		data["watered"] = false
		
		watered_layer.erase_cell(cell)
			
func _update_crop_tile(cell: Vector2i, crop: CropData, stage: int) -> void:
	var coords := crop.growth_stages[stage]
	crop_layer.set_cell(cell, crop.tileset_source_id, coords)
	
func is_tile_farmable(cell: Vector2i) -> bool:
	var tile_data := base_layer_ground.get_cell_tile_data(cell)
	
	if tile_data == null:
		return false

	return tile_data.get_custom_data("farmable") == true
	
func get_cell_data(cell: Vector2i) -> Dictionary:
	return farm_data.get(cell, {})
