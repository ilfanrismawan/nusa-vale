extends Node2D
## Separate playable rooms, configured with a constructed building's stable session UID.
@export_enum("barn", "chicken_coop") var housing := "barn"
@export var ranch_uid := 0
const ROOM := Rect2(251, 128, 352, 224)
const FONT = preload("res://assets/fonts/m5x7.ttf")
const TILES = preload("res://assets/farm_rpg/tileset/ext/Barn tileset.png")
const FLOOR = preload("res://assets/farm_rpg/tileset/int/Tileset House.png")
var _decor: Node2D
var _herd: Node2D
var _dirt: Node2D
var _status: Label
var _tier := -1
var _spots: Array[Dictionary] = []

func configure_ranch(uid: int) -> void:
	ranch_uid = uid

func _ready() -> void:
	y_sort_enabled = true
	if ranch_uid == 0:
		ranch_uid = StructureManager.solo_ranch_uid
	set_meta("ranch_uid", ranch_uid)
	set_meta("farm_area", "ranch")
	_build_floor()
	_build_bounds()
	_decor = Node2D.new()
	_decor.name = "Furniture"
	_decor.z_index = -5
	add_child(_decor)
	_dirt = Node2D.new()
	_dirt.name = "Dirt"
	_dirt.z_index = -4
	add_child(_dirt)
	_herd = Node2D.new()
	_herd.name = "Animals"
	_herd.y_sort_enabled = true
	# The herd is a separate sibling from the player, so y-sort cannot order
	# them against the character. Keep animal sprites behind the player.
	_herd.z_index = -1
	_herd.set_meta("world", weakref(self))
	add_child(_herd)
	_status = _label(self, "", Vector2(270, 130), 12)
	_status.z_index = 10
	StructureManager.changed.connect(_refresh)
	SaveManager.game_loaded.connect(_refresh)
	_refresh()
	DayCycle.is_running = true
	for candidate in find_children("*", "CharacterBody2D", true, false):
		if candidate is Player:
			candidate.refresh_world()
			var camera := candidate.get_node_or_null("Camera2D") as Camera2D
			if camera != null and not Coop.has_root():
				camera.set_default_zoom(2.0)
				camera.reset_smoothing()

func _build_floor() -> void:
	var layer := TileMapLayer.new()
	layer.name = "BaseLayerGround"
	layer.z_index = -10
	layer.position = ROOM.position
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(16, 16)
	tiles.add_custom_data_layer()
	tiles.set_custom_data_layer_name(0, "farmable")
	tiles.set_custom_data_layer_type(0, TYPE_BOOL)
	var source := TileSetAtlasSource.new()
	source.texture = TILES
	source.texture_region_size = Vector2i(16, 16)
	for cell in [Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(1, 6), Vector2i(2, 6), Vector2i(1, 7), Vector2i(2, 7)]:
		source.create_tile(cell)
	tiles.add_source(source, 0)
	var floor_texture := AtlasTexture.new()
	floor_texture.atlas = FLOOR
	floor_texture.region = Rect2(272, 16, 16, 16)
	var floor_source := TileSetAtlasSource.new()
	floor_source.texture = floor_texture
	floor_source.texture_region_size = Vector2i(16, 16)
	floor_source.create_tile(Vector2i.ZERO)
	tiles.add_source(floor_source, 1)
	var wall_texture := AtlasTexture.new()
	wall_texture.atlas = FLOOR
	wall_texture.region = Rect2(256, 0, 16, 16)
	var wall_source := TileSetAtlasSource.new()
	wall_source.texture = wall_texture
	wall_source.texture_region_size = Vector2i(16, 16)
	wall_source.create_tile(Vector2i.ZERO)
	tiles.add_source(wall_source, 2)
	layer.tile_set = tiles
	for y in 14:
		for x in 22:
			if y < 2:
				layer.set_cell(Vector2i(x, y), 2, Vector2i.ZERO)
			else:
				layer.set_cell(Vector2i(x, y), 1, Vector2i.ZERO)
	add_child(layer)

