extends SceneTree

## Initial scene authoring tool. The saved .tscn files remain editable in Godot.
## Re-running replaces only the ranch exterior and Eep's home/shop interior.
const OUTSIDE := "res://scenes/world/eep_ranch.tscn"
const INSIDE := "res://scenes/world/interior/eep_home.tscn"
const GRASS := "res://assets/farm_rpg/tileset/ext/Tileset Grass Spring.png"
const BARN := "res://assets/farm_rpg/objects/exterior/Houses/Farm Buildings/Barn/Big Barn.png"
var world: Node2D
var rng := RandomNumberGenerator.new()

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
	board.font_size = 10
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
	world.map_size = Vector2i(640, 448) if path == INSIDE else Vector2i(1152, 768)
	var scene := PackedScene.new()
	assert(scene.pack(world) == OK)
	assert(ResourceSaver.save(scene, path) == OK)
	world.free()
	print("SAVED ", path)

func outside() -> void:
	world = Node2D.new()
	world.name = "EepRanch"
	rng.seed = 20261024
	var meadow := Polygon2D.new()
	meadow.polygon = PackedVector2Array([Vector2.ZERO,Vector2(1152,0),Vector2(1152,768),Vector2(0,768)])
	meadow.color = Color8(121,191,86)
	meadow.z_index = -11
	put(meadow,world,"MeadowBase")
	var grass := layers("BaseLayerGround", GRASS, [Vector2i(9, 2)], -10)
	grass.material = load("res://resources/grass_detail_material.tres")
	var coordinates: Array[Vector2i] = []
	for x in range(4, 8):
		for y in range(8, 12):
			coordinates.append(Vector2i(x,y))
	var paths := layers("Paths", GRASS, coordinates, -8)
	var water := layers("PondWater", "res://assets/farm_rpg/tileset/ext/Water tile.png", [Vector2i.ZERO], -9)
	water.material = load("res://resources/water_detail_material.tres")
	var pond: Dictionary = {}
	var roads: Dictionary = {}
	for x in 72:
		for y in 48:
			var pos := Vector2(x * 16 + 8, y * 16 + 8)
			var p := Vector2((pos.x - 304) / 168, (pos.y - 480) / 136)
			var wet := p.length_squared() < 1.0 + 0.09 * sin(float(x) * 0.9) or (x > 55 and y > 42 - (x - 56) / 3)
			if wet:
				water.set_cell(Vector2i(x,y), 0, Vector2i.ZERO)
				pond[Vector2i(x,y)] = true
			else:
				grass.set_cell(Vector2i(x,y), 0, Vector2i(9,2))
	# Broad dirt paths: Farm north, Town west, ranch and pasture east.
	var lines := [[Vector2(608,0),Vector2(608,336)], [Vector2(608,336),Vector2(816,288)], [Vector2(0,320),Vector2(608,336)], [Vector2(608,336),Vector2(672,640)], [Vector2(672,448),Vector2(976,416)], [Vector2(816,288),Vector2(944,352)]]
	for x in 72:
		for y in 48:
			var cell := Vector2i(x,y)
			if pond.has(cell):
				continue
			var position := Vector2(x * 16 + 8, y * 16 + 8)
			for line: Array in lines:
				if Geometry2D.get_closest_point_to_segment(position, line[0], line[1]).distance_to(position) < 31:
					roads[cell] = true
			for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if pond.has(cell + direction):
					roads[cell] = true
	for cell: Vector2i in roads:
		var left := not roads.has(cell + Vector2i.LEFT)
		var right := not roads.has(cell + Vector2i.RIGHT)
		var top := not roads.has(cell + Vector2i.UP)
		var bottom := not roads.has(cell + Vector2i.DOWN)
		paths.set_cell(cell, 0, Vector2i(4 if left else 7 if right else 5, 8 if top else 11 if bottom else 9))
	var terrain := group("TerrainCollisions")
	# Merge water cells into row strips: every visible water tile blocks walking.
	for y in 48:
		var start := -1
		for x in 73:
			var wet := pond.has(Vector2i(x,y))
			if wet and start < 0:
				start = x
			elif not wet and start >= 0:
				solid("Water_%d_%d" % [start,y], terrain, Rect2(start*16,y*16,(x-start)*16,16))
				start = -1
	for rect in [Rect2(0,-16,576,16),Rect2(640,-16,512,16),Rect2(-16,0,16,288),Rect2(-16,352,16,416),Rect2(1152,0,16,768),Rect2(0,768,1152,16)]:
		solid("Edge" + str(terrain.get_child_count()), terrain, rect)
	var decor := group("Scenery")
	decor.y_sort_enabled = true
	for i in 100:
		var pos := Vector2(rng.randi_range(64,1088),rng.randi_range(128,704))
		var cell := Vector2i(pos/16)
		if roads.has(cell) or pond.has(cell) or Rect2(688,40,400,260).has_point(pos):
			continue
		image("Wildflower"+str(i),decor,"res://assets/farm_rpg/tileset/ext/ALL props seasons.png",pos,Rect2(192 if i%2 else 208,0,16,16))
	var house := group("EepRanchHouse", decor)
	house.position = Vector2(816,256)
	var building := image("BarnHouse", house, BARN, Vector2(0,-100), Rect2(0,0,112,112), 2.0)
	building.offset = Vector2(0,0)
	solid("BuildingBody", house, Rect2(-100,-170,200,144))
	entrance("Door", Vector2(0,0), Vector2(34,28), INSIDE, Vector2(320,384), false, house)
	point(house,"ReturnSpawn",Vector2(0,32))
	signboard("RanchSign", house, Vector2(-90,-24), "RANCH EEP")
	# A small coop and fenced grazing meadow frame the lower-right clearing.
	image("Coop", decor, "res://assets/farm_rpg/objects/exterior/Houses/Farm Buildings/Chicken Coop/Chicken Coop.png", Vector2(1008,486), Rect2(0,0,80,80), 1.5)
	solid("CoopBody", decor, Rect2(960,460,88,44))
	var fences := group("PastureFence", decor)
	for x in range(784,1089,16):
		for y in [336,528]:
			if y == 336 and x >= 912 and x <= 960:
				continue
			image("Rail_%d_%d" % [x,y], fences, "res://assets/farm_rpg/objects/exterior/Fence Wood.png",Vector2(x,y),Rect2(16,0,16,16))
			solid("RailBody_%d_%d" % [x,y], fences, Rect2(x-8,y-2,16,6))
	for y in range(352,528,16):
		for x in [784,1088]:
			if x == 784 and y >= 400 and y <= 432:
				continue
			image("Post_%d_%d" % [x,y], fences, "res://assets/farm_rpg/objects/exterior/Fence Wood.png",Vector2(x,y),Rect2(0,16,16,16))
			solid("PostBody_%d_%d" % [x,y], fences, Rect2(x-3,y-8,6,16))
	image("Trough", decor, "res://assets/ranch/feeding_trough.svg",Vector2(1016,360))
	image("WaterBasin", decor, "res://assets/ranch/water_basin.svg",Vector2(848,496))
	# Scenic animals are display sprites, not player-owned livestock/save records.
	image("DisplayCow", decor,"res://assets/farm_rpg/animals/cow.png",Vector2(880,394),Rect2(0,0,32,32),1.5)
	image("DisplaySheep", decor,"res://assets/farm_rpg/animals/sheep.png",Vector2(1008,432),Rect2(0,0,32,32),1.5)
	image("DisplayChicken", decor,"res://assets/farm_rpg/animals/chicken/white.png",Vector2(944,470),Rect2(0,0,16,16),1.5)
	# Dense tree borders; keep authored paths, pond bank and home yard clear.
	for i in 260:
		var pos := Vector2(rng.randi_range(20,1130),rng.randi_range(32,752))
		var border := pos.y < 100 or pos.x < 92 or pos.y > 696 or pos.x > 1100
		var grove := (pos.x < 520 and pos.y < 260) or (pos.x > 480 and pos.x < 560 and pos.y > 420)
		if not border and not grove:
			continue
		var cell := Vector2i(pos/16)
		if pond.has(cell) or roads.has(cell) or (pos.x > 556 and pos.x < 660) or (pos.x < 105 and absf(pos.y-320)<72) or Rect2(688,40,400,260).has_point(pos):
			continue
		var tree := image("Tree"+str(i),decor,"res://assets/farm_rpg/objects/tree/Maple Tree Animation.png" if i%3 else "res://assets/farm_rpg/objects/tree/Pine Tree Animation.png",pos+Vector2(0,-32),Rect2(0,48,32,48),1.5)
		# Y-sort by the trunk rather than canopy center.
		tree.offset = Vector2(0,-8)
		solid("Trunk"+str(i),decor,Rect2(pos.x-6,pos.y-6,12,12))
	# Dock on the north shore. Its land-side planks do not bypass water collision.
	for y in range(336,370,8):
		image("Dock"+str(y),decor,"res://assets/farm_rpg/tileset/ext/Bridge.png",Vector2(304,y),Rect2(0,0,16,16))
	signboard("FarmDirection",decor,Vector2(688,80),"UTARA: FARM")
	signboard("TownDirection",decor,Vector2(128,276),"BARAT: TOWN")
	entrance("NorthToFarm",Vector2(608,4),Vector2(64,24),"res://scenes/world/farm.tscn",Vector2(992,928))
	entrance("WestToTown",Vector2(4,320),Vector2(24,64),"res://scenes/world/town.tscn",Vector2(1184,640))
	residents("eep_ranch", {"eep_home":Vector2(816,288),"eep_feed":Vector2(944,352),"eep_rest":Vector2(960,416)},Vector2(816,288),"eep_home",[Vector2(816,288),Vector2(944,288),Vector2(944,352),Vector2(944,416),Vector2(960,416)])
	var seasons := Node.new()
	seasons.set_script(load("res://scripts/world/seasonal_tile_swapper.gd"))
	put(seasons,world,"SeasonalTileSwapper")
	player(Vector2(608,72))
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
	image("FeedSack",furniture,"res://assets/ranch/feeding_trough.svg",Vector2(112,208))
	signboard("ShopBoard",furniture,Vector2(272,96),"TOKO TERNAK EEP")
	signboard("Hours",furniture,Vector2(128,304),"09–12 / 13–17\nRabu libur")
	signboard("Bedroom",furniture,Vector2(528,64),"RUMAH EEP")
	entrance("ExitDoor",Vector2(320,436),Vector2(64,24),OUTSIDE,Vector2(816,288))
	residents("eep_home",{"eep_home":Vector2(528,144),"eep_stall":Vector2(272,176),"eep_lunch":Vector2(528,240),"eep_rest":Vector2(464,208)},Vector2(320,400),"eep_ranch",[Vector2(320,400),Vector2(400,400),Vector2(400,176),Vector2(272,176)])
	var network := world.get_node("NPCPaths")
	route(network,"EepBedroom",[Vector2(400,176),Vector2(464,176),Vector2(528,176),Vector2(528,144)])
	route(network,"EepLunch",[Vector2(464,176),Vector2(464,208),Vector2(528,208),Vector2(528,240)])
	player(Vector2(320,384))
	save_world(INSIDE)

func _initialize() -> void:
	outside()
	inside()
	var farm: Node = load("res://scenes/world/farm.tscn").instantiate()
	print("FARM RECT ",farm.get_node("BaseLayerGround").get_used_rect())
	farm.free()
	quit()
