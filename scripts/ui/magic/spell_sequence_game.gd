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
	burst(_pad_position(symbol), (COLORS[symbol] as Color) if good else BAD, 10, 60.0)
	_lit = symbol
	_lit_good = good
	_lit_timer = seconds


func _pad_position(i: int) -> Vector2:
	var angle := -PI * 0.5 + i * PI * 0.5
	return BOARD_SIZE * 0.5 + Vector2(cos(angle), sin(angle)) * RING_RADIUS


func _mistake_state() -> Vector2i:
	return Vector2i(_mistakes, MAX_MISTAKES)


func _draw_board(canvas: Control) -> void:
	var center := BOARD_SIZE * 0.5
	var t := age()
	# Lingkaran rapal: cincin ganda, glyph berputar, garis bintang antar pad.
	canvas.draw_arc(center, RING_RADIUS + 12.0, 0, TAU, 64, Color(0.65, 0.5, 1.0, 0.22), 1.0)
	canvas.draw_arc(center, RING_RADIUS, 0, TAU, 64, Color(0.7, 0.55, 1.0, 0.4), 1.5)
	for i in 16:
		var a := -t * 0.3 + TAU * i / 16.0
		diamond(canvas, center + Vector2(cos(a), sin(a)) * (RING_RADIUS + 12.0), 1.6 if i % 2 else 2.4, Color(GOLD, 0.35))
	for i in SYMBOLS.size():
		var a := _pad_position(i)
		var b := _pad_position((i + 1) % SYMBOLS.size())
		canvas.draw_line(a, b, Color(0.7, 0.55, 1.0, 0.12), 1.0)
		canvas.draw_line(a, center, Color(COLORS[i] as Color, 0.1 if _lit != i else 0.5), 1.0 if _lit != i else 2.0)
	# Inti tengah: orb dengan manik progres melingkar dan sisa waktu.
	var phase_color := Color(0.75, 0.6, 1.0) if _showing else GOLD
	draw_glow_circle(canvas, center, 15.0 + sin(t * 3.0) * 1.0, Color(phase_color, 0.35))
	canvas.draw_circle(center, 11.0, Color(0.08, 0.05, 0.14))
	var font := ServiceTheme.FONT
	var label := "LIHAT" if _showing else "ULANG"
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	canvas.draw_string(font, center + Vector2(-width * 0.5, 3.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, phase_color)
	var count := _sequence.size()
	for i in count:
		var a := -PI * 0.5 + TAU * i / count
		var p := center + Vector2(cos(a), sin(a)) * 28.0
		var filled := (not _showing and i < _answer_index) or (_showing and i <= _show_index)
		if filled:
			var sym: int = _sequence[i] if not _showing else -1
			draw_glow_circle(canvas, p, 3.2, Color(COLORS[sym] as Color, 0.95) if sym >= 0 else Color(0.8, 0.7, 1.0, 0.9))
		else:
			canvas.draw_arc(p, 3.0, 0, TAU, 12, Color(0.6, 0.5, 0.85, 0.6), 1.0)
	if not _showing and not is_done():
		var ratio := clampf(_timer / answer_seconds, 0.0, 1.0)
		var warn := Color(1.0, 0.75, 0.4).lerp(BAD, clampf(1.0 - ratio * 2.0, 0.0, 1.0))
		canvas.draw_arc(center, 38.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 48, warn, 2.5)
	# Pad elemen.
	for i in SYMBOLS.size():
		var pos := _pad_position(i)
		var lit := _lit == i
		var color: Color = COLORS[i]
		var k := clampf(_lit_timer / 0.3, 0.0, 1.0) if lit else 0.0
		var r := PAD_RADIUS * (1.0 + 0.12 * k)
		if lit:
			var glow := color if _lit_good else BAD
			draw_glow_circle(canvas, pos, r, glow)
			canvas.draw_arc(pos, r + 6.0 + (1.0 - k) * 8.0, 0, TAU, 32, Color(glow, 0.5 * k), 2.0)
		else:
			canvas.draw_circle(pos, r + 3.0, Color(color, 0.08 + 0.04 * sin(t * 2.0 + i)))
			canvas.draw_circle(pos, r, Color(0.08, 0.05, 0.14))
			canvas.draw_circle(pos, r, Color(color, 0.18))
			canvas.draw_arc(pos, r, 0, TAU, 32, Color(color, 0.8), 2.0)
			canvas.draw_arc(pos, r - 4.0, PI * 1.1, PI * 1.6, 8, Color(1, 1, 1, 0.25), 1.5)
		_draw_symbol(canvas, i, pos, Color(0.1, 0.05, 0.15) if lit else color)
		var element: String = NAMES[i]
		var nw := font.get_string_size(element, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		# Atas/bawah: label di kanan pad; kanan/kiri: label di bawah pad.
		var label_pos := pos + Vector2(PAD_RADIUS + 6.0, 4.0) if i % 2 == 0 else pos + Vector2(-nw * 0.5, PAD_RADIUS + 13.0)
		canvas.draw_string(font, label_pos, element, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(color, 0.85))


## Simbol elemen sederhana (garis), bukan huruf: angin, api, bumi, air.
func _draw_symbol(canvas: Control, i: int, pos: Vector2, color: Color) -> void:
	match i:
		0:
			canvas.draw_arc(pos + Vector2(-2, -3), 7, PI, TAU * 0.95, 12, color, 2.5)
			canvas.draw_line(pos + Vector2(-9, 3), pos + Vector2(9, 3), color, 2.5)
			canvas.draw_line(pos + Vector2(-6, 8), pos + Vector2(5, 8), color, 2.0)
		1:
			canvas.draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -10), pos + Vector2(7, 6), pos + Vector2(-7, 6)]), color)
		2:
			canvas.draw_rect(Rect2(pos - Vector2(7, 7), Vector2(14, 14)), color, false, 2.0)
			canvas.draw_line(pos + Vector2(-7, 0), pos + Vector2(7, 0), color, 2.0)
		3:
			canvas.draw_circle(pos + Vector2(0, 3), 6, color)
			canvas.draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -10), pos + Vector2(5, 1), pos + Vector2(-5, 1)]), color)
