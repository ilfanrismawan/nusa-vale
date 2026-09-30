class_name TileEffect
extends ActionEffect

@export var source_id: int = 0
@export var atlas_coords := Vector2i.ZERO
@export var alternative_tile: int = 0

@export var required_flag: StringName

func apply(
	player: Player,
	cell: Vector2i
) -> void:
	var layer := player.base_layer_ground
	if not _can_apply(layer, cell):
		return
	layer.set_cell(cell, source_id, atlas_coords, alternative_tile)

func _can_apply(layer: TileMapLayer, cell: Vector2i) -> bool:
	if required_flag.is_empty():
		return true
	var data := layer.get_cell_tile_data(cell)
	return data != null and bool(data.get_custom_data(required_flag))
