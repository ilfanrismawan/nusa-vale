extends CanvasLayer

## Horor malam per pemain (GDD 4.1, Horor Tengah Malam). Scene: scenes/effects/night_horror.tscn,
## dibuat oleh HUD. Interior dan pemain yang tidur tetap tenang.
## Semua angka diatur di Inspector; kejadian ganjil = file di resources/horror/events/.

@export var enabled: bool = true

@export_group("Rasa Takut")
## Kenaikan rasa takut per detik di gelap sebelum 00.00 (dikali kegelapan).
@export var fear_rise_per_second: float = 0.004
## Tambahan kenaikan per detik setelah 00.00.
@export var fear_rise_midnight: float = 0.014
## Batas rasa takut sebelum 00.00.
@export_range(0.0, 1.0, 0.01) var fear_cap_before_midnight: float = 0.45
## Turun per detik saat berdiri dekat cahaya.
@export var fear_fall_near_light: float = 0.15
## Turun per detik di dalam ruangan / saat tidur.
@export var fear_fall_indoors: float = 0.5
## Jarak aman dari cahaya (PointLight2D yang menyala atau node grup "horror_safe_light").
@export var safe_light_radius: float = 72.0

@export_group("Detak Jantung")
## Rasa takut minimal agar detak jantung terdengar.
@export_range(0.0, 1.0, 0.01) var heartbeat_start: float = 0.25
## Jeda antar detak saat baru mulai takut / saat sangat takut (detik).
@export var heartbeat_slow: float = 1.15
@export var heartbeat_fast: float = 0.4
@export_range(-60.0, 6.0, 0.5) var heartbeat_volume_min: float = -28.0
@export_range(-60.0, 6.0, 0.5) var heartbeat_volume_max: float = -4.0
## Kosong = detak sintesis bawaan.
@export var heartbeat_sound: AudioStream
## Mulai rasa takut ini kamera ikut berguncang tiap detak (solo saja).
@export_range(0.0, 1.0, 0.01) var shake_from_fear: float = 0.75
@export_range(0.0, 4.0, 0.1) var shake_strength: float = 1.0

@export_group("Layar")
@export_range(0.0, 2.0, 0.05) var fog_amount: float = 1.0
## Warna memudar setelah 00.00.
@export_range(0.0, 1.0, 0.05) var desaturate_amount: float = 0.55
@export_range(0.0, 0.4, 0.01) var grain_amount: float = 0.08
## Pergeseran warna merah/biru (piksel) saat sangat takut.
@export_range(0.0, 6.0, 0.1) var aberration_px: float = 1.5
## Denyut merah di tepi layar saat jantung berdetak.
@export_range(0.0, 1.0, 0.05) var red_pulse_amount: float = 0.5
@export_range(0.0, 2.0, 0.05) var glitch_amount: float = 1.0

@export_group("Kejadian Ganjil")
@export var events: Array[HorrorEvent] = []
## Kejadian hanya muncul bila malam sudah segelap ini (0,7 = 00.00).
@export_range(0.0, 1.0, 0.01) var events_min_night: float = 0.7
@export var first_event_delay: float = 10.0
@export var event_interval_min: float = 18.0
@export var event_interval_max: float = 38.0
## Rasa takut penuh mempercepat jadwal kejadian sebanyak (1 + nilai ini) kali.
@export var fear_event_speedup: float = 1.0

@export_group("Penunggu")
## Makhluk penguntit (scene dengan script NightStalker). Masukkan dua kali untuk peluang ganda.
@export var stalker_scenes: Array[PackedScene] = []
## Muncul hanya bila malam segelap ini (0,75 = ±01.00) dan rasa takut minimal ini.
@export_range(0.0, 1.0, 0.01) var stalker_min_night: float = 0.75
@export_range(0.0, 1.0, 0.01) var stalker_min_fear: float = 0.45
@export var stalker_first_delay: float = 40.0
## Tiap selang ini diundi dengan peluang stalker_chance.
@export var stalker_check_interval: float = 15.0
@export_range(0.0, 1.0, 0.01) var stalker_chance: float = 0.35
## Jeda setelah makhluk pergi / menyentuh sebelum boleh muncul lagi (detik nyata).
@export var stalker_cooldown: float = 150.0
## Jarak muncul dari pemain, diutamakan di belakangnya.
@export var stalker_spawn_distance: float = 170.0
## Energi boleh habis karena jumpscare (bisa membuat pingsan). Mati = sisa minimal 1.
@export var jumpscare_can_faint: bool = false
@export_range(-20.0, 12.0, 0.5) var jumpscare_volume_db: float = 0.0
@export var jumpscare_lock_seconds: float = 0.9

