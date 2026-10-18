class_name BossHealthBar
extends CanvasLayer

## Bar HP boss besar di bawah layar (GDD 8.2-C1): nama boss, isi merah dengan sisa putih yang
## menyusul pelan, garis ambang fase, label fase/MURKA, dan spanduk saat boss ditaklukkan.
## Dibuat BossArena untuk tiap layar pemain (Coop.ui_parent), membaca HP langsung dari Boss.

const FONT := preload("res://assets/fonts/m5x7.ttf")
const FILL := Color(0.82, 0.16, 0.12)
const FILL_ENRAGED := Color(1.0, 0.38, 0.1)
const CHIP := Color(1.0, 0.93, 0.75)
const FRAME := Color(1.0, 0.82, 0.3)
const BACK := Color(0.05, 0.03, 0.03, 0.8)
## Sisa putih mulai menyusul setelah jeda ini, lalu turun sekian rasio per detik.
const CHIP_DELAY := 0.5
const CHIP_SPEED := 0.6

var boss: Boss
var ratio := 1.0
var chip := 1.0
var _chip_wait := 0.0
var _time := 0.0
var _root: Control
var _bar: Control
var _name: Label
var _status: Label
var _banner: Label
var _closing := false

static func show_for(p_boss: Boss, parent: Node) -> BossHealthBar:
	var created := BossHealthBar.new()
	created.boss = p_boss
	parent.add_child(created)
	return created

func _ready() -> void:
	layer = 15
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_bar = Control.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_bar, -46.0, -32.0)
	_bar.draw.connect(_draw_bar)
	_root.add_child(_bar)
	_name = _label(32, HORIZONTAL_ALIGNMENT_LEFT)
	_place(_name, -80.0, -46.0)
	_name.text = boss.boss.title if boss != null and boss.boss != null else "Boss"
	_status = _label(32, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(_status, -80.0, -46.0)
	if boss != null:
		ratio = _boss_ratio()
		chip = ratio
	# Muncul dari bawah.
	_root.modulate.a = 0.0
	_root.position.y = 24.0
	var tween := create_tween().set_parallel()
	tween.tween_property(_root, "modulate:a", 1.0, 0.6)
	tween.tween_property(_root, "position:y", 0.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Bar selebar 60% layar di tengah bawah.
func _place(control: Control, top: float, bottom: float) -> void:
	control.anchor_left = 0.2
	control.anchor_right = 0.8
	control.anchor_top = 1.0
	control.anchor_bottom = 1.0
	control.offset_top = top
	control.offset_bottom = bottom

func _label(size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", FRAME)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.04, 0.02))
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(label)
	return label

func _boss_ratio() -> float:
	return clampf(float(boss.hp) / float(maxi(1, boss.data.max_hp)), 0.0, 1.0)

func _process(delta: float) -> void:
	_time += delta
	if is_instance_valid(boss) and boss.data != null:
		var now := _boss_ratio()
		if now < ratio:
			_chip_wait = CHIP_DELAY
		ratio = now
		if chip < ratio:
			chip = ratio
		_chip_wait -= delta
		if _chip_wait <= 0.0:
			chip = move_toward(chip, ratio, CHIP_SPEED * delta)
		if boss.enraged:
			_status.text = "MURKA"
			_status.add_theme_color_override("font_color", FILL_ENRAGED if int(_time * 6.0) % 2 == 0 else Color(1, 0.9, 0.6))
		else:
			_status.text = "Fase %d" % boss.phase if boss.phase > 1 else ""
			_status.add_theme_color_override("font_color", FRAME)
	_bar.queue_redraw()

func _draw_bar() -> void:
	var size := _bar.size
	_bar.draw_rect(Rect2(Vector2(-2, -2), size + Vector2(4, 4)), Color(0.1, 0.04, 0.02))
	_bar.draw_rect(Rect2(Vector2.ZERO, size), BACK)
	_bar.draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * chip, size.y)), CHIP)
	var enraged := is_instance_valid(boss) and boss.enraged
	var fill := FILL_ENRAGED.lerp(FILL, 0.5 + 0.5 * sin(_time * 12.0)) if enraged else FILL
	_bar.draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * ratio, size.y)), fill)
	_bar.draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * ratio, 3)), Color(fill.lightened(0.35), 0.8))
	# Garis ambang fase.
	if is_instance_valid(boss) and boss.boss != null:
		for threshold in [boss.boss.phase2_hp_ratio, boss.boss.phase3_hp_ratio]:
			if threshold > 0.0 and threshold < 1.0:
				var x := roundf(size.x * threshold)
				_bar.draw_line(Vector2(x, -4), Vector2(x, size.y + 4), FRAME, 2.0)
	_bar.draw_rect(Rect2(Vector2.ZERO, size), FRAME, false, 2.0)

## Boss kalah: bar memudar, spanduk "<NAMA> DITAKLUKKAN" tampil lalu hilang.
func victory(title: String) -> void:
	if _closing:
		return
	_closing = true
	ratio = 0.0
	_banner = _label(64, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.anchor_left = 0.0
	_banner.anchor_right = 1.0
	_banner.anchor_top = 0.35
	_banner.anchor_bottom = 0.35
	_banner.offset_top = -40.0
	_banner.offset_bottom = 40.0
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.text = "%s DITAKLUKKAN" % title.to_upper()
	_banner.modulate.a = 0.0
	_banner.scale = Vector2(1.0, 1.0)
	var tween := create_tween()
	tween.tween_property(_banner, "modulate:a", 1.0, 0.5)
	tween.parallel().tween_property(_bar, "modulate:a", 0.0, 0.8)
	tween.parallel().tween_property(_name, "modulate:a", 0.0, 0.8)
	tween.parallel().tween_property(_status, "modulate:a", 0.0, 0.8)
	tween.tween_interval(2.5)
	tween.tween_property(_root, "modulate:a", 0.0, 0.8)
	tween.tween_callback(queue_free)

## Pertarungan diulang (semua pemain keluar): bar turun dan hilang.
func close() -> void:
	if _closing:
		return
	_closing = true
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)
