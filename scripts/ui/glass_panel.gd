@tool
extends ColorRect
## Panel kaca Balai Nadi. Ukuran node dikirim ke shader supaya sudut, lensa, dan bayangan pas.

@export var corner_radius := 999.0:
	set(value):
		corner_radius = value
		_sync()
## Ruang kosong di sekeliling kaca untuk bayangan dan pendar.
@export var padding := 14.0:
	set(value):
		padding = value
		_sync()
@export var tint := Color(0.80, 0.90, 1.0, 0.20):
	set(value):
		tint = value
		_sync()
@export_range(0.0, 1.0) var glow := 0.0:
	set(value):
		glow = value
		_set_param(&"glow", glow)
@export var light_dir := Vector2(-0.35, -1.0):
	set(value):
		light_dir = value
		_set_param(&"light_dir", light_dir)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Setiap panel butuh parameter sendiri (ukuran, pendar); di editor bahan tidak digandakan.
	if material != null and not Engine.is_editor_hint():
		material = material.duplicate()
	resized.connect(_sync)
	_sync()

func _set_param(key: StringName, value: Variant) -> void:
	if is_node_ready() and material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter(key, value)

func _sync() -> void:
	_set_param(&"rect_size", size)
	_set_param(&"padding", padding)
	_set_param(&"corner_radius", corner_radius)
	_set_param(&"tint", tint)
	_set_param(&"glow", glow)
	_set_param(&"light_dir", light_dir)