@export_group("Ambience")
@export_range(-60.0, 0.0, 0.5) var ambience_volume_min: float = -45.0
@export_range(-60.0, 0.0, 0.5) var ambience_volume_max: float = -23.0

var player: Player
## Rasa takut per pemain dibawa saat pindah scene (HUD dibuat ulang tiap scene).
static var _carried_fear: Dictionary = {}
var _key := 0
var intensity := 0.0
## Rasa takut pemain ini, 0..1. Tidak disimpan; habis saat masuk rumah atau tidur.
var fear := 0.0
var midnight := 0.0

@onready var _veil: ColorRect = $Veil
@onready var _jumpscare: TextureRect = get_node_or_null("Jumpscare")
@onready var _flash: ColorRect = get_node_or_null("Flash")
var _material: ShaderMaterial
var _ambience: AudioStreamPlayer
var _heart: AudioStreamPlayer
var _sting: AudioStreamPlayer
var _shadow: ShadowDrawing
var _bus := &"Master"
var _rng := RandomNumberGenerator.new()

var _beat := 0.0
var _beat_timer := 0.0
var _glitch := 0.0
var _blackout := 0.0
var _event_timer := 10.0
var _last_fired: Dictionary = {}

var _lights: Array[Node2D] = []
var _light_world: Node
var _light_refresh := 0.0
var _safe_check := 0.0
var _safe := false

var _step_event: HorrorEvent
var _steps_left := 0
var _steps_total := 0
var _step_timer := 0.0
var _step_idle := 0.0

var _stalker: Node2D
var _stalker_timer := 40.0
var _stalker_ready_at := 0.0
var _scream: AudioStreamPlayer


class ShadowDrawing extends Node2D:
	var life := 0.0
	var location := Vector2.ZERO
	var velocity := Vector2.ZERO
	func _process(delta: float) -> void:
		life = maxf(0.0, life - delta)
		location += velocity * delta
		queue_redraw()
	func _draw() -> void:
		if life <= 0.0:
			return
		var alpha := minf(life, 0.7) * 0.7
		var lean := clampf(velocity.x * 0.012, -8.0, 8.0)
		var c := Color(0.015, 0.025, 0.03, alpha)
		draw_circle(location + Vector2(lean * 0.6, -18), 7, c)
		draw_colored_polygon(PackedVector2Array([location + Vector2(-5 + lean * 0.5, -13), location + Vector2(5 + lean * 0.5, -13), location + Vector2(12, 15), location + Vector2(-12, 15)]), c)
		if velocity.x != 0.0:
			var trail := Color(c.r, c.g, c.b, alpha * 0.35)
			draw_colored_polygon(PackedVector2Array([location + Vector2(-5, -13), location + Vector2(-5 - lean * 4.0, -8), location + Vector2(-12 - lean * 4.0, 12), location + Vector2(-12, 15)]), trail)


## Sepasang mata merah di kegelapan (dunia). Berkedip, lalu hilang bila didekati.
class RedEyes extends Node2D:
	var life := 4.0
	var watcher: Node2D
	var _age := 0.0
	var _fade := 1.0
	var _leaving := false
	func _ready() -> void:
		z_index = 60
	func _process(delta: float) -> void:
		_age += delta
		life -= delta
		if is_instance_valid(watcher) and watcher.global_position.distance_to(global_position) < 40.0:
			_leaving = true
		if life <= 0.0:
			_leaving = true
		if _leaving:
			_fade -= delta * 3.0
			if _fade <= 0.0:
				queue_free()
				return
		queue_redraw()
	func _draw() -> void:
		var appear := minf(1.0, _age * 1.5) * _fade
		var blink := fmod(_age, 1.6) > 1.45
		# Warna di atas 1 sengaja: CanvasModulate malam menggelapkan dunia ±0,3x,
		# jadi mata tetap menyala merah.
		var glow := Color(2.4, 0.1, 0.1, 0.22 * appear)
		draw_circle(Vector2(-3, 0), 3.0, glow)
		draw_circle(Vector2(3, 0), 3.0, glow)
		if blink:
			return
		var eye := Color(3.3, 0.35, 0.25, appear)
		draw_rect(Rect2(-4, -1, 2, 1), eye)
		draw_rect(Rect2(2, -1, 2, 1), eye)
		draw_rect(Rect2(-4, 0, 2, 1), Color(2.0, 0.0, 0.0, appear))
		draw_rect(Rect2(2, 0, 2, 1), Color(2.0, 0.0, 0.0, appear))


