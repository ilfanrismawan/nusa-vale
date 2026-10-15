extends RefCounted
## Native tiles and props from the supplied Farm RPG Deep Forest set.
const EXT := "res://assets/farm_rpg/tileset/ext/"
const PROPS := "res://assets/farm_rpg/objects/exterior/Deep Forest/"
const SIZE := Vector2i(100, 80)
const TRAIL := [Vector2(800, 64), Vector2(800, 192), Vector2(736, 288), Vector2(624, 352), Vector2(576, 464), Vector2(480, 496), Vector2(368, 480), Vector2(176, 480), Vector2(160, 656), Vector2(192, 832), Vector2(240, 944), Vector2(432, 944), Vector2(544, 1024), Vector2(720, 1088), Vector2(912, 1072), Vector2(1088, 992), Vector2(1168, 848), Vector2(1120, 752), Vector2(1072, 624), Vector2(1120, 480), Vector2(1056, 368), Vector2(912, 304), Vector2(736, 288)]
const BRANCHES := [[Vector2(576, 464), Vector2(656, 576), Vector2(800, 672), Vector2(944, 704), Vector2(1072, 624)], [Vector2(800, 672), Vector2(768, 832), Vector2(832, 944), Vector2(912, 1072)]]
const GLADES := [Vector3(800, 672, 132), Vector3(1016, 400, 95), Vector3(552, 968, 105), Vector3(1088, 976, 102), Vector3(184, 720, 78)]
var world: Node2D
var entities: Node2D
var ground: TileMapLayer
var paths: TileMapLayer
var land: Dictionary = {}
var roads: Dictionary = {}
var resource_cells: Dictionary = {}
var blocked: Dictionary = {}
var rng := RandomNumberGenerator.new()

func build(root: Node2D) -> void:
	world = root
	rng.seed = 4101426
	world.y_sort_enabled = true
	ground = layer("BaseLayerGround", EXT + "Tileset Grass Deep Forest.png", -3)
	var water := layer("Water", EXT + "Water tile.png", -4)
	water.material = preload("res://resources/water_detail_material.tres")
	var shore := layer("RiverBanks", EXT + "Tileset Grass Water Deep Forest.png", -2)
	paths = layer("ForestPaths", EXT + "Tileset Grass Deep Forest.png", -2)
	add_center_tile(ground, Rect2(88, 24, 16, 16))
	add_center_tile(paths, Rect2(88, 152, 16, 16))
	for terrain in [ground, shore, paths]:
		terrain.self_modulate = Color(0.85, 0.9, 0.58)
		terrain.material = preload("res://resources/grass_detail_material.tres")
	entities = Node2D.new()
	entities.name = "YSortEntities"
	entities.y_sort_enabled = true
	world.add_child(entities)
	for y in SIZE.y:
		for x in SIZE.x:
			var cell := Vector2i(x, y)
			var p := Vector2(cell * 16) + Vector2(8, 8)
			water.set_cell(cell, 0, Vector2i.ZERO)
			if not is_water(p) or on_bridge(p):
				land[cell] = true
				ground.set_cell(cell, 1, Vector2i.ZERO)
				if trail_distance(p) < 22.0 + 3.0 * sin(p.x * 0.034 + p.y * 0.021):
					roads[cell] = true
			else:
				blocked[cell] = true
	# Grass banks with corners and cliff lips surround the river and spring.
	for cell: Vector2i in land:
		if on_bridge(Vector2(cell * 16) + Vector2(8, 8)):
			continue
		var atlas := edge_tile(cell, land)
		if atlas != Vector2i(6, 1):
			shore.set_cell(cell, 0, atlas)
	for cell: Vector2i in roads:
		if not on_bridge(Vector2(cell * 16) + Vector2(8, 8)):
			# Dirt patches have their own grass-fringed edge tiles.
			var tile := edge_tile(cell, roads)
			if tile == Vector2i(6, 1): paths.set_cell(cell, 1, Vector2i.ZERO)
			else: paths.set_cell(cell, 0, tile + Vector2i(0, 8))
	_build_cliffs()
	_build_landmarks()
	_build_vegetation()
	_build_water_collisions()
	for rect in [Rect2(0, 0, 1600, 16), Rect2(0, 1264, 1600, 16), Rect2(0, 0, 16, 1280), Rect2(1584, 0, 16, 1280)]:
		wall(rect)
	for cell: Vector2i in land:
		var p := Vector2(cell * 16) + Vector2(8, 8)
		if not blocked.has(cell) and not on_bridge(p) and trail_distance(p) > 38 and in_glade(p, -20):
			resource_cells[cell] = true

