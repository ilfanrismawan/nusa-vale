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
const POT_CENTER := Vector2(190, 100)
const POT_RADIUS := Vector2(70, 34)
const TRAY_Y := 214.0
const FIRE_Y := 196.0
const STIR_RING := Vector2(92, 56)
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
## Bahan yang sedang terbang ke kuali: item, from, t (0..1).
var _flying: Array[Dictionary] = []


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
	for i in range(_flying.size() - 1, -1, -1):
		_flying[i]["t"] = float(_flying[i]["t"]) + delta * 3.2
		if float(_flying[i]["t"]) >= 1.0:
			_flying.remove_at(i)
			_splash = 1.0
			burst(POT_CENTER + Vector2(0, -4), _liquid_color().lightened(0.4), 12, 70.0)
	if randf() < delta * (6.0 + _stir * 10.0):
		sparkle(POT_CENTER + Vector2(randf_range(-50, 50), -8), Vector2(randf_range(-6, 6), randf_range(-38, -22)), Color(_liquid_color().lightened(0.5), 0.7), randf_range(0.8, 1.4), randf_range(1.6, 2.8))
	if randf() < delta * 5.0:
		sparkle(Vector2(POT_CENTER.x + randf_range(-36, 36), FIRE_Y - 8), Vector2(randf_range(-10, 10), randf_range(-40, -20)), Color(1.0, 0.6, 0.25), 0.6, 1.0)
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
		_flying.append({"item": item, "from": _tray_position(index), "t": 0.0})
		_added += 1
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
		burst(POT_CENTER, _target().lightened(0.3), 24, 120.0)
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


func _mistake_state() -> Vector2i:
	return Vector2i(_mistakes, MAX_MISTAKES)


func _time_ratio() -> float:
	return clampf(_stir_time / STIR_SECONDS, 0.0, 1.0) if _phase == Phase.STIR else -1.0


