extends Node

signal crop_planted(cell: Vector2i, crop: CropData)
signal crop_harvested(cell: Vector2i, item_id: String, count: int)

const ItemPickupScript = preload("res://scripts/world/item_pickup.gd")

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
	
	if base_layer_ground:
		if soil_layer:
			soil_layer.position = base_layer_ground.position
		if watered_layer:
			watered_layer.position = base_layer_ground.position
		if crop_layer:
			crop_layer.position = base_layer_ground.position
	
	if not DayCycle.day_passed.is_connected(_on_day_passed):
		DayCycle.day_passed.connect(_on_day_passed)
	
	_restore_tiles()
	
func _restore_tiles() -> void:
	for cell in farm_data:
		var data: Dictionary = farm_data[cell]
		
		soil_layer.set_cells_terrain_connect(
			[cell], TERRAIN_SET_SOIL, TERRAIN_TILLED
		)
		
		if data["watered"]:
			watered_layer.set_cells_terrain_connect(
				[cell], TERRAIN_SET_SOIL, 0
			)
		
		if data["crop"] != null:
			_update_crop_tile(cell, data["crop"], data["stage"])
	
	if not farm_data.is_empty():
		print("Restore tile: %d petak dikembalikan" % farm_data.size())
	
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
	
func can_harvest(cell: Vector2i) -> bool:
	if not farm_data.has(cell):
		return false
	var data: Dictionary = farm_data[cell]
	if data.get("crop") == null:
		return false
	var crop: CropData = data["crop"]
	return crop.is_harvestable(data["stage"])


func harvest(cell: Vector2i) -> bool:
	if not can_harvest(cell):
		return false
	var data: Dictionary = farm_data[cell]
	var crop: CropData = data["crop"]
	
	var item_id: String = crop.harvest_item_id
	var count: int = crop.harvest_count
	crop_harvested.emit(cell, item_id, count)
	print("Panen: %s x%d" % [item_id, count])
	
	if is_instance_valid(crop_layer):
		crop_layer.erase_cell(cell)
	data["state"] = "tilled"
	data["crop"] = null
	data["stage"] = 0
	data["days_in_stage"] = 0
	data["watered"] = false
	_spawn_harvest_drop(cell, item_id, count)
	return true


func _spawn_harvest_drop(cell: Vector2i, item_id: String, count: int) -> void:
	var parent: Node = crop_layer.get_parent() if is_instance_valid(crop_layer) else null
	if parent == null:
		parent = get_tree().current_scene
	var world_pos := Vector2.ZERO
	if is_instance_valid(crop_layer):
		world_pos = crop_layer.to_global(crop_layer.map_to_local(cell))
	elif is_instance_valid(base_layer_ground):
		world_pos = base_layer_ground.to_global(base_layer_ground.map_to_local(cell))
	for i in count:
		var offset := Vector2(randf_range(-10.0, 10.0), randf_range(-4.0, 6.0))
		ItemPickupScript.spawn(parent, world_pos + Vector2(0, -8) + offset, item_id, 1)
	
func _on_day_passed(_day: int) -> void:
	var layers_valid := is_instance_valid(crop_layer) and is_instance_valid(watered_layer)
	
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
					if layers_valid:
						_update_crop_tile(cell, crop, data["stage"])
					print("%s tumbuh ke stage %d" % [crop.display_name, data["stage"]])
			else:
				print("%s sudah siap panen di %s" % [crop.display_name, cell])
		
		data["watered"] = false
		
		if layers_valid:
			watered_layer.erase_cell(cell)
			
func _update_crop_tile(cell: Vector2i, crop: CropData, stage: int) -> void:
	if not is_instance_valid(crop_layer):
		return
	var coords := crop.growth_stages[stage]
	crop_layer.set_cell(cell, crop.tileset_source_id, coords)
	
func is_tile_farmable(cell: Vector2i) -> bool:
	var tile_data := base_layer_ground.get_cell_tile_data(cell)
	
	if tile_data == null:
		return false

	return tile_data.get_custom_data("farmable") == true
	
func get_cell_data(cell: Vector2i) -> Dictionary:
	return farm_data.get(cell, {})


func shovel(cell: Vector2i) -> void:
	if not farm_data.has(cell):
		print("Tidak ada tanah di sini")
		return
	var data: Dictionary = farm_data[cell]
	if data["crop"] != null:
		print("Ada tanaman di sini, tidak bisa digali!")
		return
	if is_instance_valid(soil_layer):
		soil_layer.erase_cell(cell)
	if is_instance_valid(watered_layer):
		watered_layer.erase_cell(cell)
	farm_data.erase(cell)
	print("Tanah dihapus: ", cell)


func chop(player: Player, cell: Vector2i, damage: int = 1) -> bool:
	return hit_world(player, cell, &"choppable", damage)


func mine(player: Player, cell: Vector2i, damage: int = 1) -> bool:
	return hit_world(player, cell, &"mineable", damage)


func hit_world(player: Player, cell: Vector2i, target_group: StringName, damage: int = 1) -> bool:
	if player == null:
		return false
	var scene_tree := player.get_tree()
	if scene_tree == null:
		return false
	var target_pos := player.get_target_world_position()
	const REACH := 24.0
	for node in scene_tree.get_nodes_in_group(target_group):
		if not (node is Node2D and node.has_method("take_hit")):
			continue
		var hit_pos := _hit_origin(node)
		if player.world_to_cell(hit_pos) == cell or hit_pos.distance_to(target_pos) <= REACH:
			node.take_hit(damage)
			return true
	return false


func _hit_origin(node: Node2D) -> Vector2:
	var shape := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape:
		return shape.global_position
	return node.global_position
