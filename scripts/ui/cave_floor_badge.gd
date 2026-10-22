extends CanvasLayer

## Penanda lantai gua di atas layar: ikon tingkat + "Lantai N" + nama tingkat (GDD 9).
## Warna bingkai dan ikon berbeda tiap tingkat (CaveBand.display_name / icon / accent).

const FONT := preload("res://assets/fonts/m5x7.ttf")

var _panel: PanelContainer
var _icon: TextureRect
var _floor_label: Label
var _band_label: Label
var _style := StyleBoxFlat.new()

func _ready() -> void:
	layer = 6
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_CENTER_TOP)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)
	_panel = PanelContainer.new()
	_panel.name = "FloorBadge"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style.bg_color = Color(0.13, 0.09, 0.07, 0.88)
	_style.set_border_width_all(2)
	_style.set_corner_radius_all(4)
	_style.set_content_margin_all(6)
	_style.content_margin_right = 12
	_panel.add_theme_stylebox_override("panel", _style)
	anchor.add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_panel.add_child(row)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(32, 32)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(_icon)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", -4)
	row.add_child(text)
	_floor_label = _make_label(24)
	text.add_child(_floor_label)
	_band_label = _make_label(16)
	text.add_child(_band_label)

func _make_label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.98, 0.93, 0.82))
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.04))
	label.add_theme_constant_override("outline_size", 4)
	return label

func show_floor(floor_text: String, band_text: String, icon: Texture2D, accent: Color) -> void:
	if _panel == null:
		await ready
	_floor_label.text = floor_text
	_band_label.text = band_text
	_band_label.add_theme_color_override("font_color", accent.lightened(0.25))
	_band_label.visible = not band_text.is_empty()
	_icon.texture = icon
	_icon.visible = icon != null
	_style.border_color = accent
	# Posisikan di tengah atas lalu "loncat" sedikit supaya pergantian lantai terasa.
	_panel.reset_size()
	_panel.position = Vector2(-_panel.size.x * 0.5, 8)
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(1.25, 1.25)
	create_tween().tween_property(_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
