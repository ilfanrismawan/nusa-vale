class_name NightStalker
extends Node2D

## Penunggu malam (GDD 4.1, Horor Tengah Malam). Dibuat oleh NightHorror setelah 01.00.
## Hanya bergerak saat tidak dilihat: begitu pemain menghadapnya, ia diam.
## Ditatap terlalu lama, ia menghilang lalu muncul lagi di belakang pemain.
## Disentuh = jumpscare + energi berkurang. Cahaya mengusirnya.
## Scene contoh: scenes/horror/kuntilanak.tscn, scenes/horror/pocong.tscn.

signal finished

enum MoveStyle { GLIDE, HOP }

@export var display_name: String = "Penunggu"
@export var move_style: MoveStyle = MoveStyle.GLIDE

@export_group("Gerak")
## GLIDE: kecepatan melayang maksimal (px/detik). Pemain berjalan ±25, berlari ±45.
@export var glide_speed: float = 34.0
@export var glide_accel: float = 40.0
## HOP: jarak satu lompatan, lama di udara, jeda antar lompatan.
@export var hop_distance: float = 18.0
@export var hop_time: float = 0.32
@export var hop_pause: float = 0.38
@export var hop_height: float = 9.0

@export_group("Dilihat")
## Setengah sudut pandang pemain (derajat). Di dalam sudut ini makhluk membeku.
@export_range(10.0, 90.0, 1.0) var view_half_angle: float = 62.0
@export var view_distance: float = 230.0
## Ditatap selama ini (detik), makhluk menghilang lalu muncul di belakang pemain.
@export var watch_relocate_time: float = 3.5
@export var max_relocations: int = 2
## Muncul lagi pada jarak ini dari pemain.
@export var relocate_distance: float = 70.0

@export_group("Bahaya")
@export var lifetime: float = 75.0
@export var touch_radius: float = 11.0
## Dalam radius ini rasa takut naik cepat dan layar sesekali glitch.
@export var aura_radius: float = 110.0
@export var aura_fear_per_second: float = 0.35
@export var stamina_penalty: int = 25
## Cahaya (lampu/api) mengusir makhluk ini.
@export var repelled_by_light: bool = true

@export_group("Tampilan")
@export var jumpscare_texture: Texture2D
## Warna di atas 1 sengaja: tetap pucat bercahaya di bawah CanvasModulate malam.
@export var glow: Color = Color(2.1, 2.1, 2.3, 1.0)
@export var draw_shadow: bool = true

@export_group("Suara")
## Kosong = suara sintesis bawaan (GLIDE: tawa, HOP: hentakan).
@export var spawn_sound: AudioStream
@export var jumpscare_sound: AudioStream
@export_range(-40.0, 12.0, 0.5) var spawn_volume_db: float = -6.0
@export_range(-40.0, 12.0, 0.5) var presence_volume_db: float = -4.0

@export_group("Teks")
@export_multiline var notify_spawn: String = ""
## %d = energi yang hilang.
@export_multiline var notify_touch: String = "Kamu terhuyung ketakutan. Energi -%d."
@export_multiline var notify_repelled: String = "Cahaya membuatnya mundur ke kegelapan."

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var presence: AudioStreamPlayer2D = get_node_or_null("Presence")

var target: Player
## NightHorror milik pemain target (tanpa tipe: scriptnya tidak punya class_name).
var horror
var _life := 0.0
var _speed := 0.0
var _watch := 0.0
var _relocations := 0
var _fade := 0.0
var _leaving := false
var _relocating := false
var _hop_t := 0.0
var _hop_from := Vector2.ZERO
var _hop_to := Vector2.ZERO
var _in_air := false
var _bob := 0.0
var _sprite_base := Vector2.ZERO
var _rng := RandomNumberGenerator.new()


func setup(p_target: Player, p_horror: Node) -> void:
	target = p_target
	horror = p_horror


func _ready() -> void:
	_rng.randomize()
	_life = lifetime
	_sprite_base = sprite.position
	sprite.self_modulate = glow
	modulate.a = 0.0
	_hop_t = hop_pause
	_play_idle()
	if presence != null:
		if presence.stream == null:
			presence.stream = HorrorSynth.get_stream(&"presence")
		presence.volume_db = presence_volume_db
		presence.play()
	var cue: AudioStream = spawn_sound
	if cue == null:
		cue = HorrorSynth.get_stream(&"giggle") if move_style == MoveStyle.GLIDE else HorrorSynth.get_stream(&"footstep")
	_play_cue(cue, spawn_volume_db, 0.55 if move_style == MoveStyle.HOP else 1.0)
	if not notify_spawn.is_empty():
		Notify.say(notify_spawn)


func _process(delta: float) -> void:
	if _leaving:
		_fade = move_toward(_fade, 0.0, delta * 1.6)
		modulate.a = _fade
		sprite.position = _sprite_base + Vector2(_rng.randf_range(-1, 1), 0).round()
		if _fade <= 0.0:
			finished.emit()
			queue_free()
		return
	if not _relocating:
		_fade = move_toward(_fade, 1.0, delta * 0.8)
		modulate.a = _fade
	if not _target_ok():
		leave()
		return
	_life -= delta
	if _life <= 0.0:
		leave()
		return
	if repelled_by_light and (horror.is_near_light() or horror.is_lit(global_position)):
		if not notify_repelled.is_empty() and _fade > 0.3:
			Notify.say(notify_repelled)
		leave()
		return

	var feet := _target_feet()
	var dist := global_position.distance_to(feet)
	if dist <= touch_radius and _fade > 0.5:
		horror.stalker_touched(self)
		_leaving = true
		_fade = 0.0
		modulate.a = 0.0
		return
	if dist < aura_radius:
		var k := 1.0 - dist / aura_radius
		horror.add_fear(aura_fear_per_second * k * delta)
		if dist < 55.0 and _rng.randf() < delta * 1.5:
			horror.pulse_glitch(0.35)

	var watched := is_watched()
	if watched:
		_watch += delta
		_speed = 0.0
		sprite.speed_scale = 0.0 if _in_air else 0.25
		if _watch >= watch_relocate_time and _relocations < max_relocations and not _relocating:
			_relocate()
	else:
		_watch = maxf(0.0, _watch - delta * 0.5)
		sprite.speed_scale = 1.0
		if not _relocating:
			_move(delta, feet)
	_animate_bob(delta, watched)
	queue_redraw()


