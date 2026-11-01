extends Node

## Alat authoring awal layout interior rumah tingkat 1-3 dan gudang bawah tanah (GDD 4.12).
## Jalankan: Godot --path . tools/build_house_interiors.tscn
## Scene hasilnya adalah scene biasa yang diedit di Godot; menjalankan ulang alat ini MENIMPA
## house_interior_lv1..3.tscn dan home_cellar.tscn. Tingkat 0 (house_interior_lv0.tscn) tidak disentuh.
##
## Koordinat tile relatif terhadap origin tilemap (270, 122), sama seperti ruangan tingkat 0, supaya
## pintu masuk (kolom 2, baris 3-5) dan ruang utama berada di tempat yang sama di semua tingkat.

const LV0 := "res://scenes/world/interior/house/house_interior_lv0.tscn"
const OUT := "res://scenes/world/interior/house/house_interior_lv%d.tscn"
const CELLAR := "res://scenes/world/interior/home_cellar.tscn"
const FLOOR_TILESET := "res://resources/house/interior_floor_tileset.tres"
const WALL_TILESET := "res://resources/house/interior_wall_tileset.tres"
const ORIGIN := Vector2(270, 122)
const T := 16
const BEDS := "res://scenes/world/interior/objects/Beds.png"
const INTERIOR := "res://assets/farm_rpg/objects/interior/"
const KITCHEN_ENTRY := "res://scenes/objects/cooking/home_kitchen_entry.tscn"
const CELLAR_ENTRY := "res://scenes/objects/house/home_cellar_entry.tscn"

## Tile garis dinding menurut sambungan (atas, bawah, kiri, kanan) di Tileset House.png.
const LINE := {
	"LR": Vector2i(2, 3), "R": Vector2i(1, 3), "L": Vector2i(3, 3),
	"UD": Vector2i(0, 1), "D": Vector2i(0, 0), "U": Vector2i(0, 3),
	"DR": Vector2i(1, 0), "DL": Vector2i(3, 0), "UR": Vector2i(1, 2), "UL": Vector2i(3, 2),
}
const FLOOR := Vector2i(16, 0)

var root: Node2D
var lv0: Node
var floor_set: TileSet
var wall_set: TileSet

func _ready() -> void:
	lv0 = load(LV0).instantiate()
	_save_tilesets()
	_build(1, _lv1())
	_build(2, _lv2())
	_build(3, _lv3())
	_build_cellar()
	lv0.free()
	print("HOUSE INTERIORS BUILT")
	get_tree().quit()

func _save_tilesets() -> void:
	floor_set = (lv0.get_node("TileMapLayer2") as TileMapLayer).tile_set
	wall_set = (lv0.get_node("TileMapLayer") as TileMapLayer).tile_set
	if ResourceLoader.exists(FLOOR_TILESET):
		floor_set = load(FLOOR_TILESET)
	else:
		ResourceSaver.save(floor_set, FLOOR_TILESET)
		floor_set.take_over_path(FLOOR_TILESET)
	if ResourceLoader.exists(WALL_TILESET):
		wall_set = load(WALL_TILESET)
	else:
		ResourceSaver.save(wall_set, WALL_TILESET)
		wall_set.take_over_path(WALL_TILESET)

# --- Denah ---------------------------------------------------------------------------------
# Ruangan = Rect2i bingkai (termasuk garis dinding). Dua baris pertama di dalam bingkai adalah
# dinding belakang; sisanya lantai. `gaps` = sel garis dinding yang dibuka jadi lantai (pintu).

func _lv1() -> Dictionary:
	return {"rooms": [Rect2i(0, -4, 12, 8)], "gaps": [], "bottom": Rect2i(0, 3, 12, 1)}

func _lv2() -> Dictionary:
	return {"rooms": [Rect2i(0, -4, 12, 8), Rect2i(11, -6, 8, 10)], "gaps": [Vector2i(11, 0), Vector2i(11, 1)], "bottom": Rect2i(0, 3, 19, 1)}

func _lv3() -> Dictionary:
	return {"rooms": [Rect2i(-7, -4, 8, 8), Rect2i(0, -4, 12, 8), Rect2i(11, -6, 8, 10)],
		"gaps": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(11, 0), Vector2i(11, 1)], "bottom": Rect2i(-7, 3, 26, 1)}

