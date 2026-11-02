extends Node

## Penyusun awal interior Greenhouse: rangka kaca, lantai papan, bedeng pohon buah di kiri/kanan,
## ladang tengah berbingkai bata, air mancur di belakang, bedeng bunga dan lampu di depan pintu.
## Hasilnya scene biasa: semua layer (Floor, Grass, Walls, BaseLayerGround) dan dekorasi bisa
## dicat/digeser di editor. Petak tanam = sel BaseLayerGround (tile "farmable"); cat sel baru
## dengan resource greenhouse_plot_tileset.tres untuk menambah petak.
## Menjalankan ulang MENIMPA scene beserta suntingan editor.
## Godot.exe --headless --path . res://tools/build_greenhouse.tscn
const SCENE := "res://scenes/world/interior/greenhouse.tscn"
const ROOM_TILESET := "res://resources/greenhouse/greenhouse_interior_tileset.tres"
const PLOT_TILESET := "res://resources/greenhouse/greenhouse_plot_tileset.tres"
const HOUSE := "res://assets/farm_rpg/tileset/int/Tileset House.png"
const FRAME := "res://assets/greenhouse/greenhouse_frame.png"
const GRASS := "res://assets/farm_rpg/tileset/ext/Tileset Grass Spring.png"
const SOIL := "res://assets/farm_rpg/tileset/ext/Tilled Soil and wet soil.png"
const BUSHES := "res://assets/farm_rpg/tileset/ext/bushes.png"
const PROPS := "res://assets/farm_rpg/tileset/ext/ALL props seasons.png"
const FOUNTAIN := "res://assets/farm_rpg/objects/exterior/Water fountain.png"
const BUCKETS := "res://assets/farm_rpg/objects/exterior/Wooden Buckets.png"
const LAMP := "res://assets/farm_rpg/objects/exterior/Street Lamp.png"
const TOOLS := "res://assets/farm_rpg/objects/exterior/Farm Tools.png"
const GRASS_DETAIL := "res://resources/grass_detail_material.tres"
const SOIL_DETAIL := "res://resources/soil_detail_material.tres"
const SWAY_MATERIAL := "res://resources/greenhouse/plant_sway_material.tres"
const FLOWERS: Array[Rect2] = [Rect2(176, 0, 16, 16), Rect2(192, 0, 16, 16), Rect2(224, 0, 16, 16), Rect2(192, 16, 16, 16), Rect2(224, 16, 16, 16), Rect2(176, 48, 16, 16)]
const TILE := 16
## Pojok kiri atas ruangan (piksel dunia); ruangan 20 × 19 tile.
const ROOM := Vector2(256, 96)
const SIZE := Vector2i(20, 19)
## Sel logis greenhouse (lihat greenhouse_interior.gd) dimulai di tile ruangan (6, 8).
const FIRST_CELL := Vector2i(10000, 10000)
const FIELD := Rect2i(6, 8, 8, 4)
const TREE_COLUMNS: Array[int] = [3, 16]
const TREE_ROWS: Array[int] = [6, 9, 12, 15]
const DOOR: Array[int] = [9, 10]
## Source di ROOM_TILESET.
const SRC_HOUSE := 0
const SRC_FRAME := 1
const SRC_GRASS := 2
const PLANK := Vector2i(26, 3)
const BRICK := Vector2i(2, 1)
## Di greenhouse_frame.png: tanah ladang (rata, tanpa tepi), piringan tanah bedeng pohon, sulur.
const FIELD_SOIL := Vector2i(0, 3)
const TREE_SOIL := Vector2i(1, 3)
const VINES: Array[Vector2i] = [Vector2i(2, 3), Vector2i(3, 3)]

var world: Node2D
var rng := RandomNumberGenerator.new()


func put(node: Node, parent: Node, label: String) -> Node:
	node.name = label
	parent.add_child(node)
	node.owner = world
	return node


