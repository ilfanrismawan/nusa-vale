extends Node2D

@export var room_title := "Rumah Warga"
@export_enum("house", "blacksmith", "warung", "shop", "clinic", "library") var service := "house"
const FLOOR = preload("res://assets/farm_rpg/tileset/int/Tileset House.png")
const FONT = preload("res://assets/fonts/m5x7.ttf")

func _ready() -> void:
	_build_room()
	_build_service()
	# Warga yang tinggal di sini (jadwal map = nama file scene) pulang-pergi lewat pintu.
	var residents := ResidentRoom.new()
	residents.map_id = scene_file_path.get_file().get_basename()
	add_child(residents)
	DayCycle.is_running = true
	for candidate in find_children("*", "CharacterBody2D", true, false):
		if candidate is Player:
			candidate.refresh_world()
			var camera := candidate.get_node_or_null("Camera2D") as Camera2D
			if camera != null and not Coop.has_root():
				camera.set_default_zoom(2.0)
				camera.reset_smoothing()

func _build_room() -> void:
	var ground := TileMapLayer.new()
	ground.name = "BaseLayerGround"
	ground.z_index = -10
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(16, 16)
	tiles.add_custom_data_layer()
	tiles.set_custom_data_layer_name(0, "farmable")
	tiles.set_custom_data_layer_type(0, TYPE_BOOL)
	for index in 2:
		var texture := AtlasTexture.new()
		texture.atlas = FLOOR
		texture.region = Rect2(272 if index == 0 else 256, 16 if index == 0 else 0, 16, 16)
		texture.filter_clip = true
		var source := TileSetAtlasSource.new()
		source.texture = texture
		source.texture_region_size = Vector2i(16, 16)
		source.create_tile(Vector2i.ZERO)
		tiles.add_source(source, index)
	ground.tile_set = tiles
	for x in 30:
		for y in 20:
			ground.set_cell(Vector2i(x, y), 1 if y < 3 else 0, Vector2i.ZERO)
	add_child(ground)
	var bounds := StaticBody2D.new()
	bounds.name = "Walls"
	add_child(bounds)
	for rect in [Rect2(0, 0, 480, 48), Rect2(-8, 0, 8, 320), Rect2(480, 0, 8, 320), Rect2(0, 304, 220, 16), Rect2(260, 304, 220, 16)]:
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		collision.shape = shape
		collision.position = rect.get_center()
		bounds.add_child(collision)
	var title := Label.new()
	title.text = room_title
	title.position = Vector2(24, 16)
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 16)
	add_child(title)
	var hint := Label.new()
	hint.text = "Keluar ↓"
	hint.position = Vector2(220, 280)
	hint.add_theme_font_override("font", FONT)
	add_child(hint)

func _build_service() -> void:
	if service == "blacksmith":
		# Rumah & bengkel Empu Bima: ia melayani upgrade di tungku luar pada jam kerja.
		_add_notice("Rumah dan bengkel Empu Bima. Upgrade alat dilayani di tungku depan, 08.00–17.00.")
	elif service == "warung":
		var kitchen := preload("res://scripts/world/kitchen_station.gd").new()
		kitchen.position = Vector2(240, 120)
		add_child(kitchen)
	elif service == "shop":
		var counter := preload("res://scenes/world/exterior/object/ShopCounter.tscn").instantiate()
		counter.position = Vector2(240, 112)
		add_child(counter)
	elif service == "library":
		# Buku riset Role & EXP (GDD 13.1) dijual di meja pustakawan.
		var desk := preload("res://scenes/world/exterior/object/ShopCounter.tscn").instantiate()
		desk.shop_data = preload("res://resources/shop/library_books.tres")
		desk.position = Vector2(240, 112)
		add_child(desk)
	else:
		_add_notice("Selamat datang di " + room_title + ".")
	if service == "library":
		_add_notice("Perpustakaan buka " + ServiceHours.hours_text("library") + ".", Vector2(360, 104))
	elif service == "warung":
		_add_notice("Warung Rasa Nusa buka " + ServiceHours.hours_text("warung") + ". Joko melayani di depan.", Vector2(360, 104))

func _add_notice(text: String, at: Vector2 = Vector2(240, 104)) -> void:
	var notice := preload("res://scripts/world/school_notice.gd").new()
	notice.position = at
	notice.message = text
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(48, 24)
	shape.shape = rectangle
	notice.add_child(shape)
	var furniture := Sprite2D.new()
	furniture.texture = preload("res://assets/ranch/care_board.png")
	notice.add_child(furniture)
	add_child(notice)