func layer(node_name: String, texture_path: String, depth: int) -> TileMapLayer:
	var node := TileMapLayer.new()
	node.name = node_name
	node.z_index = depth
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(16, 16)
	var source := TileSetAtlasSource.new()
	source.texture = load(texture_path)
	source.texture_region_size = Vector2i(16, 16)
	for y in int(source.texture.get_height() / 16):
		for x in int(source.texture.get_width() / 16):
			source.create_tile(Vector2i(x, y))
	tiles.add_source(source, 0)
	node.tile_set = tiles
	world.add_child(node)
	return node

func edge_tile(cell: Vector2i, cells: Dictionary) -> Vector2i:
	var left := not cells.has(cell + Vector2i.LEFT)
	var right := not cells.has(cell + Vector2i.RIGHT)
	var top := not cells.has(cell + Vector2i.UP)
	var bottom := not cells.has(cell + Vector2i.DOWN)
	if not left and not right and not top and not bottom:
		return Vector2i(6, 1)
	return Vector2i(8 if left else (11 if right else 9), 0 if top else (3 if bottom else 1))

func add_center_tile(node: TileMapLayer, rect: Rect2) -> void:
	# Crop the actual seamless center; the sheet's aligned center tiles contain
	# corner tufts, which otherwise repeat as a visible grid across the whole map.
	var source := TileSetAtlasSource.new()
	source.texture = atlas_texture(EXT + "Tileset Grass Deep Forest.png", rect)
	source.texture_region_size = Vector2i(16, 16)
	source.create_tile(Vector2i.ZERO)
	node.tile_set.add_source(source, 1)

static func river_x(y: float) -> float:
	return 320.0 + 48.0 * sin(y * 0.006) + 18.0 * sin(y * 0.013)

static func is_water(p: Vector2) -> bool:
	var river := absf(p.x - river_x(p.y)) < 30.0 + 8.0 * sin(p.y * 0.019)
	var lake := Vector2((p.x - 1304) / 133, (p.y - 624) / 116).length() < 1.0
	return river or lake

static func on_bridge(p: Vector2) -> bool:
	return (absf(p.y - 480) < 24 or absf(p.y - 944) < 24) and absf(p.x - river_x(p.y)) < 64

static func trail_distance(p: Vector2) -> float:
	var distance := 10000.0
	for i in range(TRAIL.size() - 1):
		distance = minf(distance, Geometry2D.get_closest_point_to_segment(p, TRAIL[i], TRAIL[i + 1]).distance_to(p))
	for branch: Array in BRANCHES:
		for i in range(branch.size() - 1):
			distance = minf(distance, Geometry2D.get_closest_point_to_segment(p, branch[i], branch[i + 1]).distance_to(p))
	return distance

static func in_glade(p: Vector2, expand: float = 0) -> bool:
	for glade: Vector3 in GLADES:
		if p.distance_to(Vector2(glade.x, glade.y)) < glade.z + expand:
			return true
	return false

func _build_water_collisions() -> void:
	# Merge horizontal runs into shapes; bridges remain walkable.
	for y in SIZE.y:
		var start := -1
		for x in range(SIZE.x + 1):
			var solid := x < SIZE.x and not land.has(Vector2i(x, y))
			if solid and start < 0: start = x
			elif not solid and start >= 0:
				wall(Rect2(start * 16, y * 16, (x - start) * 16, 16))
				start = -1