## Sprite berpijak di `at` (y-sort di kaki).
func image(label: String, parent: Node, texture_path: String, at: Vector2, region: Rect2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(texture_path)
	sprite.position = at
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.offset = Vector2(0, -region.size.y * 0.5 + 2)
	return put(sprite, parent, label) as Sprite2D


func solid(label: String, parent: Node, rect: Rect2) -> StaticBody2D:
	var body := put(StaticBody2D.new(), parent, label) as StaticBody2D
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = rect.get_center()
	put(collider, body, "CollisionShape2D")
	return body


func at(cell: Vector2i) -> Vector2:
	return ROOM + Vector2(cell * TILE)


func layer(label: String, tiles: TileSet, z: int, origin := ROOM) -> TileMapLayer:
	var node := TileMapLayer.new()
	node.tile_set = tiles
	node.z_index = z
	node.position = origin
	return put(node, world, label) as TileMapLayer


func atlas(texture_path: String, coords: Array[Vector2i]) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.texture = load(texture_path)
	source.texture_region_size = Vector2i(TILE, TILE)
	for cell in coords:
		if not source.has_tile(cell):
			source.create_tile(cell)
	return source


## Tile 16 px dari bagian dalam tanah cangkul (tanpa tepi bergerigi), tile (0,0) seperti dipakai
## FarmManager._set_ground_tile untuk greenhouse.
func soil_set(region_y: int) -> TileSet:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(TILE, TILE)
	var texture := AtlasTexture.new()
	texture.atlas = load(SOIL)
	texture.region = Rect2(96, region_y, 16, 16)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE, TILE)
	source.create_tile(Vector2i.ZERO)
	tiles.add_source(source, 0)
	return tiles


## Tanah belum dicangkul; setiap tile di sini bertanda "farmable".
func plot_set() -> TileSet:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(TILE, TILE)
	tiles.add_custom_data_layer()
	tiles.set_custom_data_layer_name(0, "farmable")
	tiles.set_custom_data_layer_type(0, TYPE_BOOL)
	var source := atlas(FRAME, [FIELD_SOIL, TREE_SOIL])
	tiles.add_source(source, 0)
	for coords in [FIELD_SOIL, TREE_SOIL]:
		source.get_tile_data(coords, 0).set_custom_data("farmable", true)
	return tiles


func shader_material(shader_path: String, params := {}) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(shader_path)
	for key in params:
		material.set_shader_parameter(key, params[key])
	return material


func saved(tiles: Resource, path: String) -> Resource:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	assert(ResourceSaver.save(tiles, path) == OK)
	tiles.take_over_path(path)
	return tiles


static func blob_coords() -> Array[Vector2i]:
	return [Vector2i(9, 2), Vector2i(8, 0), Vector2i(11, 0), Vector2i(8, 3), Vector2i(11, 3), Vector2i(10, 0), Vector2i(9, 3), Vector2i(8, 1), Vector2i(11, 2), Vector2i(5, 1), Vector2i(6, 1), Vector2i(5, 2), Vector2i(6, 2)]


## Autotile rumput (sama dengan build_balai.gd); `edge` = sel yang dianggap bersambung (dinding).
func blob_tile(cell: Vector2i, cells: Dictionary, edge: Dictionary) -> Vector2i:
	var has := func(c: Vector2i) -> bool:
		return cells.has(c) or edge.has(c)
	var n: bool = not has.call(cell + Vector2i.UP)
	var e: bool = not has.call(cell + Vector2i.RIGHT)
	var s: bool = not has.call(cell + Vector2i.DOWN)
	var w: bool = not has.call(cell + Vector2i.LEFT)
	if n and w: return Vector2i(8, 0)
	if n and e: return Vector2i(11, 0)
	if s and w: return Vector2i(8, 3)
	if s and e: return Vector2i(11, 3)
	if n: return Vector2i(10, 0)
	if s: return Vector2i(9, 3)
	if w: return Vector2i(8, 1)
	if e: return Vector2i(11, 2)
	if not has.call(cell + Vector2i(-1, -1)): return Vector2i(5, 1)
	if not has.call(cell + Vector2i(1, -1)): return Vector2i(6, 1)
	if not has.call(cell + Vector2i(-1, 1)): return Vector2i(5, 2)
	if not has.call(cell + Vector2i(1, 1)): return Vector2i(6, 2)
	return Vector2i(9, 2)


func plot_cell(room_cell: Vector2i) -> Vector2i:
	return FIRST_CELL + room_cell - FIELD.position


func _ready() -> void:
	call_deferred("_build")


