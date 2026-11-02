extends Node

## Initial scene authoring tool for Pantai (GDD 3, area Pantai). The saved .tscn stays editable in Godot.
## Re-running replaces res://scenes/world/beach.tscn and discards editor edits.
## Godot.exe --headless --path . res://tools/build_beach.tscn
const OUTPUT := "res://scenes/world/beach.tscn"
const EXT := "res://assets/farm_rpg/tileset/ext/"
const BEACH := "res://assets/farm_rpg/objects/exterior/Beach/"
const GRASS := EXT + "Tileset Grass Spring.png"
const SEA := EXT + "Beach animations tiles.png"
const DOCK := EXT + "Bridge Beach.png"
const PALM := "res://assets/farm_rpg/crops/Fruits Tree/Summer/Coconut tree.png"
const SIZE := Vector2i(60, 50)
const TILE := 16
## Utara: jalan dari Town (BeachAccess di tepi selatan Town).
const ENTRY_X := 480.0
const TOWN_SPAWN := Vector2(689, 1110)
## Dermaga: badan 3 tile, kepala T selebar 9 tile.
const PIER_COLS := Vector2i(34, 36)
const PIER_HEAD := Rect2i(31, 41, 9, 2)
## Ubin animasi pantai: 4 frame ke bawah, tiap frame 4 baris.
const SEA_FRAMES := 4
const SAND_TILES: Array[Vector2i] = [Vector2i(12, 12), Vector2i(13, 12), Vector2i(14, 12)]

var world: Node2D
var rng := RandomNumberGenerator.new()
var land: Dictionary = {}
var water: Dictionary = {}
var grass: Dictionary = {}
var road: Dictionary = {}
var pier: Dictionary = {}
var reserved: Dictionary = {}


func put(node: Node, parent: Node, label: String) -> Node:
	node.name = label
	parent.add_child(node)
	node.owner = world
	return node


func group(label: String, parent: Node = null) -> Node2D:
	return put(Node2D.new(), world if parent == null else parent, label) as Node2D


func image(label: String, parent: Node, path: String, at: Vector2, region := Rect2()) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(path)
	sprite.position = at
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if region.size != Vector2.ZERO:
		sprite.region_enabled = true
		sprite.region_rect = region
	# Y-sort at the object's feet.
	var height := region.size.y if region.size != Vector2.ZERO else float(sprite.texture.get_height())
	sprite.offset = Vector2(0, -height * 0.5 + 4)
	return put(sprite, parent, label) as Sprite2D


func animated(label: String, parent: Node, path: String, at: Vector2, frame_size: Vector2, frames: int, fps: float) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	var set := SpriteFrames.new()
	set.set_animation_speed(&"default", fps)
	for i in frames:
		var texture := AtlasTexture.new()
		texture.atlas = load(path)
		texture.region = Rect2(Vector2(frame_size.x * i, 0), frame_size)
		set.add_frame(&"default", texture)
	sprite.sprite_frames = set
	sprite.autoplay = "default"
	sprite.position = at
	sprite.offset = Vector2(0, -frame_size.y * 0.5 + 4)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return put(sprite, parent, label) as AnimatedSprite2D


func box(label: String, parent: Node, rect: Rect2) -> CollisionShape2D:
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = rect.get_center()
	return put(collider, parent, label) as CollisionShape2D


func solid(label: String, parent: Node, rect: Rect2) -> StaticBody2D:
	var body := put(StaticBody2D.new(), parent, label) as StaticBody2D
	box("CollisionShape2D", body, rect)
	return body


func point(parent: Node, label: String, at: Vector2) -> void:
	var marker := Marker2D.new()
	marker.position = at
	put(marker, parent, label)


func signboard(label: String, parent: Node, at: Vector2, caption: String) -> void:
	var board: Node2D = load("res://scenes/objects/building_sign.tscn").instantiate()
	board.position = at
	board.caption = caption
	board.font_size = 16
	board.minimum_width = 88
	put(board, parent, label)


