extends "res://scripts/ui/magic/magic_minigame.gd"

## Mini game C "Racik di Kuali" (Menara Penyihir):
## 1. Masukkan bahan sesuai urutan resep (pilih dari nampan).
## 2. Aduk ke arah yang diminta sampai ramuan berubah warna.
## 3. Angkat tepat saat kilau ramuan berada di zona warna matang.
## Salah bahan / meleset mengangkat = satu kesalahan; MAX_MISTAKES = ramuan gosong (gagal).

enum Phase { INGREDIENTS, STIR, LIFT }

const MAX_MISTAKES := 3
const STIR_SECONDS := 16.0
const KEY_STIR_SPEED := 4.2
const MURKY := Color(0.28, 0.3, 0.22)
const POT_CENTER := Vector2(190, 118)
const POT_RADIUS := Vector2(70, 34)
const TRAY_Y := 214.0
## Bahan pengecoh di nampan (bukan bagian resep; tidak dikonsumsi).
const DECOYS := ["moon_dew", "stardust", "bunga_kantil", "honey", "lavender", "slime_gel"]

var recipe: CraftingRecipe

var _phase := Phase.INGREDIENTS
var _order: Array[ItemData] = []
var _tray: Array[ItemData] = []
var _added := 0
var _tray_index := 0
var _mistakes := 0
var _stir := 0.0
var _stir_angle := 0.0
var _stir_time := 0.0
var _mouse_stirring := false
var _last_mouse_angle := 0.0
var _lift_t := 0.0
var _lift_speed := 0.9
var _zone := Vector2(0.42, 0.58)
var _bubbles: Array[Vector3] = []
var _splash := 0.0


func _start() -> void:
	for id in recipe.ingredients:
		var item := GameState._resolve_item(String(id))
		if item != null:
			_order.append(item)
	_tray = _order.duplicate()
	var decoys := DECOYS.duplicate()
	decoys.shuffle()
	for id in decoys:
		if _tray.size() >= _order.size() + 2:
			break
		if recipe.ingredients.has(id):
			continue
		var decoy := GameState._resolve_item(String(id))
		if decoy != null:
			_tray.append(decoy)
	_tray.shuffle()
	var diff := int(recipe.get("difficulty")) if recipe.get("difficulty") != null else 1
	var width := 0.2 - 0.04 * (diff - 1)
	var middle := randf_range(0.3, 0.7)
	_zone = Vector2(middle - width * 0.5, middle + width * 0.5)
	_lift_speed = 0.75 + 0.2 * diff
	for i in 10:
		_bubbles.append(Vector3(randf_range(-0.8, 0.8), randf_range(-0.6, 0.6), randf()))
	_enter_ingredients()


func _clockwise() -> bool:
	return bool(recipe.get("stir_clockwise")) if recipe.get("stir_clockwise") != null else true


func _turns() -> float:
	return float(recipe.get("stir_turns")) if recipe.get("stir_turns") != null else 2.0


func _target() -> Color:
	return recipe.get("brew_color") if recipe.get("brew_color") != null else Color(0.5, 0.9, 0.6)


func _enter_ingredients() -> void:
	_phase = Phase.INGREDIENTS
	set_status("Masukkan: %s (%d/%d)" % [_order[_added].display_name, _added + 1, _order.size()] if not _order.is_empty() else "")
	set_hint("Pilih bahan sesuai urutan resep: kiri/kanan + A, atau klik bahan di nampan. B/Esc batal.")


func _enter_stir() -> void:
	_phase = Phase.STIR
	_stir_time = STIR_SECONDS
	var dir := "searah jarum jam" if _clockwise() else "berlawanan jarum jam"
	set_status("Aduk %s: %d putaran." % [dir, int(_turns())])
	set_hint("Putar arah (stik/WASD) membentuk lingkaran, tahan kanan/kiri, atau tahan klik di kuali lalu putar mouse.")


func _enter_lift() -> void:
	_phase = Phase.LIFT
	_lift_t = 0.0
	set_status("Angkat saat kilau di zona warna matang!")
	set_hint("Tekan A / Interact / klik untuk mengangkat kuali.")


func _tick(delta: float) -> void:
	_splash = maxf(0.0, _splash - delta * 2.0)
	for i in _bubbles.size():
		var b := _bubbles[i]
		b.z += delta * (0.6 + _stir * 0.8)
		if b.z > 1.0:
			b = Vector3(randf_range(-0.8, 0.8), randf_range(-0.6, 0.6), 0.0)
		_bubbles[i] = b
	match _phase:
		Phase.STIR:
			_stir_time -= delta
			var pad := input()
			if not pad.uses_mouse():
				var spin := 0.0
				if pad.pressed(&"move_right"): spin += 1.0
				if pad.pressed(&"move_left"): spin -= 1.0
				var v := pad.get_vector()
				if absf(spin) > 0.0 and v.y == 0.0:
					_add_stir(spin * KEY_STIR_SPEED * delta)
				elif v.length() > 0.6:
					var angle := v.angle()
					if _last_mouse_angle != 0.0:
						_add_stir(wrapf(angle - _last_mouse_angle, -PI, PI))
					_last_mouse_angle = angle
				else:
					_last_mouse_angle = 0.0
			if _stir >= 1.0:
				_enter_lift()
			elif _stir_time <= 0.0:
				_burn("Ramuan mengental, terlambat diaduk.")
		Phase.LIFT:
			_lift_t += delta * _lift_speed


