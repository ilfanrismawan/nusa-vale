extends SceneTree

## Initial scene authoring tool. The saved .tscn files remain editable in Godot.
## Re-running replaces the ranch exterior (and Eep's home/shop interior with `-- --inside`).
const OUTSIDE := "res://scenes/world/eep_ranch.tscn"
const INSIDE := "res://scenes/world/interior/eep_home.tscn"
const GRASS := "res://assets/farm_rpg/tileset/ext/Tileset Grass Spring.png"
const BARN := "res://assets/farm_rpg/objects/exterior/Houses/Farm Buildings/Barn/Big Barn.png"
const SILO := "res://assets/farm_rpg/objects/exterior/Houses/Farm Buildings/Silo/Silo.png"
const FENCE := "res://assets/farm_rpg/objects/exterior/Fence Wood.png"
const BUSHES := "res://assets/farm_rpg/tileset/ext/bushes.png"
const PROPS := "res://assets/farm_rpg/tileset/ext/ALL props seasons.png"
const OLD_TREE := "res://assets/farm_rpg/tileset/ext/Big old Tree.png"
## Exterior layout (GDD 3.70): wide meadow, Farm road from the north, Town road leaving east.
const SIZE := Vector2i(90, 48)
const NORTH_GATE := Vector2(608, 0)
const EAST_GATE := Vector2(1440, 416)
## Town's RanchEntrance sits on Town's west edge, so arriving from the ranch faces east into Town.
const TOWN_SPAWN := Vector2(72, 791)
const HOUSE_DOOR := Vector2(1160, 262)
const EEP_HOME := Vector2(1160, 294)
const EEP_FEED := Vector2(1264, 318)
const EEP_REST := Vector2(1060, 334)
const PICNIC := Vector2(300, 196)
const DOCK_CELLS := Rect2i(20, 21, 2, 6)
## [from, to, half width] dirt roads; the plaza, yard and banks are blobs in is_dirt().
const ROADS := [
	[Vector2(608, -24), Vector2(616, 236), 26.0],
	[Vector2(700, 330), Vector2(900, 412), 24.0],
	[Vector2(900, 412), Vector2(1464, 418), 24.0],
	[Vector2(1160, 300), Vector2(1160, 412), 22.0],
	[Vector2(1016, 412), Vector2(1016, 470), 18.0],
	[Vector2(1300, 418), Vector2(1300, 590), 20.0],
	[Vector2(540, 360), Vector2(420, 352), 22.0],
	[Vector2(330, 236), Vector2(460, 344), 18.0],
]
const GROVES: Array[Rect2] = [Rect2(60, 60, 460, 110), Rect2(410, 100, 140, 110),Rect2(500, 420, 110, 250), Rect2(690, 80, 300, 120), Rect2(640, 470, 220, 260), Rect2(60, 640, 620, 128), Rect2(1170, 450, 90, 70)]
const KEEP_CLEAR: Array[Rect2] = [Rect2(560, 0, 96, 130), Rect2(1330, 380, 110, 72), Rect2(1090, 250, 140, 150), Rect2(1030, 280, 270, 70)]
const FLOWERS: Array[Rect2] = [Rect2(176, 0, 16, 16), Rect2(192, 0, 16, 16), Rect2(224, 0, 16, 16), Rect2(192, 16, 16, 16), Rect2(224, 16, 16, 16), Rect2(144, 48, 16, 16), Rect2(176, 48, 16, 16), Rect2(192, 64, 16, 16), Rect2(208, 64, 16, 16)]
const MUSHROOMS: Array[Rect2] = [Rect2(208, 0, 16, 16), Rect2(208, 16, 16, 16), Rect2(176, 32, 16, 16), Rect2(208, 32, 16, 16)]
var world: Node2D
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var ground: Dictionary = {}
var water_cells: Dictionary = {}
var occupied: Array[Vector3] = []

func put(node: Node, parent: Node, label: String) -> Node:
	node.name = label
	parent.add_child(node)
	node.owner = world
	return node

func group(label: String, parent: Node = null) -> Node2D:
	return put(Node2D.new(), world if parent == null else parent, label) as Node2D

func image(label: String, parent: Node, path: String, at: Vector2, region := Rect2(), scale_value := 1.0) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(path)
	sprite.position = at
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if region.size != Vector2.ZERO:
		sprite.region_enabled = true
		sprite.region_rect = region
	sprite.scale = Vector2.ONE * scale_value
	return put(sprite, parent, label) as Sprite2D

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

func signboard(label: String, parent: Node, at: Vector2, caption: String) -> void:
	var board: Node2D = load("res://scenes/objects/building_sign.tscn").instantiate()
	board.position = at
	board.caption = caption
	board.font_size = 16
	board.minimum_width = 88
	put(board, parent, label)

