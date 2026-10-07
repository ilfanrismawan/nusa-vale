class_name PassableTileLayer
extends TileMapLayer

var _passable_cells: Dictionary[Vector2i, bool] = {}
 
func set_cells_passable(cells: Array[Vector2i], passable: bool) -> void:
	for cell in cells:
		_passable_cells[cell] = passable
	notify_runtime_tile_data_update()
 
func _use_tile_data_runtime_update(coords: Vector2i) -> bool:
	return _passable_cells.has(coords)
 
func _tile_data_runtime_update(coords: Vector2i, tile_data: TileData) -> void:
	if _passable_cells.get(coords, false):
		for layer_id in tile_set.get_physics_layers_count():
			tile_data.set_collision_polygons_count(layer_id, 0)
 
