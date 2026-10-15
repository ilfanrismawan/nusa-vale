extends Node
## Autoload "Juice": umpan balik aksi agar terasa memuaskan.
## Suara, partikel, riak air, guncangan kamera, hitstop, item terbang ke hotbar, teks melayang.
## Pengaturan per aksi ada di resources/feedback/<nama>.tres (ActionFeedback).

const FEEDBACK_DIR := "res://resources/feedback"
const SFX_BUS := &"SFX"
const VOICES := 12
const FONT: Font = preload("res://assets/fonts/m5x7.ttf")
const IMPACT_DIR := "res://assets/audio/sfx/kenney_impact/"
## Different timbres, not just louder versions of the same tool sound.
const TIER_TIMBRES := ["impactWood_light_000", "impactTin_medium_001", "impactMetal_light_002", "impactBell_heavy_000", "impactPlate_light_001", "impactMetal_heavy_003", "impactGlass_light_002", "impactSoft_heavy_003", "impactGlass_medium_004", "impactPlate_heavy_004"]
var _audio_cache: Dictionary = {}

func impact_stream(name: String) -> AudioStream:
	if not _audio_cache.has(name):
		_audio_cache[name] = load(IMPACT_DIR + name + ".ogg") as AudioStream
	return _audio_cache[name]

func play_tool_tier(tool: ToolData) -> void:
	var tier := clampi(tool.tier, 0, TIER_TIMBRES.size() - 1)
	# Keep the original action sound/particles, with a distinct material accent.
	sfx(impact_stream(TIER_TIMBRES[tier]), -14.0, 0.03, float(tool.tool_type) - 3.0)

func play_upgrade_reward(tier: int) -> void:
	tier = clampi(tier, 0, TIER_TIMBRES.size() - 1)
	sfx(impact_stream(TIER_TIMBRES[tier]), -8.0, 0.0, 0.0)
	for note in [0, 4, 7, 12]:
		sfx(impact_stream("impactBell_heavy_000"), -19.0, 0.0, float(note + tier))

const FOOTSTEP_DIR := "res://assets/audio/sfx/footsteps/"
const FOOTSTEP_SURFACES := ["grass", "dirt"]
var _footstep_cache: Dictionary = {}

func _footstep_stream(surface: String, running: bool, variation: int) -> AudioStream:
	var mode := "run" if running else "walk"
	var key  := "%s_%s_%03d" % [surface, mode, posmod(variation, 5)]
	if _footstep_cache.has(key):
		return _footstep_cache[key]
	var path   := FOOTSTEP_DIR + "footstep_%s.wav" % key
	var stream : AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	_footstep_cache[key] = stream
	return stream

func play_footstep(surface: String, running: bool, variation: int) -> void:
	if surface in FOOTSTEP_SURFACES:
		var stream := _footstep_stream(surface, running, variation)
		if stream:
			var vol := -12.0 if running else -16.0
			sfx(stream, vol, 0.04, 0.0)
			return
	# Fallback for wood, concrete, carpet, snow → kenney_impact
	var name := "footstep_%s_%03d" % [surface, posmod(variation, 5)]
	sfx(impact_stream(name), -16.0 if running else -21.0, 0.045, 1.0 if running else 0.0)

## Nada naik saat memungut item beruntun (skala mayor, dalam semitone).
const COMBO_STEPS: Array[int] = [0, 2, 4, 5, 7, 9, 11, 12]
const COMBO_WINDOW := 0.8

var shake_enabled := true
var hitstop_enabled := true

var _cache: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _dot: Texture2D
var _ui: CanvasLayer

var _shake_camera: Camera2D
var _shake_base := Vector2.ZERO
var _shake_strength := 0.0
var _shake_time := 0.0
var _shake_duration := 0.0

var _hitstop_active := false
var _combo := 0
var _last_pickup_ms := -100000


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_voices.append(p)

	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_dot = ImageTexture.create_from_image(img)

	_ui = CanvasLayer.new()
	_ui.layer = 25
	add_child(_ui)


func _process(delta: float) -> void:
	_update_shake(delta)