func _build() -> void:
	rng.seed = 20261102
	var room_tiles := TileSet.new()
	room_tiles.tile_size = Vector2i(TILE, TILE)
	room_tiles.add_source(atlas(HOUSE, [PLANK]), SRC_HOUSE)
	var frame_tiles: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), BRICK]
	frame_tiles.append_array(VINES)
	room_tiles.add_source(atlas(FRAME, frame_tiles), SRC_FRAME)
	room_tiles.add_source(atlas(GRASS, blob_coords()), SRC_GRASS)
	saved(room_tiles, ROOM_TILESET)
	var plot_tiles := saved(plot_set(), PLOT_TILESET) as TileSet
	saved(shader_material("res://shaders/plant_sway.gdshader"), SWAY_MATERIAL)
	var uid := ResourceLoader.get_resource_uid(SCENE)

	world = Node2D.new()
	world.name = "GreenhouseInterior"
	world.y_sort_enabled = true
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.set_script(load("res://scripts/world/greenhouse_interior.gd"))

	var floor_layer := layer("Floor", room_tiles, -6)
	var grass_layer := layer("Grass", room_tiles, -5)
	var walls := layer("Walls", room_tiles, -5)
	# Di atas Walls (z lebih tinggi).
	var vines := layer("Vines", room_tiles, -4)
	# Detailing shader (parameter bisa diatur di Inspector).
	floor_layer.material = shader_material("res://shaders/floor_wear.gdshader", {"grime_strength": 0.08, "stain_strength": 0.12})
	grass_layer.material = load(GRASS_DETAIL)
	walls.material = shader_material("res://shaders/glass_sheen.gdshader")
	# Dinding: kaca belakang 3 baris, tiang samping, dinding bata bawah dengan pintu.
	var wall_cells := {}
	for x in SIZE.x:
		for y in SIZE.y:
			var cell := Vector2i(x, y)
			var side := x == 0 or x == SIZE.x - 1
			if y == SIZE.y - 1:
				if not DOOR.has(x):
					walls.set_cell(cell, SRC_FRAME, Vector2i(3, 0) if side else Vector2i(2, 0))
					wall_cells[cell] = true
			elif side:
				walls.set_cell(cell, SRC_FRAME, Vector2i(3, 0) if y == 0 else Vector2i(1, 0))
				wall_cells[cell] = true
			elif y < 3:
				walls.set_cell(cell, SRC_FRAME, Vector2i(0, y))
				wall_cells[cell] = true
			else:
				floor_layer.set_cell(cell, SRC_HOUSE, PLANK)
	# Sulur menggantung dari rangka atas kaca.
	for x in range(1, SIZE.x - 1):
		if rng.randf() < 0.55:
			vines.set_cell(Vector2i(x, 0), SRC_FRAME, VINES[rng.randi() % VINES.size()])
	for x in DOOR:
		floor_layer.set_cell(Vector2i(x, SIZE.y - 1), SRC_HOUSE, PLANK)
	# Bingkai bata ladang tengah.
	for x in range(FIELD.position.x - 1, FIELD.end.x + 1):
		for y in range(FIELD.position.y - 1, FIELD.end.y + 1):
			floor_layer.set_cell(Vector2i(x, y), SRC_FRAME, BRICK)
	# Rumput: jalur belakang, bedeng pohon kiri/kanan, bedeng bunga depan.
	var grass := {}
	for x in range(1, SIZE.x - 1):
		grass[Vector2i(x, 3)] = true
	for y in range(3, SIZE.y - 2):
		for x in [1, 2, 3, 4, 15, 16, 17, 18]:
			grass[Vector2i(x, y)] = true
	for x in range(1, SIZE.x - 1):
		if x < 8 or x > 11:
			grass[Vector2i(x, SIZE.y - 2)] = true
	for cell: Vector2i in grass:
		grass_layer.set_cell(cell, SRC_GRASS, blob_tile(cell, grass, wall_cells))

	# Layer FarmManager: sel logis mulai FIRST_CELL di tile ruangan FIELD.position.
	var plot_origin := at(FIELD.position) - Vector2(FIRST_CELL * TILE)
	# z berbeda per layer: dalam root y-sort, layer ber-z sama tidak dijamin berurutan.
	# Tanah dasar < dicangkul < basah < tanaman.
	var ground := layer("BaseLayerGround", plot_tiles, -4, plot_origin)
	ground.material = load(SOIL_DETAIL)
	for x in range(FIELD.position.x, FIELD.end.x):
		for y in range(FIELD.position.y, FIELD.end.y):
			ground.set_cell(plot_cell(Vector2i(x, y)), 0, FIELD_SOIL)
	for x in TREE_COLUMNS:
		for y in TREE_ROWS:
			ground.set_cell(plot_cell(Vector2i(x, y)), 0, TREE_SOIL)
	layer("SoilLayer", soil_set(24), -3, plot_origin).material = load(SOIL_DETAIL)
	layer("WateredLayer", soil_set(88), -2, plot_origin)
	var crop_tiles := TileSet.new()
	crop_tiles.tile_size = Vector2i(TILE, TILE)
	var crop := layer("Crop", crop_tiles, 0, plot_origin)
	crop.y_sort_enabled = true

	_decor()
	_sunlight()
	_bounds()
	_door()

	var scene := PackedScene.new()
	assert(scene.pack(world) == OK)
	var error := ResourceSaver.save(scene, SCENE)
	# PackedScene baru tidak membawa UID lama; pertahankan agar rujukan uid:// tetap valid.
	if error == OK and uid != ResourceUID.INVALID_ID:
		error = ResourceSaver.set_uid(SCENE, uid)
	print("GREENHOUSE BUILD: ", error_string(error), "; plots=", ground.get_used_cells().size())
	world.free()
	get_tree().quit(0 if error == OK else 1)


