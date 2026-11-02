extends Node

## Penyusun medan & dekorasi Balai Nadi (telaga berteratai, tebing air terjun utara, jalan tanah,
## sawah berundak, pulau lentera). Membuka balai.tscn yang ada lalu MENGGANTI isi layer medan
## (base, water, grass) dan node hasil generator; bangunan, dek, jembatan, tangga, pintu, batas,
## spawn dan sel air yang bisa dilewati (alt 1) tetap dari editor.
## Menjalankan ulang membuang suntingan editor pada layer/node hasil generator.
## Godot.exe --headless --path . res://tools/build_balai.tscn
const SCENE := "res://scenes/world/balai_nadi/balai.tscn"
const EXT := "res://assets/farm_rpg/tileset/ext/"
const GRASS := EXT + "Tileset Grass Spring.png"
const GRASS_WATER := EXT + "Tileset Grass Water Spring.png"
const CLIFF := EXT + "Tileset Grass Cliff Tileset Spring.png"
const WATERFALL := EXT + "Spring Waterfall.png"
const PROPS := EXT + "ALL props seasons.png"
const BUSHES := EXT + "bushes.png"
const DEEP_TREE := EXT + "Tree Deep Forest.png"
const MAHOGANY := "res://assets/farm_rpg/objects/tree/Mahogany Tree.png"
const WATER_PROPS := "res://assets/farm_rpg/objects/Props/Spring/props water.png"
const FENCE := "res://assets/farm_rpg/objects/exterior/Fence Wood.png"
const RICE := "res://assets/farm_rpg/crops/spring/Rice.png"
const SEA_ROCK := "res://assets/farm_rpg/objects/exterior/Beach/Stones 2.png"
const PROP_DIR := "res://scenes/world/balai_nadi/props/"
const SIZE := Vector2i(80, 57)
const TILE := 16
## Tebing utara: lereng rumput 2 baris + muka batu 2 baris; telaga mulai baris 4.
const CLIFF_ROWS := 4
const FALLS: Array[float] = [776.0, 1064.0]
## Node hasil generator, dihapus sebelum menyusun ulang.
const GENERATED := ["paths", "cliffs", "lilies", "fence", "rice", "Waterfalls", "Scenery", "CliffCollision", "SeasonalTileSwapper"]

var world: Node2D
var rng := RandomNumberGenerator.new()
var water: Dictionary = {}
var land: Dictionary = {}
var path: Dictionary = {}
var meadow: Dictionary = {}
var paddy: Dictionary = {}
var fence_cells: Dictionary = {}
var walkable: Dictionary = {}
var reserved: Dictionary = {}


func put(node: Node, parent: Node, label: String) -> Node:
	node.name = label
	parent.add_child(node)
	node.owner = world
	return node


func group(label: String, parent: Node = null) -> Node2D:
	var node := put(Node2D.new(), world if parent == null else parent, label) as Node2D
	node.y_sort_enabled = true
	return node