## Isi grid: "W" garis dinding, "B" dinding belakang, "Q" muka dinding depan, "F" lantai.
func _grid(plan: Dictionary, entrance: int) -> Dictionary:
	var grid := {}
	for room: Rect2i in plan.rooms:
		for x in range(room.position.x, room.end.x):
			for y in range(room.position.y, room.end.y):
				var cell := Vector2i(x, y)
				var edge := x == room.position.x or x == room.end.x - 1 or y == room.position.y or y == room.end.y - 1
				if edge:
					grid[cell] = "W"
				elif not grid.has(cell) or grid[cell] != "W":
					grid[cell] = "B" if y <= room.position.y + 2 else "F"
	# Sel lantai/dinding belakang dari ruangan tetangga menang atas garis bersama, kecuali di tepi luar.
	for gap: Vector2i in plan.gaps:
		grid[gap] = "F"
	var bottom: Rect2i = plan.bottom
	for x in range(bottom.position.x, bottom.end.x):
		for dy in [1, 2]:
			grid[Vector2i(x, bottom.position.y + dy)] = "Q"
	# Pintu masuk depan: kolom `entrance`, dari garis bawah sampai dua baris muka dinding.
	for dy in [0, 1, 2]:
		grid[Vector2i(entrance, bottom.position.y + dy)] = "F"
	return grid

func _paint(grid: Dictionary, floor_layer: TileMapLayer, wall_layer: TileMapLayer, rooms: Array) -> void:
	for cell: Vector2i in grid:
		var kind: String = grid[cell]
		if kind in ["F", "B"]:
			floor_layer.set_cell(cell, 0, FLOOR)
		if kind == "B":
			var room := _room_at(rooms, cell)
			var row := cell.y - room.position.y - 1
			floor_layer.set_cell(cell, 0, Vector2i(45 + posmod(cell.x - room.position.x - 1, 3), 6 + row))
		elif kind == "W":
			var key := ""
			for pair in [["U", Vector2i.UP], ["D", Vector2i.DOWN], ["L", Vector2i.LEFT], ["R", Vector2i.RIGHT]]:
				if grid.get(cell + pair[1], "") == "W":
					key += pair[0]
			if key.length() > 2:
				# Sambungan T/silang tidak punya tile sendiri: ikuti garis yang lurus.
				key = "UD" if key.contains("U") and key.contains("D") else "LR"
			wall_layer.set_cell(cell, 0, LINE.get(key, LINE.LR))
		elif kind == "Q":
			var left: String = grid.get(cell + Vector2i.LEFT, "")
			var right: String = grid.get(cell + Vector2i.RIGHT, "")
			var column := 46
			if left != "Q":
				column = 45
			elif right != "Q":
				column = 47
			var row := 6 if grid.get(cell + Vector2i.UP, "") != "Q" else 7
			wall_layer.set_cell(cell, 0, Vector2i(column, row))

func _room_at(rooms: Array, cell: Vector2i) -> Rect2i:
	for room: Rect2i in rooms:
		if room.has_point(cell) and cell.y <= room.position.y + 2:
			return room
	return rooms[0]

## Collision dinding: sel non-lantai digabung per baris jadi persegi panjang.
func _collision(grid: Dictionary) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "WallCollision"
	var cells := grid.keys()
	var min_y := 999
	var max_y := -999
	var min_x := 999
	var max_x := -999
	for cell: Vector2i in cells:
		min_y = mini(min_y, cell.y)
		max_y = maxi(max_y, cell.y)
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
	var index := 0
	for y in range(min_y, max_y + 1):
		var start := -1
		for x in range(min_x, max_x + 2):
			var solid: bool = grid.has(Vector2i(x, y)) and grid[Vector2i(x, y)] != "F"
			if solid and start < 0:
				start = x
			elif not solid and start >= 0:
				var shape := RectangleShape2D.new()
				shape.size = Vector2((x - start) * T, T)
				var collider := CollisionShape2D.new()
				collider.name = "Row%d" % index
				collider.shape = shape
				collider.position = ORIGIN + Vector2((start + x) * T / 2.0, y * T + T / 2.0)
				body.add_child(collider)
				index += 1
				start = -1
	return body

# --- Pembangun scene ------------------------------------------------------------------------

func _own(node: Node) -> void:
	for child in node.get_children():
		child.owner = root
		if child.scene_file_path.is_empty():
			_own(child)