func _draw_board(canvas: Control) -> void:
	var t := age()
	var liquid := _liquid_color()
	var font := ServiceTheme.FONT
	_draw_pot(canvas, liquid)
	_draw_fire(canvas, t)
	# Bahan yang terbang ke kuali.
	for f in _flying:
		var k := float(f["t"])
		var from: Vector2 = f["from"]
		var to := POT_CENTER + Vector2(0, -6)
		var pos := from.lerp(to, k) + Vector2(0, -70.0 * sin(k * PI))
		draw_icon(canvas, f["item"], pos, 24.0 * (1.0 - 0.4 * k))
	# Urutan resep di atas: slot berpanah.
	var n := _order.size()
	for i in n:
		var p := Vector2(BOARD_SIZE.x * 0.5 + (i - (n - 1) * 0.5) * 38.0, 24)
		var rect := Rect2(p - Vector2(15, 15), Vector2(30, 30))
		var current := i == _added and _phase == Phase.INGREDIENTS
		var border := Color(GOLD, 0.6 + 0.4 * sin(t * 6.0)) if current else Color(0.55, 0.42, 0.8, 0.6)
		draw_box(canvas, rect, Color(0.18, 0.12, 0.28, 0.95) if i >= _added else Color(0.14, 0.24, 0.2, 0.95), border, 4, 2 if current else 1)
		draw_icon(canvas, _order[i], p, 22.0)
		if i < _added:
			canvas.draw_circle(p + Vector2(10, 10), 6.0, Color(0.1, 0.3, 0.18))
			canvas.draw_line(p + Vector2(7, 10), p + Vector2(9, 12.5), GOOD, 2.0)
			canvas.draw_line(p + Vector2(9, 12.5), p + Vector2(13, 7), GOOD, 2.0)
		if i < n - 1:
			var ax := p.x + 17.0
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(ax, p.y - 3), Vector2(ax + 4, p.y), Vector2(ax, p.y + 3)]), Color(GOLD, 0.6))
	match _phase:
		Phase.INGREDIENTS:
			# Rak nampan kayu.
			var shelf := Rect2(24, TRAY_Y + 14, BOARD_SIZE.x - 48, 6)
			draw_box(canvas, shelf, Color(0.38, 0.24, 0.16), Color(0.55, 0.36, 0.22), 2)
			for i in _tray.size():
				var p := _tray_position(i)
				var sel := i == _tray_index and not input().uses_mouse()
				if sel:
					p.y -= 4.0 + sin(t * 6.0) * 1.5
				var rect := Rect2(p - Vector2(17, 17), Vector2(34, 34))
				draw_box(canvas, rect, Color(0.2, 0.14, 0.3, 0.95) if not sel else Color(0.32, 0.22, 0.46), Color(GOLD, 0.95) if sel else Color(0.5, 0.4, 0.7, 0.6), 5, 2 if sel else 1)
				draw_icon(canvas, _tray[i], p, 26.0)
				if sel:
					var name_text := _tray[i].display_name
					var w := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
					canvas.draw_string_outline(font, Vector2(p.x - w * 0.5, p.y - 22), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color(0.06, 0.03, 0.1))
					canvas.draw_string(font, Vector2(p.x - w * 0.5, p.y - 22), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, GOLD)
		Phase.STIR:
			var arrow := 1.0 if _clockwise() else -1.0
			_ellipse_arc(canvas, 0.0, TAU, Color(0.6, 0.5, 0.9, 0.18), 3.0)
			if _stir > 0.0:
				_ellipse_arc(canvas, -PI * 0.5, -PI * 0.5 + TAU * _stir * arrow, Color(_target(), 0.3), 8.0)
				_ellipse_arc(canvas, -PI * 0.5, -PI * 0.5 + TAU * _stir * arrow, _target().lightened(0.25), 3.0)
			for i in 3:
				var a := -PI * 0.5 + arrow * (t * 1.6 + TAU * i / 3.0)
				var head := POT_CENTER + Vector2(cos(a), sin(a)) * STIR_RING
				var tangent := Vector2(-sin(a) * STIR_RING.x, cos(a) * STIR_RING.y).normalized() * arrow
				var normal := Vector2(tangent.y, -tangent.x)
				canvas.draw_colored_polygon(PackedVector2Array([head + tangent * 6.0, head - tangent * 3.0 + normal * 4.0, head - tangent * 3.0 - normal * 4.0]), Color(GOLD, 0.85))
			var pct := "%d%%" % int(_stir * 100.0)
			var pw := font.get_string_size(pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			canvas.draw_string_outline(font, Vector2(POT_CENTER.x - pw * 0.5, TRAY_Y + 4), pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(0.06, 0.03, 0.1))
			canvas.draw_string(font, Vector2(POT_CENTER.x - pw * 0.5, TRAY_Y + 4), pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PARCHMENT)
		Phase.LIFT:
			var bar := Rect2(40, TRAY_Y - 6, BOARD_SIZE.x - 80, 14)
			draw_box(canvas, bar.grow(3), Color(0.06, 0.03, 0.1, 0.9), Color(0.55, 0.42, 0.8, 0.8), 6)
			var segments := 32
			for i in segments:
				var k := float(i) / (segments - 1)
				canvas.draw_rect(Rect2(bar.position.x + bar.size.x * i / segments, bar.position.y, bar.size.x / segments + 1, bar.size.y), MURKY.lerp(_target(), k))
			var zone := Rect2(bar.position.x + bar.size.x * _zone.x, bar.position.y - 4, bar.size.x * (_zone.y - _zone.x), bar.size.y + 8)
			var pulse := 0.6 + 0.4 * sin(t * 5.0)
			canvas.draw_rect(zone.grow(3), Color(GOLD, 0.15 * pulse))
			canvas.draw_rect(zone, Color(1, 1, 1, 0.12))
			canvas.draw_rect(zone, Color(GOLD, 0.9), false, 2.0)
			var mx := bar.position.x + bar.size.x * _lift_value()
			var inside := _lift_value() >= _zone.x and _lift_value() <= _zone.y
			canvas.draw_line(Vector2(mx, bar.position.y - 2), Vector2(mx, bar.end.y + 2), Color.WHITE, 2.0)
			diamond(canvas, Vector2(mx, bar.position.y - 7), 5.0, GOOD if inside else PARCHMENT)
			diamond(canvas, Vector2(mx, bar.end.y + 7), 5.0, GOOD if inside else PARCHMENT)


func _draw_fire(canvas: Control, t: float) -> void:
	var base_y := FIRE_Y
	canvas.draw_circle(Vector2(POT_CENTER.x, base_y - 6), 50.0, Color(1.0, 0.5, 0.2, 0.07))
	for side: float in [-1.0, 1.0]:
		var a := Vector2(POT_CENTER.x - 40 * side, base_y + 4)
		var b := Vector2(POT_CENTER.x + 26 * side, base_y - 2)
		canvas.draw_line(a, b, Color(0.3, 0.18, 0.1), 7.0)
		canvas.draw_line(a, b, Color(0.45, 0.28, 0.16), 3.0)
	for i in 6:
		var x := POT_CENTER.x - 35 + i * 14
		var h := 12.0 + sin(t * 9.0 + i * 1.7) * 4.0 + (5.0 if i % 2 == 0 else 0.0)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x - 8, base_y), Vector2(x + sin(t * 7.0 + i) * 2.5, base_y - h), Vector2(x + 8, base_y)]), Color(0.95, 0.35, 0.15, 0.85))
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x - 4, base_y), Vector2(x + sin(t * 8.0 + i) * 1.5, base_y - h * 0.6), Vector2(x + 4, base_y)]), Color(1.0, 0.82, 0.35, 0.95))


