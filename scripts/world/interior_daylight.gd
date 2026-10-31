class_name InteriorDaylight
extends Node
## Suasana interior mengikuti jam: siang terang oleh cahaya jendela, malam redup diterangi lampu.
## Nilai yang disusun di editor (warna CanvasModulate, energi lampu, vignette) = tampilan MALAM.
## Siang hari node ini mencerahkan ruangan ke `day_room_color`, menguatkan cahaya jendela,
## meredupkan lampu, menampilkan berkas sinar matahari dan menipiskan vignette.
## Taruh satu node ini di scene interior. Daftar kosong = dicari otomatis (lihat `auto_detect`).

## Ruangan terang penuh mulai/sampai jam ini; di luarnya memudar ke malam dalam `fade_hours`.
@export_range(0.0, 24.0, 0.25) var day_start := 7.0
@export_range(0.0, 24.0, 0.25) var day_end := 16.0
@export_range(0.25, 4.0, 0.25) var fade_hours := 2.0

@export_group("Ruangan")
## CanvasModulate ruangan; kosong = CanvasModulate pertama di scene.
@export var room_modulate: NodePath
@export var day_room_color := Color(1.0, 0.97, 0.92)

@export_group("Jendela")
## PointLight2D di jendela. Siang memakai warna & energi matahari di bawah ini.
@export var window_lights: Array[NodePath] = []
@export var day_window_color := Color(1.0, 0.94, 0.8)
@export var day_window_energy := 0.85
## Berkas sinar (ColorRect light_shaft) yang hanya tampak siang hari.
@export var sun_shafts: Array[NodePath] = []

@export_group("Lampu")
## Lampu/lilin/tungku: siang energinya dikali `day_lamp_factor`.
@export var lamps: Array[NodePath] = []
@export_range(0.0, 1.0, 0.05) var day_lamp_factor := 0.3

@export_group("Vignette")
@export var vignette: NodePath
@export_range(0.0, 1.0, 0.05) var day_vignette_factor := 0.4

@export_group("")
## Isi otomatis daftar yang kosong: PointLight2D bernama "Jendela"/"Window" = jendela,
## PointLight2D lain = lampu, ColorRect ber-shader light_shaft = berkas sinar,
## ColorRect ber-shader room_vignette = vignette.
@export var auto_detect := true

const META_BASE := &"day_tint_base"

var _modulate: CanvasModulate
var _night_color := Color.WHITE
var _windows: Array[PointLight2D] = []
var _lamps: Array[PointLight2D] = []
var _shafts: Array[CanvasItem] = []
var _vignette_material: ShaderMaterial
var _night_vignette := 0.0
## Nilai malam (dari editor) per lampu: [warna, energi].
var _night_lights := {}
var _last_factor := -1.0


func _ready() -> void:
	var root := owner if owner != null else get_parent()
	_modulate = get_node_or_null(room_modulate) as CanvasModulate
	if _modulate == null:
		_modulate = _first(root, "CanvasModulate") as CanvasModulate
	if _modulate != null:
		_night_color = _modulate.get_meta(META_BASE, _modulate.color)
	_windows = _lights(window_lights)
	_lamps = _lights(lamps)
	for path in sun_shafts:
		var shaft := get_node_or_null(path) as CanvasItem
		if shaft != null:
			_shafts.append(shaft)
	var vignette_rect := get_node_or_null(vignette) as CanvasItem
	if auto_detect:
		var found := _detect(root)
		if vignette_rect == null:
			vignette_rect = found
	if vignette_rect != null and vignette_rect.material is ShaderMaterial:
		# Duplikat agar scene lain yang berbagi material tidak ikut berubah.
		_vignette_material = vignette_rect.material.duplicate()
		vignette_rect.material = _vignette_material
		_night_vignette = float(_vignette_material.get_shader_parameter("strength"))
	for light in _windows + _lamps:
		_night_lights[light] = [light.color, light.energy]
	_apply(daylight())


func _process(_delta: float) -> void:
	var factor := daylight()
	if not is_equal_approx(factor, _last_factor):
		_apply(factor)


## 0 = malam, 1 = siang penuh, dengan peralihan pagi/sore.
func daylight() -> float:
	var time := DayCycle.hour + DayCycle.minute / 60.0
	return smoothstep(day_start - fade_hours, day_start, time) * (1.0 - smoothstep(day_end, day_end + fade_hours, time))


func _apply(factor: float) -> void:
	_last_factor = factor
	if is_instance_valid(_modulate):
		# DayCycle mengalikan warna dasar ini dengan tint waktu setiap frame.
		_modulate.set_meta(META_BASE, _night_color.lerp(day_room_color, factor))
	for light in _windows:
		if is_instance_valid(light):
			light.color = (_night_lights[light][0] as Color).lerp(day_window_color, factor)
			light.energy = lerpf(_night_lights[light][1], day_window_energy, factor)
	for light in _lamps:
		if is_instance_valid(light):
			light.energy = float(_night_lights[light][1]) * lerpf(1.0, day_lamp_factor, factor)
	for shaft in _shafts:
		if is_instance_valid(shaft):
			shaft.visible = factor > 0.01
			shaft.modulate.a = factor
	if _vignette_material != null:
		_vignette_material.set_shader_parameter("strength", _night_vignette * lerpf(1.0, day_vignette_factor, factor))


## Lengkapi daftar yang kosong dari isi scene; mengembalikan ColorRect vignette (jika ada).
func _detect(root: Node) -> CanvasItem:
	var vignette_rect: CanvasItem = null
	for light: PointLight2D in root.find_children("*", "PointLight2D", true, false):
		if light in _windows or light in _lamps:
			continue
		var is_window := light.name.containsn("jendela") or light.name.containsn("window")
		if is_window and window_lights.is_empty():
			_windows.append(light)
		elif not is_window and lamps.is_empty():
			_lamps.append(light)
	for rect: ColorRect in root.find_children("*", "ColorRect", true, false):
		var material := rect.material as ShaderMaterial
		if material == null or material.shader == null:
			continue
		var shader_path := material.shader.resource_path
		if shader_path.ends_with("light_shaft.gdshader") and sun_shafts.is_empty():
			_shafts.append(rect)
		elif shader_path.ends_with("room_vignette.gdshader") and vignette_rect == null:
			vignette_rect = rect
	return vignette_rect


func _lights(paths: Array[NodePath]) -> Array[PointLight2D]:
	var result: Array[PointLight2D] = []
	for path in paths:
		var light := get_node_or_null(path) as PointLight2D
		if light != null:
			result.append(light)
	return result


func _first(root: Node, type: String) -> Node:
	var found := root.find_children("*", type, true, false)
	return found[0] if not found.is_empty() else null