# ── API utama ────────────────────────────────────────────────────────────────

## Mainkan paket umpan balik resources/feedback/<key>.tres di posisi dunia.
func play(key: StringName, world_pos: Vector2, semitones: float = 0.0) -> void:
	var fb := get_feedback(key)
	if fb == null:
		return
	play_feedback(fb, world_pos, semitones)


func play_feedback(fb: ActionFeedback, world_pos: Vector2, semitones: float = 0.0) -> void:
	if fb.sound:
		sfx(fb.sound, fb.volume_db, fb.pitch_variation, semitones)
	if fb.particle_count > 0:
		burst(world_pos, fb)
	if fb.ripple:
		ripple(world_pos, fb.particle_color)
	if fb.shake > 0.0:
		shake(fb.shake, fb.shake_duration)
	if fb.hitstop_ms > 0:
		hitstop(fb.hitstop_ms)


## Hanya suara dari sebuah paket (tanpa partikel), mis. bunyi gulungan pancing.
func play_sound(key: StringName, semitones: float = 0.0) -> void:
	var fb := get_feedback(key)
	if fb and fb.sound:
		sfx(fb.sound, fb.volume_db, fb.pitch_variation, semitones)


func get_feedback(key: StringName) -> ActionFeedback:
	if _cache.has(key):
		return _cache[key]
	var path := "%s/%s.tres" % [FEEDBACK_DIR, key]
	var fb: ActionFeedback = null
	if ResourceLoader.exists(path):
		fb = load(path) as ActionFeedback
	if fb == null:
		push_warning("Juice: feedback '%s' tidak ditemukan di %s" % [key, path])
	_cache[key] = fb
	return fb


## Titik tengah sebuah cell pada BaseLayerGround pemain, dalam koordinat dunia.
func cell_center(player: Player, cell: Vector2i) -> Vector2:
	if player == null or player.base_layer_ground == null:
		return Vector2.ZERO
	var layer := player.base_layer_ground
	return layer.to_global(layer.map_to_local(cell))


# ── Suara ────────────────────────────────────────────────────────────────────

func sfx(stream: AudioStream, volume_db: float = 0.0, pitch_variation: float = 0.08, semitones: float = 0.0) -> void:
	if stream == null:
		return
	var p := _free_voice()
	p.stream = stream
	p.volume_db = volume_db
	var vary := randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	p.pitch_scale = maxf(0.05, pow(2.0, semitones / 12.0) * vary)
	p.play()


func _free_voice() -> AudioStreamPlayer:
	for p in _voices:
		if not p.playing:
			return p
	# Semua sibuk: pakai yang paling lama.
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	return p


func _ensure_bus() -> void:
	if AudioServer.get_bus_index(SFX_BUS) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, SFX_BUS)
	AudioServer.set_bus_send(idx, &"Master")


# ── Partikel dan riak ────────────────────────────────────────────────────────

func burst(world_pos: Vector2, fb: ActionFeedback) -> void:
	var parent := _world_parent()
	if parent == null:
		return
	var p := CPUParticles2D.new()
	p.texture = _dot
	p.one_shot = true
	p.emitting = false
	p.amount = fb.particle_count
	p.lifetime = fb.particle_lifetime
	p.explosiveness = 0.95
	p.randomness = 0.5
	p.local_coords = false
	p.direction = Vector2.UP
	p.spread = fb.particle_spread
	p.initial_velocity_min = fb.particle_speed * 0.45
	p.initial_velocity_max = fb.particle_speed
	p.gravity = Vector2(0.0, fb.particle_gravity)
	p.damping_min = 10.0
	p.damping_max = 30.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = float(fb.particle_size)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(4, 2)

	var initial := Gradient.new()
	initial.set_color(0, fb.particle_color)
	initial.set_color(1, fb.particle_color_alt)
	p.color_initial_ramp = initial

	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.add_point(0.7, Color.WHITE)
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	p.color_ramp = fade

	p.z_index = 20
	parent.add_child(p)
	p.global_position = world_pos.round()
	p.emitting = true
	get_tree().create_timer(fb.particle_lifetime + 0.3, false).timeout.connect(p.queue_free)