## Gagak-gagak hitam yang terbang mendadak menjauh.
class CrowFlock extends Node2D:
	var birds: Array[Dictionary] = []
	var life := 2.6
	func setup(count: int, rng: RandomNumberGenerator, away: Vector2) -> void:
		z_index = 55
		for i in count:
			var dir := away.rotated(rng.randf_range(-0.9, 0.9))
			birds.append({
				"pos": Vector2(rng.randf_range(-10, 10), rng.randf_range(-6, 6)),
				"vel": (dir * rng.randf_range(70, 120) + Vector2(0, -rng.randf_range(40, 80))),
				"phase": rng.randf() * TAU,
			})
	func _process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			queue_free()
			return
		for b in birds:
			b.pos += b.vel * delta
			b.vel *= 1.0 + delta * 0.6
			b.phase += delta * 22.0
		queue_redraw()
	func _draw() -> void:
		var alpha := clampf(life, 0.0, 1.0)
		var c := Color(0.03, 0.02, 0.04, alpha)
		for b in birds:
			var p: Vector2 = (b.pos as Vector2).round()
			var up := sin(float(b.phase)) > 0.0
			draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 2)), c)
			if up:
				draw_rect(Rect2(p + Vector2(-4, -2), Vector2(3, 1)), c)
				draw_rect(Rect2(p + Vector2(2, -2), Vector2(3, 1)), c)
			else:
				draw_rect(Rect2(p + Vector2(-4, 2), Vector2(3, 1)), c)
				draw_rect(Rect2(p + Vector2(2, 2), Vector2(3, 1)), c)


func _ready() -> void:
	_rng.randomize()
	_event_timer = first_event_delay
	if AudioServer.get_bus_index(&"SFX") >= 0:
		_bus = &"SFX"
	if _veil == null:
		_veil = ColorRect.new()
		_veil.name = "Veil"
		_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_veil)
	_material = _veil.material as ShaderMaterial
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load("res://resources/horror/night_horror.gdshader")
		_veil.material = _material
	_veil.visible = false
	_shadow = ShadowDrawing.new()
	add_child(_shadow)
	_ambience = _make_player(HorrorSynth.get_stream(&"ambience"))
	_heart = _make_player(heartbeat_sound if heartbeat_sound != null else HorrorSynth.get_stream(&"heartbeat"))
	_sting = _make_player(HorrorSynth.get_stream(&"sting"))
	_scream = _make_player(HorrorSynth.get_stream(&"scream"))
	_stalker_timer = stalker_first_delay
	if _jumpscare != null:
		_jumpscare.visible = false
	if _flash != null:
		_flash.visible = false
	DayCycle.day_passed.connect(func(_d: int) -> void:
		fear = 0.0
		_carried_fear.clear())
	_key = _player_key()
	fear = float(_carried_fear.get(_key, 0.0))
	# Setelah scene baru menjadi current_scene: pasang efek malam langsung, tanpa fade-in.
	_snap_to_current.call_deferred()


func _exit_tree() -> void:
	_carried_fear[_key] = fear


func _player_key() -> int:
	return player.player_index if is_instance_valid(player) else 0


func _midnight_target(target: float) -> float:
	if target > 0.0 and DayCycle.hour < 6:
		return lerpf(0.45, 1.0, clampf((DayCycle.night_intensity() - 0.7) / 0.3, 0.0, 1.0))
	return 0.0


## Efek layar + ambience langsung ke nilai sekarang (dipakai saat scene baru dimuat).
func _snap_to_current() -> void:
	var target := outdoor_intensity()
	intensity = target
	midnight = _midnight_target(target)
	_ambience.volume_db = lerpf(ambience_volume_min, ambience_volume_max, intensity)
	if target > 0.0 and not _ambience.playing:
		_ambience.play()
	_apply_shader()


func _make_player(stream: AudioStream) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = _bus
	p.stream = stream
	add_child(p)
	return p