func wall(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.position = rect.get_center()
	body.add_child(collision)
	world.add_child(body)

func _build_cliffs() -> void:
	var cliff := layer("MossyCliffs", EXT + "Tileset Grass Cliff Tileset Deep Forest.png", -1)
	for area: Rect2i in [Rect2i(70, 12, 18, 5), Rect2i(8, 14, 7, 5), Rect2i(76, 27, 10, 5)]:
		for y in range(area.position.y, area.end.y):
			for x in range(area.position.x, area.end.x):
				var edge := 8 if x == area.position.x else (11 if x == area.end.x - 1 else 9)
				var row := y - area.position.y
				cliff.set_cell(Vector2i(x, y), 0, Vector2i(6, 1) if row < 2 else Vector2i(edge, row + 1))
				blocked[Vector2i(x, y)] = true
		wall(Rect2(area.position * 16, area.size * 16))
		for x in range(area.position.x + 1, area.end.x, 3):
			prop(EXT + "Tree Deep Forest.png", Rect2(64, 48, 32, 48), Vector2(x * 16, area.position.y * 16 + 12), 0, Color(0.65, 0.85, 0.7))

func _build_landmarks() -> void:
	for y in [480, 944]:
		var bridge := prop(PROPS + "Bridge Wood.png", Rect2(8, 4, 64, 48), Vector2(river_x(y), y), 0)
		bridge.centered = true
		bridge.offset = Vector2.ZERO
		bridge.scale = Vector2(2, 1)
		bridge.z_index = -1
	waterfall(Vector2(river_x(240), 240), 0)
	waterfall(Vector2(1304, 484), 1)
	# A root arch marks the north exit; all collision stays beside its opening.
	prop(PROPS + "Root portal.png", Rect2(48, 0, 48, 48), Vector2(800, 94), 0).scale = Vector2(2, 2)
	for x in [750, 850]:
		prop(PROPS + "Stone Pillar.png", Rect2(0, 0, 16, 32), Vector2(x, 126), 7)
	# Ancient sanctuary framed by standing and broken columns.
	var altar := prop(PROPS + "Altar.png", Rect2(0, 0, 48, 48), Vector2(800, 610), 18)
	altar.name = "AncientAltar"
	for p in [Vector2(704, 592), Vector2(896, 592), Vector2(712, 728), Vector2(896, 744)]:
		prop(PROPS + "Stone Pillar.png", Rect2(0, 0, 16, 32), p, 7)
	for p in [Vector2(736, 620), Vector2(864, 624)]:
		prop(PROPS + "Broken Stone Column.png", Rect2(0, 0, 16, 32), p, 6)
	for p in [Vector2(760, 548), Vector2(832, 544), Vector2(816, 520)]:
		var tree := prop(EXT + "Tree Deep Forest.png", Rect2(64, 0, 32, 48), p, 12)
		tree.scale = Vector2(2, 2)
	for p in [Vector2(1000, 342), Vector2(1064, 336), Vector2(1136, 416), Vector2(536, 920), Vector2(504, 1008), Vector2(1168, 1024)]:
		prop("res://assets/farm_rpg/objects/Props/deep forest stones 2.png", Rect2(0, 0, 32, 32), p, 12)
	for p in [Vector2(1032, 936), Vector2(1136, 960), Vector2(1080, 1056), Vector2(472, 952)]:
		prop(EXT + "Fantasy Mushroom.png", Rect2(64, 96, 32, 48), p, 7)

func waterfall(p: Vector2, row: int) -> void:
	var sprite := AnimatedSprite2D.new()
	sprite.name = "DeepWaterfall%d" % row
	sprite.position = p
	sprite.z_index = 0
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", 8)
	for i in 8:
		frames.add_frame("default", atlas_texture(EXT + "Deep Forest Waterfall.png", Rect2(i * 64, row * 64, 64, 64)))
	sprite.sprite_frames = frames
	sprite.play()
	world.add_child(sprite)

func _build_vegetation() -> void:
	# Irregular overlapping groves frame clear paths and five resource clearings.
	for y in range(32, 1270, 28):
		for x in range(24, 1590, 28):
			var p := Vector2(x + rng.randf_range(-11, 11), y + rng.randf_range(-10, 10))
			var cell := Vector2i(p / 16)
			if not land.has(cell) or is_water(p + Vector2(0, 24)):
				continue
			if Rect2(1120, 192, 288, 80).has_point(p) or Rect2(128, 224, 112, 80).has_point(p) or Rect2(1216, 432, 160, 80).has_point(p):
				continue
			var distance := trail_distance(p)
			if distance < 60 or in_glade(p, 32):
				continue
			if rng.randf() < 0.16: continue
			var row := 0 if rng.randf() < 0.35 else 48
			var tint := Color(0.65, 0.86, 0.77) if distance > 140 else Color(0.83, 0.98, 0.87)
			prop(EXT + "Tree Deep Forest.png", Rect2(64, row, 32, 48), p, 8, tint)
			if rng.randf() < 0.18:
				prop(EXT + "bushes.png", Rect2(0, 96, 48, 32), p + Vector2(10, 12), 0, Color(0.6, 0.82, 0.65))
	# Harvest trees at the clearing edges use the same Deep Forest art.
	for i in 30:
		var glade: Vector3 = GLADES[i % GLADES.size()]
		var angle := float(i) * 2.39996
		var p := Vector2(glade.x, glade.y) + Vector2.from_angle(angle) * (glade.z + 2)
		if trail_distance(p) < 58 or is_water(p): continue
		var tree := make_tree(true)
		tree.name = "AncientTree_%02d" % i
		tree.persistence_id = "deep_forest_layout2_tree_%02d" % i
		tree.position = p
		tree.drop_count = 8
		entities.add_child(tree)
		reserve(p, 22)
	# Small ground detail is concentrated off the walking line.
	for i in 700:
		var p := Vector2(rng.randf_range(24, 1576), rng.randf_range(32, 1248))
		var cell := Vector2i(p / 16)
		if not land.has(cell) or blocked.has(cell) or trail_distance(p) < 26: continue
		if rng.randf() < 0.65:
			prop(EXT + "Tileset Grass Deep Forest.png", Rect2(64, 64, 16, 16), p, 0, Color(0.8, 0.96, 0.72))
		else:
			prop(PROPS + "Decor.png", Rect2(rng.randi_range(0, 4) * 16, 0, 16, 16), p, 0)

static func make_tree(mature: bool) -> Choppable:
	var tree := Choppable.new()
	tree.health = 5 if mature else 2
	tree.drop_count = 5 if mature else 2
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.offset = Vector2(0, -22 if mature else -12)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim in ["idle", "chopping", "stump"]:
		frames.add_animation(anim)
		frames.set_animation_loop(anim, false)
		var rect := Rect2(64, 0, 32, 48) if mature else Rect2(32, 16, 32, 32)
		if anim == "stump": rect = Rect2(0, 32, 32, 16)
		frames.add_frame(anim, atlas_texture(EXT + "Tree Deep Forest.png", rect))
	sprite.sprite_frames = frames
	sprite.animation = "idle"
	tree.add_child(sprite)
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := CircleShape2D.new()
	shape.radius = 7 if mature else 4
	collision.shape = shape
	tree.add_child(collision)
	return tree

static func atlas_texture(path: String, rect: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = load(path)
	texture.region = rect
	return texture

func prop(path: String, rect: Rect2, p: Vector2, radius: float, tint: Color = Color.WHITE) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = atlas_texture(path, rect)
	sprite.position = p
	sprite.offset = Vector2(0, -rect.size.y * 0.5 + 4)
	sprite.modulate = tint
	entities.add_child(sprite)
	if radius > 0:
		var body := StaticBody2D.new()
		var collision := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = radius
		collision.shape = shape
		body.add_child(collision)
		sprite.add_child(body)
		reserve(p, radius + 8)
	return sprite

func reserve(p: Vector2, radius: float) -> void:
	var cell := Vector2i(p / 16)
	var reach := ceili(radius / 16)
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			blocked[cell + Vector2i(x, y)] = true