func _decor() -> void:
	var decor := put(Node2D.new(), world, "Decor") as Node2D
	decor.y_sort_enabled = true
	# Air mancur di tengah dinding belakang (animasi 4 frame).
	var fountain := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", 5.0)
	for i in 4:
		var texture := AtlasTexture.new()
		texture.atlas = load(FOUNTAIN)
		texture.region = Rect2(48 * i, 0, 48, 64)
		frames.add_frame(&"default", texture)
	fountain.sprite_frames = frames
	fountain.autoplay = "default"
	fountain.position = at(Vector2i(10, 6)) + Vector2(0, -4)
	fountain.offset = Vector2(0, -30)
	put(fountain, decor, "Fountain")
	solid("FountainBody", decor, Rect2(at(Vector2i(9, 4)) + Vector2(-4, 0), Vector2(40, 26)))
	# Semak di jalur belakang dan pojok bedeng.
	for x in [2, 5, 14, 17]:
		var p := at(Vector2i(x, 4)) + Vector2(8, -2)
		image("BackBush%d" % x, decor, BUSHES, p, Rect2(48 * (x % 2), 32 * (x % 3), 48, 32)).material = load(SWAY_MATERIAL)
		solid("BackBush%dBody" % x, decor, Rect2(p.x - 12, p.y - 6, 24, 8))
	for x in [8, 11]:
		var p := at(Vector2i(x, 5)) + Vector2(8, 14)
		image("Bucket%d" % x, decor, BUCKETS, p, Rect2(0, 16, 16, 16))
		solid("Bucket%dBody" % x, decor, Rect2(p.x - 6, p.y - 6, 12, 6))
	# Bunga di sela pohon (sisi luar bedeng) dan bedeng depan.
	var flower_cells: Array[Vector2i] = []
	for y in range(5, 16):
		if not TREE_ROWS.has(y):
			flower_cells.append(Vector2i(1, y))
			flower_cells.append(Vector2i(18, y))
	for x in range(1, SIZE.x - 1):
		if x < 8 or x > 11:
			flower_cells.append(Vector2i(x, SIZE.y - 2))
	for cell in flower_cells:
		image("Flower%d_%d" % [cell.x, cell.y], decor, PROPS, at(cell) + Vector2(8, 14), FLOWERS[rng.randi() % FLOWERS.size()]).material = load(SWAY_MATERIAL)
	# Rak alat di lantai belakang, kiri air mancur.
	var rack := at(Vector2i(6, 5)) + Vector2(8, 14)
	image("FarmTools", decor, TOOLS, rack, Rect2(0, 0, 48, 16))
	solid("FarmToolsBody", decor, Rect2(rack.x - 22, rack.y - 6, 44, 6))
	# Lampu di kiri/kanan jalan pintu.
	for x in [7, 12]:
		var p := at(Vector2i(x, SIZE.y - 3)) + Vector2(8, 12)
		var lamp := image("Lamp%d" % x, decor, LAMP, p, Rect2(0, 0, 32, 48))
		lamp.offset = Vector2(0, -21)
		solid("Lamp%dBody" % x, decor, Rect2(p.x - 4, p.y - 6, 8, 6))


