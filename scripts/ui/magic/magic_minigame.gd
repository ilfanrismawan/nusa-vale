extends CanvasLayer

## Dasar mini game sihir (GDD "Menara Penyihir & Mini Game Sihir"): panel grimoire gelap berbingkai
## emas di tengah layar dengan papan gambar (board) yang digambar sendiri oleh turunan lewat
## _draw_board(). Papan punya latar langit berbintang, partikel kilau, lilin nyawa, bar waktu,
## dan banner hasil yang sama untuk semua mini game.
## Hanya pemain pemilik yang dikunci (co-op: pemain lain tetap bebas; solo: game dijeda lewat
## Coop.set_menu_open). Selesai -> sinyal finished(success). Batal (tombol B/Esc) = gagal tanpa
## biaya (cancelled = true), pemanggil yang memutuskan akibatnya.

signal finished(success: bool)

const ServiceTheme = preload("res://scripts/ui/farm_service_theme.gd")
const BOARD_SIZE := Vector2(380, 240)
const RESULT_SECONDS := 1.3
const GOOD := Color(0.55, 1.0, 0.7)
const BAD := Color(1.0, 0.45, 0.45)
const GOLD := Color(0.98, 0.82, 0.45)
const PARCHMENT := Color(0.95, 0.9, 0.8)
const MUTED := Color(0.72, 0.66, 0.82)
const MAGIC_INK := Color(0.42, 0.25, 0.62)
const PANEL_BG := Color(0.1, 0.07, 0.16, 0.97)
const SKY_TOP := Color(0.13, 0.08, 0.22)
const SKY_BOTTOM := Color(0.05, 0.03, 0.09)
const STAR_COUNT := 34
const MAX_PARTICLES := 160

var player: Player
var title := "Sihir"
## true bila pemain membatalkan sendiri.
var cancelled := false

var board: Control
var _panel: PanelContainer
var _title_label: Label
var _hint_label: Label
var _status_label: Label
var _done := false
var _success := false
var _result := -1.0
var _flash := 0.0
var _flash_color := Color.WHITE
var _shake := 0.0
var _age := 0.0
var _stars: Array[Vector3] = []
## Partikel: p posisi, v kecepatan, life sisa umur, max umur awal, c warna, s ukuran.
var _particles: Array[Dictionary] = []


func _ready() -> void:
	layer = ServiceTheme.LAYER + 1
	process_mode = Node.PROCESS_MODE_ALWAYS
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331
	for i in STAR_COUNT:
		_stars.append(Vector3(rng.randf() * BOARD_SIZE.x, rng.randf() * BOARD_SIZE.y, rng.randf() * TAU))
	_build()
	Coop.set_menu_open(player, true)
	_start()
	_animate_open()


func _build() -> void:
	var root := Control.new()
	root.theme = ServiceTheme.make_theme()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.08, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	_panel.add_child(box)
	_title_label = Label.new()
	_title_label.text = title
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", GOLD)
	_title_label.add_theme_color_override("font_outline_color", Color(0.25, 0.1, 0.35))
	_title_label.add_theme_constant_override("outline_size", 4)
	box.add_child(_title_label)
	var ornament := Control.new()
	ornament.custom_minimum_size = Vector2(BOARD_SIZE.x, 8)
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ornament.draw.connect(_draw_ornament.bind(ornament))
	box.add_child(ornament)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _board_frame_style())
	box.add_child(frame)
	board = Control.new()
	board.custom_minimum_size = BOARD_SIZE
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.clip_contents = true
	board.draw.connect(_on_board_draw)
	board.gui_input.connect(_on_board_gui_input)
	frame.add_child(board)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 17)
	_status_label.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.1))
	_status_label.add_theme_constant_override("outline_size", 3)
	box.add_child(_status_label)
	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(BOARD_SIZE.x, 0)
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.add_theme_color_override("font_color", MUTED)
	box.add_child(_hint_label)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = GOLD.darkened(0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.45, 0.25, 0.85, 0.35)
	style.shadow_size = 14
	style.set_content_margin_all(12)
	style.content_margin_top = 8
	return style


