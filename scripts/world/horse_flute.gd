class_name HorseFlute
extends Node2D
## Seruling Kuda (GDD 4.10.10): dipegang lalu dipakai di area luar, kuda berlari datang ke sisi pemain.
## Pemindahan kuda ada di StructureManager.call_horse(); node ini hanya juice di atas kepala pemain:
## pose meniup dari sheet karakter, lalu not balok berwarna yang naik bergoyang dan memudar
## (abu-abu bila kuda tidak bisa datang).
const ITEM_ID := "horse_flute"
const COOLDOWN_MS := 1500
const NOTE_COLORS := [Color("fff1c9"), Color("ffd36e"), Color("8fd3ff")]
const NOTE_GRAY := Color("a59aa6")
const OUTLINE := Color("302333")
const LIFE := 1.3

var _notes: Array[Dictionary] = []
var _spawn_left := 3
var _spawn_timer := 0.0
var _failed := false


## Tiup seruling dari tas. true bila kuda dipanggil (atau sudah di sisi pemain).
static func play(player: Player) -> bool:
	var now := Time.get_ticks_msec()
	if now - int(player.get_meta(&"horse_flute_ms", -COOLDOWN_MS)) < COOLDOWN_MS:
		return false
	player.set_meta(&"horse_flute_ms", now)
	var result := StructureManager.call_horse(player)
	# Pose meniup seruling (character_catalog: PNG/22. Flute + layer Flute.png/Fx.png), sekali main.
	player._clear_pickup_visual()
	player.animation_controller.set_direction(player.facing_direction)
	var posed := player.animation_controller.play_item_gesture(&"flute")
	var feet := player.global_position + Player.FEET_OFFSET
	# Gagal: nada lebih rendah dan not abu-abu, seperti tiupan yang tak terjawab.
	Juice.play(&"horse_flute", feet, 0.0 if result.ok else -5.0)
	Juice.ripple(feet, Color("ffd36e") if result.ok else NOTE_GRAY, 16.0)
	var fx := HorseFlute.new()
	fx._failed = not result.ok
	# Not berwarna menyusul not kecil dari sheet animasi supaya tidak bertumpuk.
	fx._spawn_timer = 0.45 if posed else 0.0
	player.add_child(fx)
	fx.position = Player.SPRITE_OFFSET + Vector2(0, -22)
	# Tanpa animasi seruling (mis. sprite lama), pemain tetap sedikit membusung saat meniup.
	var body := player.animation_controller.sprite as Node2D
	if body != null and not posed:
		var tween := player.create_tween()
		tween.tween_property(body, "scale", Vector2(0.92, 1.1), 0.08)
		tween.tween_property(body, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	Notify.say(result.message)
	return result.ok


func _ready() -> void:
	z_index = 30
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	# Tiga not keluar mengikuti tiga nada SFX (selang 0,2 detik).
	_spawn_timer -= delta
	if _spawn_left > 0 and _spawn_timer <= 0.0:
		_spawn_timer = 0.2
		var index := 3 - _spawn_left
		_notes.append({"pos": Vector2(randf_range(-3, 3), 0), "age": 0.0, "phase": randf() * TAU,
			"color": NOTE_GRAY if _failed else NOTE_COLORS[index], "double": index == 2})
		_spawn_left -= 1
	for note in _notes:
		note.age += delta
		note.pos.y -= (20.0 if not _failed else 9.0) * delta
	_notes.assign(_notes.filter(func(n: Dictionary) -> bool: return n.age < LIFE))
	if _spawn_left == 0 and _notes.is_empty():
		queue_free()
	queue_redraw()


func _draw() -> void:
	for note in _notes:
		var t: float = note.age / LIFE
		var sway := sin(note.age * 7.0 + note.phase) * 4.0
		var pop := minf(1.0, note.age / 0.12)
		var alpha := 1.0 - maxf(0.0, (t - 0.6) / 0.4)
		var at: Vector2 = (note.pos + Vector2(sway, 0)).round()
		draw_set_transform(at, sin(note.age * 5.0 + note.phase) * 0.25, Vector2.ONE * (0.6 + 0.4 * pop))
		_draw_note(note.color * Color(1, 1, 1, alpha), OUTLINE * Color(1, 1, 1, alpha), note.double)
	draw_set_transform(Vector2.ZERO)


## Not 1/8 (kepala oval, batang, bendera) atau not ganda, digambar dengan garis luar gelap.
func _draw_note(fill: Color, outline: Color, double: bool) -> void:
	var heads: Array[Vector2] = [Vector2(-3, 0)]
	if double:
		heads = [Vector2(-5, 1), Vector2(2, 0)]
	for pass_index in 2:
		var color := outline if pass_index == 0 else fill
		var grow := 1.0 if pass_index == 0 else 0.0
		for head in heads:
			draw_circle(head, 2.0 + grow, color)
			draw_rect(Rect2(head + Vector2(1 - grow, -8 - grow), Vector2(1 + grow * 2, 8 + grow * 2)), color)
		if double:
			draw_rect(Rect2(Vector2(-4 - grow, -9 - grow), Vector2(7 + grow * 2, 2 + grow * 2)), color)
		else:
			draw_rect(Rect2(Vector2(-1 - grow, -8 - grow), Vector2(3 + grow * 2, 2 + grow * 2)), color)
			draw_rect(Rect2(Vector2(1 - grow, -6 - grow), Vector2(1 + grow * 2, 2 + grow * 2)), color)