func layer(label: String, path: String, atlas_coords: Array[Vector2i], z: int, animate := false) -> TileMapLayer:
	var node := TileMapLayer.new()
	node.z_index = z
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(TILE, TILE)
	var source := TileSetAtlasSource.new()
	source.texture = load(path)
	source.texture_region_size = Vector2i(TILE, TILE)
	for cell in atlas_coords:
		if source.has_tile(cell):
			continue
		source.create_tile(cell)
		if animate:
			source.set_tile_animation_columns(cell, 1)
			source.set_tile_animation_separation(cell, Vector2i(0, 3))
			source.set_tile_animation_frames_count(cell, SEA_FRAMES)
			for frame in SEA_FRAMES:
				source.set_tile_animation_frame_duration(cell, frame, 0.3)
	tiles.add_source(source, 0)
	node.tile_set = tiles
	return put(node, world, label) as TileMapLayer


# --- Bentuk peta (pusat sel dalam piksel) ---

static func grass_edge(x: float) -> float:
	return 96.0 + 12.0 * sin(x * 0.02) + 8.0 * sin(x * 0.051)


## Garis pantai; di timur pasir menjorok ke laut membentuk tanjung karang.
static func shore_y(x: float) -> float:
	var cape := clampf((x - 740.0) * 0.4, 0.0, 70.0)
	return 472.0 + 14.0 * sin(x * 0.013) + 10.0 * sin(x * 0.031) + cape


## Muara sungai di barat, menempel ke tepi peta.
static func river_x(y: float) -> float:
	return 56.0 + y * 0.1 + 10.0 * sin(y * 0.02)


static func is_sea(p: Vector2) -> bool:
	return p.y > shore_y(p.x) or p.x < river_x(p.y) + 20.0 + p.y * 0.04


func in_pier(cell: Vector2i) -> bool:
	return pier.has(cell)


func edge_tile(cell: Vector2i, cells: Dictionary) -> Vector2i:
	# Outside the map counts as the same terrain, so the map border has no fringe.
	var has := func(c: Vector2i) -> bool:
		return cells.has(c) or c.x < 0 or c.y < 0 or c.x >= SIZE.x or c.y >= SIZE.y
	var left: bool = not has.call(cell + Vector2i.LEFT)
	var right: bool = not has.call(cell + Vector2i.RIGHT)
	var top: bool = not has.call(cell + Vector2i.UP)
	var bottom: bool = not has.call(cell + Vector2i.DOWN)
	return Vector2i(8 if left else (11 if right else 9), 0 if top else (3 if bottom else 1))


func edge_coords(offset := Vector2i.ZERO) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in [8, 9, 11]:
		for y in [0, 1, 3]:
			out.append(Vector2i(x, y) + offset)
	return out


func reserve(p: Vector2, radius: float) -> void:
	var cell := Vector2i(p / TILE)
	var reach := ceili(radius / TILE)
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			reserved[cell + Vector2i(x, y)] = true


func free_spot(p: Vector2, radius: float) -> bool:
	var cell := Vector2i(p / TILE)
	if not land.has(cell) or road.has(cell) or pier.has(cell):
		return false
	var reach := ceili(radius / TILE)
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			var c := cell + Vector2i(x, y)
			if reserved.has(c) or water.has(c):
				return false
	return true


func _classify() -> void:
	for y in SIZE.y:
		for x in SIZE.x:
			var cell := Vector2i(x, y)
			var p := Vector2(cell * TILE) + Vector2(8, 8)
			if is_sea(p):
				water[cell] = true
			else:
				land[cell] = true
				if p.y < grass_edge(p.x):
					grass[cell] = true
				if absf(p.x - ENTRY_X) < 24.0 and p.y < grass_edge(p.x) + 28.0:
					road[cell] = true
	# Dermaga: badan dari pasir terakhir sampai kepala T.
	var first_water := SIZE.y
	for y in SIZE.y:
		if water.has(Vector2i(PIER_COLS.x, y)):
			first_water = y
			break
	for x in range(PIER_COLS.x, PIER_COLS.y + 1):
		for y in range(first_water - 1, PIER_HEAD.position.y):
			pier[Vector2i(x, y)] = true
	for x in range(PIER_HEAD.position.x, PIER_HEAD.end.x):
		for y in range(PIER_HEAD.position.y, PIER_HEAD.end.y):
			pier[Vector2i(x, y)] = true


