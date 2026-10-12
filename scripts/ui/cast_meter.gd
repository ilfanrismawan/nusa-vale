class_name CastMeter
extends Node2D
## Meter power lemparan (horizontal) di atas kepala pemain + penanda titik jatuh kail.
## Dibuat FishingState saat tahan klik, lalu dipakai untuk animasi kail terbang.

const TEX_BARS: Texture2D = preload("res://assets/farm_rpg/ui/Bars.png")

# --- Bingkai kayu horizontal di Bars.png (42x7), tutup kotak di kanan ---
const FRAME_REGION := Rect2(147, 118, 42, 7)
const FRAME_MARGIN_LEFT := 3
const FRAME_MARGIN_RIGHT := 13  # tutup kanan (kotak oranye) tidak ikut melar
const METER_W := 38.0           # lebar meter di dunia (piksel)
const FILL_LEFT := 2.0          # kanal isi di dalam bingkai, mengisi kiri -> kanan
const FILL_Y := 2.0
const FILL_H := 3.0
const CAP_W := 8.0              # isi kotak tutup kanan, menyala saat "Sempurna"
const CAP_RIGHT := 10.0         # jarak tepi kiri isi tutup dari tepi kanan meter

# --- Posisi relatif terhadap pemain (kaki) ---
const TOP_Y := -40.0            # tepi atas meter, sedikit di atas kepala

# --- Warna (sama dengan mini-game, dari palet) ---
const FILL_LOW := Color8(228, 33, 43)
const FILL_MID := Color8(255, 199, 27)
const FILL_HIGH := Color8(126, 196, 51)
const FILL_SHINE := Color8(249, 230, 207)
const CAP_IDLE := Color8(74, 33, 35)
const MARK_WATER := Color8(249, 230, 207)
const MARK_LAND := Color8(228, 33, 43)
const LINE_COLOR := Color(1, 1, 1, 0.55)

var power := 0.0
var perfect_window := 0.05
var landing := Vector2.ZERO
var landing_on_water := false
var follow_target: Node2D

var _meter: Control
var _fill: ColorRect
var _shine: ColorRect
var _cap: ColorRect
var _time := 0.0
var _flying := false
var _fly_t := 0.0
var _fly_from := Vector2.ZERO


func _ready() -> void:
	z_index = 50
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_meter = Control.new()
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_meter)

	var frame := NinePatchRect.new()
	frame.texture = TEX_BARS
	frame.region_rect = FRAME_REGION
	frame.patch_margin_left = FRAME_MARGIN_LEFT
	frame.patch_margin_right = FRAME_MARGIN_RIGHT
	frame.size = Vector2(METER_W, FRAME_REGION.size.y)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.add_child(frame)

	_cap = ColorRect.new()
	_cap.position = Vector2(METER_W - CAP_RIGHT, FILL_Y)
	_cap.size = Vector2(CAP_W, FILL_H)
	_cap.color = CAP_IDLE
	_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.add_child(_cap)

	_fill = ColorRect.new()
	_fill.position = Vector2(FILL_LEFT, FILL_Y)
	_fill.size.y = FILL_H
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.add_child(_fill)

	_shine = ColorRect.new()
	_shine.color = FILL_SHINE
	_shine.size = Vector2(1, FILL_H)
	_shine.position.y = FILL_Y
	_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.add_child(_shine)

	_update_meter()


func is_perfect() -> bool:
	return power >= 1.0 - perfect_window


## Kail terbang melengkung dari pemain ke titik jatuh. Meter disembunyikan.
func launch(from: Vector2) -> void:
	_flying = true
	_fly_t = 0.0
	_fly_from = from
	_meter.visible = false


func _process(delta: float) -> void:
	_time += delta
	if _flying:
		_fly_t = minf(_fly_t + delta / 0.3, 1.0)
	elif is_instance_valid(follow_target):
		_place_meter()
	_update_meter()
	queue_redraw()


func _place_meter() -> void:
	# Meter di tengah, tepat di atas kepala pemain (ikut pemainnya masing-masing saat co-op).
	var origin := follow_target.global_position
	_meter.position = Vector2(origin.x - METER_W * 0.5, origin.y + TOP_Y).round()


func _update_meter() -> void:
	var inner_w := METER_W - FRAME_MARGIN_RIGHT - FILL_LEFT
	var w := roundf(inner_w * clampf(power, 0.0, 1.0))
	_fill.size.x = w
	_shine.position.x = FILL_LEFT + w - 1.0
	_shine.visible = w >= 2.0
	var blink := 0.5 + 0.5 * sin(_time * 30.0)
	if is_perfect():
		_fill.color = FILL_HIGH.lerp(FILL_SHINE, blink)
		_cap.color = FILL_MID.lerp(FILL_SHINE, blink)
	else:
		_fill.color = _power_color(power)
		_cap.color = CAP_IDLE


func _power_color(p: float) -> Color:
	if p < 0.5:
		return FILL_LOW.lerp(FILL_MID, p / 0.5)
	return FILL_MID.lerp(FILL_HIGH, (p - 0.5) / 0.5)


func _draw() -> void:
	if _flying:
		_draw_flight()
		return
	# Penanda titik jatuh: cincin piksel berkedip, warna krem di air, merah di darat.
	var on := fmod(_time, 0.5) < 0.35
	var color := MARK_WATER if landing_on_water else MARK_LAND
	if not on:
		color.a = 0.45
	var c := landing.round()
	for p in [Vector2(-1, -3), Vector2(0, -3), Vector2(1, -3), Vector2(-1, 3), Vector2(0, 3), Vector2(1, 3),
			Vector2(-3, -1), Vector2(-3, 0), Vector2(-3, 1), Vector2(3, -1), Vector2(3, 0), Vector2(3, 1),
			Vector2(-2, -2), Vector2(2, -2), Vector2(-2, 2), Vector2(2, 2)]:
		draw_rect(Rect2(c + p, Vector2.ONE), color)
	if not landing_on_water:
		for i in range(-1, 2):
			draw_rect(Rect2(c + Vector2(i, i), Vector2.ONE), color)
			draw_rect(Rect2(c + Vector2(i, -i), Vector2.ONE), color)


func _draw_flight() -> void:
	# Tali tipis dan kail (titik 2x2) di lintasan parabola.
	var height := clampf(_fly_from.distance_to(landing) * 0.35, 6.0, 30.0)
	var prev := _fly_from
	var steps := 8
	for i in range(1, steps + 1):
		var t := _fly_t * float(i) / float(steps)
		var p := _fly_from.lerp(landing, t) + Vector2(0, -4.0 * height * t * (1.0 - t))
		draw_line(prev, p, LINE_COLOR, 1.0)
		prev = p
	draw_rect(Rect2(prev.round() - Vector2.ONE, Vector2(2, 2)), FILL_SHINE)
