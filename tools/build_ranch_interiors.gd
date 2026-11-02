extends Node

## Penyusun awal interior Barn dan Coop (gaya lumbung kayu: dinding papan berjendela, palung jerami
## panjang di dinding belakang, kandang jerami berpagar). Hasilnya scene biasa yang diedit di editor:
## lantai/jerami/dinding (TileMapLayer), dekorasi (`Decor`), titik hewan (`Pens/Pen0..11`), titik
## interaksi (`Spots/<aksi>`, `DirtSpots/Dirt0..2`), pintu hewan (`AnimalDoor`), batas (`Bounds`), `Exit`.
## Menjalankan ulang MENIMPA kedua scene beserta suntingan editor.
## Godot.exe --headless --path . res://tools/build_ranch_interiors.tscn
const OUT := {"barn": "res://scenes/world/interior/barn_interior.tscn", "chicken_coop": "res://scenes/world/interior/coop_interior.tscn"}
const ROOM_TILESET := "res://resources/ranch/ranch_interior_tileset.tres"
const HOUSE := "res://assets/farm_rpg/tileset/int/Tileset House.png"
const BARN_TILES := "res://assets/farm_rpg/tileset/ext/Barn tileset.png"
const FRAME := "res://assets/greenhouse/greenhouse_frame.png"
const FENCE := "res://assets/farm_rpg/objects/exterior/Fence Wood.png"
const WINDOW := "res://assets/farm_rpg/objects/exterior/Houses/Farm Buildings/Barn/Window.png"
const LAMP := "res://assets/farm_rpg/objects/exterior/Houses/Farm Buildings/Barn/Lamp.png"
const HAY := "res://assets/farm_rpg/objects/exterior/Hay Bales.png"
const BARRELS := "res://assets/farm_rpg/objects/exterior/Stacked Barrels.png"
const BUCKETS := "res://assets/farm_rpg/objects/exterior/Wooden Buckets.png"
const TOOLS := "res://assets/farm_rpg/objects/exterior/Farm Tools.png"
const BUSHES := "res://assets/farm_rpg/tileset/ext/bushes.png"
const PROPS := "res://assets/farm_rpg/tileset/ext/ALL props seasons.png"
const CHICKEN_DOOR := "res://assets/farm_rpg/objects/exterior/Houses/Farm Buildings/Chicken Coop/Chicken Door.png"
const RANCH := "res://assets/ranch/"
const FONT := "res://assets/fonts/m5x7.ttf"
const TILE := 16
## Ruangan 28 × 16 tile; cukup kecil untuk terlihat utuh pada zoom interior 2×.
const ROOM := Vector2(224, 112)
const SIZE := Vector2i(28, 16)
## Source di ROOM_TILESET.
const SRC_HOUSE := 0
const SRC_BARN := 1
const SRC_FRAME := 2
const BRICK_FLOOR := Vector2i(14, 2)
const PLANK_FLOOR := Vector2i(26, 3)
const PLANTER := Vector2i(2, 1)
## Jerami bertekstur (Barn tileset baris 11-14): persegi bertepi.
const STRAW := {"tl": Vector2i(8, 11), "t": Vector2i(9, 11), "tr": Vector2i(11, 11), "l": Vector2i(8, 13), "r": Vector2i(11, 12),
	"bl": Vector2i(8, 14), "b": Vector2i(10, 14), "br": Vector2i(11, 14), "c": [Vector2i(10, 12), Vector2i(9, 13)]}

var world: Node2D
var housing := ""
var room_tiles: TileSet
var rng := RandomNumberGenerator.new()


func put(node: Node, parent: Node, label: String) -> Node:
	node.name = label
	parent.add_child(node)
	node.owner = world
	return node


func at(cell: Vector2) -> Vector2:
	return ROOM + cell * TILE