## Sprite berpijak di `at` (y-sort di kaki), sama seperti build_beach.gd.
func image(label: String, parent: Node, texture_path: String, at: Vector2, region: Rect2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(texture_path)
	sprite.position = at
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.offset = Vector2(0, -region.size.y * 0.5 + 4)
	return put(sprite, parent, label) as Sprite2D


func animated(label: String, parent: Node, texture_path: String, at: Vector2, region: Rect2, frames: int, fps: float) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	var set := SpriteFrames.new()
	set.set_animation_speed(&"default", fps)
	for i in frames:
		var texture := AtlasTexture.new()
		texture.atlas = load(texture_path)
		texture.region = Rect2(region.position + Vector2(region.size.x * i, 0), region.size)
		set.add_frame(&"default", texture)
	sprite.sprite_frames = set
	sprite.autoplay = "default"
	sprite.position = at
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return put(sprite, parent, label) as AnimatedSprite2D


func prop(label: String, parent: Node, scene_name: String, at: Vector2) -> Node2D:
	var node: Node2D = load(PROP_DIR + scene_name + ".tscn").instantiate()
	node.position = at
	return put(node, parent, label) as Node2D


func solid(label: String, parent: Node, rect: Rect2) -> StaticBody2D:
	var body := put(StaticBody2D.new(), parent, label) as StaticBody2D
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = rect.get_center()
	put(collider, body, "CollisionShape2D")
	return body


## Atlas 16 px; `frames` > 1 memberi animasi (horizontal dengan jarak `separation`, atau ke bawah).
func atlas_source(texture_path: String, coords: Array[Vector2i], frames := 1, separation := Vector2i.ZERO, columns := 0, speed := 3.0) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.texture = load(texture_path)
	source.texture_region_size = Vector2i(TILE, TILE)
	for cell in coords:
		if source.has_tile(cell):
			continue
		source.create_tile(cell)
		if frames > 1:
			source.set_tile_animation_columns(cell, columns)
			source.set_tile_animation_separation(cell, separation)
			source.set_tile_animation_speed(cell, speed)
			source.set_tile_animation_frames_count(cell, frames)
	return source


func tile_set_of(source: TileSetAtlasSource) -> TileSet:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(TILE, TILE)
	tiles.add_source(source, 0)
	return tiles


func new_layer(label: String, tiles: TileSet, z: int, after: String) -> TileMapLayer:
	var node := TileMapLayer.new()
	node.tile_set = tiles
	node.z_index = z
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	put(node, world, label)
	world.move_child(node, world.get_node(after).get_index() + 1)
	return node


# --- Bentuk peta (piksel) ---

## Telaga = gabungan persegi bersudut bulat [rect, radius]: tepi lurus panjang dan lengkung bertangga
## yang cocok dengan autotile (tanpa diagonal 1:1). Tepi bawah tepat di atas ujung titian (spawn y=784).
const LAKE := [
	[Rect2(208, 64, 976, 240), 56.0], [Rect2(224, 200, 960, 264), 40.0],
	[Rect2(240, 560, 340, 144), 48.0], [Rect2(400, 620, 180, 148), 40.0],
	[Rect2(560, 440, 600, 272), 64.0], [Rect2(560, 620, 430, 148), 48.0],
]
## Daratan di dalam telaga: tanjung barat (kaki tangga & bale kecil), tanjung timur (bale istirahat),
## tanjung batu di kaki tebing.
const LAND := [
	[Rect2(-40, 464, 594, 96), 16.0], [Rect2(984, 288, 260, 164), 20.0], [Rect2(368, 40, 144, 104), 32.0],
]


static func in_rounded(p: Vector2, rect: Rect2, radius: float) -> bool:
	var half := rect.size * 0.5
	var d := ((p - rect.get_center()).abs() - half + Vector2(radius, radius)).max(Vector2.ZERO)
	return absf(p.x - rect.get_center().x) <= half.x and absf(p.y - rect.get_center().y) <= half.y and d.length() <= radius


const ISLAND := Vector2(880, 610)
const ISLAND_RADIUS := Vector2(64, 44)

## Jalan tanah: tulang punggung barat (utara-tanjung-sawah), selatan ke pintu Kota, tenggara ke bale istirahat.
const PATHS := [
	[48.0, [Vector2(616, 770), Vector2(616, 912)]],
	[40.0, [Vector2(600, 864), Vector2(360, 868), Vector2(150, 860), Vector2(100, 800), Vector2(92, 660), Vector2(100, 512), Vector2(88, 380), Vector2(104, 240), Vector2(96, 104)]],
	[40.0, [Vector2(100, 512), Vector2(392, 512)]],
	[40.0, [Vector2(632, 864), Vector2(820, 868), Vector2(1000, 840), Vector2(1150, 780), Vector2(1222, 680), Vector2(1228, 480), Vector2(1170, 436), Vector2(1090, 436)]],
]

## Petak sawah berundak (sel) di antara jalan barat dan telaga.
const PADDIES: Array[Rect2i] = [Rect2i(9, 36, 5, 7), Rect2i(9, 45, 15, 4), Rect2i(9, 50, 25, 3)]


static func segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


func _classify() -> void:
	for y in SIZE.y:
		for x in SIZE.x:
			var cell := Vector2i(x, y)
			var p := Vector2(cell * TILE) + Vector2(8, 8)
			# Riak tepi agar garis pantai tidak kaku; ujung titian & area dek tetap persis.
			var calm := Rect2(520, 690, 200, 140).has_point(p) or Rect2(500, 330, 520, 150).has_point(p)
			var q := p
			if not calm:
				q += Vector2(14.0 * sin(p.y * 0.031 + 1.3) + 8.0 * sin(p.y * 0.083), 14.0 * sin(p.x * 0.027) + 8.0 * sin(p.x * 0.071 + 0.7))
			var wet := false
			for spec in LAKE:
				wet = wet or in_rounded(q, spec[0], spec[1])
			wet = wet and y >= CLIFF_ROWS
			for spec in LAND:
				if in_rounded(p, spec[0], spec[1]):
					wet = false
			if ((p - ISLAND) / ISLAND_RADIUS).length() < 1.0:
				wet = false
			if wet:
				water[cell] = true
	# Tanpa ubin daratan/air setebal 1 sel (tileset tidak punya ujung sempit).
	for pass_index in 4:
		for y in range(CLIFF_ROWS, SIZE.y):
			for x in SIZE.x:
				var cell := Vector2i(x, y)
				var w := func(c: Vector2i) -> bool: return water.has(c)
				var thin_land: bool = not water.has(cell) and ((w.call(cell + Vector2i.UP) and w.call(cell + Vector2i.DOWN)) or (w.call(cell + Vector2i.LEFT) and w.call(cell + Vector2i.RIGHT)))
				var thin_water: bool = water.has(cell) and ((not w.call(cell + Vector2i.UP) and not w.call(cell + Vector2i.DOWN) and cell.y > CLIFF_ROWS) or (not w.call(cell + Vector2i.LEFT) and not w.call(cell + Vector2i.RIGHT)))
				if thin_land and cell.y > CLIFF_ROWS:
					water[cell] = true
				elif thin_water:
					water.erase(cell)
	for y in range(CLIFF_ROWS, SIZE.y):
		for x in SIZE.x:
			if not water.has(Vector2i(x, y)):
				land[Vector2i(x, y)] = true
	for spec in PATHS:
		var width: float = spec[0]
		var points: Array = spec[1]
		for cell: Vector2i in land:
			var p := Vector2(cell * TILE) + Vector2(8, 8)
			for i in points.size() - 1:
				if segment_distance(p, points[i], points[i + 1]) <= width * 0.5:
					path[cell] = true
					break
	for rect in PADDIES:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var cell := Vector2i(x, y)
				if not land.has(cell) or path.has(cell):
					continue
				meadow[cell] = true
				var border := x == rect.position.x or x == rect.end.x - 1 or y == rect.position.y or y == rect.end.y - 1
				if border:
					fence_cells[cell] = rect
				else:
					paddy[cell] = true


# --- Autotile: tata letak blok 4x4 yang sama dipakai rumput-air, rumput terang, tanah dan tebing ---

## Pengambilan atlas berdasarkan tetangga di luar `cells`; tepi peta dihitung sama (tanpa pinggiran).
func blob_tile(cell: Vector2i, cells: Dictionary, row: int, solid_outside: Dictionary = {}, column := 0) -> Vector2i:
	var has := func(c: Vector2i) -> bool:
		return cells.has(c) or solid_outside.has(c) or c.x < 0 or c.y < 0 or c.x >= SIZE.x or c.y >= SIZE.y
	var n: bool = not has.call(cell + Vector2i.UP)
	var e: bool = not has.call(cell + Vector2i.RIGHT)
	var s: bool = not has.call(cell + Vector2i.DOWN)
	var w: bool = not has.call(cell + Vector2i.LEFT)
	var tile := Vector2i(9, 2)
	if n and w:
		tile = Vector2i(8, 0)
	elif n and e:
		tile = Vector2i(11, 0)
	elif s and w:
		tile = Vector2i(8, 3)
	elif s and e:
		tile = Vector2i(11, 3)
	elif n:
		tile = Vector2i(10, 0)
	elif s:
		tile = Vector2i(9, 3)
	elif w:
		tile = Vector2i(8, 1)
	elif e:
		tile = Vector2i(11, 2)
	elif not has.call(cell + Vector2i(-1, -1)):
		tile = Vector2i(5, 1)
	elif not has.call(cell + Vector2i(1, -1)):
		tile = Vector2i(6, 1)
	elif not has.call(cell + Vector2i(-1, 1)):
		tile = Vector2i(5, 2)
	elif not has.call(cell + Vector2i(1, 1)):
		tile = Vector2i(6, 2)
	return tile + Vector2i(column, row)


static func blob_coords(row: int, column := 0) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in [Vector2i(9, 2), Vector2i(8, 0), Vector2i(11, 0), Vector2i(8, 3), Vector2i(11, 3), Vector2i(10, 0), Vector2i(9, 3), Vector2i(8, 1), Vector2i(11, 2), Vector2i(5, 1), Vector2i(6, 1), Vector2i(5, 2), Vector2i(6, 2)]:
		out.append(c + Vector2i(column, row))
	return out


func _terrain() -> void:
	# Air: sel yang sudah bisa dilewati di editor (dek timur, titian) dan sel di bawah dek tetap alt 1.
	var water_layer := world.get_node("water") as TileMapLayer
	var old_land: Dictionary = {}
	for y in range(CLIFF_ROWS, SIZE.y):
		for x in range(SIZE.x):
			if water_layer.get_cell_source_id(Vector2i(x, y)) == -1:
				old_land[Vector2i(x, y)] = true
	# Run pertama: alt 1 dari editor. Run berikutnya: daftar tersimpan di metadata (layer kini penuh).
	if water_layer.has_meta("walkable_cells"):
		for cell: Vector2i in water_layer.get_meta("walkable_cells"):
			walkable[cell] = true
	else:
		for cell in water_layer.get_used_cells():
			if water_layer.get_cell_alternative_tile(cell) == 1:
				walkable[cell] = true
	for layer_name in ["TileMapLayer", "Bridge"]:
		for cell in (world.get_node(layer_name) as TileMapLayer).get_used_cells():
			walkable[cell] = true
	for cell: Vector2i in old_land:
		if Rect2i(34, 23, 9, 5).has_point(cell):
			walkable[cell] = true
	water_layer.clear()
	water_layer.z_index = -4
	water_layer.set_meta("walkable_cells", walkable.keys())
	# Seluruh peta diberi air (seperti Hutan) agar sudut transparan ubin tepi tidak bolong;
	# sel darat & sel yang bisa dilewati memakai alt 1 tanpa kolisi.
	for y in SIZE.y:
		for x in SIZE.x:
			var cell := Vector2i(x, y)
			water_layer.set_cell(cell, 0, Vector2i.ZERO, 0 if water.has(cell) and not walkable.has(cell) else 1)

	# Rumput bertepi air beranimasi (sama dengan BaseLayerGround Hutan): 4 frame, langkah 12 kolom.
	var cliff_cells: Dictionary = {}
	for y in CLIFF_ROWS:
		for x in SIZE.x:
			cliff_cells[Vector2i(x, y)] = true
	var base := world.get_node("base") as TileMapLayer
	base.clear()
	base.tile_set = tile_set_of(atlas_source(GRASS_WATER, blob_coords(8), 4, Vector2i(11, 0)))
	base.z_index = -3
	for cell: Vector2i in land:
		base.set_cell(cell, 0, blob_tile(cell, land, 8, cliff_cells))

	var light := world.get_node("grass") as TileMapLayer
	light.clear()
	light.tile_set = tile_set_of(atlas_source(GRASS, blob_coords(0)))
	light.z_index = -3
	for cell: Vector2i in meadow:
		light.set_cell(cell, 0, blob_tile(cell, meadow, 0))

	# Blok tanah varian rumput gelap (kolom +12) agar tepi jalan menyatu dengan rumput dasar.
	var dirt := new_layer("paths", tile_set_of(atlas_source(GRASS, blob_coords(8, 12))), -3, "grass")
	dirt.material = load("res://resources/soil_detail_material.tres")
	for cell: Vector2i in path:
		dirt.set_cell(cell, 0, blob_tile(cell, path, 8, {}, 12))


## Tebing utara: lereng rumput gelap (blok tebing baris 6-9), muka batu, kaki batu berair di atas telaga.
func _cliffs() -> void:
	var faces: Array[Vector2i] = [Vector2i(12, 2), Vector2i(14, 2), Vector2i(16, 2), Vector2i(18, 2)]
	var feet_water: Array[Vector2i] = [Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5)]
	var feet_ground: Array[Vector2i] = [Vector2i(12, 3), Vector2i(14, 3), Vector2i(16, 3), Vector2i(18, 3)]
	var coords := blob_coords(6)
	coords.append_array(faces)
	coords.append_array(feet_water)
	coords.append_array(feet_ground)
	var cliffs := new_layer("cliffs", tile_set_of(atlas_source(CLIFF, coords)), -3, "paths")
	var plateau: Dictionary = {}
	for x in SIZE.x:
		plateau[Vector2i(x, 0)] = true
		plateau[Vector2i(x, 1)] = true
	for cell: Vector2i in plateau:
		cliffs.set_cell(cell, 0, blob_tile(cell, plateau, 6))
	for x in SIZE.x:
		var center := x * TILE + 8.0
		var under_fall := false
		for fall_x in FALLS:
			under_fall = under_fall or absf(center - (fall_x - 2.0)) < 18.0
		if under_fall:
			continue
		cliffs.set_cell(Vector2i(x, 2), 0, faces[rng.randi() % faces.size()])
		var over_water := water.has(Vector2i(x, CLIFF_ROWS))
		var feet := feet_water if over_water else feet_ground
		cliffs.set_cell(Vector2i(x, 3), 0, feet[rng.randi() % feet.size()])
	var body := put(StaticBody2D.new(), world, "CliffCollision") as StaticBody2D
	var shape := RectangleShape2D.new()
	shape.size = Vector2(SIZE.x * TILE, CLIFF_ROWS * TILE)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = shape.size * 0.5
	put(collider, body, "CollisionShape2D")
	# Air terjun 64x64 (8 frame) jatuh dari tepi atas peta ke telaga.
	var falls := put(Node2D.new(), world, "Waterfalls") as Node2D
	falls.z_index = -2
	for i in FALLS.size():
		var sprite := animated("Waterfall%d" % i, falls, WATERFALL, Vector2(FALLS[i], 36), Rect2(0, 64, 64, 64), 8, 8.0)
		sprite.centered = true