func point(parent: Node, label: String, at: Vector2) -> void:
	var marker := Marker2D.new()
	marker.position = at
	put(marker, parent, label)

func entrance(label: String, at: Vector2, size: Vector2, target: String, spawn: Vector2, automatic := true, parent: Node = null) -> void:
	var area := Area2D.new()
	area.position = at
	area.set_script(load("res://scripts/world/scene_entrance.gd" if automatic else "res://scripts/world/exit_door_school.gd"))
	if automatic:
		area.scene_target = target
	else:
		area.target_scene = target
	area.spawn_position = spawn
	put(area, world if parent == null else parent, label)
	box("CollisionShape2D", area, Rect2(-size * 0.5, size))

func layers(label: String, path: String, atlas_coords: Array[Vector2i], z: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.z_index = z
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(16, 16)
	tiles.add_custom_data_layer()
	tiles.set_custom_data_layer_name(0, "farmable")
	tiles.set_custom_data_layer_type(0, TYPE_BOOL)
	var source := TileSetAtlasSource.new()
	source.texture = load(path)
	source.texture_region_size = Vector2i(16, 16)
	for cell in atlas_coords:
		if not source.has_tile(cell):
			source.create_tile(cell)
	tiles.add_source(source, 0)
	layer.tile_set = tiles
	return put(layer, world, label) as TileMapLayer

func route(parent: Node, label: String, positions: Array[Vector2]) -> void:
	var path := Path2D.new()
	path.set_script(load("res://scripts/npc/npc_walk_path.gd"))
	path.npc_id = &"eep"
	path.curve = Curve2D.new()
	path.curve.resource_local_to_scene = true
	for position in positions:
		path.curve.add_point(position)
	put(path, parent, label)

func residents(map_id: String, points: Dictionary, gateway: Vector2, other: String, positions: Array[Vector2]) -> void:
	var markers := group("NPCPoints")
	for label: String in points:
		point(markers, label, points[label])
	var actors := group("NPCActors")
	actors.y_sort_enabled = true
	var network := group("NPCPaths")
	network.set_script(load("res://scripts/npc/npc_route_network.gd"))
	var door := Marker2D.new()
	door.set_script(load("res://scripts/npc/npc_route_point.gd"))
	door.position = gateway
	door.destination_maps = PackedStringArray([other])
	door.npc_id = &"eep"
	door.default_gateway = true
	put(door, network, "EepGateway")
	route(network, "Eep_stall", positions)
	var presenter := Node.new()
	presenter.set_script(load("res://scripts/npc/npc_map_presenter.gd"))
	presenter.map_id = map_id
	put(presenter, world, "NPCMapPresenter")

func player(at: Vector2) -> void:
	var root: Node2D = load("res://scenes/player/Player.tscn").instantiate()
	root.position = at
	put(root, world, "Player")
	point(world, "SpawnPoint", at)

func save_world(path: String) -> void:
	world.set_script(load("res://scripts/world/eep_ranch.gd"))
	world.set_meta("farm_area", "eep_home" if path == INSIDE else "eep_ranch")
	world.map_size = Vector2i(640, 448) if path == INSIDE else SIZE * 16
	var scene := PackedScene.new()
	assert(scene.pack(world) == OK)
	assert(ResourceSaver.save(scene, path) == OK)
	world.free()
	print("SAVED ", path)

## Dirt autotile from "Tileset Grass Spring": outer edges/corners (8..11, 8..11),
## single inner corners (5..6, 9..10) and full dirt (9,10).
func dirt_tile(cell: Vector2i, solid_ground: Dictionary) -> Vector2i:
	var has := func(c: Vector2i) -> bool:
		return solid_ground.has(c) or c.x < 0 or c.y < 0 or c.x >= SIZE.x or c.y >= SIZE.y
	var left: bool = not has.call(cell + Vector2i.LEFT)
	var right: bool = not has.call(cell + Vector2i.RIGHT)
	var top: bool = not has.call(cell + Vector2i.UP)
	var bottom: bool = not has.call(cell + Vector2i.DOWN)
	if left or right or top or bottom:
		var column := 8 if left else (11 if right else 9 + (cell.x + cell.y) % 2)
		var row := 8 if top else (11 if bottom else 9 + (cell.y % 2))
		return Vector2i(column, row)
	var tl: bool = not has.call(cell + Vector2i(-1, -1))
	var tr: bool = not has.call(cell + Vector2i(1, -1))
	var bl: bool = not has.call(cell + Vector2i(-1, 1))
	var br: bool = not has.call(cell + Vector2i(1, 1))
	if tl and br:
		return Vector2i(9, 9)
	if tr and bl:
		return Vector2i(10, 10)
	if tl:
		return Vector2i(5, 9)
	if tr:
		return Vector2i(6, 9)
	if bl:
		return Vector2i(5, 10)
	if br:
		return Vector2i(6, 10)
	return Vector2i(9, 10)

func dirt_coords() -> Array[Vector2i]:
	var out: Array[Vector2i] = [Vector2i(5, 9), Vector2i(6, 9), Vector2i(5, 10), Vector2i(6, 10)]
	for x in range(8, 12):
		for y in range(8, 12):
			if Vector2i(x, y) != Vector2i(10, 9):
				out.append(Vector2i(x, y))
	return out

func blob(p: Vector2, center: Vector2, radius: Vector2) -> bool:
	var wobble := noise.get_noise_2dv(p) * 0.22
	return ((p - center) / radius).length() < 1.0 + wobble

func is_pond(p: Vector2) -> bool:
	return blob(p, Vector2(320, 486), Vector2(176, 122)) or blob(p, Vector2(232, 572), Vector2(104, 76)) or blob(p, Vector2(438, 440), Vector2(92, 70))

## South-east water that runs off the map, framing the coop meadow; it tapers out to the west.
func creek_y(x: float) -> float:
	return 704.0 - (x - 1120.0) * 0.28 + noise.get_noise_2d(x * 2.0, 9.0) * 14.0 + maxf(0.0, 1170.0 - x) * 1.6

func is_creek(p: Vector2) -> bool:
	return p.y > creek_y(p.x)

func is_water(p: Vector2) -> bool:
	return is_pond(p) or is_creek(p)

## Smooth pond outline: the farthest pond point along each ray from its center.
func pond_outline() -> PackedVector2Array:
	var center := Vector2(320, 486)
	var outline := PackedVector2Array()
	for step in 120:
		var direction := Vector2.RIGHT.rotated(TAU * step / 120.0)
		var reach := 0.0
		for r in range(0, 320, 2):
			if is_pond(center + direction * r):
				reach = r
		outline.append(center + direction * reach)
	return outline

func creek_outline() -> PackedVector2Array:
	var outline := PackedVector2Array()
	for x in range(1060, 1481, 8):
		if creek_y(x) < 792.0:
			outline.append(Vector2(x, creek_y(x)))
	outline.append(Vector2(1480, 800))
	outline.append(Vector2(outline[0].x - 8, 800))
	return outline

## Textured, shader-animated water surface with a wet-sand rim and a foam line.
func water_body(label: String, outline: PackedVector2Array, terrain: Node, carve := PackedVector2Array()) -> void:
	var rim := Line2D.new()
	rim.points = outline
	rim.closed = true
	rim.width = 7
	rim.default_color = Color8(196, 128, 72, 150)
	rim.z_index = -8
	put(rim, world, label + "WetSand")
	var surface := Polygon2D.new()
	surface.polygon = outline
	surface.texture = load("res://assets/farm_rpg/tileset/ext/Water tile.png")
	surface.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	surface.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	surface.material = load("res://resources/water_detail_material.tres")
	surface.z_index = -8
	put(surface, world, label)
	var foam := Line2D.new()
	foam.points = outline
	foam.closed = true
	foam.width = 2
	foam.default_color = Color(0.92, 0.97, 1.0, 0.55)
	put(foam, surface, "Foam")
	var body := put(StaticBody2D.new(), terrain, label + "Body")
	var shapes := [outline] if carve.is_empty() else Geometry2D.clip_polygons(outline, carve)
	for shape: PackedVector2Array in shapes:
		if Geometry2D.is_polygon_clockwise(shape) != Geometry2D.is_polygon_clockwise(outline):
			continue
		var collider := CollisionPolygon2D.new()
		collider.polygon = shape
		put(collider, body, "Shape" + str(body.get_child_count()))

func is_dirt(p: Vector2) -> bool:
	for segment: Array in ROADS:
		var width: float = segment[2] + noise.get_noise_2dv(p * 1.7) * 7.0
		if Geometry2D.get_closest_point_to_segment(p, segment[0], segment[1]).distance_to(p) < width:
			return true
	# Wide sandy plaza where Farm, Town, the pond and the ranch meet.
	return blob(p, Vector2(650, 300), Vector2(150, 92)) or blob(p, Vector2(560, 360), Vector2(90, 58)) \
		or blob(p, Vector2(1146, 312), Vector2(196, 62)) or blob(p, Vector2(1300, 604), Vector2(74, 40))

## Removes one-tile slivers and diagonal pinches the autotile cannot draw.
func smooth(cells: Dictionary, wet: Dictionary) -> void:
	var has := func(c: Vector2i) -> bool:
		return cells.has(c) or wet.has(c)
	for pass_index in 6:
		var changed := false
		for cell: Vector2i in cells.keys():
			var l: bool = has.call(cell + Vector2i.LEFT)
			var r: bool = has.call(cell + Vector2i.RIGHT)
			var u: bool = has.call(cell + Vector2i.UP)
			var d: bool = has.call(cell + Vector2i.DOWN)
			if (not l and not r) or (not u and not d):
				cells.erase(cell)
				changed = true
		for x in SIZE.x:
			for y in SIZE.y:
				var cell := Vector2i(x, y)
				if has.call(cell):
					continue
				var l: bool = has.call(cell + Vector2i.LEFT)
				var r: bool = has.call(cell + Vector2i.RIGHT)
				var u: bool = has.call(cell + Vector2i.UP)
				var d: bool = has.call(cell + Vector2i.DOWN)
				if (l and r) or (u and d) or (int(l) + int(r) + int(u) + int(d) >= 3):
					cells[cell] = true
					changed = true
		if not changed:
			break

func reserve(p: Vector2, radius: float) -> void:
	occupied.append(Vector3(p.x, p.y, radius))

func free_spot(p: Vector2, radius: float) -> bool:
	if p.x < 8 or p.y < 8 or p.x > SIZE.x * 16 - 8 or p.y > SIZE.y * 16 - 8:
		return false
	for spot: Vector3 in occupied:
		if p.distance_to(Vector2(spot.x, spot.y)) < radius + spot.z:
			return false
	for rect: Rect2 in KEEP_CLEAR:
		if rect.grow(radius * 0.5).has_point(p):
			return false
	var cell := Vector2i(p / 16)
	for offset in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
		if ground.has(cell + offset) or water_cells.has(cell + offset):
			return false
	return true

## Bottom-anchored sprite: `at` is where it touches the ground, which is also its Y-sort point.
func standing(label: String, parent: Node, path: String, at: Vector2, region: Rect2, foot: float, scale_value := 1.0) -> Sprite2D:
	var sprite := image(label, parent, path, at, region, scale_value)
	sprite.offset = Vector2(0, region.size.y * 0.5 - foot)
	return sprite

func tree(label: String, parent: Node, at: Vector2, kind: int) -> void:
	var paths := ["res://assets/farm_rpg/objects/tree/Maple Tree Animation.png", "res://assets/farm_rpg/objects/tree/Pine Tree Animation.png", "res://assets/farm_rpg/objects/tree/Maple Tree Animation.png"]
	var regions := [Rect2(0, 48, 32, 48), Rect2(0, 48, 32, 48), Rect2(0, 192, 32, 48)]
	var sprite := standing(label, parent, paths[kind], at, regions[kind], 46, 1.5)
	sprite.flip_h = rng.randf() < 0.5
	solid(label + "Trunk", parent, Rect2(at.x - 6, at.y - 8, 12, 9))
	reserve(at, 22)

func fence_line(parent: Node, from: Vector2, to: Vector2, gaps: Array = []) -> void:
	var horizontal := is_equal_approx(from.y, to.y)
	var steps := int(round((to - from).length() / 16.0))
	for i in steps + 1:
		var at := from + (to - from).normalized() * 16.0 * i
		var skip := false
		for gap: Vector2 in gaps:
			var along := at.x if horizontal else at.y
			if along >= gap.x and along <= gap.y:
				skip = true
		if skip:
			continue
		var region := Rect2(16, 32, 16, 16) if horizontal else Rect2(0, 16, 16, 16)
		var key := "%d_%d" % [at.x, at.y]
		var rail := image("Fence_" + key, parent, FENCE, at + (Vector2.ZERO if horizontal else Vector2(5, 0)), region)
		rail.offset = Vector2(0, -6)
		solid("FenceBody_" + key, parent, Rect2(at.x - 8, at.y - 4, 16, 6) if horizontal else Rect2(at.x - 3, at.y - 12, 6, 16))
		reserve(at, 10)

func outside() -> void:
	world = Node2D.new()
	world.name = "EepRanch"
	rng.seed = 20261102
	noise.seed = 1102
	noise.frequency = 0.012
	var meadow := Polygon2D.new()
	var px := Vector2(SIZE * 16)
	meadow.polygon = PackedVector2Array([Vector2.ZERO, Vector2(px.x, 0), px, Vector2(0, px.y)])
	meadow.color = Color8(121, 191, 86)
	meadow.z_index = -11
	put(meadow, world, "MeadowBase")
	var grass := layers("BaseLayerGround", GRASS, [Vector2i(9, 2)], -10)
	grass.material = load("res://resources/grass_detail_material.tres")
	var paths := layers("Paths", GRASS, dirt_coords(), -8)
	for x in SIZE.x:
		for y in SIZE.y:
			var cell := Vector2i(x, y)
			var p := Vector2(x * 16 + 8, y * 16 + 8)
			grass.set_cell(cell, 0, Vector2i(9, 2))
			if is_water(p):
				water_cells[cell] = true
			# Sandy bank about two tiles wide around all water, plus roads and yards.
			var bank := false
			for offset in [Vector2.ZERO, Vector2(-28, 0), Vector2(28, 0), Vector2(0, -28), Vector2(0, 28), Vector2(-20, -20), Vector2(20, -20), Vector2(-20, 20), Vector2(20, 20)]:
				bank = bank or is_water(p + offset)
			if bank or is_dirt(p):
				ground[cell] = true
	smooth(ground, {})
	for cell: Vector2i in ground:
		paths.set_cell(cell, 0, dirt_tile(cell, ground))
	var terrain := group("TerrainCollisions")
	# Dock planks stay walkable: the pond collider has the dock carved out of it.
	var dock_px := Rect2(Vector2(DOCK_CELLS.position * 16), Vector2(DOCK_CELLS.size * 16))
	water_body("PondWater", pond_outline(), terrain, PackedVector2Array([dock_px.position - Vector2(0, 64), Vector2(dock_px.end.x, dock_px.position.y - 64), dock_px.end, Vector2(dock_px.position.x, dock_px.end.y)]))
	water_body("CreekWater", creek_outline(), terrain)
	var w := px.x
	var h := px.y
	for rect in [Rect2(0, -16, NORTH_GATE.x - 32, 16), Rect2(NORTH_GATE.x + 32, -16, w - NORTH_GATE.x - 32, 16), Rect2(-16, 0, 16, h), Rect2(w, 0, 16, EAST_GATE.y - 32), Rect2(w, EAST_GATE.y + 32, 16, h - EAST_GATE.y - 32), Rect2(0, h, w, 16)]:
		solid("Edge" + str(terrain.get_child_count()), terrain, rect)
	var decor := group("Scenery")
	decor.y_sort_enabled = true

	# Ranch house (Eep's home and shop) with its silo, yard and lamp light.
	var house := group("EepRanchHouse", decor)
	house.position = HOUSE_DOOR
	var building := image("BarnHouse", house, BARN, Vector2.ZERO, Rect2(0, 0, 112, 112), 2.0)
	building.offset = Vector2(8, -41)
	solid("BuildingBody", house, Rect2(-86, -132, 172, 106))
	entrance("Door", Vector2.ZERO, Vector2(34, 28), INSIDE, Vector2(320, 384), false, house)
	point(house, "ReturnSpawn", Vector2(0, 32))
	signboard("RanchSign", house, Vector2(-120, 6), "RANCH EEP")
	reserve(HOUSE_DOOR + Vector2(0, -70), 130)
	standing("Silo", decor, SILO, HOUSE_DOOR + Vector2(-142, -6), Rect2(0, 0, 48, 96), 80, 2.0)
	solid("SiloBody", decor, Rect2(HOUSE_DOOR.x - 178, HOUSE_DOOR.y - 40, 72, 34))
	reserve(HOUSE_DOOR + Vector2(-142, -40), 50)
	for i in 3:
		var bale := HOUSE_DOOR + Vector2(-210 + i * 18, 18 - (i % 2) * 6)
		standing("HayBale" + str(i), decor, "res://assets/farm_rpg/objects/exterior/Hay Bales.png", bale, Rect2(16 * (i % 3), 0, 16, 16), 15, 1.5)
		reserve(bale, 12)
	solid("HayBody", decor, Rect2(HOUSE_DOOR.x - 222, HOUSE_DOOR.y + 4, 56, 14))
	standing("Barrels", decor, "res://assets/farm_rpg/objects/exterior/Stacked Barrels.png", HOUSE_DOOR + Vector2(118, 10), Rect2(0, 0, 48, 48), 46)
	solid("BarrelBody", decor, Rect2(HOUSE_DOOR.x + 98, HOUSE_DOOR.y - 6, 40, 16))
	reserve(HOUSE_DOOR + Vector2(118, 0), 26)
	standing("Trough", decor, "res://assets/ranch/feeding_trough.png", EEP_FEED + Vector2(36, -2), Rect2(), 12)
	reserve(EEP_FEED + Vector2(36, 0), 22)
	var yard := group("YardFence", decor)
	fence_line(yard, Vector2(HOUSE_DOOR.x - 232, 376), Vector2(HOUSE_DOOR.x + 200, 376), [Vector2(HOUSE_DOOR.x - 40, HOUSE_DOOR.x + 40)])
	fence_line(yard, Vector2(HOUSE_DOOR.x + 200, 216), Vector2(HOUSE_DOOR.x + 200, 360))

	# Fenced grazing meadow below the yard; scenic animals are not player livestock.
	var fences := group("PastureFence", decor)
	var pasture := Rect2(880, 480, 272, 160)
	fence_line(fences, pasture.position, Vector2(pasture.end.x, pasture.position.y), [Vector2(990, 1042)])
	fence_line(fences, Vector2(pasture.position.x, pasture.end.y), pasture.end)
	fence_line(fences, pasture.position + Vector2(0, 16), Vector2(pasture.position.x, pasture.end.y - 16))
	fence_line(fences, Vector2(pasture.end.x, pasture.position.y + 16), pasture.end - Vector2(0, 16))
	var gate := image("PastureGate", fences, FENCE, Vector2(1016, pasture.position.y), Rect2(48, 0, 48, 16))
	gate.offset = Vector2(0, -6)
	solid("PastureGateBody", fences, Rect2(992, pasture.position.y - 4, 48, 6))
	reserve(pasture.get_center(), 150)
	standing("WaterBasin", decor, "res://assets/ranch/water_basin.png", Vector2(916, 616), Rect2(), 12)
	standing("PastureTrough", decor, "res://assets/ranch/feeding_trough.png", Vector2(1092, 524), Rect2(), 12)
	standing("DisplayCow", decor, "res://assets/farm_rpg/animals/Farm/Cow/Common Cow/Female Cow Black.png", Vector2(960, 548), Rect2(0, 0, 32, 32), 28, 1.5)
	var cow := standing("DisplayCow2", decor, "res://assets/farm_rpg/animals/Farm/Cow/Common Cow/Female Cow Black.png", Vector2(1056, 600), Rect2(0, 0, 32, 32), 28, 1.5)
	cow.flip_h = true
	standing("DisplaySheep", decor, "res://assets/farm_rpg/animals/Farm/Sheep/Sheep Female.png", Vector2(1100, 566), Rect2(0, 0, 32, 32), 28, 1.5)

	# Coop cottage and chickens on the creek meadow in the south-east.
	standing("Coop", decor, "res://assets/farm_rpg/objects/exterior/Houses/Farm Buildings/Chicken Coop/Chicken Coop.png", Vector2(1300, 586), Rect2(0, 0, 80, 80), 79, 1.5)
	solid("CoopBody", decor, Rect2(1258, 520, 84, 58))
	reserve(Vector2(1300, 550), 70)
	for spot in [Vector2(1236, 612), Vector2(1352, 620), Vector2(1220, 572)]:
		standing("DisplayChicken" + str(spot.x), decor, "res://assets/farm_rpg/animals/Farm/Chicken/Chicken White.png", spot, Rect2(0, 0, 16, 16), 14, 1.5)
		reserve(spot, 10)

	# Picnic clearing in the north-west woods: a rest stop on the way to the pond.
	var picnic := image("PicnicBlanket", decor, "res://assets/farm_rpg/objects/exterior/Picnic.png", PICNIC, Rect2(48, 0, 48, 48))
	picnic.z_index = -7
	picnic.z_as_relative = false
	for item in [[Vector2(-10, -6), Rect2(144, 96, 16, 16)], [Vector2(10, 4), Rect2(160, 128, 16, 16)], [Vector2(12, -10), Rect2(144, 128, 16, 16)]]:
		var food := image("PicnicFood" + str(item[1].position.x + item[1].position.y), decor, "res://assets/farm_rpg/objects/exterior/Picnic.png", PICNIC + item[0], item[1])
		food.z_index = -6
		food.z_as_relative = false
	reserve(PICNIC, 70)
	standing("OldStump", decor, OLD_TREE, PICNIC + Vector2(96, -22), Rect2(52, 38, 72, 30), 28)
	solid("OldStumpBody", decor, Rect2(PICNIC.x + 70, PICNIC.y - 40, 52, 16))
	reserve(PICNIC + Vector2(96, -30), 44)
	standing("FallenLog", decor, OLD_TREE, Vector2(512, 640), Rect2(4, 0, 120, 30), 26)
	solid("FallenLogBody", decor, Rect2(456, 622, 112, 16))
	reserve(Vector2(512, 630), 64)

	# Dock on the north shore: plank deck with mooring posts; its sides and end stay water.
	var dock := group("Dock")
	dock.z_index = -7
	for y in range(int(dock_px.position.y), int(dock_px.end.y), 24):
		var height := minf(24, dock_px.end.y - y)
		image("Planks" + str(y), dock, "res://assets/farm_rpg/tileset/ext/Bridge.png", Vector2(dock_px.get_center().x, y + height * 0.5), Rect2(19, 12, 32, height))
	for post: Vector2 in [Vector2(dock_px.position.x - 1, dock_px.end.y - 6), Vector2(dock_px.end.x + 1, dock_px.end.y - 6), Vector2(dock_px.position.x - 1, dock_px.position.y + 40), Vector2(dock_px.end.x + 1, dock_px.position.y + 40)]:
		image("Post%d_%d" % [post.x, post.y], dock, "res://assets/farm_rpg/tileset/ext/Bridge.png", post, Rect2(16, 65, 4, 14))
	reserve(dock_px.get_center(), 40)

	# Signs and lamps at the two map exits.
	signboard("FarmDirection", decor, NORTH_GATE + Vector2(-92, 96), "UTARA: FARM")
	signboard("TownDirection", decor, EAST_GATE + Vector2(-44, -46), "TIMUR: TOWN")
	reserve(NORTH_GATE + Vector2(-92, 90), 40)
	reserve(EAST_GATE + Vector2(-44, -52), 44)
	for spot in [NORTH_GATE + Vector2(-56, 150), EAST_GATE + Vector2(-176, 50)]:
		standing("Lamp" + str(spot.x), decor, "res://assets/farm_rpg/objects/exterior/Street Lamp.png", spot, Rect2(0, 0, 32, 48), 46)
		solid("LampBody" + str(spot.x), decor, Rect2(spot.x - 4, spot.y - 6, 8, 6))
		reserve(spot, 14)

	# Forest frame and groves; trees never touch roads, water or the yard.
	var index := 0
	for gx in range(0, SIZE.x * 16 + 1, 34):
		for gy in range(8, SIZE.y * 16 + 1, 30):
			var p := Vector2(gx + rng.randf_range(-10, 10) + (17 if (gy / 30) % 2 else 0), gy + rng.randf_range(-8, 8))
			var edge := minf(minf(p.x, p.y), minf(px.x - p.x, px.y - p.y))
			var forest := edge < 84 + noise.get_noise_2dv(p * 3.0) * 40.0
			for grove: Rect2 in GROVES:
				forest = forest or (grove.has_point(p) and noise.get_noise_2dv(p * 4.0) > -0.25)
			if not forest or not free_spot(p, 18):
				continue
			index += 1
			tree("Tree" + str(index), decor, p, 1 if noise.get_noise_2dv(p * 0.7) > 0.05 else (2 if index % 7 == 0 else 0))
	# Undergrowth: bushes along tree lines, tufts, flowers, stumps and stones.
	for i in 760:
		var p := Vector2(rng.randf_range(24, px.x - 24), rng.randf_range(24, px.y - 24))
		var roll := rng.randf()
		if roll < 0.18:
			if not free_spot(p, 16):
				continue
			var bush := standing("Bush" + str(i), decor, BUSHES, p, Rect2(48 if rng.randf() < 0.6 else 0, 32 * [0, 0, 0, 1, 4, 5][rng.randi() % 6], 48, 32), 26, 0.9)
			bush.flip_h = rng.randf() < 0.5
			solid("BushBody" + str(i), decor, Rect2(p.x - 12, p.y - 8, 24, 8))
			reserve(p, 18)
		elif roll < 0.55:
			if not free_spot(p, 6):
				continue
			var tuft := image("Tuft" + str(i), decor, "res://assets/farm_rpg/tileset/ext/grass_tufts.png", p, Rect2(16 * (rng.randi() % 6), 0, 16, 16))
			tuft.z_index = -7
			tuft.z_as_relative = false
		elif roll < 0.88:
			if not free_spot(p, 6):
				continue
			var flower := image("Flower" + str(i), decor, PROPS, p, FLOWERS[rng.randi() % FLOWERS.size()])
			flower.z_index = -7
			flower.z_as_relative = false
		elif roll < 0.94:
			if not free_spot(p, 12):
				continue
			standing("Stump" + str(i), decor, "res://assets/farm_rpg/objects/tree/Maple Tree Animation.png", p, Rect2(0, 272, 32, 16), 14)
			solid("StumpBody" + str(i), decor, Rect2(p.x - 7, p.y - 6, 14, 6))
			reserve(p, 14)
		else:
			if not free_spot(p, 8):
				continue
			var mushroom := image("Mushroom" + str(i), decor, PROPS, p, MUSHROOMS[rng.randi() % MUSHROOMS.size()])
			mushroom.z_index = -7
			mushroom.z_as_relative = false
	entrance("NorthToFarm", NORTH_GATE + Vector2(0, 4), Vector2(64, 24), "res://scenes/world/farm.tscn", Vector2(992, 928))
	entrance("EastToTown", EAST_GATE + Vector2(-4, 0), Vector2(24, 64), "res://scenes/world/town.tscn", TOWN_SPAWN)
	residents("eep_ranch", {"eep_home": EEP_HOME, "eep_feed": EEP_FEED, "eep_rest": EEP_REST}, EEP_HOME, "eep_home", [EEP_HOME, Vector2(EEP_FEED.x, EEP_HOME.y), EEP_FEED])
	route(world.get_node("NPCPaths"), "EepYardRest", [EEP_HOME, Vector2(EEP_REST.x, EEP_HOME.y), EEP_REST])
	var seasons := Node.new()
	seasons.set_script(load("res://scripts/world/seasonal_tile_swapper.gd"))
	put(seasons, world, "SeasonalTileSwapper")
	player(NORTH_GATE + Vector2(0, 64))
	save_world(OUTSIDE)

func inside() -> void:
	world = Node2D.new()
	world.name = "EepHome"
	var floor := layers("BaseLayerGround","res://assets/farm_rpg/tileset/int/Tileset House.png",[Vector2i(17,1),Vector2i(16,0)],-10)
	for x in 40:
		for y in 28:
			floor.set_cell(Vector2i(x,y),0,Vector2i(16,0) if y<4 else Vector2i(17,1))
	var walls := group("Walls")
	for rect in [Rect2(0,0,640,64),Rect2(0,0,16,448),Rect2(624,0,16,448),Rect2(0,432,288,16),Rect2(352,432,288,16),Rect2(416,64,8,64),Rect2(416,240,8,192)]:
		solid("Wall"+str(walls.get_child_count()),walls,rect)
	var furniture := group("Furniture")
	furniture.y_sort_enabled = true
	for spec in [["Bed","single_bed_wood",Vector2(528,112)],["Wardrobe","wardrobe_classic",Vector2(592,112)],["DiningTable","dining_table_wood",Vector2(528,304)],["Bookshelf","bookshelf_tall",Vector2(464,112)],["CounterLeft","kitchen_cabinet",Vector2(208,240)],["CounterRight","kitchen_cabinet",Vector2(336,240)],["Shelf","dresser_drawers",Vector2(176,112)],["Plant","indoor_plant_large",Vector2(80,112)]]:
		var item: Node2D = load("res://scenes/objects/interior/"+str(spec[1])+".tscn").instantiate()
		item.position = spec[2]
		item.scale = Vector2(2,2)
		put(item,furniture,str(spec[0]))
	var rug := image("BedroomRug",world,"res://resources/interior/atlas/carpet_rug.tres",Vector2(528,272),Rect2(),3.0)
	rug.z_index = -5
	for rect in [Rect2(416,64,8,64),Rect2(416,240,8,192)]:
		var partition := Polygon2D.new()
		partition.polygon = PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
		partition.color = Color8(104,65,45)
		put(partition,world,"RoomPartition"+str(world.get_child_count()))
	image("FeedSack",furniture,"res://assets/ranch/feeding_trough.png",Vector2(112,208))
	signboard("ShopBoard",furniture,Vector2(272,96),"TOKO TERNAK EEP")
	signboard("Hours",furniture,Vector2(128,304),"09–12 / 13–17\nRabu libur")
	signboard("Bedroom",furniture,Vector2(528,64),"RUMAH EEP")
	entrance("ExitDoor",Vector2(320,436),Vector2(64,24),OUTSIDE,EEP_HOME)
	residents("eep_home",{"eep_home":Vector2(528,144),"eep_stall":Vector2(272,176),"eep_lunch":Vector2(528,240),"eep_rest":Vector2(464,208)},Vector2(320,400),"eep_ranch",[Vector2(320,400),Vector2(400,400),Vector2(400,176),Vector2(272,176)])
	var network := world.get_node("NPCPaths")
	route(network,"EepBedroom",[Vector2(400,176),Vector2(464,176),Vector2(528,176),Vector2(528,144)])
	route(network,"EepLunch",[Vector2(464,176),Vector2(464,208),Vector2(528,208),Vector2(528,240)])
	player(Vector2(320,384))
	save_world(INSIDE)

## Godot.exe --headless --path . --script res://tools/build_eep_ranch.gd [-- --inside]
func _initialize() -> void:
	outside()
	if OS.get_cmdline_user_args().has("--inside"):
		inside()
	quit()