## Sprite berpijak di `foot` (y-sort di kaki).
func image(label: String, parent: Node, texture_path: String, foot: Vector2, region: Rect2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(texture_path)
	sprite.position = foot
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.offset = Vector2(0, -region.size.y * 0.5)
	return put(sprite, parent, label) as Sprite2D


func solid(parent: Node, label: String, rect: Rect2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = rect.get_center()
	put(collider, parent, label)


func marker(parent: Node, label: String, pos: Vector2) -> Marker2D:
	var node := Marker2D.new()
	node.position = pos
	return put(node, parent, label) as Marker2D


func label(parent: Node, text: String, pos: Vector2) -> Label:
	var node := Label.new()
	node.text = text
	node.position = pos
	node.z_index = 5
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_override("font", load(FONT))
	node.add_theme_font_size_override("font_size", 16)
	node.add_theme_color_override("font_color", Color("fff1c9"))
	node.add_theme_color_override("font_outline_color", Color("50332b"))
	node.add_theme_constant_override("outline_size", 2)
	return put(node, parent, label_name(text)) as Label


func label_name(text: String) -> String:
	return "Label" + text.replace(" ", "")


func atlas(texture_path: String, coords: Array[Vector2i]) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.texture = load(texture_path)
	source.texture_region_size = Vector2i(TILE, TILE)
	for cell in coords:
		if not source.has_tile(cell):
			source.create_tile(cell)
	return source


func tileset() -> TileSet:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(TILE, TILE)
	tiles.add_source(atlas(HOUSE, [BRICK_FLOOR, PLANK_FLOOR]), SRC_HOUSE)
	var barn: Array[Vector2i] = []
	for x in 4:
		for y in [4, 5]:
			barn.append(Vector2i(x, y))
	for key in STRAW:
		if STRAW[key] is Array:
			for c: Vector2i in STRAW[key]:
				barn.append(c)
		else:
			barn.append(STRAW[key])
	tiles.add_source(atlas(BARN_TILES, barn), SRC_BARN)
	tiles.add_source(atlas(FRAME, [PLANTER]), SRC_FRAME)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOM_TILESET.get_base_dir()))
	assert(ResourceSaver.save(tiles, ROOM_TILESET) == OK)
	tiles.take_over_path(ROOM_TILESET)
	return tiles


func layer(label_text: String, z: int) -> TileMapLayer:
	var node := TileMapLayer.new()
	node.tile_set = room_tiles
	node.z_index = z
	node.position = ROOM
	return put(node, world, label_text) as TileMapLayer


func straw_rect(layer_node: TileMapLayer, rect: Rect2i) -> void:
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var left := x == rect.position.x
			var right := x == rect.end.x - 1
			var top := y == rect.position.y
			var bottom := y == rect.end.y - 1
			var key := ("t" if top else "b" if bottom else "") + ("l" if left else "r" if right else "")
			var tile: Vector2i = STRAW.c[(x + y) % 2] if key.is_empty() else STRAW[key]
			layer_node.set_cell(Vector2i(x, y), SRC_BARN, tile)


## Pagar kayu: tiang/rel per 16 px dengan collision, celah `gaps` (koordinat sepanjang garis).
func fence_line(parent: Node, bounds: Node, from: Vector2, to: Vector2, gaps: Array = []) -> void:
	var horizontal := is_equal_approx(from.y, to.y)
	var steps := int(round((to - from).length() / 16.0))
	for i in steps + 1:
		var spot := from + (to - from).normalized() * 16.0 * i
		var along := spot.x if horizontal else spot.y
		var skip := false
		for gap: Vector2 in gaps:
			if along >= gap.x and along <= gap.y:
				skip = true
		if skip:
			continue
		var key := "%d_%d" % [spot.x, spot.y]
		var rail := image("Fence_" + key, parent, FENCE, spot + (Vector2(0, 6) if horizontal else Vector2(5, 6)), Rect2(16, 32, 16, 16) if horizontal else Rect2(0, 16, 16, 16))
		rail.modulate = Color(0.78, 0.62, 0.5)
		solid(bounds, "Fence_" + key, Rect2(spot.x - 8, spot.y - 4, 16, 6) if horizontal else Rect2(spot.x - 3, spot.y - 12, 6, 16))


