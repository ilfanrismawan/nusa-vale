extends SceneTree
## One-shot native scene authoring; playable map contains only saved editor nodes.
const OUT := "res://scenes/world/balai_nadi/exterior.tscn"
const PROPS := "res://assets/balai_nadi/v3/sacred_props.png"
const TILE := 16
var courtyard: Node2D
var rng := RandomNumberGenerator.new()
var land: Dictionary = {}
var walkable: Dictionary = {}
var objects: Node2D
var anims := Animation.new()
# One AtlasTexture per (texture, region): sprites share sub-resources instead of saving duplicates.
var atlas_cache: Dictionary = {}

func own(node: Node, parent: Node) -> Node:
	parent.add_child(node)
	node.owner = courtyard
	return node

func group(label: String, parent: Node = null) -> Node2D:
	if parent == null: parent = courtyard
	var node := Node2D.new()
	node.name = label
	own(node, parent)
	return node

func rect_body(label: String, center: Vector2, size: Vector2, parent: Node) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = label
	body.position = center
	own(body, parent)
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	own(shape, body)
	return body

func blocker(label: String, center: Vector2, size: Vector2, body: StaticBody2D) -> void:
	var shape := CollisionShape2D.new()
	shape.name = label
	shape.position = center
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	own(shape, body)

func sprite(label: String, path: String, point: Vector2, region: Rect2, scale_value: Vector2, parent: Node) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = label
	s.position = point
	s.scale = scale_value
	if region.has_area():
		var key := "%s|%s" % [path, region]
		if not atlas_cache.has(key):
			var atlas := AtlasTexture.new()
			atlas.atlas = load(path)
			atlas.region = region
			atlas_cache[key] = atlas
		s.texture = atlas_cache[key]
	else:
		s.texture = load(path)
	own(s, parent)
	return s

func polygon(label: String, points: PackedVector2Array, color: Color, parent: Node) -> Polygon2D:
	var p := Polygon2D.new()
	p.name = label
	p.polygon = points
	p.color = color
	own(p, parent)
	return p

func atlas_layer(label: String, texture_path: String, parent: Node, material_path: String = "") -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = label
	layer.tile_set = TileSet.new()
	layer.tile_set.tile_size = Vector2i(TILE, TILE)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load(texture_path)
	atlas.texture_region_size = Vector2i(TILE, TILE)
	layer.tile_set.add_source(atlas, 0)
	for y in range(atlas.texture.get_height() / TILE):
		for x in range(atlas.texture.get_width() / TILE):
			atlas.create_tile(Vector2i(x, y))
	if not material_path.is_empty():
		layer.material = load(material_path)
	own(layer, parent)
	return layer

## Trees as one y-sorted TileMapLayer instead of four nodes each. Alternative id = horizontal
## jitter (0..8 px), so every tree keeps its baked position, sort point, and root collider.
const TREE_REGION := Rect2i(0, 48, 32, 48)
const TREE_JITTER := 9
func tree_layer(label: String, texture_paths: Array, parent: Node) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = label
	layer.y_sort_enabled = true
	layer.tile_set = TileSet.new()
	layer.tile_set.tile_size = Vector2i(TILE, TILE)
	layer.tile_set.add_physics_layer()
	var coords := TREE_REGION.position / TREE_REGION.size
	for i in range(texture_paths.size()):
		var source := TileSetAtlasSource.new()
		source.texture = load(texture_paths[i])
		source.texture_region_size = TREE_REGION.size
		layer.tile_set.add_source(source, i)
		source.create_tile(coords)
		for jitter in range(TREE_JITTER):
			var alternative := 0 if jitter == 0 else source.create_alternative_tile(coords)
			var data := source.get_tile_data(coords, alternative)
			# Cell centre is cell*16+(8,8); the old node sat at cell*16+(4+jitter,8) with art 24 px above.
			var shift := Vector2(jitter - 4, 0)
			data.texture_origin = Vector2i(4 - jitter, 24)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, PackedVector2Array([shift + Vector2(-5,-5), shift + Vector2(5,-5), shift + Vector2(5,1), shift + Vector2(-5,1)]))
	own(layer, parent)
	return layer