func _draw_pot(canvas: Control, liquid: Color) -> void:
	var body := Color(0.13, 0.11, 0.16)
	# Kaki.
	for side: float in [-1.0, 1.0]:
		canvas.draw_rect(Rect2(POT_CENTER.x + side * 44 - 4, 172, 8, 18), Color(0.1, 0.08, 0.12))
	# Badan bulat dengan bayangan dan kilap kiri.
	var belly := Vector2(POT_CENTER.x, POT_CENTER.y + 24)
	canvas.draw_rect(Rect2(POT_CENTER.x - 76, POT_CENTER.y, 152, 24), body)
	_draw_ellipse(canvas, belly, Vector2(76, 60), body)
	_draw_ellipse(canvas, belly + Vector2(16, 10), Vector2(54, 44), Color(0.08, 0.06, 0.1, 0.6))
	canvas.draw_arc(belly, 66, PI * 0.72, PI * 1.05, 16, Color(0.4, 0.36, 0.5, 0.5), 3.0)
	canvas.draw_rect(Rect2(POT_CENTER.x - 76, POT_CENTER.y + 14, 152, 5), Color(0.22, 0.18, 0.26))
	# Bibir kuali.
	_draw_ellipse(canvas, POT_CENTER, POT_RADIUS + Vector2(9, 6), Color(0.26, 0.23, 0.3))
	_draw_ellipse(canvas, POT_CENTER + Vector2(0, -1), POT_RADIUS + Vector2(5, 3), Color(0.08, 0.06, 0.1))
	# Cairan + pendar + pusaran.
	canvas.draw_circle(POT_CENTER, POT_RADIUS.x + 14, Color(liquid, 0.08))
	_draw_ellipse(canvas, POT_CENTER, POT_RADIUS, liquid)
	_draw_ellipse(canvas, POT_CENTER + Vector2(-10, -6), POT_RADIUS * Vector2(0.55, 0.4), Color(liquid.lightened(0.25), 0.5))
	for i in 3:
		var r := 0.3 + i * 0.22
		var start := _stir_angle * (1.0 - i * 0.2) + i * 2.0
		var pts := PackedVector2Array()
		for s in 9:
			var a := start + s * 0.22
			pts.append(POT_CENTER + Vector2(cos(a) * POT_RADIUS.x * r, sin(a) * POT_RADIUS.y * r))
		canvas.draw_polyline(pts, Color(liquid.lightened(0.45), 0.45), 1.5)
	for b in _bubbles:
		var p := POT_CENTER + Vector2(b.x * POT_RADIUS.x, b.y * POT_RADIUS.y)
		canvas.draw_arc(p, 1.5 + b.z * 3.0, 0, TAU, 10, Color(liquid.lightened(0.55), 1.0 - b.z), 1.0)
	if _splash > 0.0:
		var ring := (1.0 - _splash)
		canvas.draw_arc(POT_CENTER, 12.0 + ring * 48.0, 0, TAU, 32, Color(1, 1, 1, _splash * 0.6), 2.0)
	# Sendok kayu.
	var tip := POT_CENTER + Vector2(cos(_stir_angle), sin(_stir_angle)) * Vector2(POT_RADIUS.x * 0.55, POT_RADIUS.y * 0.55)
	var handle := tip + Vector2(20, -60)
	canvas.draw_line(tip, handle, Color(0.35, 0.22, 0.12), 6.0)
	canvas.draw_line(tip + Vector2(-1, 0), handle + Vector2(-1, 0), Color(0.62, 0.42, 0.25), 3.0)
	_draw_ellipse(canvas, tip, Vector2(6, 3), Color(0.5, 0.33, 0.2))
	canvas.draw_circle(handle, 3.5, Color(0.45, 0.3, 0.18))


func _ellipse_arc(canvas: Control, from: float, to: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	var steps := maxi(2, int(absf(to - from) / TAU * 64.0))
	for i in steps + 1:
		var a := lerpf(from, to, float(i) / steps)
		points.append(POT_CENTER + Vector2(cos(a), sin(a)) * STIR_RING)
	canvas.draw_polyline(points, color, width)


static func _draw_ellipse(canvas: Control, center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	canvas.draw_colored_polygon(points, color)