func _add_stir(angle_delta: float) -> void:
	_stir_angle += angle_delta
	var signed := angle_delta if _clockwise() else -angle_delta
	_stir = clampf(_stir + signed / (TAU * _turns()), 0.0, 1.0)
	if signed < -0.05:
		set_status("Arah salah! Aduk %s." % ("searah jarum jam" if _clockwise() else "berlawanan jarum jam"), BAD)


func _lift_value() -> float:
	return 0.5 - 0.5 * cos(_lift_t * PI)


func _handle_input(event: InputEvent) -> bool:
	var pad := input()
	match _phase:
		Phase.INGREDIENTS:
			if pad.is_event(event, &"move_left"):
				_tray_index = wrapi(_tray_index - 1, 0, _tray.size())
				return true
			if pad.is_event(event, &"move_right"):
				_tray_index = wrapi(_tray_index + 1, 0, _tray.size())
				return true
			if _is_confirm(pad, event):
				_drop(_tray_index)
				return true
		Phase.LIFT:
			if _is_confirm(pad, event):
				_lift()
				return true
	return false


## Konfirmasi tombol. Klik kiri (use_tool) hanya untuk pemain tanpa mouse supaya klik di papan tidak dobel.
func _is_confirm(pad: PlayerInput, event: InputEvent) -> bool:
	return pad.is_event(event, &"ui_accept") or pad.is_event(event, &"interact") or (not pad.uses_mouse() and pad.is_event(event, &"use_tool"))


