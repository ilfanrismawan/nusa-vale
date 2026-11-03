extends "res://scripts/ui/magic/magic_minigame.gd"

## Mini game B "Urutan Mantra": simbol mantra menyala satu per satu di lingkaran rapal,
## lalu pemain mengulang urutannya sebelum bara tiap simbol padam. Arah atas/kanan/bawah/kiri
## (keyboard, gamepad, atau klik simbolnya). Salah/terlambat = satu retakan; MAX_MISTAKES = gagal.

const SYMBOLS := [&"move_up", &"move_right", &"move_down", &"move_left"]
const NAMES := ["Angin", "Api", "Bumi", "Air"]
const COLORS := [Color(0.7, 0.95, 1.0), Color(1.0, 0.6, 0.35), Color(0.75, 0.9, 0.45), Color(0.45, 0.65, 1.0)]
const SHOW_SECONDS := 0.65
const GAP_SECONDS := 0.2
const MAX_MISTAKES := 2
const RING_RADIUS := 78.0
const PAD_RADIUS := 22.0

## Panjang urutan.
var length := 5
## Detik per simbol saat giliran pemain.
var answer_seconds := 2.2

var _sequence: Array[int] = []
var _showing := true
var _show_index := -1
var _timer := 0.0
var _answer_index := 0
var _mistakes := 0
var _lit := -1
var _lit_timer := 0.0
var _lit_good := true


func _start() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var last := -1
	for i in length:
		var pick := rng.randi_range(0, SYMBOLS.size() - 1)
		if pick == last:
			pick = (pick + 1 + rng.randi_range(0, 2)) % SYMBOLS.size()
		_sequence.append(pick)
		last = pick
	_timer = 0.6
	set_status("Perhatikan urutan mantra...")
	set_hint("Hafalkan simbol yang menyala, lalu ulangi dengan arah atas/kanan/bawah/kiri atau klik simbolnya. B/Esc batal.")


func _tick(delta: float) -> void:
	_lit_timer = maxf(0.0, _lit_timer - delta)
	if _lit_timer <= 0.0:
		_lit = -1
	_timer -= delta
	if _showing:
		if _timer <= 0.0:
			_show_index += 1
			if _show_index >= _sequence.size():
				_showing = false
				_timer = answer_seconds
				set_status("Giliranmu! (%d/%d)" % [0, _sequence.size()])
				return
			_light(_sequence[_show_index], true, SHOW_SECONDS)
			play(&"magic_cast")
			_timer = SHOW_SECONDS + GAP_SECONDS
		return
	if _timer <= 0.0:
		_miss("Terlambat!")
		_timer = answer_seconds


func _handle_input(event: InputEvent) -> bool:
	if _showing:
		return false
	for i in SYMBOLS.size():
		if input().is_event(event, SYMBOLS[i]):
			_answer(i)
			return true
	return false


func _board_pointer(event: InputEvent) -> void:
	if _showing or not (event is InputEventMouseButton) or not (event as InputEventMouseButton).pressed:
		return
	var pos := (event as InputEventMouseButton).position
	for i in SYMBOLS.size():
		if pos.distance_to(_pad_position(i)) <= PAD_RADIUS * 1.3:
			_answer(i)
			return


func _answer(symbol: int) -> void:
	if is_done():
		return
	if symbol == _sequence[_answer_index]:
		_light(symbol, true, 0.3)
		play(&"magic_cast")
		_answer_index += 1
		_timer = answer_seconds
		if _answer_index >= _sequence.size():
			finish(true, "Mantra terucap sempurna!")
		else:
			set_status("Giliranmu! (%d/%d)" % [_answer_index, _sequence.size()])
	else:
		_light(symbol, false, 0.4)
		_miss("Simbol salah!")


func _miss(text: String) -> void:
	_mistakes += 1
	flash(BAD)
	if _mistakes >= MAX_MISTAKES:
		finish(false, "Mantra buyar.")
	else:
		set_status("%s Retakan %d/%d" % [text, _mistakes, MAX_MISTAKES], BAD)


func _light(symbol: int, good: bool, seconds: float) -> void:
	_lit = symbol
	_lit_good = good
	_lit_timer = seconds


func _pad_position(i: int) -> Vector2:
	var angle := -PI * 0.5 + i * PI * 0.5
	return BOARD_SIZE * 0.5 + Vector2(cos(angle), sin(angle)) * RING_RADIUS


func _draw_board(canvas: Control) -> void:
	var center := BOARD_SIZE * 0.5
	var t := Time.get_ticks_msec() * 0.001
	canvas.draw_arc(center, RING_RADIUS, 0, TAU, 48, Color(0.7, 0.55, 1.0, 0.35), 2.0)
	canvas.draw_arc(center, RING_RADIUS * 0.45, t, t + TAU * 0.8, 24, Color(0.8, 0.7, 1.0, 0.25), 1.5)
	for i in SYMBOLS.size():
		var pos := _pad_position(i)
		var lit := _lit == i
		var color: Color = COLORS[i]
		if lit:
			draw_glow_circle(canvas, pos, PAD_RADIUS, color if _lit_good else BAD)
		else:
			canvas.draw_circle(pos, PAD_RADIUS, Color(color, 0.22))
			canvas.draw_arc(pos, PAD_RADIUS, 0, TAU, 24, Color(color, 0.7), 2.0)
		_draw_symbol(canvas, i, pos, Color(0.1, 0.05, 0.15) if lit else color)
	# Manik urutan di tengah.
	var count := _sequence.size()
	for i in count:
		var p := center + Vector2((i - (count - 1) * 0.5) * 12.0, 0)
		var filled := (not _showing and i < _answer_index) or (_showing and i <= _show_index)
		canvas.draw_circle(p, 4.0, Color(1, 0.9, 0.6) if filled else Color(0.5, 0.4, 0.7, 0.6))
	if not _showing and not is_done():
		var ratio := clampf(_timer / answer_seconds, 0.0, 1.0)
		canvas.draw_arc(center, RING_RADIUS * 0.3, -PI * 0.5, -PI * 0.5 + TAU * ratio, 32, Color(1.0, 0.75, 0.4, 0.9), 3.0)
	for i in _mistakes:
		canvas.draw_line(Vector2(14 + i * 14, 14), Vector2(22 + i * 14, 28), BAD, 2.0)


## Simbol elemen sederhana (garis), bukan huruf: angin, api, bumi, air.
func _draw_symbol(canvas: Control, i: int, pos: Vector2, color: Color) -> void:
	match i:
		0:
			canvas.draw_arc(pos + Vector2(-2, -3), 7, PI, TAU * 0.95, 12, color, 2.0)
			canvas.draw_line(pos + Vector2(-9, 3), pos + Vector2(9, 3), color, 2.0)
		1:
			canvas.draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -10), pos + Vector2(7, 6), pos + Vector2(-7, 6)]), color)
		2:
			canvas.draw_rect(Rect2(pos - Vector2(7, 7), Vector2(14, 14)), color, false, 2.0)
			canvas.draw_line(pos + Vector2(-7, 0), pos + Vector2(7, 0), color, 2.0)
		3:
			canvas.draw_circle(pos + Vector2(0, 3), 6, color)
			canvas.draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -10), pos + Vector2(5, 1), pos + Vector2(-5, 1)]), color)