func _water_life() -> void:
	# Daun teratai & alang-alang (animasi 4 frame ke bawah), jauh dari dek/titian.
	var pads: Array[Vector2i] = [Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0), Vector2i(0, 0), Vector2i(2, 0), Vector2i(6, 0), Vector2i(1, 4), Vector2i(2, 4)]
	var reeds: Array[Vector2i] = [Vector2i(9, 0), Vector2i(6, 4), Vector2i(7, 4)]
	var coords: Array[Vector2i] = []
	coords.append_array(pads)
	coords.append_array(reeds)
	var lilies := new_layer("lilies", tile_set_of(atlas_source(WATER_PROPS, coords, 4, Vector2i.ZERO, 1, 3.0)), -3, "cliffs")
	var busy := func(cell: Vector2i) -> bool:
		for y in range(-2, 3):
			for x in range(-2, 3):
				if walkable.has(cell + Vector2i(x, y)):
					return true
		return Rect2i(26, 14, 38, 16).has_point(cell)
	var cells := water.keys()
	cells.shuffle()
	var pad_count := 0
	var reed_count := 0
	for cell: Vector2i in cells:
		if busy.call(cell) or cell.y < CLIFF_ROWS + 1:
			continue
		var shore := false
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if land.has(cell + d):
				shore = true
		if shore and reed_count < 60 and rng.randf() < 0.4:
			lilies.set_cell(cell, 0, reeds[rng.randi() % reeds.size()])
			reed_count += 1
		elif not shore and pad_count < 150 and rng.randf() < 0.05:
			# Gerombol 3-7 daun, sebagian berbunga.
			for k in rng.randi_range(3, 7):
				var c: Vector2i = cell + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-1, 1))
				if water.has(c) and not busy.call(c) and lilies.get_cell_source_id(c) == -1:
					lilies.set_cell(c, 0, pads[rng.randi() % pads.size()])
					pad_count += 1