## Berkas sinar matahari dari kaca belakang (shaders/light_shaft.gdshader pada ColorRect),
## debu melayang di dalamnya, dan vignette hangat di tepi ruangan.
func _sunlight() -> void:
	var light := put(Node2D.new(), world, "Sunlight") as Node2D
	light.z_index = 2
	for i in 3:
		var beam := ColorRect.new()
		beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
		beam.position = at(Vector2i(1 + i * 5, 1))
		beam.size = Vector2(88, 230)
		beam.material = shader_material("res://shaders/light_shaft.gdshader", {"intensity": 0.3 if i % 2 else 0.24, "top_width": 0.4, "slant": 0.35, "shimmer_speed": 0.4 + 0.15 * i})
		put(beam, light, "Beam%d" % i)
	var dust := CPUParticles2D.new()
	dust.position = at(Vector2i(10, 9))
	dust.amount = 28
	dust.lifetime = 7.0
	dust.preprocess = 7.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(104, 96)
	dust.direction = Vector2(0.3, -1)
	dust.spread = 60.0
	dust.gravity = Vector2(0.5, 0.5)
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 4.0
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 1.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.96, 0.8, 0.0))
	fade.set_color(1, Color(1.0, 0.96, 0.8, 0.0))
	fade.add_point(0.3, Color(1.0, 0.96, 0.8, 0.55))
	fade.add_point(0.7, Color(1.0, 0.96, 0.8, 0.55))
	dust.color_ramp = fade
	put(dust, light, "Dust")
	var vignette := ColorRect.new()
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.position = ROOM
	vignette.size = Vector2(SIZE * TILE)
	vignette.material = shader_material("res://shaders/room_vignette.gdshader", {"vignette_color": Color(0.16, 0.08, 0.04), "strength": 0.28, "inner_radius": 0.7, "outer_radius": 1.45})
	put(vignette, light, "Vignette")


func _bounds() -> void:
	var bounds := put(StaticBody2D.new(), world, "Bounds")
	var rects := {
		"Back": Rect2(at(Vector2i(0, 0)), Vector2(SIZE.x * TILE, 3 * TILE + 10)),
		"Left": Rect2(at(Vector2i(0, 0)), Vector2(TILE, SIZE.y * TILE)),
		"Right": Rect2(at(Vector2i(SIZE.x - 1, 0)), Vector2(TILE, SIZE.y * TILE)),
		"BottomLeft": Rect2(at(Vector2i(0, SIZE.y - 2)), Vector2(DOOR[0] * TILE - 16, 2 * TILE)),
		"BottomRight": Rect2(at(Vector2i(DOOR[1] + 2, SIZE.y - 2)), Vector2((SIZE.x - DOOR[1] - 2) * TILE, 2 * TILE)),
		"DoorStop": Rect2(at(Vector2i(DOOR[0] - 1, SIZE.y)), Vector2(4 * TILE, 8)),
		"DoorLeft": Rect2(at(Vector2i(DOOR[0] - 1, SIZE.y - 1)), Vector2(TILE, TILE)),
		"DoorRight": Rect2(at(Vector2i(DOOR[1] + 1, SIZE.y - 1)), Vector2(TILE, TILE)),
	}
	for label in rects:
		var rect: Rect2 = rects[label]
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		var collider := CollisionShape2D.new()
		collider.shape = shape
		collider.position = rect.get_center()
		put(collider, bounds, label)


func _door() -> void:
	var door_center := at(Vector2i(DOOR[1], SIZE.y - 1)) + Vector2(0, 8)
	var spawn_at := door_center + Vector2(0, -28)
	var player: Node2D = load("res://scenes/player/Player.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	player.position = spawn_at
	put(player, world, "Player")
	var spawn := Marker2D.new()
	spawn.position = spawn_at
	put(spawn, world, "spawn")
	var exit := Area2D.new()
	exit.position = door_center
	exit.set_script(load("res://scripts/world/balai_nadi_interactable.gd"))
	exit.set("interaction_type", 1)
	exit.set("target_scene", "res://scenes/world/farm.tscn")
	exit.set("spawn_position", Vector2(576, 123))
	put(exit, world, "Exit")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32, 20)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	put(collider, exit, "CollisionShape2D")
