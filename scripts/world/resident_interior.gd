extends "res://scripts/world/town_interior.gd"

@export var resident_id := "wira"

func _build_service() -> void:
	# A shared living corner, with the work area on the opposite side.
	_furniture("Bed", "res://scenes/world/interior/objects/Beds.png", Rect2(0, 0, 32, 48), Vector2(390, 90), Vector2(24, 32))
	_furniture("Wardrobe", "res://assets/farm_rpg/objects/interior/Closet.png", Rect2(0, 0, 32, 48), Vector2(438, 90), Vector2(26, 30))
	var rug := Polygon2D.new()
	rug.name = "DiningRug"
	rug.polygon = PackedVector2Array([Vector2(264, 106), Vector2(348, 106), Vector2(348, 178), Vector2(264, 178)])
	rug.color = Color("b16c47") if resident_id == "wira" else Color("5f91a0")
	rug.z_index = -2
	add_child(rug)
	_furniture("Chair", "res://assets/farm_rpg/objects/interior/Chairs.png", Rect2(146, 15, 11, 16), Vector2(306, 158), Vector2(10, 8))
	_furniture("Table", "res://assets/farm_rpg/objects/interior/Tables and desks.png", Rect2(224, 224, 64, 32), Vector2(306, 130), Vector2(60, 24))
	_furniture("WorkCounter", "res://assets/farm_rpg/objects/interior/Tables and desks.png", Rect2(136, 192, 48, 32), Vector2(128, 112), Vector2(44, 24))
	var label := Label.new()
	label.position = Vector2(72, 62)
	label.add_theme_font_override("font", FONT)
	label.text = "Bengkel · Bangunan / Upgrade" if resident_id == "wira" else "Pos Pengiriman · Koperasi"
	add_child(label)
	if resident_id == "ubay":
		for index in 3:
			_furniture("Parcel%d" % index, "res://assets/farm_rpg/objects/exterior/shipping box.png", Rect2(0, 16, 16, 16), Vector2(78 + index * 24, 198), Vector2(14, 13))
	else:
		for index in 3:
			_furniture("Timber%d" % index, "res://assets/farm_rpg/objects/exterior/Fence and Bridge/Fence Wood.png", Rect2(0, 0, 16, 16), Vector2(72 + index * 16, 198), Vector2(16, 12))

func _furniture(node_name: String, path: String, region: Rect2, pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = node_name
	body.position = pos
	var art := Sprite2D.new()
	art.texture = load(path)
	art.region_enabled = true
	art.region_rect = region
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.add_child(art)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