func _build_bounds() -> void:
	var body := StaticBody2D.new()
	body.name = "Bounds"
	add_child(body)
	for rect in [Rect2(251, 128, 352, 34), Rect2(247, 128, 8, 224), Rect2(599, 128, 8, 224), Rect2(251, 348, 158, 8), Rect2(445, 348, 158, 8), Rect2(403, 175, 48, 10), Rect2(262, 169, 32, 17), Rect2(553, 168, 28, 14)]:
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		collision.shape = shape
		collision.position = rect.get_center()
		body.add_child(collision)
	var exit := Area2D.new()
	exit.name = "Exit"
	exit.position = Vector2(427, 347)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(30, 12)
	collision.shape = shape
	exit.add_child(collision)
	exit.body_entered.connect(func(body: Node2D):
		if body is Player and not body.is_input_locked():
			StructureManager.leave_ranch(body))
	add_child(exit)

func _label(parent: Node, text: String, pos: Vector2, size: int = 12) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("fff1c9"))
	label.add_theme_color_override("font_outline_color", Color("50332b"))
	label.add_theme_constant_override("outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _prop(texture: Texture2D, pos: Vector2, region: Rect2 = Rect2()) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = pos
	if region.size != Vector2.ZERO:
		sprite.region_enabled = true
		sprite.region_rect = region
	_decor.add_child(sprite)

func _rail(rect: Rect2, color: Color) -> void:
	var polygon := Polygon2D.new()
	polygon.polygon = PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)])
	polygon.color = color
	_decor.add_child(polygon)

func pen_center(slot: int) -> Vector2:
	var row := slot / 4
	var column := slot % 4
	return Vector2([299, 347, 507, 555][column], 214 + row * 42)

func _build_decor(state: Dictionary) -> void:
	for child in _decor.get_children():
		_decor.remove_child(child)
		child.queue_free()
	_spots.clear()
	for x in [334, 520]:
		_prop(preload("res://assets/farm_rpg/objects/exterior/Houses/Farm Buildings/Barn/Window.png"), Vector2(x, 147), Rect2(0, 0, 48, 32))
	for x in [392, 462]:
		_prop(preload("res://assets/farm_rpg/objects/exterior/Houses/Farm Buildings/Barn/Lamp.png"), Vector2(x, 146), Rect2(0, 0, 16, 32))
	_prop(preload("res://assets/ranch/care_board.svg"), Vector2(567, 177))
	_label(_decor, "Kelola", Vector2(550, 187))
	_spots.append({"position": Vector2(567, 195), "action": "menu"})
	_prop(preload("res://assets/farm_rpg/objects/exterior/Hay Bales.png"), Vector2(278, 178), Rect2(0, 0, 32, 16))
	_label(_decor, "Cadangan", Vector2(257, 188))
	_spots.append({"position": Vector2(278, 199), "action": "stock"})
	_prop(preload("res://assets/ranch/feeding_trough.svg"), Vector2(427, 180))
	_label(_decor, "Palung", Vector2(410, 187))
	_spots.append({"position": Vector2(427, 203), "action": "feed"})
	_prop(preload("res://assets/ranch/water_basin.svg"), Vector2(587, 308))
	_label(_decor, "Keluar", Vector2(446, 312))
	_spots.append({"position": Vector2(427, 339), "action": "exit"})
	for slot in RanchHusbandry.capacity(state):
		var center := pen_center(slot)
		_rail(Rect2(center - Vector2(23, 22), Vector2(46, 3)), Color("b58451"))
		_rail(Rect2(center - Vector2(23, 22), Vector2(3, 33)), Color("754b31"))
		var bedding := Sprite2D.new()
		bedding.texture = TILES
		bedding.region_enabled = true
		bedding.region_rect = Rect2(16, 96, 32, 32)
		bedding.position = center
		bedding.modulate = Color(1, 1, 1, 0.85)
		_decor.add_child(bedding)
		if housing == "chicken_coop":
			_prop(preload("res://assets/ranch/nesting_box.svg"), center + Vector2(0, -18))
	if housing == "chicken_coop":
		_label(_decor, "Sarang telur", Vector2(464, 168))
		_spots.append({"position": Vector2(499, 185), "action": "eggs"})
		_prop(preload("res://assets/ranch/nesting_box.svg"), Vector2(500, 174))
	_tier = int(state.tier)