func outdoor_intensity() -> float:
	if not enabled or not is_instance_valid(player) or Coop.is_sleeping(player) or DayCycle.is_sleep_transition or DayCycle._is_passing_out:
		return 0.0
	var world := player.world_root()
	if not is_instance_valid(world):
		return 0.0
	var path := world.scene_file_path.to_lower()
	if "/interior/" in path or path.ends_with("/interior.tscn"):
		return 0.0
	return DayCycle.night_intensity()


func _process(delta: float) -> void:
	if _veil == null:
		return
	var target := outdoor_intensity()
	intensity = move_toward(intensity, target, delta * 0.6)
	midnight = move_toward(midnight, _midnight_target(target), delta * 0.25)
	_update_fear(delta, target)
	_update_heartbeat(delta)
	_beat = move_toward(_beat, 0.0, delta * 3.0)
	_glitch = move_toward(_glitch, 0.0, delta * 2.8)
	_apply_shader()

	_ambience.volume_db = lerpf(ambience_volume_min, ambience_volume_max, intensity)
	if target > 0.0 and not _ambience.playing:
		_ambience.play()
	elif target == 0.0:
		_ambience.stop()
		_shadow.life = 0.0
		_event_timer = first_event_delay
		_stalker_timer = stalker_first_delay
		_steps_left = 0
		return
	_update_footsteps(delta)
	_update_stalker(delta, target)
	if target < events_min_night:
		return
	_event_timer -= delta * (1.0 + fear * fear_event_speedup)
	if _event_timer <= 0.0:
		_event_timer = _rng.randf_range(event_interval_min, event_interval_max)
		var event := _pick_event(target)
		if event != null:
			trigger(event)


func _apply_shader() -> void:
	var active := intensity > 0.001 or fear > 0.001 or _glitch > 0.0 or _blackout > 0.0
	_veil.visible = active
	if not active:
		return
	_material.set_shader_parameter("intensity", clampf(intensity + _blackout, 0.0, 2.0))
	_material.set_shader_parameter("midnight", midnight)
	_material.set_shader_parameter("fear", fear)
	_material.set_shader_parameter("beat", _beat)
	_material.set_shader_parameter("glitch", _glitch)
	_material.set_shader_parameter("fog_amount", fog_amount)
	_material.set_shader_parameter("desaturate_amount", desaturate_amount)
	_material.set_shader_parameter("grain_amount", grain_amount)
	_material.set_shader_parameter("aberration_px", aberration_px)
	_material.set_shader_parameter("red_pulse_amount", red_pulse_amount)
	_material.set_shader_parameter("glitch_amount", glitch_amount)


# ── Rasa takut + detak jantung ───────────────────────────────────────────────

func _update_fear(delta: float, target: float) -> void:
	if target <= 0.0:
		fear = move_toward(fear, 0.0, fear_fall_indoors * delta)
		return
	_refresh_safe(delta)
	if _safe:
		fear = move_toward(fear, 0.0, fear_fall_near_light * delta)
		return
	var cap := 1.0 if midnight > 0.0 else fear_cap_before_midnight
	if fear < cap:
		var rise := (fear_rise_per_second + fear_rise_midnight * midnight) * target
		fear = minf(cap, fear + rise * delta)


## true bila pemain dekat cahaya yang menyala.
func is_near_light() -> bool:
	return _safe


func _refresh_safe(delta: float) -> void:
	_safe_check -= delta
	_light_refresh -= delta
	if _safe_check > 0.0:
		return
	_safe_check = 0.25
	var world := player.world_root()
	if world != _light_world or _light_refresh <= 0.0:
		_collect_lights(world)
	_safe = is_lit(player.global_position)


## true bila titik dunia ini berada dalam cahaya yang menyala (dipakai juga oleh NightStalker).
func is_lit(world_pos: Vector2) -> bool:
	for light in _lights:
		if not is_instance_valid(light) or not light.is_visible_in_tree():
			continue
		if light is PointLight2D and not (light as PointLight2D).enabled:
			continue
		var radius: float = light.get("safe_radius") if "safe_radius" in light else safe_light_radius
		if light.global_position.distance_to(world_pos) <= radius:
			return true
	return false


func _collect_lights(world: Node) -> void:
	_light_world = world
	_light_refresh = 3.0
	_lights.clear()
	if not is_instance_valid(world):
		return
	for node in world.find_children("*", "PointLight2D", true, false):
		_lights.append(node as Node2D)
	for node in get_tree().get_nodes_in_group(&"horror_safe_light"):
		if node is Node2D and world.is_ancestor_of(node):
			_lights.append(node as Node2D)


