extends TileMapLayer
class_name TileLanternLights
## Pasang ke TileMapLayer jembatan. Setiap tile yang punya custom data bool
## `light` = true diberi PointLight2D hangat yang menyala saat malam
## (DayCycle.night_intensity() > 0), sama seperti lampu dekorasi.
## Cahaya ikut terdeteksi NightHorror sebagai cahaya aman.

@export var custom_data_name: String = "light"
## Posisi cahaya relatif ke tengah tile (mis. naik sedikit ke kaca lentera).
@export var light_offset: Vector2 = Vector2(0, -4)
@export var light_color: Color = Color(1.0, 0.78, 0.4)
@export var base_energy: float = 0.7
@export var flicker_amount: float = 0.08
@export var texture_scale: float = 1.0

var _lights: Array[PointLight2D] = []


func _ready() -> void:
	rebuild_lights()


func rebuild_lights() -> void:
	for light in _lights:
		light.queue_free()
	_lights.clear()
	if tile_set == null or tile_set.get_custom_data_layer_by_name(custom_data_name) == -1:
		push_warning("TileLanternLights: TileSet belum punya custom data '%s'." % custom_data_name)
		return
	var tex := _make_texture()
	for cell in get_used_cells():
		var data := get_cell_tile_data(cell)
		if data == null or not bool(data.get_custom_data(custom_data_name)):
			continue
		var light := PointLight2D.new()
		light.texture = tex
		light.texture_scale = texture_scale
		light.color = light_color
		light.position = map_to_local(cell) + light_offset
		light.enabled = false
		add_child(light)
		_lights.append(light)


func _process(_delta: float) -> void:
	var night := DayCycle.night_intensity() > 0.0
	var t := Time.get_ticks_msec() * 0.006
	for i in _lights.size():
		var light := _lights[i]
		light.enabled = night
		if night:
			light.energy = base_energy + sin(t + i * 1.7) * flicker_amount


func _make_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1.0, 0.65, 0.2, 0.8), Color(1.0, 0.35, 0.0, 0.0)])
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = gradient
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(1.0, 0.5)
	grad_tex.width = 64
	grad_tex.height = 64
	return grad_tex