func _board_frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = SKY_BOTTOM
	style.border_color = Color(0.55, 0.42, 0.8, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(2)
	return style


func _animate_open() -> void:
	_panel.modulate = Color(1, 1, 1, 0)
	_panel.scale = Vector2(0.92, 0.92)
	_panel.resized.connect(func() -> void: _panel.pivot_offset = _panel.size * 0.5)
	var tween := _panel.create_tween().set_parallel(true)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.18)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw_ornament(canvas: Control) -> void:
	var mid := canvas.size * 0.5
	var half := minf(130.0, mid.x - 10.0)
	canvas.draw_line(Vector2(mid.x - half, mid.y), Vector2(mid.x - 10, mid.y), Color(GOLD, 0.55), 1.0)
	canvas.draw_line(Vector2(mid.x + 10, mid.y), Vector2(mid.x + half, mid.y), Color(GOLD, 0.55), 1.0)
	diamond(canvas, mid, 4.0, GOLD)
	diamond(canvas, Vector2(mid.x - half, mid.y), 2.0, Color(GOLD, 0.7))
	diamond(canvas, Vector2(mid.x + half, mid.y), 2.0, Color(GOLD, 0.7))


func input() -> PlayerInput:
	return player.input if is_instance_valid(player) else PlayerInput.solo()


func set_status(text: String, color: Color = PARCHMENT) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)


func set_hint(text: String) -> void:
	_hint_label.text = text


func flash(color: Color) -> void:
	_flash = 1.0
	_flash_color = color
	if color == BAD:
		_shake = 1.0


## Ledakan partikel kilau di posisi papan.
func burst(pos: Vector2, color: Color, count: int = 12, speed: float = 70.0) -> void:
	for i in count:
		var angle := randf() * TAU
		_spawn(pos, Vector2(cos(angle), sin(angle)) * speed * randf_range(0.35, 1.0), randf_range(0.35, 0.8), color, randf_range(1.0, 2.4))


## Satu partikel kilau (jejak tongkat, uap, dsb.).
func sparkle(pos: Vector2, velocity: Vector2, color: Color, life: float = 0.6, size: float = 1.6) -> void:
	_spawn(pos, velocity, life, color, size)


func _spawn(pos: Vector2, velocity: Vector2, life: float, color: Color, size: float) -> void:
	if _particles.size() >= MAX_PARTICLES:
		_particles.remove_at(0)
	_particles.append({"p": pos, "v": velocity, "life": life, "max": life, "c": color, "s": size})


func is_done() -> bool:
	return _done


## Detik sejak panel dibuka; dipakai turunan untuk animasi.
func age() -> float:
	return _age


func _process(delta: float) -> void:
	_age += delta
	_flash = maxf(0.0, _flash - delta * 3.0)
	_shake = maxf(0.0, _shake - delta * 4.0)
	for i in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[i]
		p["life"] = float(p["life"]) - delta
		if float(p["life"]) <= 0.0:
			_particles.remove_at(i)
			continue
		p["p"] = Vector2(p["p"]) + Vector2(p["v"]) * delta
		p["v"] = Vector2(p["v"]) * (1.0 - 2.2 * delta) + Vector2(0, -12.0 * delta)
	if _done:
		_result -= delta
		if _result <= 0.0:
			_close()
		board.queue_redraw()
		return
	_tick(delta)
	board.queue_redraw()


func _input(event: InputEvent) -> void:
	if _done or not Coop.accepts_event(player, event):
		return
	if input().is_event(event, &"ui_cancel"):
		cancelled = true
		finish(false, "Dibatalkan.")
		get_viewport().set_input_as_handled()
		return
	if _handle_input(event):
		get_viewport().set_input_as_handled()


func _on_board_gui_input(event: InputEvent) -> void:
	if _done or not Coop.accepts_event(player, event):
		return
	_board_pointer(event)


func _on_board_draw() -> void:
	var shake_offset := Vector2(sin(_age * 70.0), cos(_age * 53.0)) * 3.0 * _shake
	board.draw_set_transform(shake_offset)
	_draw_sky(board)
	_draw_board(board)
	_draw_particles(board)
	_draw_hud(board)
	board.draw_set_transform(Vector2.ZERO)
	if _flash > 0.0:
		board.draw_rect(Rect2(Vector2.ZERO, BOARD_SIZE), Color(_flash_color, 0.2 * _flash))
	if _done and not cancelled:
		_draw_result(board)