func ripple(world_pos: Vector2, color: Color, max_radius: float = 9.0) -> void:
	var parent := _world_parent()
	if parent == null:
		return
	var r := Ripple.new()
	r.color = color
	r.z_index = 5
	parent.add_child(r)
	r.global_position = world_pos.round()
	r.scale = Vector2(1.0, 0.5)
	var tw := r.create_tween().set_parallel(true)
	tw.tween_method(r.set_radius, 1.0, max_radius, 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(r, "modulate:a", 0.0, 0.55).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(r.queue_free)


class Ripple extends Node2D:
	var color := Color.WHITE
	var radius := 1.0

	func set_radius(value: float) -> void:
		radius = value
		queue_redraw()

	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, color, 1.0)


func _world_parent() -> Node:
	return Coop.world_parent()

## Co-op: pemain yang sedang beraksi (null saat solo).
func _actor() -> Player:
	return Coop.current_player()

## Viewport tempat efek layar digambar: layar pemain yang beraksi, atau layar utama.
func _screen() -> Viewport:
	var view := Coop.view_of(_actor())
	return view if view != null else get_viewport()

func _screen_layer() -> CanvasLayer:
	var layer := Coop.juice_layer_of(_actor())
	return layer if layer != null else _ui


# ── Kamera dan waktu ─────────────────────────────────────────────────────────

func shake(strength: float, duration: float = 0.15) -> void:
	if not shake_enabled or strength <= 0.0:
		return
	var cam := Coop.camera_of(_actor())
	if cam == null:
		cam = get_viewport().get_camera_2d()
	if cam == null:
		return
	if _shake_time <= 0.0 or cam != _shake_camera:
		_restore_camera()
		_shake_camera = cam
		_shake_base = cam.offset
	_shake_strength = maxf(_shake_strength if _shake_time > 0.0 else 0.0, strength)
	_shake_duration = maxf(duration, 0.01)
	_shake_time = _shake_duration


func _update_shake(delta: float) -> void:
	if _shake_time <= 0.0:
		return
	if not is_instance_valid(_shake_camera):
		_shake_time = 0.0
		return
	_shake_time -= delta
	if _shake_time <= 0.0:
		_restore_camera()
		return
	var k := _shake_time / _shake_duration
	var amount := _shake_strength * k
	var jitter := Vector2(randf_range(-amount, amount), randf_range(-amount, amount)).round()
	_shake_camera.offset = _shake_base + jitter


func _restore_camera() -> void:
	if is_instance_valid(_shake_camera):
		_shake_camera.offset = _shake_base
	_shake_time = 0.0
	_shake_strength = 0.0


func hitstop(ms: int) -> void:
	if not hitstop_enabled or ms <= 0 or _hitstop_active:
		return
	# Co-op: time_scale berlaku untuk semua pemain, jadi hitstop dimatikan.
	if Coop.active:
		return
	_hitstop_active = true
	var previous := Engine.time_scale
	Engine.time_scale = 0.05
	await get_tree().create_timer(ms / 1000.0, true, false, true).timeout
	Engine.time_scale = previous
	_hitstop_active = false


# ── Hadiah: item terbang ke hotbar, teks melayang ────────────────────────────

## Dipanggil saat pemain memungut item: bunyi "pop" bernada naik bila beruntun,
## ikon terbang ke slot hotbar, lalu slot berdenyut.
func collect(item_id: String, icon: Texture2D, world_pos: Vector2) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_pickup_ms <= int(COMBO_WINDOW * 1000.0):
		_combo = mini(_combo + 1, COMBO_STEPS.size() - 1)
	else:
		_combo = 0
	_last_pickup_ms = now
	play_sound(&"pickup", float(COMBO_STEPS[_combo]))
	fly_to_hotbar(icon, world_pos, item_id)