func walls(wall_layer: TileMapLayer, floor_layer: TileMapLayer, door_cols: Array) -> void:
	for x in SIZE.x:
		for y in SIZE.y:
			var cell := Vector2i(x, y)
			var plank := Vector2i(posmod(x, 4), 4 + posmod(y, 2))
			if y < 3 or x == 0 or x == SIZE.x - 1 or (y == SIZE.y - 1 and not door_cols.has(x)):
				wall_layer.set_cell(cell, SRC_BARN, plank)
	for x in door_cols:
		floor_layer.set_cell(Vector2i(x, SIZE.y - 1), SRC_HOUSE, PLANK_FLOOR)


func windows_and_lamps(decor: Node, columns: Array) -> void:
	for i in columns.size():
		var x: float = columns[i]
		image("Window%d" % i, decor, WINDOW, at(Vector2(x, 2.4)), Rect2(0, 0, 48, 32)).z_index = -3
	for x in [columns[0] + 2.5, columns[-1] - 2.5]:
		image("Lamp%d" % int(x), decor, LAMP, at(Vector2(x, 2.6)), Rect2(0, 0, 16, 32)).z_index = -3


## Palung jerami panjang di dinding belakang (feeding_trough 48 px, berulang).
func trough(decor: Node, bounds: Node, from_col: int, count: int) -> Vector2:
	for i in count:
		image("Trough%d" % i, decor, RANCH + "feeding_trough.png", at(Vector2(from_col + 1.5 + i * 3, 4.6)), Rect2(0, 0, 48, 16))
	solid(bounds, "Trough", Rect2(at(Vector2(from_col, 3.6)), Vector2(count * 48, 16)))
	return at(Vector2(from_col + count * 1.5, 5.6))


func animal_door(spots: Node, pos: Vector2, spot: Vector2) -> void:
	var door := image("AnimalDoor", world, CHICKEN_DOOR, pos, Rect2(5, 2, 17, 14))
	door.z_index = -2
	door.set_meta("open_region", Rect2(5, 18, 17, 14))
	door.set_meta("closed_region", Rect2(5, 2, 17, 14))
	marker(spots, "door", spot)


func pens(origin: Vector2, step: Vector2) -> void:
	var holder := put(Node2D.new(), world, "Pens")
	for slot in 12:
		marker(holder, "Pen%d" % slot, at(origin + Vector2(slot % 4, slot / 4) * step))


func base_scene(name_text: String) -> Array:
	world = Node2D.new()
	world.name = name_text
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.set_script(load("res://scripts/world/ranch_interior.gd"))
	world.set("housing", housing)
	var floor_layer := layer("BaseLayerGround", -10)
	var straw := layer("Straw", -9)
	var wall_layer := layer("Walls", -9)
	var decor := put(Node2D.new(), world, "Decor") as Node2D
	decor.y_sort_enabled = true
	var spots := put(Node2D.new(), world, "Spots")
	var dirt := put(Node2D.new(), world, "DirtSpots")
	var bounds := put(StaticBody2D.new(), world, "Bounds")
	return [floor_layer, straw, wall_layer, decor, spots, dirt, bounds]