func _add(node: Node, label: String, parent: Node = null) -> Node:
	node.name = label
	(root if parent == null else parent).add_child(node)
	return node

func _new_root(label: String, script_path: String) -> void:
	root = Node2D.new()
	root.name = label
	root.y_sort_enabled = true
	root.set_script(load(script_path))

func _layers(grid: Dictionary, rooms: Array) -> void:
	var floor_layer := TileMapLayer.new()
	floor_layer.tile_set = floor_set
	floor_layer.position = ORIGIN
	floor_layer.z_index = -1
	_add(floor_layer, "Floor")
	var wall_layer := TileMapLayer.new()
	wall_layer.tile_set = wall_set
	wall_layer.position = ORIGIN
	wall_layer.z_index = -1
	_add(wall_layer, "Walls")
	_paint(grid, floor_layer, wall_layer, rooms)
	_add(_collision(grid), "WallCollision")

func _copy(label: String, at: Vector2 = Vector2.INF) -> Node2D:
	var node := lv0.get_node(label).duplicate() as Node2D
	if at != Vector2.INF:
		node.position = at
	return _add(node, label) as Node2D

func _instance(path: String, label: String, at: Vector2, parent: Node = null) -> Node2D:
	var node := load(path).instantiate() as Node2D
	node.position = at
	return _add(node, label, parent) as Node2D

func _marker(label: String, at: Vector2) -> void:
	var marker := Marker2D.new()
	marker.position = at
	_add(marker, label)

## Perabot statis: Sprite2D (origin di kaki) + StaticBody2D seukuran `solid` (lokal).
func _prop(label: String, texture: String, region: Rect2, at: Vector2, solid := Rect2(), parent: Node = null) -> void:
	var holder := Node2D.new()
	holder.position = at
	_add(holder, label, parent)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load(texture)
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.offset = Vector2(0, -region.size.y / 2.0)
	holder.add_child(sprite)
	if solid.has_area():
		var body := StaticBody2D.new()
		body.name = "StaticBody2D"
		holder.add_child(body)
		var shape := RectangleShape2D.new()
		shape.size = solid.size
		var collider := CollisionShape2D.new()
		collider.name = "CollisionShape2D"
		collider.shape = shape
		collider.position = solid.get_center()
		body.add_child(collider)

func _tile(x: float, y: float) -> Vector2:
	return ORIGIN + Vector2(x * T, y * T)

func _common(plan: Dictionary) -> void:
	var grid := _grid(plan, 2)
	_layers(grid, plan.rooms)
	# Pintu keluar, penghalang di ujung lorong, dan titik bangun sama dengan tingkat 0.
	_copy("ExitDoor")
	_copy("StaticBody2D").name = "EntranceBlocker"
	_copy("BedSpawn")

func _save(path: String) -> void:
	_own(root)
	var packed := PackedScene.new()
	var error := packed.pack(root)
	if error != OK:
		push_error("Gagal pack %s: %d" % [path, error])
	error = ResourceSaver.save(packed, path)
	if error != OK:
		push_error("Gagal simpan %s: %d" % [path, error])
	root.free()
	print("SAVED ", path)