func _update_heartbeat(delta: float) -> void:
	if fear < heartbeat_start:
		_beat_timer = 0.0
		return
	_beat_timer -= delta
	if _beat_timer > 0.0:
		return
	var k := inverse_lerp(heartbeat_start, 1.0, fear)
	_beat_timer = lerpf(heartbeat_slow, heartbeat_fast, k)
	_heart.volume_db = lerpf(heartbeat_volume_min, heartbeat_volume_max, k)
	_heart.pitch_scale = lerpf(1.0, 1.12, k)
	_heart.play()
	_beat = 1.0
	if fear >= shake_from_fear and not Coop.active:
		Juice.shake(shake_strength * k, 0.12)


# ── Kejadian ganjil ──────────────────────────────────────────────────────────

func _pick_event(night: float) -> HorrorEvent:
	var now := Time.get_ticks_msec() / 1000.0
	var pool: Array[HorrorEvent] = []
	var total := 0.0
	for e in events:
		if e == null or e.weight <= 0.0 or fear < e.min_fear or night < e.min_night:
			continue
		if _last_fired.has(e) and now - float(_last_fired[e]) < e.cooldown_seconds:
			continue
		pool.append(e)
		total += e.weight
	if pool.is_empty():
		return null
	var roll := _rng.randf() * total
	for e in pool:
		roll -= e.weight
		if roll <= 0.0:
			return e
	return pool.back()


## Picu kejadian berdasarkan id (untuk uji / debug), mis. trigger_id(&"red_eyes").
func trigger_id(id: StringName) -> void:
	for e in events:
		if e != null and e.id == id:
			trigger(e)
			return


func trigger(e: HorrorEvent) -> void:
	if not is_instance_valid(player):
		return
	_last_fired[e] = Time.get_ticks_msec() / 1000.0
	fear = minf(1.0, fear + e.fear_add)
	if e.glitch:
		_glitch = 1.0
		_sting.play()
	if e.shake > 0.0 and not Coop.active:
		Juice.shake(e.shake, 0.25)
	if not e.notify_text.is_empty():
		Notify.say(e.notify_text)
	var size := get_viewport().get_visible_rect().size
	match e.kind:
		HorrorEvent.Kind.SHADOW_GLIMPSE:
			_shadow.velocity = Vector2.ZERO
			_shadow.location = Vector2(size.x * (0.12 if _rng.randf() < 0.5 else 0.88), size.y * _rng.randf_range(0.25, 0.7))
			_shadow.life = e.duration
			_play_flat(e, null)
		HorrorEvent.Kind.SHADOW_DASH:
			var from_left := _rng.randf() < 0.5
			_shadow.location = Vector2(-20.0 if from_left else size.x + 20.0, size.y * _rng.randf_range(0.3, 0.7))
			_shadow.velocity = Vector2((size.x + 40.0) / maxf(e.duration, 0.1) * (1.0 if from_left else -1.0), 0.0)
			_shadow.life = e.duration
			_play_flat(e, null)
		HorrorEvent.Kind.WHISPER:
			var side := -1.0 if _rng.randf() < 0.5 else 1.0
			var at := player.global_position + Vector2(side * e.distance, _rng.randf_range(-10.0, 10.0))
			_play_at(e.sound if e.sound != null else HorrorSynth.get_stream(&"whisper"), at, e.volume_db, _rng.randf_range(0.85, 1.05))
		HorrorEvent.Kind.FOOTSTEPS:
			_step_event = e
			_steps_total = e.count
			_steps_left = e.count
			_step_timer = 0.5
			_step_idle = 0.0
		HorrorEvent.Kind.LAMP_FLICKER:
			_flicker_lights(e)
		HorrorEvent.Kind.RED_EYES:
			var eyes := RedEyes.new()
			eyes.life = e.duration
			eyes.watcher = player
			player.world_root().add_child(eyes)
			eyes.global_position = (player.global_position + Vector2.from_angle(_rng.randf() * TAU) * e.distance).round()
			_play_flat(e, null)
		HorrorEvent.Kind.CROWS:
			var flock := CrowFlock.new()
			var offset := Vector2.from_angle(_rng.randf() * TAU) * e.distance * 0.5
			flock.setup(e.count, _rng, offset.normalized() if offset != Vector2.ZERO else Vector2.UP)
			player.world_root().add_child(flock)
			flock.global_position = player.global_position + offset
			_play_at(e.sound if e.sound != null else HorrorSynth.get_stream(&"caw"), flock.global_position, e.volume_db, _rng.randf_range(0.9, 1.1))