func _paddies() -> void:
	# Pagar kayu berkolisi + padi; keduanya y-sort per sel.
	var fence_coords: Array[Vector2i] = [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]
	var source := atlas_source(FENCE, fence_coords)
	var tiles := tile_set_of(source)
	tiles.add_physics_layer()
	for c in fence_coords:
		var vertical := c.y == 1
		var data := source.get_tile_data(c, 0)
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-3, -8), Vector2(3, -8), Vector2(3, 8), Vector2(-3, 8)]) if vertical else PackedVector2Array([Vector2(-8, 0), Vector2(8, 0), Vector2(8, 6), Vector2(-8, 6)]))
	var fence := new_layer("fence", tiles, 0, "lilies")
	fence.y_sort_enabled = true
	for cell: Vector2i in fence_cells:
		var rect: Rect2i = fence_cells[cell]
		var left := cell.x == rect.position.x
		var right := cell.x == rect.end.x - 1
		var top := cell.y == rect.position.y
		var column := 0 if left else (2 if right else 1)
		var row := 0 if top else (2 if cell.y == rect.end.y - 1 else 1)
		if row == 0 and column == 1:
			row = 2
		fence.set_cell(cell, 0, Vector2i(column, row))
	var rice := new_layer("rice", tile_set_of(atlas_source(RICE, [Vector2i(3, 0), Vector2i(4, 0)])), 0, "fence")
	rice.y_sort_enabled = true
	for cell: Vector2i in paddy:
		rice.set_cell(cell, 0, Vector2i(3 + rng.randi() % 2, 0))


