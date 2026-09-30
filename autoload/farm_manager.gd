extends Node

var base_layer_ground: TileMapLayer
var soil_layer: TileMapLayer
var farm_data: Dictionary = {}

const TERRAIN_SET_SOIL := 0
const TERRAIN_TILLED := 0

func initialize(world: Node) -> void:
	base_layer_ground = world.get_node("BaseLayerGround")
	soil_layer = world.get_node("SoilLayer")
	
	
func hoe(cell: Vector2i) -> void:
	
	print ("Target cell: ", cell)
	
	if not is_tile_farmable(cell):
		return
	
	hoe_tile(cell)

func hoe_tile(cell: Vector2i) -> void:
	
	
	soil_layer.set_cells_terrain_connect(
		[cell],
		TERRAIN_SET_SOIL,
		TERRAIN_TILLED
	)
	
	farm_data[cell] = {
		"state": "tilled"
	}
	
func is_tile_farmable(cell: Vector2i) -> bool:
	var tile_data := base_layer_ground.get_cell_tile_data(cell)
	
	if tile_data == null:
		return false

	return tile_data.get_custom_data("farmable") == true
