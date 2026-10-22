@tool
extends Node2D

## Kolam pancing yang tidak membeku di Musim Dingin (GDD 5): kolam air panas Gunung
## dan danau bawah tanah Gua Tambang. Dibangun dari kode: tepi kolam memakai ubin animasi
## "Water Ground animations tiles.png", isi kolam memakai warna Water tile.png,
## lalu FishingSpot (freezes_in_winter = false) dan tabrakan supaya pemain tidak masuk air.
## Berjalan juga di editor (@tool) supaya kolam terlihat dan ikut berubah saat properti diubah.
## Bagian buatan kode tidak tersimpan ke .tscn; node anak yang ditambah sendiri tidak dihapus.

const RIM_TEXTURE := preload("res://assets/farm_rpg/tileset/ext/Water Ground animations tiles.png")
const WATER_COLOR := Color8(0, 146, 221)
const TILE := 16
## Ubin kolam 3x3 di atlas (kolom 13-15, baris 0-2); 4 frame animasi ke bawah tiap 4 baris.
const RIM_ORIGIN := Vector2i(13, 0)
const RIM_FRAMES := 4
const RIM_FRAME_TIME := 0.3
## Isi kolam ditimpa warna air mulai jarak ini dari tepi (menutupi titik batu di ubin tepi).
const WATER_INSET := 9.0

## Ukuran kolam dalam tile (minimal 3x3).
@export var size_tiles: Vector2i = Vector2i(8, 6):
	set(value):
		size_tiles = value
		_rebuild_if_ready()
@export var location_id: String = "mountain_hot_spring":
	set(value):
		location_id = value
		_rebuild_if_ready()
## Uap hangat di atas air (kolam air panas).
@export var steam: bool = true:
	set(value):
		steam = value
		_rebuild_if_ready()
@export var tint: Color = Color.WHITE:
	set(value):
		tint = value
		_rebuild_if_ready()

const GENERATED := &"winter_pond_generated"

func _ready() -> void:
	build()

func _rebuild_if_ready() -> void:
	if is_node_ready():
		build()

func build() -> void:
	for child in get_children():
		if child.has_meta(GENERATED):
			remove_child(child)
			child.queue_free()
	var size := Vector2i(maxi(size_tiles.x, 3), maxi(size_tiles.y, 3))
	var pixel_size := Vector2(size * TILE)
	modulate = tint
	_build_rim(size)
	var water := ColorRect.new()
	water.name = "Water"
	water.color = WATER_COLOR
	water.position = Vector2(WATER_INSET, WATER_INSET)
	water.size = pixel_size - Vector2(WATER_INSET, WATER_INSET) * 2.0
	water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	water.z_index = -8
	water.z_as_relative = false
	_add_generated(water)
	_add_body(pixel_size)
	_add_spot(pixel_size)
	if steam:
		_add_steam(pixel_size)

func _build_rim(size: Vector2i) -> void:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(TILE, TILE)
	var source := TileSetAtlasSource.new()
	source.texture = RIM_TEXTURE
	source.texture_region_size = Vector2i(TILE, TILE)
	tiles.add_source(source, 0)
	var rim := TileMapLayer.new()
	rim.name = "Rim"
	rim.z_index = -9
	rim.z_as_relative = false
	rim.tile_set = tiles
	_add_generated(rim)
	for x in size.x:
		for y in size.y:
			var col := 0 if x == 0 else (2 if x == size.x - 1 else 1)
			var row := 0 if y == 0 else (2 if y == size.y - 1 else 1)
			if col == 1 and row == 1:
				continue
			var atlas := RIM_ORIGIN + Vector2i(col, row)
			if not source.has_tile(atlas):
				source.create_tile(atlas)
				source.set_tile_animation_columns(atlas, 1)
				source.set_tile_animation_separation(atlas, Vector2i(0, 3))
				source.set_tile_animation_frames_count(atlas, RIM_FRAMES)
				for frame in RIM_FRAMES:
					source.set_tile_animation_frame_duration(atlas, frame, RIM_FRAME_TIME)
			rim.set_cell(Vector2i(x, y), 0, atlas)

## Pemain berhenti di bibir kolam.
func _add_body(pixel_size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = "Edge"
	_add_generated(body)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = pixel_size - Vector2(8, 8)
	shape.shape = box
	shape.position = pixel_size * 0.5
	body.add_child(shape)

func _add_spot(pixel_size: Vector2) -> void:
	var spot := FishingSpot.new()
	spot.name = "FishingSpot"
	spot.location_id = location_id
	spot.freezes_in_winter = false
	_add_generated(spot)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = pixel_size - Vector2(10, 10)
	shape.shape = box
	shape.position = pixel_size * 0.5
	spot.add_child(shape)

func _add_steam(pixel_size: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.name = "Steam"
	particles.position = pixel_size * 0.5
	particles.z_index = 5
	particles.amount = int(clampf(pixel_size.x * pixel_size.y / 400.0, 8.0, 40.0))
	particles.lifetime = 2.4
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = pixel_size * 0.5 - Vector2(WATER_INSET, WATER_INSET)
	particles.direction = Vector2.UP
	particles.spread = 15.0
	particles.gravity = Vector2(0, -6)
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 9.0
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.5
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	fade.add_point(0.25, Color(1, 1, 1, 0.45))
	particles.color_ramp = fade
	_add_generated(particles)

func _add_generated(node: Node) -> void:
	node.set_meta(GENERATED, true)
	add_child(node)
