extends Node2D

## Kawasan Gunung (GDD 9): dataran batu kecil di utara Hill dengan mulut Gua Tambang.
## Tile dan dinding dibangun dari kode (Rock Caves.png) supaya scene .tscn tetap kecil;
## dekorasi bisa ditambah di editor sebagai node biasa.

const ROCK_TILES := preload("res://assets/farm_rpg/tileset/ext/Rock Caves.png")
const DOOR_SHEET := preload("res://assets/farm_rpg/objects/exterior/Mine and Dungeon/Mine/Door Mine.png")
const FONT := preload("res://assets/fonts/m5x7.ttf")
const SCENE_ENTRANCE := preload("res://scripts/world/scene_entrance.gd")
const WINTER_POND := preload("res://scripts/world/winter_pond.gd")

const TILE := 16
const SIZE := Vector2i(40, 24)
const FLOOR_TOP := 3
## Mulut gua di tengah dinding atas.
const CAVE_CELL := Vector2i(20, 2)
## Celah dinding bawah menuju Hill.
const EXIT_CELLS := [Vector2i(19, 23), Vector2i(20, 23)]
const HILL_SCENE := "res://scenes/world/hill.tscn"
## Muncul di Hill tepat di bawah celah utara.
const HILL_SPAWN := Vector2(240, 150)
## Kolam air panas: spot pancing yang tidak membeku di Musim Dingin (GDD 5).
const HOT_SPRING_CELL := Vector2i(4, 10)
const HOT_SPRING_SIZE := Vector2i(8, 6)

const T_GROUND := Vector2i(4, 4)
const T_WALL_TOP := Vector2i(9, 1)
const T_WALL_EDGE := Vector2i(9, 3)
const T_CLIFF := Vector2i(9, 4)
const T_WALL_BOTTOM := Vector2i(9, 0)
const T_WALL_LEFT := Vector2i(11, 1)
const T_WALL_RIGHT := Vector2i(8, 1)

func _ready() -> void:
	_build()
	DayCycle.is_running = true
	for candidate in find_children("*", "CharacterBody2D", true, false):
		if candidate is Player:
			candidate.refresh_world()
			var camera := candidate.get_node_or_null("Camera2D") as Camera2D
			if camera != null and not Coop.has_root():
				if camera.has_method("set_default_zoom"):
					camera.set_default_zoom(2.0)
				camera.reset_smoothing()
	if DiscoveryManager.discover("mountain"):
		Notify.say("Gunung: mulut Gua Tambang ada di tebing utara. Toko Combat menunggu di lobi gua.")

func _build() -> void:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(TILE, TILE)
	tiles.add_custom_data_layer()
	tiles.set_custom_data_layer_name(0, "farmable")
	tiles.set_custom_data_layer_type(0, TYPE_BOOL)
	var source := TileSetAtlasSource.new()
	source.texture = ROCK_TILES
	source.texture_region_size = Vector2i(TILE, TILE)
	tiles.add_source(source, 0)
	var ground := TileMapLayer.new()
	ground.name = "BaseLayerGround"
	ground.z_index = -10
	ground.tile_set = tiles
	add_child(ground)
	var walls := TileMapLayer.new()
	walls.name = "MountainWalls"
	walls.z_index = -9
	walls.tile_set = tiles
	add_child(walls)
	for x in SIZE.x:
		for y in SIZE.y:
			_tile(ground, Vector2i(x, y), T_GROUND)
	for x in SIZE.x:
		_tile(walls, Vector2i(x, 0), T_WALL_TOP)
		_tile(walls, Vector2i(x, 1), T_WALL_EDGE)
		_tile(walls, Vector2i(x, 2), T_CLIFF)
		if not EXIT_CELLS.has(Vector2i(x, SIZE.y - 1)):
			_tile(walls, Vector2i(x, SIZE.y - 1), T_WALL_BOTTOM)
	for y in range(1, SIZE.y):
		_tile(walls, Vector2i(0, y), T_WALL_LEFT)
		_tile(walls, Vector2i(SIZE.x - 1, y), T_WALL_RIGHT)
	var bounds := StaticBody2D.new()
	bounds.name = "Walls"
	add_child(bounds)
	var w := float(SIZE.x * TILE)
	var h := float(SIZE.y * TILE)
	var gap_left := float(EXIT_CELLS[0].x * TILE)
	var gap_right := float((EXIT_CELLS[EXIT_CELLS.size() - 1].x + 1) * TILE)
	for rect in [Rect2(0, 0, w, FLOOR_TOP * TILE), Rect2(-8, 0, TILE + 8, h), Rect2(w - TILE, 0, TILE + 8, h),
			Rect2(0, h - TILE, gap_left, TILE + 8), Rect2(gap_right, h - TILE, w - gap_right, TILE + 8),
			Rect2(gap_left - 8, h + 8, gap_right - gap_left + 16, 8)]:
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.get_center()
		bounds.add_child(shape)
	_add_cave_mouth()
	_add_exit()
	_add_hot_spring()
	var sign_label := Label.new()
	sign_label.text = "Gua Tambang"
	sign_label.position = Vector2(CAVE_CELL * TILE) + Vector2(-16, 40)
	sign_label.add_theme_font_override("font", FONT)
	add_child(sign_label)

func _tile(layer: TileMapLayer, cell: Vector2i, atlas: Vector2i) -> void:
	var source := layer.tile_set.get_source(0) as TileSetAtlasSource
	if not source.has_tile(atlas):
		source.create_tile(atlas)
	layer.set_cell(cell, 0, atlas)

func _add_cave_mouth() -> void:
	var mouth := CaveEntrance.new()
	mouth.name = "CaveEntrance"
	mouth.position = Vector2(CAVE_CELL * TILE) + Vector2(8, 0)
	mouth.z_index = -8
	mouth.z_as_relative = false
	var sprite := Sprite2D.new()
	sprite.texture = DOOR_SHEET
	sprite.region_enabled = true
	sprite.region_rect = Rect2(32, 0, 32, 32)
	mouth.add_child(sprite)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(24, 14)
	shape.shape = box
	shape.position = Vector2(0, 18)
	mouth.add_child(shape)
	add_child(mouth)

func _add_exit() -> void:
	var exit := Area2D.new()
	exit.name = "ExitToHill"
	exit.set_script(SCENE_ENTRANCE)
	exit.set("scene_target", HILL_SCENE)
	exit.set("spawn_position", HILL_SPAWN)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(EXIT_CELLS.size() * TILE, 10)
	shape.shape = box
	exit.position = Vector2(float(EXIT_CELLS[0].x * TILE) + box.size.x * 0.5, SIZE.y * TILE + 2)
	exit.add_child(shape)
	add_child(exit)

func _add_hot_spring() -> void:
	var pond: Node2D = WINTER_POND.new()
	pond.name = "HotSpring"
	pond.size_tiles = HOT_SPRING_SIZE
	pond.location_id = "mountain_hot_spring"
	pond.steam = true
	pond.position = Vector2(HOT_SPRING_CELL * TILE)
	add_child(pond)
	var sign_label := Label.new()
	sign_label.text = "Air Panas"
	sign_label.position = Vector2(HOT_SPRING_CELL * TILE) + Vector2(HOT_SPRING_SIZE.x * TILE * 0.5 - 18, -14)
	sign_label.add_theme_font_override("font", FONT)
	add_child(sign_label)