func _update_footsteps(delta: float) -> void:
	if _steps_left <= 0 or _step_event == null:
		return
	_step_timer -= delta
	if _step_timer > 0.0:
		return
	if player.velocity.length() < 4.0:
		# Pemain berhenti: langkah di belakang ikut berhenti.
		_step_idle += 0.1
		_step_timer = 0.1
		if _step_idle > 2.5:
			_steps_left = 0
		return
	_step_idle = 0.0
	var progress := 1.0 - float(_steps_left) / float(maxi(_steps_total, 1))
	var dist := lerpf(_step_event.distance, 18.0, progress)
	var behind := -player.velocity.normalized() * dist
	var stream: AudioStream = _step_event.sound if _step_event.sound != null else HorrorSynth.get_stream(&"footstep")
	_play_at(stream, player.global_position + behind, _step_event.volume_db + progress * 4.0, _rng.randf_range(0.85, 0.95))
	_steps_left -= 1
	_step_timer = 0.46


func _flicker_lights(e: HorrorEvent) -> void:
	var near: Array[PointLight2D] = []
	var feet := player.global_position
	if player.world_root() != _light_world:
		_collect_lights(player.world_root())
	for light in _lights:
		if light is PointLight2D and is_instance_valid(light) and (light as PointLight2D).enabled and light.global_position.distance_to(feet) <= e.distance * 2.0:
			near.append(light as PointLight2D)
			if near.size() >= 3:
				break
	if near.is_empty():
		# Tidak ada lampu: layar sendiri yang berkedip gelap.
		var tw := create_tween()
		for i in e.count:
			tw.tween_property(self, "_blackout", 0.9, 0.05)
			tw.tween_property(self, "_blackout", 0.0, _rng.randf_range(0.05, 0.12))
			tw.tween_interval(_rng.randf_range(0.05, 0.25))
		_play_flat(e, HorrorSynth.get_stream(&"flicker"))
		return
	for light in near:
		var base := light.color
		var tw := light.create_tween()
		for i in e.count:
			tw.tween_property(light, "color", Color(0.04, 0.04, 0.07), 0.04)
			tw.tween_property(light, "color", base, _rng.randf_range(0.04, 0.1))
			tw.tween_interval(_rng.randf_range(0.05, 0.3))
		tw.tween_property(light, "color", Color(0.02, 0.02, 0.04), 0.05)
		tw.tween_interval(maxf(e.duration - 1.0, 0.3))
		tw.tween_property(light, "color", base, 0.4)
		_play_at(e.sound if e.sound != null else HorrorSynth.get_stream(&"flicker"), light.global_position, e.volume_db, 1.0)
	# Lampu padam sesaat = aman hilang sesaat.
	_safe = false
	_safe_check = maxf(e.duration, 0.5)


func _play_flat(e: HorrorEvent, fallback: AudioStream) -> void:
	var stream: AudioStream = e.sound if e.sound != null else fallback
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.bus = _bus
	p.stream = stream
	p.volume_db = e.volume_db
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _play_at(stream: AudioStream, world_pos: Vector2, volume_db: float, pitch: float) -> void:
	if stream == null or not is_instance_valid(player):
		return
	var world := player.world_root()
	if not is_instance_valid(world):
		return
	var p := AudioStreamPlayer2D.new()
	p.bus = _bus
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.max_distance = 700.0
	world.add_child(p)
	p.global_position = world_pos
	p.finished.connect(p.queue_free)
	p.play()


# ── Penunggu: makhluk penguntit + jumpscare ──────────────────────────────────

func add_fear(amount: float) -> void:
	fear = clampf(fear + amount, 0.0, 1.0)


func pulse_glitch(amount: float) -> void:
	_glitch = maxf(_glitch, amount)


## Makhluk yang sedang mengikuti pemain ini (null bila tidak ada).
func current_stalker() -> Node2D:
	return _stalker if is_instance_valid(_stalker) else null


