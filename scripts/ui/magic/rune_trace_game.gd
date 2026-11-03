extends "res://scripts/ui/magic/magic_minigame.gd"

## Mini game A "Gambar Rune": telusuri garis rune dari titik ke titik sesuai urutan sebelum
## waktu habis. Mouse: tahan klik kiri lalu seret. Gamepad/keyboard: gerakkan ujung tongkat
## dengan arah (tahan A/Interact sambil bergerak). Keluar jalur terlalu jauh = goresan meleset;
## MAX_MISTAKES goresan meleset = gagal.

## Titik rune dalam koordinat 0..1 (dipetakan ke papan). Bentuk orisinal Nusa Vale.
const RUNES := {
	"staff": [Vector2(0.3, 0.85), Vector2(0.5, 0.15), Vector2(0.6, 0.5), Vector2(0.75, 0.3), Vector2(0.7, 0.85)],
	"bolt": [Vector2(0.62, 0.1), Vector2(0.38, 0.5), Vector2(0.6, 0.5), Vector2(0.36, 0.9)],
	"shield": [Vector2(0.5, 0.1), Vector2(0.8, 0.28), Vector2(0.74, 0.7), Vector2(0.5, 0.9), Vector2(0.26, 0.7), Vector2(0.2, 0.28), Vector2(0.5, 0.1)],
	"light": [Vector2(0.5, 0.1), Vector2(0.62, 0.42), Vector2(0.9, 0.45), Vector2(0.66, 0.62), Vector2(0.76, 0.92), Vector2(0.5, 0.72), Vector2(0.24, 0.92), Vector2(0.34, 0.62), Vector2(0.1, 0.45), Vector2(0.38, 0.42), Vector2(0.5, 0.1)],
	"charm": [Vector2(0.5, 0.5), Vector2(0.62, 0.42), Vector2(0.6, 0.62), Vector2(0.4, 0.66), Vector2(0.32, 0.4), Vector2(0.52, 0.22), Vector2(0.78, 0.36), Vector2(0.78, 0.72), Vector2(0.5, 0.88), Vector2(0.18, 0.76)],
	"ward": [Vector2(0.2, 0.2), Vector2(0.8, 0.2), Vector2(0.2, 0.8), Vector2(0.8, 0.8), Vector2(0.5, 0.5)],
	"moon": [Vector2(0.62, 0.12), Vector2(0.36, 0.22), Vector2(0.26, 0.5), Vector2(0.36, 0.78), Vector2(0.62, 0.88), Vector2(0.46, 0.62), Vector2(0.44, 0.38), Vector2(0.62, 0.12)],
}
const HIT_RADIUS := 15.0
const STRAY_DISTANCE := 28.0
const MAX_MISTAKES := 3
const CURSOR_SPEED := 190.0
const MARGIN := Vector2(40, 18)

## Nama rune di RUNES.
var rune := "staff"
## Detik untuk menyelesaikan.
var time_limit := 14.0

var _points: Array[Vector2] = []
var _next := 1
var _trail: Array[Vector2] = []
var _cursor := Vector2.ZERO
var _drawing := false
var _mistakes := 0
var _time_left := 0.0
var _stray_cooldown := 0.0
var _started := false


func _start() -> void:
	var shape: Array = RUNES.get(rune, RUNES["staff"])
	var area := BOARD_SIZE - MARGIN * 2.0
	for p in shape:
		_points.append(MARGIN + Vector2(p) * area)
	_cursor = _points[0]
	_time_left = time_limit
	set_status("Mulai dari titik bercahaya.")
	set_hint("Mouse: tahan klik & seret mengikuti garis. Gamepad/keyboard: tahan A (Interact) sambil menggerakkan arah. B/Esc batal.")


func _tick(delta: float) -> void:
	_stray_cooldown = maxf(0.0, _stray_cooldown - delta)
	if _started:
		_time_left -= delta
		if _time_left <= 0.0:
			finish(false, "Waktu habis, rune memudar.")
			return
	var pad := input()
	if pad.uses_mouse():
		return
	_drawing = pad.pressed(&"ui_accept") or pad.pressed(&"interact") or pad.pressed(&"use_tool")
	var dir := pad.get_vector()
	if dir.length() > 0.15:
		_move_cursor(_cursor + dir * CURSOR_SPEED * delta)


func _board_pointer(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_drawing = (event as InputEventMouseButton).pressed
		if _drawing:
			_move_cursor((event as InputEventMouseButton).position, true)
	elif event is InputEventMouseMotion:
		_move_cursor((event as InputEventMouseMotion).position)


func _move_cursor(pos: Vector2, jump: bool = false) -> void:
	_cursor = pos.clamp(Vector2.ZERO, BOARD_SIZE)
	if is_done() or not _drawing:
		return
	if not _started:
		if _cursor.distance_to(_points[0]) <= HIT_RADIUS * 1.4:
			_started = true
			_trail = [_points[0]]
			play(&"magic_cast")
			set_status("Ikuti garisnya...")
		return
	if jump:
		return
	_trail.append(_cursor)
	if _trail.size() > 600:
		_trail.remove_at(1)
	var target := _points[_next]
	if _cursor.distance_to(target) <= HIT_RADIUS:
		_next += 1
		play(&"magic_cast")
		flash(GOOD)
		if _next >= _points.size():
			finish(true, "Rune bersinar sempurna!")
		return
	var off := _segment_distance(_cursor, _points[_next - 1], target)
	if off > STRAY_DISTANCE and _stray_cooldown <= 0.0:
		_mistakes += 1
		_stray_cooldown = 0.6
		flash(BAD)
		if _mistakes >= MAX_MISTAKES:
			finish(false, "Goresan terlalu liar, rune pecah.")
		else:
			set_status("Meleset! (%d/%d)" % [_mistakes, MAX_MISTAKES], BAD)


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


func _draw_board(canvas: Control) -> void:
	var t := Time.get_ticks_msec() * 0.001
	# Lingkaran rune samar di latar.
	canvas.draw_arc(BOARD_SIZE * 0.5, BOARD_SIZE.y * 0.46, 0, TAU, 48, Color(0.6, 0.45, 0.9, 0.18), 2.0)
	for i in _points.size() - 1:
		var done := i < _next - 1 and _started
		canvas.draw_line(_points[i], _points[i + 1], Color(0.55, 0.9, 1.0, 0.9) if done else Color(0.75, 0.65, 1.0, 0.28), 6.0 if done else 4.0)
	if _trail.size() > 1:
		canvas.draw_polyline(PackedVector2Array(_trail), Color(1.0, 0.95, 0.7, 0.85), 2.0)
	for i in _points.size():
		var reached := _started and i < _next
		var is_next := (not _started and i == 0) or (_started and i == _next)
		var r := 5.0
		if is_next:
			r = 7.0 + sin(t * 8.0) * 1.5
			draw_glow_circle(canvas, _points[i], r, Color(1.0, 0.9, 0.5, 0.95))
		else:
			canvas.draw_circle(_points[i], r, Color(0.55, 0.95, 1.0) if reached else Color(0.6, 0.5, 0.85, 0.6))
	# Ujung tongkat.
	draw_glow_circle(canvas, _cursor, 3.0, Color(1, 1, 1, 0.9) if _drawing else Color(0.8, 0.8, 1, 0.5))
	# Sisa waktu.
	var ratio := clampf(_time_left / time_limit, 0.0, 1.0)
	canvas.draw_rect(Rect2(8, BOARD_SIZE.y - 10, (BOARD_SIZE.x - 16) * ratio, 4), Color(0.7, 0.55, 1.0, 0.85))