func finish(exit_col: float, spawn: Vector2) -> void:
	var bounds := world.get_node("Bounds")
	solid(bounds, "Back", Rect2(ROOM, Vector2(SIZE.x * TILE, 3 * TILE + 6)))
	solid(bounds, "Left", Rect2(ROOM, Vector2(TILE, SIZE.y * TILE)))
	solid(bounds, "Right", Rect2(at(Vector2(SIZE.x - 1, 0)), Vector2(TILE, SIZE.y * TILE)))
	solid(bounds, "BottomLeft", Rect2(at(Vector2(0, SIZE.y - 1)), Vector2((exit_col - 1) * TILE, TILE)))
	solid(bounds, "BottomRight", Rect2(at(Vector2(exit_col + 1, SIZE.y - 1)), Vector2((SIZE.x - exit_col - 1) * TILE, TILE)))
	solid(bounds, "DoorStop", Rect2(at(Vector2(exit_col - 1, SIZE.y)) + Vector2(0, 6), Vector2(2 * TILE, 6)))
	var exit := Area2D.new()
	exit.position = at(Vector2(exit_col, SIZE.y - 0.3))
	put(exit, world, "Exit")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(30, 10)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	put(collider, exit, "CollisionShape2D")
	marker(world.get_node("Spots"), "exit", at(Vector2(exit_col, SIZE.y - 0.6)))
	var player: Node2D = load("res://scenes/player/Player.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	player.position = spawn
	put(player, world, "Player")
	marker(world, "spawn", spawn)
	# Hewan di dalam (`Animals`) dan label status dibuat oleh ranch_interior.gd saat runtime.


func save(path: String) -> void:
	var uid := ResourceLoader.get_resource_uid(path)
	var scene := PackedScene.new()
	assert(scene.pack(world) == OK)
	var error := ResourceSaver.save(scene, path)
	# PackedScene baru tidak membawa UID lama; pertahankan agar rujukan uid:// tetap valid.
	if error == OK and uid != ResourceUID.INVALID_ID:
		error = ResourceSaver.set_uid(path, uid)
	print("RANCH INTERIOR BUILD %s: %s" % [path, error_string(error)])
	world.free()
	assert(error == OK)


## Barn: ruang simpan kiri atas, bilik jerami kiri bawah, aula bata, kandang jerami besar di kanan.
func build_barn() -> void:
	housing = "barn"
	var parts := base_scene("BarnInterior")
	var floor_layer: TileMapLayer = parts[0]
	var straw: TileMapLayer = parts[1]
	var wall_layer: TileMapLayer = parts[2]
	var decor: Node2D = parts[3]
	var spots: Node = parts[4]
	var dirt: Node = parts[5]
	var bounds: Node = parts[6]
	for x in range(1, SIZE.x - 1):
		for y in range(3, SIZE.y - 1):
			floor_layer.set_cell(Vector2i(x, y), SRC_HOUSE, PLANK_FLOOR if x <= 7 else BRICK_FLOOR)
	walls(wall_layer, floor_layer, [9, 10])
	# Sekat ruang simpan (kiri atas) dengan pintu di kanan.
	for x in range(1, 7):
		wall_layer.set_cell(Vector2i(x, 8), SRC_BARN, Vector2i(posmod(x, 4), 5))
	solid(bounds, "StoreWall", Rect2(at(Vector2(1, 8)), Vector2(6 * TILE, TILE)))
	straw_rect(straw, Rect2i(1, 10, 6, 4))
	straw_rect(straw, Rect2i(12, 7, 15, 8))
	windows_and_lamps(decor, [3.5, 10.5, 15.5, 20.5, 25.5])
	var feed := trough(decor, bounds, 11, 4)
	marker(spots, "feed", feed)
	label(decor, "Palung", feed + Vector2(-17, -44))
	image("Water0", decor, RANCH + "water_basin.png", at(Vector2(24.5, 4.6)), Rect2(0, 0, 16, 16))
	image("Water1", decor, RANCH + "water_basin.png", at(Vector2(25.5, 4.6)), Rect2(0, 0, 16, 16))
	solid(bounds, "Water", Rect2(at(Vector2(24, 3.6)), Vector2(32, 16)))
	# Ruang simpan: jerami cadangan, papan Kelola, tong, ember.
	image("HayStock", decor, HAY, at(Vector2(2.5, 4.4)), Rect2(0, 0, 32, 16))
	solid(bounds, "HayStock", Rect2(at(Vector2(1.5, 3.6)), Vector2(32, 12)))
	marker(spots, "stock", at(Vector2(2.5, 5.4)))
	label(decor, "Cadangan", at(Vector2(1, 5.5)))
	image("CareBoard", decor, RANCH + "care_board.png", at(Vector2(5.5, 4.6)), Rect2(0, 0, 32, 32))
	solid(bounds, "CareBoard", Rect2(at(Vector2(4.6, 3.6)), Vector2(28, 14)))
	marker(spots, "menu", at(Vector2(5.5, 5.6)))
	label(decor, "Kelola", at(Vector2(4.6, 5.7)))
	image("Barrels", decor, BARRELS, at(Vector2(1.6, 7.8)), Rect2(0, 0, 32, 32))
	solid(bounds, "Barrels", Rect2(at(Vector2(1, 7)), Vector2(24, 12)))
	image("Bucket", decor, BUCKETS, at(Vector2(6.2, 7.6)), Rect2(0, 16, 16, 16))
	# Bilik jerami kiri bawah: tumpukan jerami dan alat.
	image("HayLeft", decor, HAY, at(Vector2(2.5, 11)), Rect2(0, 0, 32, 16))
	image("HayRight", decor, HAY, at(Vector2(5.5, 11)), Rect2(0, 0, 32, 16))
	solid(bounds, "HayStall", Rect2(at(Vector2(1.5, 10.2)), Vector2(5 * TILE, 10)))
	image("Tools", decor, TOOLS, at(Vector2(4, 14.6)), Rect2(0, 0, 48, 16))
	solid(bounds, "Tools", Rect2(at(Vector2(2.6, 14)), Vector2(44, 8)))
	# Kandang: pagar dengan gerbang di sisi kiri.
	fence_line(decor, bounds, at(Vector2(11.5, 6.5)), at(Vector2(26.5, 6.5)))
	fence_line(decor, bounds, at(Vector2(11.5, 7.5)), at(Vector2(11.5, 14.5)), [Vector2(at(Vector2(0, 9.5)).y, at(Vector2(0, 11.5)).y)])
	pens(Vector2(14, 8.6), Vector2(3.5, 2.2))
	animal_door(spots, at(Vector2(20, 15.1)), at(Vector2(20, 14.2)))
	label(decor, "Pintu hewan", at(Vector2(18.2, 13.4)))
	for i in 3:
		marker(dirt, "Dirt%d" % i, at(Vector2(9, 7.5 + i * 2.2)))
	finish(9.5, at(Vector2(9.5, 13.5)))
	save(OUT.barn)


## Coop: palung panjang di belakang, kandang jerami tengah berpagar dengan gerbang, pot pohon di
## kedua ujung, sarang telur di depan pagar, penyimpanan kiri, kebun kecil kanan.
func build_coop() -> void:
	housing = "chicken_coop"
	var parts := base_scene("CoopInterior")
	var floor_layer: TileMapLayer = parts[0]
	var straw: TileMapLayer = parts[1]
	var wall_layer: TileMapLayer = parts[2]
	var decor: Node2D = parts[3]
	var spots: Node = parts[4]
	var dirt: Node = parts[5]
	var bounds: Node = parts[6]
	for x in range(1, SIZE.x - 1):
		for y in range(3, SIZE.y - 1):
			floor_layer.set_cell(Vector2i(x, y), SRC_HOUSE, PLANK_FLOOR)
	walls(wall_layer, floor_layer, [2, 3])
	straw_rect(straw, Rect2i(6, 4, 16, 6))
	windows_and_lamps(decor, [4.5, 10.5, 17.5, 23.5])
	var feed := trough(decor, bounds, 9, 3)
	marker(spots, "feed", feed)
	label(decor, "Palung", feed + Vector2(-17, -44))
	# Pot pohon bata di kedua ujung kandang.
	for side in [[6, "Left"], [18, "Right"]]:
		var x: int = side[0]
		for dx in 3:
			wall_layer.set_cell(Vector2i(x + dx, 4), SRC_FRAME, PLANTER)
		var p := at(Vector2(x + 1.5, 4.9))
		image("Planter%sBush" % side[1], decor, BUSHES, p, Rect2(48, 0, 48, 32))
		solid(bounds, "Planter" + side[1], Rect2(at(Vector2(x, 4)), Vector2(48, 14)))
	# Pagar depan dengan gerbang tengah, sisi kiri/kanan kandang.
	fence_line(decor, bounds, at(Vector2(5.5, 10.2)), at(Vector2(22.5, 10.2)), [Vector2(at(Vector2(13, 0)).x, at(Vector2(15, 0)).x)])
	fence_line(decor, bounds, at(Vector2(5.5, 4.5)), at(Vector2(5.5, 9.5)))
	fence_line(decor, bounds, at(Vector2(22.5, 4.5)), at(Vector2(22.5, 9.5)))
	pens(Vector2(8.5, 6), Vector2(3.6, 1.4))
	# Sarang telur di depan pagar kiri.
	for i in 3:
		image("Nest%d" % i, decor, RANCH + "nesting_box.png", at(Vector2(7.5 + i * 2, 11.8)), Rect2(0, 0, 32, 16))
	solid(bounds, "Nests", Rect2(at(Vector2(6.5, 11)), Vector2(6 * TILE, 12)))
	marker(spots, "eggs", at(Vector2(9.5, 12.6)))
	label(decor, "Sarang telur", at(Vector2(7.6, 12.6)))
	# Mesin dan tong di depan pagar kanan.
	image("Mayo", decor, RANCH + "mayonnaise_maker.png", at(Vector2(17, 12)), Rect2(0, 0, 32, 32))
	image("Incubator", decor, RANCH + "incubator.png", at(Vector2(19, 11.9)), Rect2(0, 0, 16, 16))
	image("HayFront", decor, HAY, at(Vector2(21.5, 12)), Rect2(0, 0, 32, 16))
	solid(bounds, "FrontRight", Rect2(at(Vector2(16, 11.2)), Vector2(7 * TILE, 12)))
	# Penyimpanan kiri: jerami cadangan dan papan Kelola dekat pintu.
	image("HayStock", decor, HAY, at(Vector2(2.5, 4.4)), Rect2(0, 0, 32, 16))
	solid(bounds, "HayStock", Rect2(at(Vector2(1.5, 3.6)), Vector2(32, 12)))
	marker(spots, "stock", at(Vector2(2.5, 5.4)))
	label(decor, "Cadangan", at(Vector2(1, 5.5)))
	image("CareBoard", decor, RANCH + "care_board.png", at(Vector2(2.5, 8.6)), Rect2(0, 0, 32, 32))
	solid(bounds, "CareBoard", Rect2(at(Vector2(1.5, 7.6)), Vector2(32, 14)))
	marker(spots, "menu", at(Vector2(2.5, 9.6)))
	label(decor, "Kelola", at(Vector2(1.6, 9.7)))
	image("Barrels", decor, BARRELS, at(Vector2(4.6, 14.6)), Rect2(0, 0, 32, 32))
	solid(bounds, "Barrels", Rect2(at(Vector2(4, 13.8)), Vector2(24, 12)))
	# Kebun kecil kanan: semak dan bunga.
	for i in 3:
		var p := at(Vector2(25.5, 5.5 + i * 3))
		var bush := image("GardenBush%d" % i, decor, BUSHES, p, Rect2(48 * (i % 2), 32 * i, 48, 32))
		bush.material = load("res://resources/greenhouse/plant_sway_material.tres")
		solid(bounds, "GardenBush%d" % i, Rect2(p.x - 12, p.y - 6, 24, 8))
	var flowers: Array[Rect2] = [Rect2(176, 0, 16, 16), Rect2(192, 0, 16, 16), Rect2(224, 0, 16, 16), Rect2(192, 16, 16, 16)]
	for i in 6:
		image("Flower%d" % i, decor, PROPS, at(Vector2(24 + (i % 2) * 2.5, 7 + i * 1.3)), flowers[i % flowers.size()])
	animal_door(spots, at(Vector2(21.5, 3.9)), at(Vector2(21.5, 5)))
	label(decor, "Pintu hewan", at(Vector2(19.2, 2.3)))
	for i in 3:
		marker(dirt, "Dirt%d" % i, at(Vector2(13 + i * 1.2, 11.6)))
	finish(2.5, at(Vector2(2.5, 13.5)))
	save(OUT.chicken_coop)


func _ready() -> void:
	call_deferred("_build")


func _build() -> void:
	rng.seed = 20261102
	room_tiles = tileset()
	build_barn()
	build_coop()
	get_tree().quit()