func _draw_sky(canvas: Control) -> void:
	var bands := 12
	for i in bands:
		var k := float(i) / (bands - 1)
		canvas.draw_rect(Rect2(0, BOARD_SIZE.y * i / bands, BOARD_SIZE.x, BOARD_SIZE.y / bands + 1), SKY_TOP.lerp(SKY_BOTTOM, k))
	canvas.draw_circle(BOARD_SIZE * 0.5, BOARD_SIZE.y * 0.62, Color(0.45, 0.3, 0.75, 0.06))
	for s in _stars:
		var twinkle := 0.35 + 0.65 * absf(sin(_age * 1.4 + s.z))
		var c := Color(0.9, 0.85, 1.0, 0.55 * twinkle)
		canvas.draw_rect(Rect2(Vector2(s.x, s.y), Vector2.ONE * (2.0 if s.z > 5.0 else 1.0)), c)
		if s.z > 5.6 and twinkle > 0.85:
			canvas.draw_line(Vector2(s.x - 3, s.y + 0.5), Vector2(s.x + 4, s.y + 0.5), Color(c, 0.4), 1.0)
			canvas.draw_line(Vector2(s.x + 0.5, s.y - 3), Vector2(s.x + 0.5, s.y + 4), Color(c, 0.4), 1.0)
	# Sudut grimoire.
	for corner: Vector2 in [Vector2(6, 6), Vector2(BOARD_SIZE.x - 6, 6), Vector2(6, BOARD_SIZE.y - 6), BOARD_SIZE - Vector2(6, 6)]:
		var dir := Vector2(signf(BOARD_SIZE.x * 0.5 - corner.x), signf(BOARD_SIZE.y * 0.5 - corner.y))
		canvas.draw_line(corner, corner + Vector2(dir.x * 14, 0), Color(GOLD, 0.35), 1.0)
		canvas.draw_line(corner, corner + Vector2(0, dir.y * 14), Color(GOLD, 0.35), 1.0)
		diamond(canvas, corner + dir * 3.0, 1.5, Color(GOLD, 0.5))


func _draw_particles(canvas: Control) -> void:
	for p in _particles:
		var k := float(p["life"]) / float(p["max"])
		var c: Color = p["c"]
		var size := float(p["s"]) * (0.5 + 0.5 * k)
		canvas.draw_circle(Vector2(p["p"]), size * 2.2, Color(c, 0.15 * k))
		canvas.draw_circle(Vector2(p["p"]), size, Color(c.lightened(0.3), 0.9 * k))


## Lilin nyawa (kanan atas) dari _mistake_state(), bar waktu (bawah) dari _time_ratio().
func _draw_hud(canvas: Control) -> void:
	var state := _mistake_state()
	if state.y > 0:
		var left := state.y - state.x
		for i in state.y:
			var pos := Vector2(BOARD_SIZE.x - 16 - i * 13, 14)
			var lit := i < left
			canvas.draw_rect(Rect2(pos + Vector2(-2.5, 0), Vector2(5, 9)), Color(0.92, 0.88, 0.78) if lit else Color(0.4, 0.36, 0.42))
			canvas.draw_rect(Rect2(pos + Vector2(-3.5, 9), Vector2(7, 2)), Color(0.55, 0.42, 0.3))
			if lit:
				var flicker := 1.0 + sin(_age * 13.0 + i * 2.0) * 0.15
				canvas.draw_circle(pos + Vector2(0, -3), 5.0 * flicker, Color(1.0, 0.65, 0.25, 0.22))
				canvas.draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -7 * flicker), pos + Vector2(2, -1.5), pos + Vector2(0, 0), pos + Vector2(-2, -1.5)]), Color(1.0, 0.85, 0.4))
			else:
				canvas.draw_line(pos + Vector2(0, -1), pos + Vector2(1, -5), Color(0.6, 0.6, 0.65, 0.5), 1.0)
	var ratio := _time_ratio()
	if ratio >= 0.0:
		var bar := Rect2(10, BOARD_SIZE.y - 9, BOARD_SIZE.x - 20, 4)
		canvas.draw_rect(bar.grow(1), Color(0.02, 0.01, 0.05, 0.8))
		var color := Color(0.65, 0.5, 1.0).lerp(Color(1.0, 0.45, 0.35), clampf(1.0 - ratio * 3.0, 0.0, 1.0))
		var fill := Rect2(bar.position, Vector2(bar.size.x * clampf(ratio, 0.0, 1.0), bar.size.y))
		canvas.draw_rect(fill, color)
		canvas.draw_rect(Rect2(fill.position, Vector2(fill.size.x, 1)), Color(1, 1, 1, 0.35))
		if fill.size.x > 2.0:
			canvas.draw_circle(Vector2(fill.end.x, bar.get_center().y), 3.5, Color(color.lightened(0.4), 0.9))