func _terrain() -> void:
	var base := Polygon2D.new()
	base.polygon = PackedVector2Array([Vector2.ZERO, Vector2(SIZE.x * TILE, 0), Vector2(SIZE * TILE), Vector2(0, SIZE.y * TILE)])
	base.color = Color8(242, 206, 150)
	base.z_index = -12
	put(base, world, "SandBase")
	# Pasir di semua sel darat; ForageSpawner memakai layer ini sebagai tanah.
	var ground := layer("BaseLayerGround", SEA, SAND_TILES, -10)
	for cell: Vector2i in land:
		ground.set_cell(cell, 0, SAND_TILES[rng.randi() % SAND_TILES.size()])
	var sea := layer("SeaWater", SEA, edge_coords(), -10, true)
	for cell: Vector2i in water:
		sea.set_cell(cell, 0, edge_tile(cell, water))
	var meadow_coords := edge_coords()
	meadow_coords.append(Vector2i(9, 2))
	var meadow := layer("Grass", GRASS, meadow_coords, -9)
	meadow.material = load("res://resources/grass_detail_material.tres")
	for cell: Vector2i in grass:
		var tile := edge_tile(cell, grass)
		meadow.set_cell(cell, 0, Vector2i(9, 2) if tile == Vector2i(9, 1) else tile)
	var dirt_coords: Array[Vector2i] = []
	for x in range(4, 8):
		for y in range(8, 12):
			dirt_coords.append(Vector2i(x, y))
	var paths := layer("Paths", GRASS, dirt_coords, -8)
	for cell: Vector2i in road:
		var left := not road.has(cell + Vector2i.LEFT)
		var right := not road.has(cell + Vector2i.RIGHT)
		var top := not road.has(cell + Vector2i.UP) and cell.y > 0
		var bottom := not road.has(cell + Vector2i.DOWN)
		paths.set_cell(cell, 0, Vector2i(4 if left else 7 if right else 5, 8 if top else 11 if bottom else 9))


func _dock() -> void:
	var coords: Array[Vector2i] = []
	for x in 8:
		for y in 5:
			coords.append(Vector2i(x, y))
	var deck := layer("Pier", DOCK, coords, -7)
	var top_row := PIER_HEAD.position.y
	for cell: Vector2i in pier:
		if cell.y >= top_row:
			continue
		var column := 5 + (cell.x - PIER_COLS.x)
		# Baris pertama di pasir memakai ujung dermaga yang menyatu dengan pasir.
		deck.set_cell(cell, 0, Vector2i(column, 0 if not pier.has(cell + Vector2i.UP) else 2))
	for x in range(PIER_HEAD.position.x, PIER_HEAD.end.x):
		var column := 0 if x == PIER_HEAD.position.x else (2 if x == PIER_HEAD.end.x - 1 else 1)
		deck.set_cell(Vector2i(x, top_row), 0, Vector2i(column, 1))
		deck.set_cell(Vector2i(x, top_row + 1), 0, Vector2i(column, 2))
		deck.set_cell(Vector2i(x, top_row + 2), 0, Vector2i(column, 3))


func _collisions() -> void:
	var terrain := group("TerrainCollisions")
	# Air laut menahan pemain; sel dermaga dibiarkan bisa dilewati.
	for y in SIZE.y:
		var start := -1
		for x in SIZE.x + 1:
			var wet := x < SIZE.x and water.has(Vector2i(x, y)) and not pier.has(Vector2i(x, y))
			if wet and start < 0:
				start = x
			elif not wet and start >= 0:
				solid("Water_%d_%d" % [start, y], terrain, Rect2(start * TILE, y * TILE, (x - start) * TILE, TILE))
				start = -1
	var width := SIZE.x * TILE
	var gap := Rect2(ENTRY_X - 32.0, -16, 64, 16)
	for rect in [Rect2(0, -16, gap.position.x, 16), Rect2(gap.end.x, -16, width - gap.end.x, 16), Rect2(-16, 0, 16, SIZE.y * TILE), Rect2(width, 0, 16, SIZE.y * TILE), Rect2(0, SIZE.y * TILE, width, 16)]:
		solid("Edge%d" % terrain.get_child_count(), terrain, rect)