func _board_pointer(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		match _phase:
			Phase.INGREDIENTS:
				if mb.pressed:
					for i in _tray.size():
						if mb.position.distance_to(_tray_position(i)) <= 18.0:
							_tray_index = i
							_drop(i)
			Phase.STIR:
				_mouse_stirring = mb.pressed
				_last_mouse_angle = (mb.position - POT_CENTER).angle()
			Phase.LIFT:
				if mb.pressed:
					_lift()
	elif event is InputEventMouseMotion and _phase == Phase.STIR and _mouse_stirring:
		var angle := ((event as InputEventMouseMotion).position - POT_CENTER).angle()
		_add_stir(wrapf(angle - _last_mouse_angle, -PI, PI))
		_last_mouse_angle = angle


func _drop(index: int) -> void:
	if is_done() or index < 0 or index >= _tray.size() or _added >= _order.size():
		return
	var item := _tray[index]
	if item == _order[_added]:
		_added += 1
		_splash = 1.0
		play(&"splash")
		_tray.remove_at(index)
		_tray_index = clampi(_tray_index, 0, maxi(0, _tray.size() - 1))
		if _added >= _order.size():
			_enter_stir()
		else:
			set_status("Masukkan: %s (%d/%d)" % [_order[_added].display_name, _added + 1, _order.size()])
	else:
		_mistake("%s bukan bahan berikutnya!" % item.display_name)


func _lift() -> void:
	if is_done():
		return
	var v := _lift_value()
	if v >= _zone.x and v <= _zone.y:
		finish(true, "Ramuan matang sempurna!")
	else:
		_mistake("Belum matang!" if v < _zone.x else "Terlalu lama!")


func _mistake(text: String) -> void:
	_mistakes += 1
	flash(BAD)
	if _mistakes >= MAX_MISTAKES:
		_burn("Ramuan gosong.")
	else:
		set_status("%s Kesalahan %d/%d" % [text, _mistakes, MAX_MISTAKES], BAD)


func _burn(text: String) -> void:
	finish(false, text)


func _tray_position(i: int) -> Vector2:
	var count := _tray.size()
	return Vector2(BOARD_SIZE.x * 0.5 + (i - (count - 1) * 0.5) * 44.0, TRAY_Y)


func _liquid_color() -> Color:
	var base := MURKY.lerp(_target(), _stir * 0.85)
	if _phase == Phase.LIFT:
		var v := _lift_value()
		base = MURKY.lerp(_target(), v).lightened(0.15 * sin(_lift_t * 9.0) + 0.1)
	return base.darkened(0.12 * _mistakes)


func _draw_board(canvas: Control) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var liquid := _liquid_color()
	# Api & kuali.
	for i in 5:
		var x := POT_CENTER.x - 40 + i * 20
		var h := 10.0 + sin(t * 10.0 + i) * 3.0
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x - 7, 176), Vector2(x, 176 - h - 6), Vector2(x + 7, 176)]), Color(1.0, 0.55, 0.2, 0.85))
	canvas.draw_rect(Rect2(POT_CENTER.x - 74, POT_CENTER.y, 148, 52), Color(0.12, 0.1, 0.14))
	canvas.draw_circle(Vector2(POT_CENTER.x, POT_CENTER.y + 52), 74, Color(0.12, 0.1, 0.14))
	_draw_ellipse(canvas, POT_CENTER, POT_RADIUS + Vector2(6, 4), Color(0.22, 0.2, 0.26))
	_draw_ellipse(canvas, POT_CENTER, POT_RADIUS, liquid)
	for b in _bubbles:
		var p := POT_CENTER + Vector2(b.x * POT_RADIUS.x, b.y * POT_RADIUS.y)
		canvas.draw_arc(p, 2.0 + b.z * 3.0, 0, TAU, 10, Color(liquid.lightened(0.4), 1.0 - b.z), 1.0)
	if _splash > 0.0:
		canvas.draw_arc(POT_CENTER, 20.0 + (1.0 - _splash) * 40.0, 0, TAU, 24, Color(1, 1, 1, _splash * 0.7), 2.0)
	# Sendok aduk.
	var tip := POT_CENTER + Vector2(cos(_stir_angle), sin(_stir_angle)) * Vector2(POT_RADIUS.x * 0.55, POT_RADIUS.y * 0.55)
	canvas.draw_line(tip, tip + Vector2(18, -56), Color(0.6, 0.4, 0.25), 4.0)
	# Urutan resep di atas.
	for i in _order.size():
		var p := Vector2(BOARD_SIZE.x * 0.5 + (i - (_order.size() - 1) * 0.5) * 34.0, 22)
		canvas.draw_rect(Rect2(p - Vector2(14, 14), Vector2(28, 28)), Color(0.25, 0.18, 0.35) if i != _added else Color(0.45, 0.32, 0.6))
		draw_icon(canvas, _order[i], p, 22.0)
		if i < _added:
			canvas.draw_line(p + Vector2(-7, 1), p + Vector2(-2, 7), GOOD, 3.0)
			canvas.draw_line(p + Vector2(-2, 7), p + Vector2(8, -6), GOOD, 3.0)
	match _phase:
		Phase.INGREDIENTS:
			for i in _tray.size():
				var p := _tray_position(i)
				var sel := i == _tray_index and not input().uses_mouse()
				canvas.draw_rect(Rect2(p - Vector2(17, 17), Vector2(34, 34)), Color(0.75, 0.6, 1.0, 0.9) if sel else Color(0.3, 0.24, 0.4), not sel, 2.0)
				draw_icon(canvas, _tray[i], p, 26.0)
		Phase.STIR:
			var arrow := 1.0 if _clockwise() else -1.0
			canvas.draw_arc(POT_CENTER, POT_RADIUS.x + 18, -PI * 0.5, -PI * 0.5 + TAU * _stir * arrow, 40, Color(0.7, 1.0, 0.8, 0.9), 4.0)
			var head_angle := -PI * 0.5 + 0.6 * arrow + t * 2.0 * arrow
			var head := POT_CENTER + Vector2(cos(head_angle), sin(head_angle)) * (POT_RADIUS.x + 30)
			draw_glow_circle(canvas, head, 4.0, Color(1, 0.9, 0.6, 0.9))
			var ratio := clampf(_stir_time / STIR_SECONDS, 0.0, 1.0)
			canvas.draw_rect(Rect2(8, BOARD_SIZE.y - 10, (BOARD_SIZE.x - 16) * ratio, 4), Color(1.0, 0.7, 0.4, 0.85))
		Phase.LIFT:
			var bar := Rect2(40, TRAY_Y - 8, BOARD_SIZE.x - 80, 16)
			for i in 24:
				var k := i / 23.0
				canvas.draw_rect(Rect2(bar.position.x + bar.size.x * k, bar.position.y, bar.size.x / 24.0 + 1, bar.size.y), MURKY.lerp(_target(), k))
			canvas.draw_rect(Rect2(bar.position.x + bar.size.x * _zone.x, bar.position.y - 3, bar.size.x * (_zone.y - _zone.x), bar.size.y + 6), Color(1, 1, 1, 0.9), false, 2.0)
			var mx := bar.position.x + bar.size.x * _lift_value()
			canvas.draw_line(Vector2(mx, bar.position.y - 6), Vector2(mx, bar.end.y + 6), Color.WHITE, 3.0)


static func _draw_ellipse(canvas: Control, center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	canvas.draw_colored_polygon(points, color)
