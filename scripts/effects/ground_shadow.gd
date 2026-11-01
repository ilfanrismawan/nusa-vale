extends Node2D
## Bayangan oval di kaki karakter/hewan supaya terlihat menapak di tanah (seperti Stardew).
## Dipakai lewat preload: GroundShadow.attach(node, radius). Titik asal node = kaki.
## lift > 0 (lompat, terbang, kendaraan melayang): bayangan tetap di tanah, mengecil dan memudar.

const DEFAULT_RADIUS := 6.0
const ALPHA := 0.28
## Elips: tinggi = lebar x SQUASH.
const SQUASH := 0.45

var radius := DEFAULT_RADIUS:
	set(value):
		radius = value
		queue_redraw()
var lift := 0.0:
	set(value):
		lift = value
		queue_redraw()


## Pasang bayangan sebagai anak pertama `parent` (digambar di bawah sprite), di titik `at`.
static func attach(parent: Node2D, p_radius: float = DEFAULT_RADIUS, at: Vector2 = Vector2.ZERO) -> Node2D:
	var shadow: Node2D = load("res://scripts/effects/ground_shadow.gd").new()
	shadow.name = "GroundShadow"
	shadow.radius = p_radius
	shadow.position = at
	parent.add_child(shadow)
	parent.move_child(shadow, 0)
	return shadow


## Cache baris bawah piksel terlihat per tekstur/region (gambar hanya dibaca sekali).
static var _bottom_cache: Dictionary = {}


## Baris di bawah piksel tak-transparan terbawah tekstur (0..tinggi), atau -1 bila tak terbaca.
static func visible_bottom(texture: Texture2D) -> int:
	if texture == null:
		return -1
	var key: String = texture.resource_path
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		key = "%s|%s" % [atlas.atlas.resource_path if atlas.atlas != null else "", atlas.region]
	if not key.is_empty() and _bottom_cache.has(key):
		return _bottom_cache[key]
	var image := texture.get_image()
	var bottom := -1
	if image != null:
		if image.is_compressed():
			image.decompress()
		var used := image.get_used_rect()
		bottom = used.end.y if used.size.y > 0 else -1
	if not key.is_empty():
		_bottom_cache[key] = bottom
	return bottom


## Geser offset Y sprite (Sprite2D / AnimatedSprite2D) supaya kaki tepat di titik asal induknya,
## dibenamkan `sink` px. `texture` = frame acuan (idle). false bila tekstur tak terbaca.
static func align_feet(sprite: Node2D, texture: Texture2D, sink: float = 1.0) -> bool:
	var bottom := visible_bottom(texture)
	if bottom < 0:
		return false
	var centered: bool = sprite.get("centered")
	var offset: Vector2 = sprite.get("offset")
	var top := sprite.position.y + offset.y * sprite.scale.y - (texture.get_height() * 0.5 * sprite.scale.y if centered else 0.0)
	var feet := top + bottom * sprite.scale.y
	offset.y += (sink - feet) / sprite.scale.y
	sprite.set("offset", offset)
	return true


func _draw() -> void:
	var scale_by := clampf(1.0 - lift / 30.0, 0.55, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, SQUASH))
	draw_circle(Vector2.ZERO, radius * scale_by, Color(0, 0, 0, ALPHA * scale_by))