func leave() -> void:
	if _leaving:
		return
	_leaving = true
	if presence != null:
		var tw := create_tween()
		tw.tween_property(presence, "volume_db", -60.0, 0.8)


## true bila salah satu pemain di area ini menghadap makhluk (dalam sudut dan jarak pandang).
func is_watched() -> bool:
	var world := get_parent()
	for node in get_tree().get_nodes_in_group(&"night_players"):
		var p := node as Player
		if p == null or not p.is_inside_tree() or p.world_root() != world:
			continue
		var to_me := global_position - (p.global_position + Player.FEET_OFFSET)
		var d := to_me.length()
		if d > view_distance:
			continue
		if d < 6.0:
			return true
		if p.facing_direction.normalized().dot(to_me / d) >= cos(deg_to_rad(view_half_angle)):
			return true
	return false


func _target_ok() -> bool:
	return is_instance_valid(target) and is_instance_valid(horror) and horror.outdoor_intensity() > 0.0 and target.world_root() == get_parent()


func _target_feet() -> Vector2:
	return target.global_position + Player.FEET_OFFSET


func _move(delta: float, feet: Vector2) -> void:
	match move_style:
		MoveStyle.GLIDE:
			_speed = move_toward(_speed, glide_speed, glide_accel * delta)
			var dir := (feet - global_position).normalized()
			var side := dir.orthogonal() * sin(_life * 2.3) * 0.35
			global_position += (dir + side).normalized() * _speed * delta
			sprite.flip_h = dir.x < 0.0
			# Dekat: mulut menganga.
			var near := global_position.distance_to(feet) < 45.0
			if near and sprite.sprite_frames.has_animation(&"lunge") and sprite.animation != &"lunge":
				sprite.play(&"lunge")
			elif not near and sprite.animation == &"lunge":
				_play_idle()
		MoveStyle.HOP:
			_hop_t -= delta
			if not _in_air:
				if _hop_t <= 0.0:
					_in_air = true
					_hop_t = hop_time
					_hop_from = global_position
					var step := minf(hop_distance, global_position.distance_to(feet))
					_hop_to = global_position + (feet - global_position).normalized() * step
					if sprite.sprite_frames.has_animation(&"hop"):
						sprite.play(&"hop")
			else:
				var k := clampf(1.0 - _hop_t / hop_time, 0.0, 1.0)
				global_position = _hop_from.lerp(_hop_to, k)
				if _hop_t <= 0.0:
					_in_air = false
					_hop_t = hop_pause
					_land()


func _land() -> void:
	_play_idle()
	var dist := global_position.distance_to(_target_feet())
	_play_cue(HorrorSynth.get_stream(&"footstep"), lerpf(-4.0, -16.0, clampf(dist / 200.0, 0.0, 1.0)), 0.55)
	if dist < 70.0 and not Coop.active:
		Juice.shake(0.6, 0.08)


func _animate_bob(delta: float, watched: bool) -> void:
	if move_style == MoveStyle.GLIDE:
		_bob += delta * (0.6 if watched else 2.2)
		sprite.position = _sprite_base + Vector2(0, roundf(sin(_bob) * 1.5))
		if watched and _watch > 1.2:
			# Diam menatap balik; sesekali berkedut.
			if _rng.randf() < delta * 2.0:
				sprite.position.x += _rng.randf_range(-1.0, 1.0)
	else:
		var lift := 0.0
		if _in_air:
			var k := clampf(1.0 - _hop_t / hop_time, 0.0, 1.0)
			lift = sin(PI * k) * hop_height
		sprite.position = _sprite_base - Vector2(0, roundf(lift))


func _relocate() -> void:
	_relocating = true
	_relocations += 1
	_watch = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func() -> void:
		var back := -target.facing_direction.normalized()
		if back == Vector2.ZERO:
			back = Vector2.DOWN
		var spot := _target_feet() + back.rotated(_rng.randf_range(-0.6, 0.6)) * relocate_distance
		global_position = spot.round()
		_in_air = false
		_hop_t = hop_pause
		_play_cue(HorrorSynth.get_stream(&"whisper"), -6.0, _rng.randf_range(0.8, 0.95))
		horror.add_fear(0.12)
		horror.pulse_glitch(0.6))
	tw.tween_interval(0.25)
	tw.tween_property(self, "modulate:a", 1.0, 0.35)
	tw.tween_callback(func() -> void:
		_fade = 1.0
		_relocating = false)


func _play_idle() -> void:
	var anim := &"float" if sprite.sprite_frames.has_animation(&"float") else &"idle"
	if sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)


func _play_cue(stream: AudioStream, volume_db: float, pitch: float) -> void:
	if stream == null:
		return
	var p := AudioStreamPlayer2D.new()
	p.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.max_distance = 900.0
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _draw() -> void:
	if not draw_shadow or move_style != MoveStyle.GLIDE:
		return
	var w := 6.0 + sin(_bob) * 0.8
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, w, Color(0.02, 0.01, 0.03, 0.45))