func _refresh() -> void:
	var record := StructureManager.record_for(ranch_uid)
	if record.get("item") != housing:
		_status.text = "Kandang tidak tersedia. Pintu keluar tetap dapat digunakan."
		if _spots.is_empty():
			_spots.append({"position": Vector2(427, 339), "action": "exit"})
		return
	var state := StructureManager.coop_state(record)
	if int(state.tier) != _tier:
		_build_decor(state)
	var fed := 0
	var live := {}
	for index in state.chickens.size():
		var animal: Dictionary = state.chickens[index]
		fed += 1 if int(animal.fed_day) == DayCycle.current_day else 0
		var name := "Animal_%d" % int(animal.id)
		live[name] = true
		var actor := _herd.get_node_or_null(name)
		if actor == null:
			actor = load("res://scripts/world/ranch_animal.gd").new()
			actor.name = name
			actor.uid = ranch_uid
			actor.animal_id = int(animal.id)
			actor.indoors = true
			actor.home = pen_center(index)
			actor.roam_rect = Rect2(actor.home - Vector2(10, 6), Vector2(20, 12))
			_herd.add_child(actor)
		actor.refresh()
	for actor in _herd.get_children():
		if not live.has(str(actor.name)):
			_herd.remove_child(actor)
			actor.queue_free()
	_status.text = "%s · Kenyang %d/%d · Jerami %d · Kotor %d/3" % ["TERNAK" if housing == "barn" else "UNGGAS", fed, state.chickens.size(), int(state.hay), int(state.dirt)]
	_spots = _spots.filter(func(spot: Dictionary): return spot.action != "clean")
	for child in _dirt.get_children():
		_dirt.remove_child(child)
		child.queue_free()
	for index in int(state.dirt):
		var pos := Vector2(393, 225 + index * 40)
		var sprite := Sprite2D.new()
		sprite.texture = preload("res://assets/ranch/dirt.svg")
		sprite.position = pos
		_dirt.add_child(sprite)
		_spots.append({"position": pos, "action": "clean"})

func interact_ranch_near(player: Player) -> bool:
	var carried := player.get_meta("carried_animal") as Node if player.has_meta("carried_animal") else null
	if is_instance_valid(carried) and carried.has_method("place_from_player"):
		carried.place_from_player(player)
		return true
	var feet := player.global_position + Player.FEET_OFFSET
	for actor in _herd.get_children():
		if actor.visible and feet.distance_to(actor.global_position) < 22:
			actor.interact_with(player)
			return true
	var nearest := 30.0
	var selected := ""
	for spot in _spots:
		var distance := feet.distance_to(spot.position)
		if distance < nearest:
			nearest = distance
			selected = spot.action
	if selected.is_empty():
		return false
	var result: Dictionary = {}
	match selected:
		"exit": StructureManager.leave_ranch(player)
		"menu", "stock": StructureManager.open_ranch_menu(player, ranch_uid)
		"feed":
			var record := StructureManager.record_for(ranch_uid)
			if record.is_empty():
				return true
			result = StructureManager.feed_stored(ranch_uid) if int(StructureManager.coop_state(record).hay) > 0 else StructureManager.feed_chickens(player.data, ranch_uid)
		"eggs": result = StructureManager.collect_eggs(player.data, ranch_uid)
		"clean": result = StructureManager.clean_ranch(player.data, ranch_uid)
	if not result.is_empty():
		Notify.say(result.message)
	return true