## Collinear one-cell rail edges merged into one Line2D pair per straight run.
func rail_runs(segments: Array, parent: Node) -> void:
	var rows: Dictionary = {}
	for seg: Array in segments:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var horizontal := is_equal_approx(a.y, b.y)
		var key := Vector2(0 if horizontal else 1, a.y if horizontal else a.x)
		if not rows.has(key): rows[key] = []
		rows[key].append(minf(a.x, b.x) if horizontal else minf(a.y, b.y))
	var index := 0
	var keys := rows.keys()
	keys.sort()
	for key: Vector2 in keys:
		var starts: Array = rows[key]
		starts.sort()
		var run_start: float = starts[0]
		var run_end: float = starts[0] + TILE
		for i in range(1, starts.size() + 1):
			if i < starts.size() and is_equal_approx(starts[i], run_end):
				run_end += TILE
				continue
			var a := Vector2(run_start, key.y) if key.x == 0 else Vector2(key.y, run_start)
			var b := Vector2(run_end, key.y) if key.x == 0 else Vector2(key.y, run_end)
			edge_line("Rail_%d" % index, a, b, parent)
			index += 1
			if i < starts.size():
				run_start = starts[i]
				run_end = starts[i] + TILE

## Props are generated once; after that the editor owns them (bale_agung carries hand-made
## restoration art and collision), so an existing file is reused, never overwritten.
func prop_scene(label: String, region: Rect2, width: float, height: float, collider: Vector2, source := PROPS) -> PackedScene:
	var destination := "res://scenes/world/balai_nadi/props/%s.tscn" % label.to_snake_case()
	if ResourceLoader.exists(destination): return load(destination)
	var node := Node2D.new()
	node.name = label
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var art := Sprite2D.new()
	art.name = "Art"
	var tex := AtlasTexture.new()
	tex.atlas = load(source)
	tex.region = region
	art.texture = tex
	art.scale = Vector2(width / region.size.x, height / region.size.y)
	art.position.y = -height / 2.0
	node.add_child(art)
	art.owner = node
	if collider != Vector2.ZERO:
		var body := StaticBody2D.new()
		body.name = "BaseCollision"
		body.position.y = -collider.y / 2.0
		node.add_child(body)
		body.owner = node
		var collision := CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var box := RectangleShape2D.new()
		box.size = collider
		collision.shape = box
		body.add_child(collision)
		collision.owner = node
	var packed := PackedScene.new()
	packed.pack(node)
	ResourceSaver.save(packed, destination)
	node.free()
	return load(destination)

## Tile layers repainted in the editor after the first bake; their cells are copied from the
## existing scene so a re-bake keeps them.
const EDITOR_PAINTED := ["PelataranDanJembatan/TamanDanTeras"]
func keep_painted_layers() -> void:
	if not ResourceLoader.exists(OUT): return
	var previous: Node = load(OUT).instantiate()
	for path: String in EDITOR_PAINTED:
		var source := previous.get_node_or_null(path) as TileMapLayer
		if source != null: (courtyard.get_node(path) as TileMapLayer).tile_map_data = source.tile_map_data
	previous.free()

func instance_prop(scene: PackedScene, label: String, point: Vector2, parent: Node) -> Node2D:
	# Edit-state instance: only real overrides (name, position) are saved, so later prop edits show through.
	var node: Node2D = scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	node.name = label
	node.position = point
	own(node, parent)
	return node

func motion(node: Node, property: String, values: Array, duration: float) -> void:
	var index := anims.add_track(Animation.TYPE_VALUE)
	anims.track_set_path(index, NodePath(str(courtyard.get_path_to(node)) + ":" + property))
	for i in range(values.size()):
		anims.track_insert_key(index, duration * i / float(values.size() - 1), values[i])


const CELLS := Rect2i(-20,-8,94,64)
const WORLD := Rect2(-320,-128,1504,1024)
const GRASS_WATER := "res://assets/farm_rpg/tileset/ext/Tileset Grass Water Spring.png"
const GRASS := "res://assets/farm_rpg/tileset/ext/Tileset Grass Spring.png"
const PATH_ART := "res://assets/farm_rpg/tileset/ext/Path tiles.png"
const ROUTE := [Vector2(144,-40),Vector2(80,32),Vector2(64,224),Vector2(112,384),Vector2(80,560),Vector2(176,688),Vector2(432,720),Vector2(688,704),Vector2(848,608),Vector2(832,400),Vector2(880,224),Vector2(864,32),Vector2(784,-40)]
var boards: Dictionary = {}
var paths: Dictionary = {}
var platform: Dictionary = {}
var reserved: Dictionary = {}