func _fishing() -> void:
	# Seluruh laut adalah spot beach_sea; air laut tidak membeku di Musim Dingin (Glacier Fish).
	var spot := Area2D.new()
	spot.set_script(load("res://scripts/world/fishing_spot.gd"))
	spot.location_id = "beach_sea"
	spot.freezes_in_winter = false
	put(spot, world, "SeaFishingSpot")
	for y in SIZE.y:
		var start := -1
		for x in SIZE.x + 1:
			var wet := x < SIZE.x and water.has(Vector2i(x, y))
			if wet and start < 0:
				start = x
			elif not wet and start >= 0:
				box("Sea_%d_%d" % [start, y], spot, Rect2(start * TILE, y * TILE, (x - start) * TILE, TILE))
				start = -1
	# Gelembung ikan sebagai penanda spot favorit: ujung dermaga, karang timur, bibir pantai barat.
	var markers := group("FishHotspots")
	for spec in [["PierEnd", Vector2(568, 724)], ["Reef", Vector2(840, 618)], ["WestShore", Vector2(300, 540)]]:
		animated(spec[0], markers, BEACH + "FishPoint.png", spec[1], Vector2(16, 16), 5, 6.0)


func _scenery() -> Node2D:
	var decor := group("Scenery")
	decor.y_sort_enabled = true
	# Pohon kelapa di barat laut dan timur laut (forage kelapa/lidah buaya sekitar sini).
	var palms := [Vector2(200, 176), Vector2(264, 214), Vector2(176, 256), Vector2(312, 168), Vector2(232, 300), Vector2(808, 168), Vector2(872, 214), Vector2(920, 160), Vector2(760, 250)]
	for i in palms.size():
		var p: Vector2 = palms[i]
		var column: int = [5, 7, 1, 2][i % 4]
		image("Palm%d" % i, decor, PALM, p, Rect2(column * 32, 0, 32, 48))
		solid("PalmTrunk%d" % i, decor, Rect2(p.x - 5, p.y - 6, 10, 8))
		reserve(p, 14)
	image("Hammock", decor, BEACH + "Coconut Tree.png", Vector2(392, 236), Rect2(0, 0, 80, 48))
	for x in [372.0, 412.0]:
		solid("HammockPost%d" % int(x), decor, Rect2(x - 5, 230, 10, 8))
	reserve(Vector2(392, 236), 28)
	# Area festival / santai: payung, handuk, kursi, istana pasir.
	var festival := group("FestivalArea", decor)
	image("UmbrellaRed", festival, BEACH + "Beach Umbrella.png", Vector2(664, 260), Rect2(0, 0, 32, 32))
	image("UmbrellaBlue", festival, BEACH + "Beach Umbrella.png", Vector2(744, 300), Rect2(32, 0, 32, 32))
	image("UmbrellaOrange", festival, BEACH + "Beach Umbrella.png", Vector2(624, 330), Rect2(64, 0, 32, 32))
	image("TowelA", festival, BEACH + "Beach Towel.png", Vector2(690, 290), Rect2(0, 0, 32, 64))
	image("TowelB", festival, BEACH + "Beach Towel.png", Vector2(650, 360), Rect2(64, 0, 32, 64))
	image("Lounger", festival, BEACH + "Beach Chair with Umbrella.png", Vector2(728, 372), Rect2(0, 0, 32, 32))
	image("Sandcastle", festival, BEACH + "Sandcastle.png", Vector2(600, 400), Rect2(0, 16, 16, 16))
	image("Ball", festival, BEACH + "Beach Volleyball Ball.png", Vector2(704, 410), Rect2(0, 0, 16, 16))
	for child in festival.get_children():
		reserve(child.position, 18)
	for p in [Vector2(664, 260), Vector2(744, 300), Vector2(624, 330)]:
		solid("UmbrellaPole%d" % int(p.x), festival, Rect2(p.x - 3, p.y - 4, 6, 6))
	# Lapak nelayan di pangkal dermaga.
	var stall := group("FishStall", decor)
	image("Crates", stall, BEACH + "Fish Crate.png", Vector2(520, 432), Rect2(0, 0, 16, 16))
	image("Crates2", stall, BEACH + "Fish Crate.png", Vector2(504, 440), Rect2(16, 0, 16, 16))
	image("Barrel", stall, BEACH + "Fish Barrel.png", Vector2(616, 436), Rect2(0, 0, 32, 32))
	image("LifeRing", stall, BEACH + "Life Ring.png", Vector2(624, 404), Rect2(0, 0, 32, 32))
	for child in stall.get_children():
		reserve(child.position, 16)
	solid("StallBody", stall, Rect2(496, 426, 32, 12))
	solid("BarrelBody", stall, Rect2(606, 428, 20, 10))
	animated("Canoe", decor, BEACH + "wood canoe.png", Vector2(664, 696), Vector2(32, 48), 4, 3.0)
	# Batu karang: tanjung timur di darat, batu berombak di laut.
	for p in [Vector2(800, 470), Vector2(872, 478), Vector2(920, 500), Vector2(824, 520)]:
		image("ShoreRock%d" % int(p.x), decor, BEACH + "Stones 3.png", p, Rect2(0, 0, 32, 32))
		solid("ShoreRockBody%d" % int(p.x), decor, Rect2(p.x - 12, p.y - 10, 24, 12))
		reserve(p, 18)
	for p in [Vector2(808, 600), Vector2(896, 580), Vector2(864, 660), Vector2(120, 640), Vector2(392, 700)]:
		animated("SeaRock%d" % int(p.x), decor, BEACH + "Stones 2.png", p, Vector2(48, 32), 4, 4.0)
	# Tanda arah dan pintu masuk utara.
	signboard("TownDirection", decor, Vector2(ENTRY_X + 64, 64), "UTARA: KOTA")
	reserve(Vector2(ENTRY_X, 40), 40)
	# Detail kecil: kerang/batu kecil tersebar di pasir, bunga liar di rumput.
	for i in 70:
		var p := Vector2(rng.randi_range(64, 940), rng.randi_range(40, 520))
		if not free_spot(p, 8):
			continue
		var cell := Vector2i(p / TILE)
		if grass.has(cell):
			image("Wildflower%d" % i, decor, EXT + "ALL props seasons.png", p, Rect2(192 if i % 2 else 208, 0, 16, 16))
		else:
			image("Pebble%d" % i, decor, BEACH + "Props.png", p, Rect2(16 * (i % 4), 48, 16, 16))
		reserve(p, 8)
	return decor


