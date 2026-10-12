extends Node2D

## Reserved logical coordinates keep greenhouse plots separate from existing farm cells.
## Layer offset places them in this small room, without editing the farm's TileMaps.
const FIRST_CELL := Vector2i(10000, 10000)
const SOIL = preload("res://assets/farm_rpg/tileset/ext/Tilled Soil and wet soil.png")
const FONT = preload("res://assets/fonts/m5x7.ttf")

func _ready() -> void:
	set_meta("farm_area", "greenhouse")
	_build_layers()
	FarmManager.initialize(self)
	SaveManager.game_loaded.connect(_reload_plots)
	DayCycle.day_passed.connect(_refresh_plots)
	DayCycle.is_running = true

func _build_layers() -> void:
	for layer_name in ["BaseLayerGround", "SoilLayer", "WateredLayer", "Crop"]:
		var layer := TileMapLayer.new()
		layer.name = layer_name
		layer.position = Vector2(363, 195) - Vector2(FIRST_CELL * 16)
		layer.tile_set = TileSet.new()
		layer.tile_set.tile_size = Vector2i(16, 16)
		if layer_name != "Crop":
			var texture := AtlasTexture.new()
			texture.atlas = SOIL
			texture.region = Rect2(64, 80 if layer_name == "WateredLayer" else 16, 16, 16)
			var source := TileSetAtlasSource.new()
			source.texture = texture
			source.texture_region_size = Vector2i(16, 16)
			source.create_tile(Vector2i.ZERO)
			layer.tile_set.add_source(source, 0)
			if layer_name == "BaseLayerGround":
				layer.tile_set.add_custom_data_layer()
				layer.tile_set.set_custom_data_layer_name(0, "farmable")
				layer.tile_set.set_custom_data_layer_type(0, TYPE_BOOL)
				source.get_tile_data(Vector2i.ZERO, 0).set_custom_data("farmable", true)
				layer.modulate = Color(0.7, 0.75, 0.7)
				for y in 4:
					for x in 8:
						layer.set_cell(FIRST_CELL + Vector2i(x, y), 0, Vector2i.ZERO)
		add_child(layer)
	# Player._ready runs first; update its ground reference once the runtime layers exist.
	for node in find_children("*", "CharacterBody2D", true, false):
		if node is Player:
			node.refresh_world()

func _reload_plots() -> void:
	$SoilLayer.clear()
	$WateredLayer.clear()
	$Crop.clear()
	FarmManager.initialize(self)

func _refresh_plots(_day: int) -> void:
	# Co-op may have another area's layers bound while this room is still loaded.
	$WateredLayer.clear()
	FarmManager.initialize(self)

func _exit_tree() -> void:
	if FarmManager._bound_world == self:
		FarmManager.clear_references()

func _draw() -> void:
	draw_rect(Rect2(320, 150, 214, 190), Color("715337"))
	draw_rect(Rect2(327, 163, 200, 168), Color("dbc99e"))
	draw_rect(Rect2(328, 152, 198, 14), Color("729e99"))
	draw_string(FONT, Vector2(371, 162), "GREENHOUSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f7e9bf"))
	draw_rect(Rect2(415, 322, 24, 15), Color("795534"))