func _initialize() -> void:
	call_deferred("bake")

func add_rect(cells: Dictionary, area: Rect2i) -> void:
	for y in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			cells[Vector2i(x,y)] = true

func brush_path(from: Vector2, to: Vector2, radius: int = 1) -> void:
	var steps := ceili(from.distance_to(to)/8.0)
	for i in range(steps+1):
		var center := Vector2i(floor(from.lerp(to,float(i)/maxi(steps,1))/16.0))
		for oy in range(-radius,radius+1):
			for ox in range(-radius,radius+1):
				var cell := center+Vector2i(ox,oy)
				if land.has(cell): paths[cell]=true
				reserved[cell]=true

func mask(cells: Dictionary, cell: Vector2i) -> int:
	var result := 0
	var offsets := [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i(-1,-1),Vector2i(1,-1),Vector2i(1,1),Vector2i(-1,1)]
	for i in range(offsets.size()):
		if cells.has(cell+offsets[i]): result |= 1<<i
	return result

func shore_tile(cells: Dictionary, cell: Vector2i, row: int = 0) -> Vector2i:
	var n := cells.has(cell+Vector2i.UP)
	var e := cells.has(cell+Vector2i.RIGHT)
	var s := cells.has(cell+Vector2i.DOWN)
	var w := cells.has(cell+Vector2i.LEFT)
	if not n and not w: return Vector2i(8,row)
	if not n and not e: return Vector2i(11,row)
	if not s and not w: return Vector2i(8,row+3)
	if not s and not e: return Vector2i(11,row+3)
	if not n: return Vector2i(9,row)
	if not s: return Vector2i(9,row+3)
	if not w: return Vector2i(8,row+1)
	if not e: return Vector2i(11,row+1)
	# Correct inward corners from the water-hole section of the original atlas.
	if not cells.has(cell+Vector2i(-1,-1)): return Vector2i(5,row+1)
	if not cells.has(cell+Vector2i(1,-1)): return Vector2i(6,row+1)
	if not cells.has(cell+Vector2i(1,1)): return Vector2i(6,row+2)
	if not cells.has(cell+Vector2i(-1,1)): return Vector2i(5,row+2)
	# This atlas has exactly one plain fill per variant: 9,2, not 9,1 or 5,1.
	return Vector2i(9,row+2)

func edge_line(label: String, a: Vector2, b: Vector2, parent: Node) -> void:
	var line := Line2D.new()
	line.name = label
	line.points = PackedVector2Array([a,b])
	line.width = 3
	line.default_color = Color("412b28")
	own(line,parent)
	var highlight := Line2D.new()
	highlight.name = label+"Highlight"
	highlight.points = PackedVector2Array([a-Vector2(0,1),b-Vector2(0,1)])
	highlight.width = 1
	highlight.default_color = Color("bd9262")
	own(highlight,parent)

func add_waypoint(label: String, point: Vector2, parent: Node) -> void:
	var marker := Marker2D.new()
	marker.name = label
	marker.position = point
	own(marker,parent)