func _draw_result(canvas: Control) -> void:
	var k := clampf((RESULT_SECONDS - _result) / 0.25, 0.0, 1.0)
	var center := BOARD_SIZE * 0.5
	var color := GOOD if _success else BAD
	canvas.draw_rect(Rect2(Vector2.ZERO, BOARD_SIZE), Color(0.02, 0.01, 0.05, 0.4 * k))
	if _success:
		for i in 12:
			var a := _age * 0.6 + TAU * i / 12.0
			var tip := center + Vector2(cos(a), sin(a)) * 150.0 * k
			var side := Vector2(cos(a + PI * 0.5), sin(a + PI * 0.5)) * 9.0 * k
			canvas.draw_colored_polygon(PackedVector2Array([center, tip + side, tip - side]), Color(GOLD, 0.1))
	var band := Rect2(0, center.y - 20, BOARD_SIZE.x, 40)
	canvas.draw_rect(band, Color(0.06, 0.03, 0.12, 0.85 * k))
	canvas.draw_line(band.position, Vector2(band.end.x, band.position.y), Color(color, 0.8 * k), 1.0)
	canvas.draw_line(Vector2(0, band.end.y), band.end, Color(color, 0.8 * k), 1.0)
	var font := ServiceTheme.FONT
	var text := "BERHASIL!" if _success else "GAGAL"
	var size := 26
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(center.x - width * 0.5, center.y + size * 0.35)
	canvas.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0.08, 0.03, 0.12, k))
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(GOLD if _success else color, k))


## Selesaikan mini game; hasil ditampilkan sebentar lalu panel tertutup.
func finish(success: bool, text: String = "") -> void:
	if _done:
		return
	_done = true
	_success = success
	_result = RESULT_SECONDS if not cancelled else 0.2
	set_status(text if not text.is_empty() else ("Berhasil!" if success else "Gagal..."), GOOD if success else BAD)
	flash(GOOD if success else BAD)
	if success:
		burst(BOARD_SIZE * 0.5, GOLD, 36, 150.0)
		burst(BOARD_SIZE * 0.5, GOOD, 18, 100.0)
	play(&"sparkle" if success else &"escape")
	finished.emit(success)


func _close() -> void:
	set_process(false)
	set_process_input(false)
	Coop.set_menu_open(player, false)
	queue_free()


func _exit_tree() -> void:
	if not _done or _result > 0.0:
		Coop.set_menu_open(player, false)


# ── Diisi turunan ───────────────────────────────────────────────────

func _start() -> void:
	pass


func _tick(_delta: float) -> void:
	pass


## Tombol/keyboard/gamepad. true = event dipakai.
func _handle_input(_event: InputEvent) -> bool:
	return false


## Mouse di dalam papan (posisi lokal papan).
func _board_pointer(_event: InputEvent) -> void:
	pass


func _draw_board(_canvas: Control) -> void:
	pass


## (kesalahan, batas kesalahan) untuk lilin nyawa; y = 0 menyembunyikannya.
func _mistake_state() -> Vector2i:
	return Vector2i.ZERO


## Sisa waktu 0..1 untuk bar bawah; negatif menyembunyikannya.
func _time_ratio() -> float:
	return -1.0


# ── Alat bantu gambar ───────────────────────────────────────────────

static func draw_glow_circle(canvas: Control, center: Vector2, radius: float, color: Color) -> void:
	for i in 4:
		var k := 1.0 - i / 4.0
		canvas.draw_circle(center, radius * (1.0 + i * 0.35), Color(color, color.a * 0.18 * k))
	canvas.draw_circle(center, radius, color)


## Garis dengan pendar lembut di bawahnya.
static func draw_glow_line(canvas: Control, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	canvas.draw_line(a, b, Color(color, color.a * 0.12), width * 3.2)
	canvas.draw_line(a, b, Color(color, color.a * 0.25), width * 1.8)
	canvas.draw_line(a, b, color, width)
	canvas.draw_circle(a, width * 0.5, color)
	canvas.draw_circle(b, width * 0.5, color)


## Kotak sudut bulat.
static func draw_box(canvas: Control, rect: Rect2, bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 4, border_width: int = 1) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width if border.a > 0.0 else 0)
	style.set_corner_radius_all(radius)
	canvas.draw_style_box(style, rect)


static func diamond(canvas: Control, center: Vector2, r: float, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -r), center + Vector2(r, 0), center + Vector2(0, r), center + Vector2(-r, 0)]), color)


static func draw_icon(canvas: Control, item: ItemData, center: Vector2, size: float) -> void:
	if item == null or item.icon == null:
		canvas.draw_circle(center, size * 0.3, Color(0.8, 0.8, 0.9))
		return
	canvas.draw_texture_rect(item.icon, Rect2(center - Vector2.ONE * size * 0.5, Vector2.ONE * size), false)


## Efek suara/umpan balik Juice di posisi pemain.
func play(preset: StringName) -> void:
	if is_instance_valid(player):
		Juice.play(preset, player.global_position)