func fly_to_hotbar(icon: Texture2D, world_pos: Vector2, item_id: String) -> void:
	if icon == null:
		return
	var screen := _screen()
	var hotbar: Node = Coop.hotbar_of(_actor()) if Coop.active else get_tree().get_first_node_in_group(&"hotbar_ui")
	var start := screen.get_canvas_transform() * world_pos
	var zoom := screen.get_canvas_transform().get_scale().x
	var target := Vector2(screen.get_visible_rect().size.x * 0.5, screen.get_visible_rect().size.y - 24.0)
	if hotbar and hotbar.has_method("get_slot_center_for"):
		var slot_pos: Variant = hotbar.get_slot_center_for(item_id)
		if slot_pos != null:
			target = slot_pos

	var sprite := Sprite2D.new()
	sprite.texture = icon
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = start
	sprite.scale = Vector2.ONE * zoom
	_screen_layer().add_child(sprite)

	# Lengkung: titik kontrol di atas garis lurus agar ikon "melompat" dulu.
	var control := (start + target) * 0.5 + Vector2(0, -60)
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "scale", Vector2.ONE * zoom * 1.3, 0.08)
	tw.tween_method(_fly_step.bind(sprite, start, control, target, zoom), 0.0, 1.0, 0.38) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	# Travel may free the old HUD before the flying icon reaches it.
	var hotbar_ref: WeakRef = weakref(hotbar) if is_instance_valid(hotbar) else null
	tw.tween_callback(_fly_done.bind(sprite, hotbar_ref, item_id))


func _fly_step(t: float, sprite: Sprite2D, start: Vector2, control: Vector2, target: Vector2, zoom: float) -> void:
	var a := start.lerp(control, t)
	var b := control.lerp(target, t)
	sprite.position = a.lerp(b, t).round()
	sprite.scale = Vector2.ONE * lerpf(zoom * 1.3, zoom * 0.8, t)


func _fly_done(sprite: Sprite2D, hotbar_ref: WeakRef, item_id: String) -> void:
	sprite.queue_free()
	var hotbar: Variant = hotbar_ref.get_ref() if hotbar_ref != null else null
	if is_instance_valid(hotbar) and hotbar.has_method("pulse_item"):
		hotbar.pulse_item(item_id)


## Sprite yang melompat lalu menghilang, mis. tanaman tercabut saat panen.
func leap(texture: Texture2D, world_pos: Vector2, height: float = 12.0) -> void:
	var parent := _world_parent()
	if texture == null or parent == null:
		return
	var s := Sprite2D.new()
	s.texture = texture
	s.z_index = 20
	parent.add_child(s)
	s.global_position = world_pos.round()
	s.scale = Vector2(1.3, 0.7)
	var top := s.position + Vector2(0, -height)
	var tw := s.create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", Vector2(0.8, 1.25), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "position", top, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(s, "scale", Vector2.ONE, 0.1)
	tw.chain().tween_property(s, "modulate:a", 0.0, 0.15)
	tw.chain().tween_callback(s.queue_free)


## Teks yang muncul di atas posisi dunia lalu naik dan memudar ("!", "BARU!").
func float_text(text: String, world_pos: Vector2, color: Color = Color.WHITE, hold: float = 0.6) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen_layer().add_child(label)
	label.reset_size()
	var screen := _screen().get_canvas_transform() * world_pos
	label.position = (screen - Vector2(label.size.x * 0.5, label.size.y)).round()
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(0.3, 0.3)
	var tw := label.create_tween()
	tw.tween_property(label, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(label, "position:y", label.position.y - 10.0, 0.35)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.35)
	tw.tween_callback(label.queue_free)


## Tekstur tile tanaman di cell (dibaca sebelum dipanen), untuk Juice.leap().
func crop_texture(cell: Vector2i) -> Texture2D:
	var layer := FarmManager.crop_layer
	if not is_instance_valid(layer) or layer.tile_set == null:
		return null
	var source_id := layer.get_cell_source_id(cell)
	if source_id < 0:
		return null
	var source := layer.tile_set.get_source(source_id) as TileSetAtlasSource
	if source == null or source.texture == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = source.texture
	atlas.region = source.get_tile_texture_region(layer.get_cell_atlas_coords(cell))
	return atlas