func _spawners(decor: Node2D) -> void:
	var forage := ForageSpawner.new()
	forage.location_id = "beach"
	forage.daily_spawn = 4
	forage.max_active = 14
	forage.entities_path = NodePath("Scenery")
	put(forage, world, "ForageSpawner")


func _exits() -> void:
	var area := Area2D.new()
	area.position = Vector2(ENTRY_X, 4)
	area.set_script(load("res://scripts/world/scene_entrance.gd"))
	area.scene_target = "res://scenes/world/town.tscn"
	area.spawn_position = TOWN_SPAWN
	put(area, world, "ExitToTown")
	box("CollisionShape2D", area, Rect2(-32, -12, 64, 24))


func _player() -> void:
	var spawn := Vector2(ENTRY_X, 72)
	var root: Node2D = load("res://scenes/player/Player.tscn").instantiate()
	root.position = spawn
	put(root, world, "Player")
	point(world, "SpawnPoint", spawn)
	var seasons := Node.new()
	seasons.set_script(load("res://scripts/world/seasonal_tile_swapper.gd"))
	put(seasons, world, "SeasonalTileSwapper")


func _ready() -> void:
	call_deferred("_build")


func _build() -> void:
	rng.seed = 20261102
	world = Node2D.new()
	world.name = "Beach"
	world.y_sort_enabled = true
	_classify()
	_terrain()
	_dock()
	_collisions()
	_fishing()
	var decor := _scenery()
	_spawners(decor)
	_exits()
	_player()
	world.set_script(load("res://scripts/world/beach.gd"))
	world.map_size = SIZE * TILE
	var scene := PackedScene.new()
	assert(scene.pack(world) == OK)
	var error := ResourceSaver.save(scene, OUTPUT)
	print("BEACH BUILD: ", error_string(error), "; land=", land.size(), " water=", water.size(), " pier=", pier.size())
	world.free()
	get_tree().quit(0 if error == OK else 1)