func bake() -> void:
	rng.seed = 15102026
	courtyard = Node2D.new()
	courtyard.name = "BalaiNadiExterior"
	courtyard.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	courtyard.y_sort_enabled = true
	courtyard.set_script(load("res://scripts/world/balai_nadi_courtyard.gd"))
	courtyard.set("camera_bounds",WORLD)
	courtyard.set_meta("design","Bale Telaga — taman, tepian air, dan jalur panorama")
	courtyard.set_meta("cell_bounds",CELLS)
	var terrain := group("Terrain")
	terrain.z_index = -10
	var water := atlas_layer("Telaga","res://assets/farm_rpg/tileset/ext/Water tile.png",terrain,"res://resources/water_detail_material.tres")
	var banks := atlas_layer("TepianBerumput",GRASS_WATER,terrain,"res://resources/grass_detail_material.tres")
	var shore_masks: Dictionary = {}
	for y in range(CELLS.position.y,CELLS.end.y):
		for x in range(CELLS.position.x,CELLS.end.x):
			var cell := Vector2i(x,y)
			water.set_cell(cell,0,Vector2i.ZERO)
			var left := 11+roundi(2*sin(y*0.20))
			var right := 44+roundi(2*sin(y*0.22))
			if y < 13: right += 6
			var west_island := (Vector2(x,y)-Vector2(16,22)).length() <= 3.3
			var east_island := (Vector2(x,y)-Vector2(36,27)).length() <= 3.0
			var south := y >= 35+roundi(sin(x*0.24))
			if x <= left or x >= right or west_island or east_island or south:
				land[cell]=true
				walkable[cell]=true
	for cell: Vector2i in land:
		banks.set_cell(cell,0,shore_tile(land,cell))
		shore_masks[cell]=mask(land,cell)
	banks.set_meta("neighbor_masks",shore_masks)
	banks.set_meta("atlas_mapping","full eight-neighbor contour; original Farm RPG atlas, with inward corners")
	# One union before choosing edge tiles: joins never acquire interior borders.
	add_rect(platform,Rect2i(19,14,16,7))
	add_rect(boards,Rect2i(25,21,4,15))
	add_rect(boards,Rect2i(8,13,11,4))
	add_rect(boards,Rect2i(35,18,11,3))
	add_rect(boards,Rect2i(38,20,8,6))
	add_rect(boards,Rect2i(34,24,4,4))
	add_rect(boards,Rect2i(9,22,8,2))
	add_rect(boards,Rect2i(8,-4,42,3))
	for cell: Vector2i in boards: walkable[cell]=true
	for cell: Vector2i in platform: walkable[cell]=true
	for i in range(ROUTE.size()-1): brush_path(ROUTE[i],ROUTE[i+1])
	brush_path(Vector2(432,720),Vector2(427,840))
	brush_path(Vector2(112,224),Vector2(176,240))
	brush_path(Vector2(112,384),Vector2(176,368))
	brush_path(Vector2(832,320),Vector2(720,320))
	brush_path(Vector2(112,384),Vector2(-40,424))
	brush_path(Vector2(864,96),Vector2(864,128))
	var garden_terraces: Dictionary = {}
	add_rect(garden_terraces,Rect2i(-6,23,5,4))
	add_rect(garden_terraces,Rect2i(52,4,6,5))
	add_rect(garden_terraces,Rect2i(7,40,5,4))
	for cell: Vector2i in garden_terraces:
		for oy in range(-2,3):
			for ox in range(-2,3): reserved[cell+Vector2i(ox,oy)]=true
	for cell: Vector2i in boards:
		for y in range(-2,3):
			for x in range(-2,3): reserved[cell+Vector2i(x,y)]=true
	var trail := atlas_layer("JalanSetapak",GRASS,terrain)
	for cell: Vector2i in paths:
		# Original terrain has the corresponding dirt contour eight rows lower.
		trail.set_cell(cell,0,shore_tile(paths,cell,8))
	# Flag signed cells beyond the image as errors at bake time.
	var deck_group := group("PelataranDanJembatan")
	deck_group.z_index = -5
	var plinth := atlas_layer("PelataranBatu",PATH_ART,deck_group)
	var garden_floor := atlas_layer("TamanDanTeras",PATH_ART,deck_group)
	for cell: Vector2i in garden_terraces:
		var tx := 9
		var ty := 1
		if not garden_terraces.has(cell+Vector2i.LEFT): tx=8
		elif not garden_terraces.has(cell+Vector2i.RIGHT): tx=11
		if not garden_terraces.has(cell+Vector2i.UP): ty=0
		elif not garden_terraces.has(cell+Vector2i.DOWN): ty=3
		garden_floor.set_cell(cell,0,Vector2i(tx,ty))
	for cell: Vector2i in platform:
		var tx := 9
		var ty := 1
		if not walkable.has(cell+Vector2i.LEFT): tx=8
		elif not walkable.has(cell+Vector2i.RIGHT): tx=11
		if not walkable.has(cell+Vector2i.UP): ty=0
		elif not walkable.has(cell+Vector2i.DOWN): ty=3
		plinth.set_cell(cell,0,Vector2i(tx,ty))
	var flooring := TileMapLayer.new()
	flooring.name="PapanJati"
	flooring.tile_set=TileSet.new()
	flooring.tile_set.tile_size=Vector2i(16,16)
	var wood := TileSetAtlasSource.new()
	wood.texture=load("res://assets/farm_rpg/tileset/ext/Bridge Wood.png")
	wood.texture_region_size=Vector2i(16,16)
	wood.margins=Vector2i(0,8)
	wood.create_tile(Vector2i(1,1))
	flooring.tile_set.add_source(wood,0)
	own(flooring,deck_group)
	for cell: Vector2i in boards:
		flooring.set_cell(cell,0,Vector2i(1,1))
	var edges := group("PagarTepi",deck_group)
	var deck_union := boards.duplicate()
	deck_union.merge(platform)
	var rail_segments: Array = []
	for cell: Vector2i in deck_union:
		var p := Vector2(cell*16)
		for offset: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.UP]:
			if walkable.has(cell+offset): continue
			var a := p
			var b := p
			if offset == Vector2i.LEFT: b += Vector2(0,16)
			elif offset == Vector2i.RIGHT:
				a+=Vector2(16,0)
				b+=Vector2(16,16)
			elif offset == Vector2i.DOWN:
				a+=Vector2(0,16)
				b+=Vector2(16,16)
			else: b+=Vector2(16,0)
			rail_segments.append([a,b])
	rail_runs(rail_segments,edges)
	var water_decor := atlas_layer("TerataiDanBatuAir","res://assets/farm_rpg/objects/Props/Spring/props water.png",terrain)
	for cell: Vector2i in water.get_used_cells():
		if not walkable.has(cell) and rng.randi_range(0,34)==0:
			water_decor.set_cell(cell,0,Vector2i([1,3,4,5,6,9][rng.randi_range(0,5)],0))
	objects = group("Objek")
	objects.y_sort_enabled = true
	var main_tex: Texture2D = load("res://assets/balai_nadi/v3/bale_agung.png")
	var main_region := Rect2(main_tex.get_image().get_used_rect())
	var bale := prop_scene("BaleAgung",main_region,192,152,Vector2.ZERO,"res://assets/balai_nadi/v3/bale_agung.png")
	var small := prop_scene("BaleIstirahat",Rect2(56,60,480,472),64,64,Vector2(44,16))
	var lantern := prop_scene("LenteraAndesit",Rect2(672,160,240,368),20,32,Vector2(10,8))
	var banner := prop_scene("UmbulUmbul",Rect2(1144,16,292,528),24,48,Vector2(6,6))
	var guardian := prop_scene("PenjagaNaga",Rect2(144,584,312,400),32,40,Vector2(24,10))
	var lotus := prop_scene("TerataiNadi",Rect2(592,656,432,316),32,24,Vector2.ZERO)
	var offering := prop_scene("DulangDaya",Rect2(1152,704,264,280),16,16,Vector2(8,6))
	var road_lamp := prop_scene("LenteraJalan",Rect2(0,0,16,32),16,32,Vector2(6,6),"res://assets/farm_rpg/objects/exterior/Street Lamp.png")
	instance_prop(bale,"BaleUtama",Vector2(427,248),objects)
	instance_prop(small,"BaleBarat",Vector2(240,240),objects)
	# Editor additions kept from the hand-edited scene (same spot as BaleBarat, as saved).
	instance_prop(small,"BaleKananAtas",Vector2(240,240),objects)
	instance_prop(small,"BaleTimur",Vector2(656,400),objects)
	instance_prop(small,"BaleTamanBarat",Vector2(-56,400),objects)
	instance_prop(small,"BaleTamanSelatan",Vector2(144,672),objects)
	instance_prop(road_lamp,"LenteraTerasAirTerjun",Vector2(912,144),objects)
	instance_prop(guardian,"NagaBarat",Vector2(264,360),objects)
	instance_prop(guardian,"NagaTimur",Vector2(584,440),objects)
	instance_prop(offering,"DulangBarat",Vector2(240,260),objects)
	instance_prop(offering,"DulangTimur",Vector2(656,416),objects)
	for p in [Vector2(320,252),Vector2(544,252),Vector2(320,312),Vector2(544,312),Vector2(400,360),Vector2(464,360),Vector2(400,440),Vector2(464,440),Vector2(400,520),Vector2(464,520),Vector2(608,320),Vector2(704,320)]:
		instance_prop(lantern,"Lentera_%d_%d" % [p.x,p.y],p,objects)
	for p in [Vector2(336,304),Vector2(528,304),Vector2(384,408),Vector2(480,488),Vector2(240,208),Vector2(688,384)]:
		instance_prop(banner,"Umbul_%d_%d" % [p.x,p.y],p,objects)
	for p in [Vector2(348,376),Vector2(520,416),Vector2(560,176),Vector2(304,480),Vector2(624,512),Vector2(240,496),Vector2(720,456),Vector2(352,168),Vector2(640,176)]:
		instance_prop(lotus,"Teratai_%d_%d" % [p.x,p.y],p,terrain)
	var exploring := group("JalurEksplorasi")
	var names := ["JembatanBarat","TamanBaratLaut","TamanBarat","DermagaPenjaga","TamanTeratai","KebunSelatan","SimpangDesa","TamanTenggara","TepianTimur","BaleTimur","PanoramaAirTerjun","TamanTimurLaut","JembatanTimur"]
	for i in range(ROUTE.size()):
		add_waypoint(names[i],ROUTE[i],exploring)
		if i%2==0:
			instance_prop(road_lamp,"Penunjuk_%d" % i,ROUTE[i]+Vector2(-32,0),objects)
	# The viewing terrace leaves the walking path clear, next to a native animated cascade.
	var cascade := AnimatedSprite2D.new()
	cascade.name = "AirTerjun"
	cascade.position = Vector2(800,96)
	cascade.sprite_frames = SpriteFrames.new()
	cascade.sprite_frames.set_animation_speed("default",5)
	var falls: Texture2D = load("res://assets/farm_rpg/tileset/ext/Spring Waterfall.png")
	for i in range(8):
		var frame := AtlasTexture.new()
		frame.atlas=falls
		frame.region=Rect2(i*64,0,64,64)
		cascade.sprite_frames.add_frame("default",frame)
	cascade.autoplay="default"
	own(cascade,terrain)
	add_waypoint("TitikPandangAirTerjun",Vector2(864,96),exploring)
	add_waypoint("BaleTamanBarat",Vector2(-40,424),exploring)
	add_waypoint("BaleTamanSelatan",Vector2(176,688),exploring)
	var nature := group("Vegetasi",objects)
	nature.y_sort_enabled = true
	var tree_paths := ["res://assets/farm_rpg/objects/tree/Mahogany Tree Animation.png","res://assets/farm_rpg/objects/tree/Maple Tree Animation.png","res://assets/farm_rpg/objects/tree/Birch Tree Animation.png"]
	var occupied: Dictionary = {}
	var trees := tree_layer("Pohon",tree_paths,nature)
	for y in range(CELLS.position.y+1,CELLS.end.y-1,2):
		for x in range(CELLS.position.x+1,CELLS.end.x-1,2):
			var cell := Vector2i(x,y)
			if not land.has(cell) or reserved.has(cell) or rng.randi_range(0,3)==0: continue
			if x>12 and x<43 and y<35: continue
			var clear := true
			for off in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				if reserved.has(cell+off) or not land.has(cell+off): clear=false
			if not clear: continue
			# Same rng call order as the node version, so the forest layout is unchanged.
			var jitter := rng.randi_range(4,12)-4
			trees.set_cell(cell,rng.randi_range(0,2),TREE_REGION.position/TREE_REGION.size,jitter)
			occupied[cell]=true
	for cell: Vector2i in land:
		if reserved.has(cell) or occupied.has(cell) or rng.randi_range(0,12)!=0: continue
		var p := Vector2(cell*16)+Vector2(8,8)
		if rng.randi_range(0,2)==0:
			sprite("Semak_%d_%d" % [cell.x,cell.y],"res://assets/farm_rpg/tileset/ext/bushes.png",p-Vector2(0,8),Rect2(48,0,48,32),Vector2.ONE,nature)
		else:
			sprite("Bunga_%d_%d" % [cell.x,cell.y],"res://assets/farm_rpg/tileset/ext/ALL props 2.png",p-Vector2(0,8),Rect2(rng.randi_range(0,6)*16,0,16,32),Vector2.ONE,nature)
	instance_prop(load("res://scenes/world/balai_nadi/props/bale_istirahat2.tscn"),"BaleIstirahat",Vector2(897,46),objects)
	# One body for lake and world edges; row runs with the same span merge into taller rectangles.
	var blocking := StaticBody2D.new()
	blocking.name = "CollisionAirDanBatas"
	own(blocking,courtyard)
	var open: Dictionary = {}
	var water_rects: Array[Rect2i] = []
	for y in range(CELLS.position.y,CELLS.end.y+1):
		var row: Dictionary = {}
		if y < CELLS.end.y:
			var start := CELLS.position.x-1
			for x in range(CELLS.position.x,CELLS.end.x+1):
				if x<CELLS.end.x and not walkable.has(Vector2i(x,y)):
					if start < CELLS.position.x: start=x
				elif start >= CELLS.position.x:
					row[Vector2i(start,x)] = true
					start=CELLS.position.x-1
		for span: Vector2i in open.keys():
			if row.has(span): continue
			water_rects.append(Rect2i(span.x,open[span],span.y-span.x,y-open[span]))
			open.erase(span)
		for span: Vector2i in row:
			if not open.has(span): open[span] = y
	for r in water_rects:
		blocker("Air_%d_%d" % [r.position.x,r.position.y],(Vector2(r.position)+Vector2(r.size)/2.0)*16,Vector2(r.size*16),blocking)
	blocker("BatasUtara",Vector2(WORLD.get_center().x,WORLD.position.y-4),Vector2(WORLD.size.x,8),blocking)
	blocker("BatasSelatan",Vector2(WORLD.get_center().x,WORLD.end.y+4),Vector2(WORLD.size.x,8),blocking)
	blocker("BatasBarat",Vector2(WORLD.position.x-4,WORLD.get_center().y),Vector2(8,WORLD.size.y),blocking)
	blocker("BatasTimur",Vector2(WORLD.end.x+4,WORLD.get_center().y),Vector2(8,WORLD.size.y),blocking)
	rect_body("Building",Vector2(427,190),Vector2(156,80),courtyard)
	var interaction: Script = load("res://scripts/world/balai_nadi_interactable.gd")
	for spec in [["Entrance",Vector2(427,239),"res://scenes/world/balai_nadi/interior.tscn",Vector2(427,296)],["ReturnWorld",Vector2(427,840),"res://scenes/world/town.tscn",Vector2(331,52)]]:
		var area := Area2D.new()
		area.name=spec[0]
		area.position=spec[1]
		area.set_script(interaction)
		area.set("interaction_type",1)
		area.set("target_scene",spec[2])
		area.set("spawn_position",spec[3])
		own(area,courtyard)
		var shape := CollisionShape2D.new()
		shape.name="CollisionShape2D"
		var box := RectangleShape2D.new()
		box.size=Vector2(36,44)
		shape.shape=box
		own(shape,area)
	var visual := group("RestorationVisual")
	visual.set_script(load("res://scripts/world/balai_nadi_visual.gd"))
	var unrestored := group("Unrestored",visual)
	var restored := group("Restored",visual)
	restored.visible=false
	for p in [Vector2(360,256),Vector2(496,256),Vector2(368,304)]:
		sprite("PapanRusak_%d" % p.x,"res://assets/farm_rpg/tileset/ext/Old planks.png",p,Rect2(0,0,32,32),Vector2.ONE,unrestored)
	for p in [Vector2(352,296),Vector2(504,296)]:
		instance_prop(offering,"Persembahan_%d" % p.x,p,restored)
	var particles := CPUParticles2D.new()
	particles.name="PijarDaya"
	particles.position=Vector2(427,277)
	particles.amount=12
	particles.lifetime=7
	particles.preprocess=3
	particles.emission_shape=CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents=Vector2(104,48)
	particles.direction=Vector2(0,-1)
	particles.spread=45
	particles.gravity=Vector2.ZERO
	particles.initial_velocity_min=2
	particles.initial_velocity_max=3
	particles.color=Color(0.5,1,0.86,0.7)
	own(particles,restored)
	var player: Node2D = load("res://scenes/player/Player.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	player.name="Player"
	player.position=Vector2(427,795)
	own(player,courtyard)
	add_waypoint("spawn",Vector2(427,795),courtyard)
	var sign := Label.new()
	sign.name="ArahDesa"
	sign.position=Vector2(397,860)
	sign.text="↓ DESA"
	sign.add_theme_font_override("font",load("res://assets/fonts/m5x7.ttf"))
	sign.add_theme_font_size_override("font_size",16)
	own(sign,courtyard)
	keep_painted_layers()
	courtyard.set_meta("walkable_cells",walkable.keys())
	var packed := PackedScene.new()
	var result := packed.pack(courtyard)
	if result==OK: result=ResourceSaver.save(packed,OUT)
	if result==OK: ResourceSaver.set_uid(OUT,ResourceUID.text_to_id("uid://c5tsfm4qrkbui"))
	print("BAKE BALAI V3: ",result,"; nodes=",courtyard.find_children("*","",true,false).size(),"; walkable=",walkable.size(),"; trails=",paths.size())
	courtyard.free()
	quit(result)
