class_name SkyFX
extends Node2D

## Efek langit area luar: bayangan awan yang melintas di tanah, dan penanda bagi
## weather_view.gd agar layar pemain di area ini menampilkan berkas sinar matahari.
## Taruh sebagai anak langsung root scene dengan nama "SkyFX", lalu atur di Inspector.
## Keduanya mengikuti jam (hilang saat malam) dan disembunyikan saat hujan/badai.

const NODE_NAME := "SkyFX"
const CLOUD_SHADER := preload("res://shaders/cloud_shadow.gdshader")
const CLOUD_Z := 90

## Pengali kekuatan berkas sinar (hill/puncak boleh lebih kuat). 0 = tanpa berkas.
@export_range(0.0, 3.0, 0.05) var ray_strength := 1.0
@export var clouds_enabled := true
@export_range(0.0, 1.0, 0.05) var cloud_coverage := 0.45
@export_range(0.0, 1.0, 0.05) var cloud_darkness := 0.25
@export var wind := Vector2(14.0, 5.0)
## Kecil = awan besar.
@export var cloud_scale := 0.0016
## Area yang diberi bayangan (world). Kosong = gabungan semua TileMapLayer di scene.
@export var area := Rect2()
## Bayangan mulai tampak dari world y x dan penuh di y (untuk scene dengan langit di atas).
@export var fade_y := Vector2.ZERO

static var _noise: NoiseTexture2D

var _clouds: ColorRect
var _material: ShaderMaterial

## SkyFX milik area tempat [param world] berada, atau null (interior, gua, dll).
static func of_world(world: Node) -> SkyFX:
	if not is_instance_valid(world):
		return null
	return world.get_node_or_null(NodePath(NODE_NAME)) as SkyFX

## 0 saat malam, 1 saat matahari tinggi.
static func sun_factor() -> float:
	var h := DayCycle.hour + DayCycle.minute / 60.0
	return smoothstep(5.5, 7.5, h) * (1.0 - smoothstep(16.5, 18.5, h))

## 1 saat pagi dan sore (cahaya keemasan), 0 saat siang.
static func golden_factor() -> float:
	var h := DayCycle.hour + DayCycle.minute / 60.0
	return maxf(1.0 - smoothstep(6.5, 8.5, h), smoothstep(14.5, 17.5, h))

static func is_overcast() -> bool:
	return GameState.weather != null and GameState.weather.is_raining()

func _ready() -> void:
	if not clouds_enabled:
		return
	_material = ShaderMaterial.new()
	_material.shader = CLOUD_SHADER
	_material.set_shader_parameter("noise", _shared_noise())
	_material.set_shader_parameter("coverage", cloud_coverage)
	_material.set_shader_parameter("wind", wind)
	_material.set_shader_parameter("scale", cloud_scale)
	_material.set_shader_parameter("fade_y", fade_y)
	_clouds = ColorRect.new()
	_clouds.name = "CloudShadow"
	_clouds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clouds.material = _material
	_clouds.z_index = CLOUD_Z
	_clouds.z_as_relative = false
	var rect := area if area.has_area() else _tile_bounds().grow(32.0)
	_clouds.position = rect.position
	_clouds.size = rect.size
	add_child(_clouds)
	_update()

func _process(_delta: float) -> void:
	_update()

func _update() -> void:
	if _clouds == null:
		return
	var strength := 0.0 if is_overcast() else sun_factor()
	_clouds.visible = strength > 0.0
	_material.set_shader_parameter("darkness", cloud_darkness * strength)

func _tile_bounds() -> Rect2:
	var bounds := Rect2()
	var parent := get_parent()
	if parent == null:
		return bounds
	for layer in parent.get_children():
		if not layer is TileMapLayer or layer.tile_set == null:
			continue
		var used: Rect2i = layer.get_used_rect()
		if not used.has_area():
			continue
		var tile := Vector2(layer.tile_set.tile_size)
		var rect := Rect2(layer.position + Vector2(used.position) * tile, Vector2(used.size) * tile)
		bounds = rect if not bounds.has_area() else bounds.merge(rect)
	return bounds

static func _shared_noise() -> NoiseTexture2D:
	if _noise == null:
		var source := FastNoiseLite.new()
		source.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		source.frequency = 0.012
		source.fractal_octaves = 3
		_noise = NoiseTexture2D.new()
		_noise.width = 256
		_noise.height = 256
		_noise.seamless = true
		_noise.noise = source
	return _noise