func _build(level: int, plan: Dictionary) -> void:
	_new_root("HouseInteriorLv%d" % level, "res://scripts/world/house_interior_layout.gd")
	_common(plan)
	var furniture := _add(Node2D.new(), "Furniture") as Node2D
	furniture.y_sort_enabled = true
	# Ruang utama: dinding belakangnya naik satu baris, perabot ikut menempel ke dinding.
	_instance("res://scenes/objects/Wardrobe.tscn", "Wardrobe", Vector2(336, 110), furniture)
	_instance("res://scenes/objects/television.tscn", "Television", Vector2(360, 112), furniture)
	_instance(KITCHEN_ENTRY, "KitchenDoor", _tile(9.6, -1.4))
	_marker("KitchenReturn", _tile(9.6, 0.4))
	_prop("DiningTable", INTERIOR + "Tables and desks.png", Rect2(6, 230, 22, 20), _tile(6.5, 1.6), Rect2(-8, -8, 16, 7), furniture)
	_prop("Fireplace", INTERIOR + "Fireplace.png", Rect2(34, 6, 28, 42), _tile(7.6, -1.0), Rect2(-13, -12, 26, 12), furniture)
	if level == 1:
		var bed := _copy("Kasur", Vector2(331, 113))
		bed.reparent(furniture)
	else:
		_double_bed(furniture)
		_prop("Sofa", INTERIOR + "Sofa and armchair.png", Rect2(34, 11, 29, 20), _tile(2.0, 0.2), Rect2(-11, -9, 22, 9), furniture)
		_prop("ChildBed", BEDS, Rect2(39, 2, 18, 34), _tile(16.6, -1.6), Rect2(-7, -8, 14, 8), furniture)
		(root.get_node("BedSpawn") as Node2D).position = _tile(13.5, 0.2)
	if level == 3:
		_prop("FamilySofa", INTERIOR + "Sofa and armchair.png", Rect2(2, 11, 29, 20), _tile(-3.5, -0.8), Rect2(-11, -9, 22, 9), furniture)
		_prop("FamilyTable", INTERIOR + "Tables and desks.png", Rect2(6, 230, 22, 20), _tile(-2.5, 1.4), Rect2(-8, -8, 16, 7), furniture)
		var stairs := _instance(CELLAR_ENTRY, "CellarDoor", _tile(-5.5, 1.5))
		stairs.z_index = -1
		_marker("CellarReturn", _tile(-4.5, 0.6))
	_save(OUT % level)

func _double_bed(parent: Node) -> void:
	var bed := lv0.get_node("Kasur").duplicate() as Area2D
	bed.position = _tile(13.5, -2.2)
	bed.set("pillow_position", Vector2(0, -12))
	bed.set("sleep_rotation_degrees", 0.0)
	_add(bed, "Kasur", parent)
	var sprite := bed.get_node("Sprite2D") as Sprite2D
	sprite.position = Vector2.ZERO
	sprite.region_rect = Rect2(103, 269, 33, 34)
	sprite.offset = Vector2(0, -2)
	var area := bed.get_node("CollisionShape2D") as CollisionShape2D
	area.position = Vector2(0, 8)
	var area_shape := RectangleShape2D.new()
	area_shape.size = Vector2(44, 44)
	area.shape = area_shape
	var solid := bed.get_node("StaticBody2D/CollisionShape2D") as CollisionShape2D
	solid.position = Vector2(0, -2)
	var solid_shape := RectangleShape2D.new()
	solid_shape.size = Vector2(30, 30)
	solid.shape = solid_shape

func _build_cellar() -> void:
	_new_root("HomeCellar", "res://scripts/world/cooking_shop_room.gd")
	var plan := {"rooms": [Rect2i(0, -3, 10, 7)], "gaps": [], "bottom": Rect2i(0, 3, 10, 1)}
	var grid := _grid(plan, 5)
	_layers(grid, plan.rooms)
	var door := Area2D.new()
	door.set_script(load("res://scripts/world/house_return_door.gd"))
	door.set("target_scene", "res://scenes/world/interior/interior_house.tscn")
	door.set("return_marker", "CellarReturn")
	door.set("spawn_position", Vector2(250, 160))
	door.position = _tile(5.5, 5.0)
	_add(door, "ExitDoor")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 16)
	var collider := CollisionShape2D.new()
	collider.name = "CollisionShape2D"
	collider.shape = shape
	door.add_child(collider)
	var blocker := StaticBody2D.new()
	_add(blocker, "EntranceBlocker")
	var block_collider := CollisionShape2D.new()
	block_collider.name = "CollisionShape2D"
	var block_shape := RectangleShape2D.new()
	block_shape.size = Vector2(25, 16)
	block_collider.shape = block_shape
	block_collider.position = _tile(5.5, 6.5)
	blocker.add_child(block_collider)
	var barrels := _add(Node2D.new(), "Barrels") as Node2D
	barrels.y_sort_enabled = true
	for i in 2:
		_prop("StackedBarrels%d" % (i + 1), "res://assets/farm_rpg/objects/exterior/Stacked Barrels.png", Rect2(0, 0, 48, 48), _tile(2.5 + i * 5.0, 0.4), Rect2(-20, -14, 40, 14), barrels)
	var player := load("res://scenes/player/Player.tscn").instantiate() as Node2D
	player.position = _tile(5.5, 2.6)
	_add(player, "Player")
	_marker("spawn", _tile(5.5, 2.6))
	_save(CELLAR)