func _update_stalker(delta: float, target: float) -> void:
	if stalker_scenes.is_empty() or current_stalker() != null:
		return
	if target < stalker_min_night or fear < stalker_min_fear or _safe:
		return
	if Time.get_ticks_msec() / 1000.0 < _stalker_ready_at:
		return
	_stalker_timer -= delta
	if _stalker_timer > 0.0:
		return
	_stalker_timer = stalker_check_interval
	if _rng.randf() < stalker_chance:
		spawn_stalker()


## Munculkan makhluk sekarang (index -1 = acak). Juga untuk uji / debug.
func spawn_stalker(index: int = -1) -> Node2D:
	if stalker_scenes.is_empty() or not is_instance_valid(player):
		return null
	var world := player.world_root()
	if not is_instance_valid(world):
		return null
	if world != _light_world:
		_collect_lights(world)
	if current_stalker() != null:
		_stalker.queue_free()
	var scene: PackedScene = stalker_scenes[index if index >= 0 and index < stalker_scenes.size() else _rng.randi_range(0, stalker_scenes.size() - 1)]
	if scene == null:
		return null
	var stalker := scene.instantiate() as NightStalker
	if stalker == null:
		push_warning("NightHorror: stalker_scenes harus memakai script NightStalker.")
		return null
	var feet := player.global_position + Player.FEET_OFFSET
	var back := -player.facing_direction.normalized()
	if back == Vector2.ZERO:
		back = Vector2.UP
	var spot := feet + back * stalker_spawn_distance
	for attempt in 10:
		var candidate := feet + back.rotated(_rng.randf_range(-1.0, 1.0) * (0.6 + attempt * 0.25)) * stalker_spawn_distance
		if not is_lit(candidate):
			spot = candidate
			break
	stalker.setup(player, self)
	world.add_child(stalker)
	stalker.global_position = spot.round()
	stalker.finished.connect(_on_stalker_finished)
	_stalker = stalker
	return stalker


func _on_stalker_finished() -> void:
	_stalker_ready_at = Time.get_ticks_msec() / 1000.0 + stalker_cooldown
	_stalker_timer = stalker_check_interval


func stalker_touched(stalker: Node2D) -> void:
	_stalker_ready_at = Time.get_ticks_msec() / 1000.0 + stalker_cooldown
	fear = 1.0
	_glitch = 1.0
	var tex: Texture2D = stalker.get("jumpscare_texture")
	var cue: AudioStream = stalker.get("jumpscare_sound")
	_scream.stream = cue if cue != null else HorrorSynth.get_stream(&"scream")
	_scream.volume_db = jumpscare_volume_db
	_scream.play()
	_sting.play()
	if not Coop.active:
		Juice.shake(5.0, 0.5)
		Juice.hitstop(90)
	if _jumpscare != null and tex != null:
		_jumpscare.texture = tex
		_jumpscare.visible = true
		_jumpscare.modulate = Color(1, 1, 1, 1)
		_jumpscare.pivot_offset = _jumpscare.size * 0.5
		_jumpscare.scale = Vector2(1.7, 1.7)
		var tw := create_tween()
		tw.tween_property(_jumpscare, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		for i in 4:
			tw.tween_property(_jumpscare, "position:x", _rng.randf_range(-6.0, 6.0), 0.04)
		tw.tween_property(_jumpscare, "position:x", 0.0, 0.04)
		tw.tween_interval(0.45)
		tw.tween_property(_jumpscare, "modulate:a", 0.0, 0.35)
		tw.tween_callback(func() -> void: _jumpscare.visible = false)
	if _flash != null:
		_flash.visible = true
		_flash.color = Color(0.55, 0.0, 0.03, 0.75)
		var fl := create_tween()
		fl.tween_property(_flash, "color:a", 0.0, 0.6)
		fl.tween_callback(func() -> void: _flash.visible = false)
	if is_instance_valid(player):
		var penalty: int = int(stalker.get("stamina_penalty"))
		var data := player.data
		var floor_value := 0 if jumpscare_can_faint else 1
		data.stamina = maxi(floor_value, data.stamina - penalty)
		player.set_input_locked(&"jumpscare", true)
		get_tree().create_timer(jumpscare_lock_seconds).timeout.connect(func() -> void:
			if is_instance_valid(player):
				player.set_input_locked(&"jumpscare", false))
		var text: String = stalker.get("notify_touch")
		if not text.is_empty():
			Notify.say(text % penalty if "%d" in text else text)
