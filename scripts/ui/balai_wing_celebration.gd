extends Control
## Perayaan layar penuh saat satu sayap Balai Nadi lengkap (GDD 4.9.1):
## kilat emas, sinar berputar, ikon sayap meletup, konfeti, lalu judul dan bonus.
## BalaiNadiUI memanggil play() dan menunggu `finished`; skip() mempercepat ke akhir.

signal finished

const GOLD := Color(1.0, 0.87, 0.55)
const MINT := Color(0.51, 0.94, 0.75)

@export var hold_time := 1.7
@export var ray_count := 12
@export var ray_length := 300.0
@export var ray_speed := 0.6
@export var confetti_amount := 48

var playing := false
var _rays := 0.0
var _spin := 0.0
var _tween: Tween
var _flash: ColorRect
var _icon: TextureRect
var _title: Label
var _subtitle: Label
var _confetti: CPUParticles2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_flash = ColorRect.new()
	_flash.color = Color(1.0, 0.95, 0.8, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.size = Vector2(128, 128)
	_icon.pivot_offset = _icon.size * 0.5
	add_child(_icon)
	_title = _label(48, GOLD)
	_subtitle = _label(32, MINT)
	_confetti = CPUParticles2D.new()
	_confetti.emitting = false
	_confetti.one_shot = true
	_confetti.amount = confetti_amount
	_confetti.lifetime = 1.6
	_confetti.explosiveness = 0.9
	_confetti.direction = Vector2.UP
	_confetti.spread = 180.0
	_confetti.initial_velocity_min = 180.0
	_confetti.initial_velocity_max = 420.0
	_confetti.gravity = Vector2(0, 420)
	_confetti.damping_min = 40.0
	_confetti.damping_max = 90.0
	_confetti.angular_velocity_min = -360.0
	_confetti.angular_velocity_max = 360.0
	_confetti.scale_amount_min = 4.0
	_confetti.scale_amount_max = 9.0
	var colors := Gradient.new()
	colors.set_color(0, GOLD)
	colors.set_color(1, MINT)
	_confetti.color_initial_ramp = colors
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.add_point(0.75, Color.WHITE)
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	_confetti.color_ramp = fade
	add_child(_confetti)

func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.12))
	label.add_theme_constant_override("outline_size", 10)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func play(icon: Texture2D, title: String, subtitle: String) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var center := size * 0.5 + Vector2(0, -40)
	playing = true
	visible = true
	modulate.a = 1.0
	_icon.texture = icon
	_icon.position = center - _icon.size * 0.5
	_icon.scale = Vector2.ZERO
	_icon.rotation = -0.4
	for label in [_title, _subtitle]:
		label.position = Vector2.ZERO
		label.size = Vector2(size.x, 0)
		label.modulate.a = 0.0
		label.scale = Vector2.ONE * 0.6
	_title.text = title
	_subtitle.text = subtitle
	_title.position.y = center.y + 84
	_subtitle.position.y = center.y + 140
	for label in [_title, _subtitle]:
		label.reset_size()
		label.size.x = size.x
		label.pivot_offset = label.size * 0.5
	_confetti.position = center
	_confetti.restart()
	_flash.color.a = 0.75
	_rays = 0.0
	_tween = create_tween()
	_tween.set_parallel()
	_tween.tween_property(_flash, "color:a", 0.0, 0.45).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "_rays", 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_icon, "scale", Vector2.ONE * 1.25, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_icon, "rotation", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_icon, "scale", Vector2.ONE, 0.16).set_delay(0.22)
	_tween.tween_property(_title, "modulate:a", 1.0, 0.18).set_delay(0.18)
	_tween.tween_property(_title, "scale", Vector2.ONE, 0.26).set_delay(0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_subtitle, "modulate:a", 1.0, 0.2).set_delay(0.36)
	_tween.tween_property(_subtitle, "scale", Vector2.ONE, 0.26).set_delay(0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_interval(hold_time)
	_tween.chain().tween_property(self, "modulate:a", 0.0, 0.3)
	_tween.chain().tween_callback(_finish)

## Tombol A/E/klik: langsung tutup perayaan (efek suara/partikel sudah terlanjur main).
func skip() -> void:
	if not playing:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_finish()

func _finish() -> void:
	if not playing:
		return
	playing = false
	visible = false
	finished.emit()

func _process(delta: float) -> void:
	if not playing:
		return
	_spin += delta * ray_speed
	_icon.position.y = size.y * 0.5 - 40 - _icon.size.y * 0.5 + sin(_spin * 5.0) * 4.0
	queue_redraw()

func _draw() -> void:
	if not playing or _rays <= 0.0:
		return
	var center := size * 0.5 + Vector2(0, -40)
	var reach := ray_length * _rays
	var half := PI / ray_count * 0.45
	for i in ray_count:
		var angle := _spin + TAU * i / ray_count
		var tip_a := center + Vector2.from_angle(angle - half) * reach
		var tip_b := center + Vector2.from_angle(angle + half) * reach
		draw_polygon(PackedVector2Array([center, tip_a, tip_b]), PackedColorArray([Color(GOLD, 0.35), Color(GOLD, 0.0), Color(GOLD, 0.0)]))
	draw_circle(center, 92.0 * _rays, Color(GOLD, 0.18))
	draw_circle(center, 70.0 * _rays, Color(1, 1, 1, 0.12))