func reserve(p: Vector2, radius: float) -> void:
	var cell := Vector2i(p / TILE)
	var reach := ceili(radius / TILE)
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			reserved[cell + Vector2i(x, y)] = true


func free_spot(p: Vector2, radius: float) -> bool:
	var cell := Vector2i(p / TILE)
	var reach := ceili(radius / TILE)
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			var c := cell + Vector2i(x, y)
			if not land.has(c) or path.has(c) or paddy.has(c) or fence_cells.has(c) or reserved.has(c):
				return false
	return true


func tree(label: String, parent: Node, at: Vector2, kind: int) -> void:
	var specs := [[MAHOGANY, Rect2(96, 0, 32, 48)], [DEEP_TREE, Rect2(64, 0, 32, 48)], [DEEP_TREE, Rect2(64, 48, 32, 48)], [DEEP_TREE, Rect2(64, 240, 32, 48)]]
	var spec: Array = specs[kind % specs.size()]
	image(label, parent, spec[0], at, spec[1])
	solid(label + "Trunk", parent, Rect2(at.x - 5, at.y - 4, 10, 8))
	reserve(at, 16)


func _scenery() -> void:
	var decor := group("Scenery")
	# Bangunan & dek dari editor tidak boleh tertimpa dekorasi.
	reserve(Vector2(616, 351), 120)
	reserve(Vector2(1049, 380), 72)
	reserve(Vector2(432, 480), 40)
	reserve(Vector2(510, 450), 48)
	reserve(Vector2(616, 800), 40)
	# Sakral: arca naga & lentera di tanjung barat, umbul-umbul mengapit ujung titian dan bale istirahat.
	var shrine := group("Shrine", decor)
	prop("NagaWest", shrine, "penjaga_naga", Vector2(500, 552))
	prop("NagaShoreLeft", shrine, "penjaga_naga", Vector2(568, 808))
	prop("NagaShoreRight", shrine, "penjaga_naga", Vector2(668, 808))
	prop("Offering", shrine, "dulang_daya", Vector2(380, 492))
	for spec in [["BannerShoreLeft", Vector2(576, 778)], ["BannerShoreRight", Vector2(658, 778)], ["BannerPavilionWest", Vector2(996, 448)], ["BannerPavilionEast", Vector2(1118, 448)], ["BannerPeninsula", Vector2(240, 488)]]:
		prop(spec[0], shrine, "umbul_umbul", spec[1])
		reserve(spec[1], 12)
	var lanterns := [Vector2(296, 488), Vector2(296, 540), Vector2(548, 498), Vector2(136, 300), Vector2(136, 700), Vector2(700, 900), Vector2(530, 900),
		Vector2(1190, 700), Vector2(1196, 520), Vector2(1100, 470), Vector2(150, 96), Vector2(880, 600)]
	for i in lanterns.size():
		prop("Lantern%d" % i, shrine, "lentera_andesit", lanterns[i])
		reserve(lanterns[i], 12)
	# Teratai Nadi besar di air terbuka.
	for p in [Vector2(320, 300), Vector2(430, 170), Vector2(720, 560), Vector2(820, 220), Vector2(1110, 600), Vector2(470, 640), Vector2(1010, 150), Vector2(300, 430), Vector2(960, 690), Vector2(360, 600)]:
		prop("Lotus%d" % int(p.x + p.y), decor, "teratai_nadi", p)
	# Batu berombak di kaki tebing dan sekitar pulau.
	for p in [Vector2(700, 96), Vector2(904, 92), Vector2(1140, 100), Vector2(300, 96), Vector2(950, 640), Vector2(800, 592)]:
		var rock := animated("WaterRock%d" % int(p.x), decor, SEA_ROCK, p, Rect2(0, 0, 48, 32), 4, 4.0)
		rock.offset = Vector2(0, -12)
	# Pulau: lentera (di atas), pohon & semak.
	tree("IslandTree", decor, Vector2(904, 596), 1)
	image("IslandBush", decor, BUSHES, Vector2(852, 620), Rect2(48, 0, 48, 32))
	# Tanjung batu di kaki tebing: pohon, semak, lentera.
	tree("PromontoryTree", decor, Vector2(408, 104), 0)
	tree("PromontoryTree2", decor, Vector2(476, 92), 2)
	image("PromontoryBush", decor, BUSHES, Vector2(440, 126), Rect2(48, 32, 48, 32))
	# Semak di atas tebing (lewati air terjun).
	var ridge := group("Ridge", decor)
	for x in range(8, 1280, 26):
		var near_fall := false
		for fall_x in FALLS:
			near_fall = near_fall or absf(x - fall_x) < 44.0
		if near_fall or rng.randf() < 0.25:
			continue
		image("RidgeBush%d" % x, ridge, BUSHES, Vector2(x + rng.randi_range(-4, 4), 20 + rng.randi_range(-3, 3)), Rect2(48 * (rng.randi() % 2), 32 * (rng.randi() % 4), 48, 32))
	# Rumpun pohon rimbun di tepi peta (barat, timur laut, timur, tenggara, barat daya).
	var trees := group("Trees", decor)
	var clusters: Array[Vector2] = [Vector2(40, 160), Vector2(160, 200), Vector2(36, 380), Vector2(170, 380), Vector2(30, 620), Vector2(40, 820),
		Vector2(1240, 120), Vector2(1240, 250), Vector2(1250, 560), Vector2(1240, 860), Vector2(1080, 880), Vector2(900, 890), Vector2(780, 800),
		Vector2(1150, 860), Vector2(300, 900), Vector2(160, 900), Vector2(1100, 760), Vector2(980, 790)]
	var count := 0
	for center in clusters:
		for k in 40:
			var p := center + Vector2(rng.randf_range(-80, 80), rng.randf_range(-64, 64))
			if p.x < 6 or p.x > 1274 or p.y < 76 or p.y > 906 or not free_spot(p, 12):
				continue
			tree("Tree%d" % count, trees, p, rng.randi() % 4)
			count += 1
	# Semak, bunga & rumput liar.
	var flowers: Array[Rect2] = [Rect2(176, 0, 16, 16), Rect2(192, 0, 16, 16), Rect2(144, 0, 16, 16), Rect2(224, 0, 16, 16), Rect2(176, 16, 16, 16), Rect2(192, 16, 16, 16),
		Rect2(144, 144, 16, 16), Rect2(160, 144, 16, 16), Rect2(176, 160, 16, 16), Rect2(192, 160, 16, 16), Rect2(160, 176, 16, 16)]
	var tufts: Array[Rect2] = [Rect2(160, 0, 16, 16), Rect2(160, 128, 16, 16), Rect2(176, 128, 16, 16), Rect2(192, 128, 16, 16)]
	var plants := group("Plants", decor)
	var cells := land.keys()
	cells.shuffle()
	for cell: Vector2i in cells:
		var p := Vector2(cell * TILE) + Vector2(rng.randi_range(3, 13), rng.randi_range(6, 14))
		if not free_spot(p, 0):
			continue
		var roll := rng.randf()
		if roll < 0.04 and free_spot(p, 16):
			image("Bush%d_%d" % [cell.x, cell.y], plants, BUSHES, p, Rect2(48 * (rng.randi() % 2), 32 * (rng.randi() % 3), 48, 32))
			solid("Bush%d_%dBody" % [cell.x, cell.y], plants, Rect2(p.x - 8, p.y - 4, 16, 6))
			reserve(p, 16)
		elif roll < 0.16:
			image("Flower%d_%d" % [cell.x, cell.y], plants, PROPS, p, flowers[rng.randi() % flowers.size()])
			reserve(p, 0)
		elif roll < 0.30:
			image("Tuft%d_%d" % [cell.x, cell.y], plants, PROPS, p, tufts[rng.randi() % tufts.size()])
			reserve(p, 0)


func _ready() -> void:
	call_deferred("_build")


func _build() -> void:
	rng.seed = 20261102
	var packed: PackedScene = load(SCENE)
	world = packed.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	for label in GENERATED:
		var old := world.get_node_or_null(label)
		if old != null:
			world.remove_child(old)
			old.free()
	_classify()
	_terrain()
	_cliffs()
	_water_life()
	_paddies()
	_scenery()
	var seasons := Node.new()
	seasons.set_script(load("res://scripts/world/seasonal_tile_swapper.gd"))
	put(seasons, world, "SeasonalTileSwapper")
	var scene := PackedScene.new()
	assert(scene.pack(world) == OK)
	var uid := ResourceLoader.get_resource_uid(SCENE)
	var error := ResourceSaver.save(scene, SCENE)
	# PackedScene baru tidak membawa UID lama; rujukan uid:// (pintu Balai di kota) harus tetap valid.
	if error == OK and uid != ResourceUID.INVALID_ID:
		error = ResourceSaver.set_uid(SCENE, uid)
	print("BALAI BUILD: ", error_string(error), "; land=", land.size(), " water=", water.size(), " path=", path.size(), " walkable=", walkable.size())
	world.free()
	get_tree().quit(0 if error == OK else 1)
