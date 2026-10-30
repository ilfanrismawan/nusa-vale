extends StaticBody2D

const PRODUCT_READY_SOUND := preload("res://scripts/world/product_ready_sound.gd")

var uid := 0
@onready var _sprite: Sprite2D = $Sprite
@onready var _collision: CollisionShape2D = $CollisionShape2D
var _chest_open := false
var _quiet_until_ms := 0
var _lid_tween: Tween
@onready var _coop_status: Label = $CoopStatus
@onready var _egg_icon: Sprite2D = $EggIcon
@onready var _particles: CPUParticles2D = $ProcessingParticles
@onready var _light: PointLight2D = $ProcessingLight
@onready var _ready_sound: PRODUCT_READY_SOUND = $ReadySound
@onready var _audio_loop: AudioStreamPlayer2D = $ProcessingAudio
var _was_running := false
var _ready_bounce_time := 0.0

# ── Stardew Valley Style Juice & Ready Bubble ──
@onready var _ready_bubble: Node2D = $ReadyBubble
@onready var _bubble_bg: Sprite2D = $ReadyBubble/Background
@onready var _bubble_icon: Sprite2D = $ReadyBubble/ProductIcon
var _squash_tween: Tween

@export_group("Balon Hasil Produksi")
@export var ready_bubble_enabled := true
## Posisi ReadyBubble di scene menjadi offset dasar, ditambah tinggi objek ini.
@export_range(0.0, 2.0, 0.05) var ready_height_factor := 0.4
@export_range(0.0, 20.0, 0.5) var ready_bob_amplitude := 3.0
## Kecepatan animasi melayang dalam radian per detik; 0 = diam.
@export_range(0.0, 20.0, 0.1) var ready_bob_speed := 6.0
@export var use_product_icon := true
@export_range(1.0, 128.0, 1.0) var ready_icon_size := 14.0
## AtlasTexture sudah dipotong oleh resource item; gambar spritesheet mentah memakai frame ini.
@export var crop_product_sheet := true
@export var product_frame_size := Vector2i(16, 16)
@export var product_frame := Vector2i.ZERO
@export_group("Juice Balon")
@export var bubble_juice_enabled := true
@export_range(0.05, 1.5, 0.01) var bubble_pop_seconds := 0.32
@export_range(0.1, 1.0, 0.05) var bubble_pop_start_scale := 0.45
@export_range(0.0, 4.0, 0.1) var bubble_pop_overshoot := 1.8
@export_range(0.0, 0.4, 0.01) var bubble_pop_stretch := 0.12
@export_range(0.0, 0.15, 0.005) var bubble_idle_pulse := 0.025
@export_range(0.0, 12.0, 0.1) var bubble_pulse_speed := 3.0
@export_range(0.0, 8.0, 0.1) var bubble_sway_degrees := 1.5
@export_range(0.0, 12.0, 0.1) var bubble_sway_speed := 2.0
@export_range(0.05, 1.0, 0.01) var bubble_collect_seconds := 0.18
@export_range(0.0, 40.0, 0.5) var bubble_collect_rise := 10.0
@export_range(0.5, 2.0, 0.01) var bubble_collect_scale := 1.12
var _bubble_base_scale := Vector2.ONE
var _bubble_base_modulate := Color.WHITE
var _bubble_base_rotation := 0.0
var _bubble_present := false
var _bubble_departing := false
var _bubble_age := 0.0
var _bubble_departure_age := 0.0
var _bubble_exit_position := Vector2.ZERO
var _bubble_origin := Vector2.ZERO
var _icon_base_scale := Vector2.ONE

func _ready() -> void:
	set_meta("player_interaction", true)
	_bubble_origin = _ready_bubble.position
	_bubble_base_scale = _ready_bubble.scale
	_bubble_base_modulate = _ready_bubble.modulate
	_bubble_base_rotation = _ready_bubble.rotation
	_icon_base_scale = _bubble_icon.scale
	_ready_bubble.hide()
	_quiet_until_ms = Time.get_ticks_msec() + 400
	refresh()

func interact(actor: Player = null) -> void:
	if actor == null:
		actor = Coop.current_player()
	StructureManager.interact_with(actor, uid)

## Juicy: Squash and stretch bounce saat bahan berhasil dimasukkan ke mesin
func bounce_insert() -> void:
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	_squash_tween = create_tween()
	_sprite.scale = Vector2(1.35, 0.7)
	_squash_tween.tween_property(_sprite, "scale", Vector2(0.85, 1.25), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_squash_tween.tween_property(_sprite, "scale", Vector2(1.08, 0.95), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_squash_tween.tween_property(_sprite, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Juice.play(&"building_place", global_position + Vector2(0, -8))

## Juicy: Pop recoil bounce saat produk siap diambil / dipanen
func bounce_harvest() -> void:
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	_squash_tween = create_tween()
	_sprite.scale = Vector2(0.8, 1.3)
	_squash_tween.tween_property(_sprite, "scale", Vector2(1.2, 0.85), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_squash_tween.tween_property(_sprite, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Juice.play(&"sparkle", global_position + Vector2(0, -12))

## Juicy: Goyang saat mesin sedang sibuk memproses
func wobble_busy() -> void:
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	_squash_tween = create_tween()
	var orig_x := _sprite.position.x
	_squash_tween.tween_property(_sprite, "position:x", orig_x - 3.0, 0.05)
	_squash_tween.tween_property(_sprite, "position:x", orig_x + 3.0, 0.05)
	_squash_tween.tween_property(_sprite, "position:x", orig_x - 2.0, 0.05)
	_squash_tween.tween_property(_sprite, "position:x", orig_x + 1.0, 0.05)
	_squash_tween.tween_property(_sprite, "position:x", orig_x, 0.05)
	Juice.play(&"plant", global_position + Vector2(0, -10))

## Juicy: Goyang halus tanda bahan tidak cocok
func wobble_reject() -> void:
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	_squash_tween = create_tween()
	var orig_x := _sprite.position.x
	_squash_tween.tween_property(_sprite, "position:x", orig_x - 2.0, 0.05)
	_squash_tween.tween_property(_sprite, "position:x", orig_x + 2.0, 0.05)
	_squash_tween.tween_property(_sprite, "position:x", orig_x - 1.0, 0.04)
	_squash_tween.tween_property(_sprite, "position:x", orig_x, 0.04)

func refresh() -> void:
	if _sprite == null:
		return
	var record := StructureManager.record_for(uid)
	if record.is_empty():
		return
	var item := GameState._resolve_item(record.item)
	_sprite.hframes = 1
	_sprite.vframes = 1
	_sprite.frame = 0
	_sprite.texture = item.icon
	_sprite.position = Vector2.ZERO
	if record.item == "barn":
		_sprite.position.y = -16
	_sprite.region_enabled = false
	_sprite.scale = Vector2.ONE
	_sprite.modulate = Color(1, 1, 1, 0.45) if record.item == "wooden_gate" and record.open else Color.WHITE
	_coop_status.visible = record.item in StructureManager.RANCHES or record.item == "silo"
	_egg_icon.visible = false
	if record.item in StructureManager.RANCHES:
		_sprite.position.y = -16
		var animals := StructureManager.coop_state(record)
		var fed := 0
		var ready := RanchHusbandry.product_count(animals)
		for animal in animals.chickens:
			fed += 1 if int(animal.fed_day) == DayCycle.current_day else 0
			ready += 1 if not str(animal.ready).is_empty() else 0
		_coop_status.text = "Makan %d/%d · Siap %d%s" % [fed, animals.chickens.size(), ready, " · Kotor!" if int(animals.dirt) >= 3 else ""]
		_egg_icon.visible = record.item == "chicken_coop" and ready > 0
		if int(animals.tier) > 0:
			var folder := "Chicken Coop" if record.item == "chicken_coop" else "Barn"
			var prefix := "Big" if int(animals.tier) == 1 else "Deluxe"
			_sprite.texture = load("res://assets/farm_rpg/objects/exterior/Houses/Farm Buildings/%s/%s %s.png" % [folder, prefix, folder])
			_sprite.region_enabled = true
			_sprite.region_rect = Rect2(0, 0, _sprite.texture.get_height(), _sprite.texture.get_height())
			_sprite.scale = Vector2.ONE * (80.0 if record.item == "chicken_coop" else 96.0) / _sprite.region_rect.size.x
	if record.item == "silo":
		_sprite.position.y = -32
		_coop_status.text = "Jerami %d/240" % int(record.get("hay", 0))
	if record.item == "pasture_grass":
		_sprite.modulate = Color("8e805d") if int(record.get("regrow_day", 0)) > DayCycle.current_day or DayCycle.get_current_season() == "winter" else Color.WHITE
		_sprite.scale = Vector2(1, 0.35) if int(record.get("regrow_day", 0)) > DayCycle.current_day else Vector2.ONE
	if record.item in StructureManager.CHESTS:
		_apply_chest_texture(item)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(item.placement_size * 16) - Vector2(2, 2)
	_collision.shape = shape
	_collision.set_deferred("disabled", record.item == "pasture_grass" or (record.item == "wooden_gate" and record.open))
	if record.item == "furnace":
		_sprite.texture = (item.icon as AtlasTexture).atlas
		_sprite.hframes = 5
	if record.item == "preserves_jar":
		_sprite.texture = (item.icon as AtlasTexture).atlas
		_sprite.hframes = 4
		_sprite.vframes = 2
	if record.item == "dehydrator":
		_sprite.texture = (item.icon as AtlasTexture).atlas
		_sprite.hframes = 4
	if record.item in ["cheese_press", "loom"]:
		_sprite.texture = (item.icon as AtlasTexture).atlas
		_sprite.hframes = maxi(1, _sprite.texture.get_width() / 32)
		_sprite.vframes = maxi(1, _sprite.texture.get_height() / 32)
	var art := _art(str(record.item))
	if record.item in StructureManager.DECOR or record.item in StructureManager.WORKSHOPS:
		if int(art.get("frames", 1)) > 1:
			_sprite.texture = (item.icon as AtlasTexture).atlas
			_sprite.hframes = int(art.frames)
		# Sprite tinggi berdiri di baris bawah tapak, bukan menggantung di tengah.
		_sprite.position.y = (item.placement_size.y * 16 - item.icon.get_height()) / 2.0
	# Lampu malam langsung menyala saat scene dimuat (tidak menunggu _process setelah transisi).
	_animate_art(str(record.item))

func _art(item_id: String) -> Dictionary:
	return StructureManager.DECOR.get(item_id, StructureManager.WORKSHOPS.get(item_id, {}))

func _process(delta: float) -> void:
	var record := StructureManager.record_for(uid)
	if record.is_empty():
		_ready_sound.update_ready(false)
		_ready_bubble.hide()
		return
	var is_machine: bool = record.get("item") in ["furnace", "preserves_jar", "dehydrator", "sawmill", "beehive", "keg", "oil_maker", "fish_smoker", "lightning_rod"] or record.get("item") in StructureManager.ARTISANS
	# Sarang lebah selalu punya job (hari panen), jadi tidak dihitung "berjalan".
	var is_running: bool = is_machine and not record.job.is_empty() and DayCycle.is_running and record.get("item") != "beehive"
	var is_ready: bool = is_machine and not record.ready.is_empty()
	_ready_sound.update_ready(is_ready)

	if record.get("item") == "furnace":
		_sprite.frame = int(Time.get_ticks_msec() / 125) % 5 if is_running else 0
	elif record.get("item") == "preserves_jar":
		if is_running:
			_sprite.frame = 4 + (int(Time.get_ticks_msec() / 150) % 4)
		elif is_ready:
			_sprite.frame = 1
		else:
			_sprite.frame = 0
	elif record.get("item") == "dehydrator":
		if is_running:
			_sprite.frame = int(Time.get_ticks_msec() / 150) % 4
		elif is_ready:
			_sprite.frame = 1
		else:
			_sprite.frame = 0
	elif record.get("item") in ["cheese_press", "loom"]:
		_sprite.frame = int(Time.get_ticks_msec() / 180) % _sprite.hframes if is_running else 0

	# ── SFX & VFX Saat Mesin Running ──
	if is_running:
		if not _audio_loop.playing:
			var sfx_file := ""
			match record.item:
				"furnace": sfx_file = "res://assets/audio/sfx/machines/machine_furnace_loop.wav"
				"keg": sfx_file = "res://assets/audio/sfx/machines/machine_preserves_loop.wav"
				"oil_maker": sfx_file = "res://assets/audio/sfx/machines/machine_cheese_loop.wav"
				"fish_smoker": sfx_file = "res://assets/audio/sfx/machines/machine_furnace_loop.wav" 
				"preserves_jar": sfx_file = "res://assets/audio/sfx/machines/machine_preserves_loop.wav"
				"dehydrator": sfx_file = "res://assets/audio/sfx/machines/machine_dehydrator_loop.wav"
				"cheese_press": sfx_file = "res://assets/audio/sfx/machines/machine_cheese_loop.wav"
				"loom": sfx_file = "res://assets/audio/sfx/machines/machine_loom_loop.wav"
				"mayonnaise_maker": sfx_file = "res://assets/audio/sfx/machines/machine_mayonnaise_loop.wav"
			if not sfx_file.is_empty():
				var source: AudioStream = load(sfx_file) if ResourceLoader.exists(sfx_file) else AudioStreamWAV.load_from_file(sfx_file)
				if source != null:
					var stream: AudioStream = source.duplicate()
					if stream is AudioStreamWAV:
						(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
						stream.loop_begin = 0
						stream.loop_end = int(round(stream.get_length() * stream.mix_rate))
					_audio_loop.stream = stream
					_audio_loop.play()
		_particles.emitting = true
		match record.item:
			"furnace":
				_particles.color = Color(1.0, 0.45 + randf() * 0.3, 0.1, 0.85)
				_light.enabled = true
				_light.energy = 0.75 + sin(Time.get_ticks_msec() * 0.015) * 0.2
			"preserves_jar":
				_particles.color = Color(0.9, 0.45, 0.8, 0.8) if int(Time.get_ticks_msec() / 250) % 2 == 0 else Color(1.0, 0.85, 0.95, 0.85)
				_light.enabled = false
			"dehydrator":
				_particles.color = Color(1.0, 0.85, 0.4, 0.75)
				_light.enabled = true
				_light.energy = 0.35 + sin(Time.get_ticks_msec() * 0.008) * 0.1
			"cheese_press":
				_particles.color = Color("efd38a")
				_light.enabled = false
			"loom":
				_particles.color = Color("e0c9a9")
				_particles.amount = 8
				_light.enabled = false
			"mayonnaise_maker":
				_particles.color = Color("fff0bd")
				_particles.amount = 10
				_light.enabled = false
			"sawmill":
				_particles.color = Color("c99a5b")
				_particles.amount = 10
				_light.enabled = false
	else:
		if _audio_loop.playing:
			_audio_loop.stop()
		_particles.emitting = false
		if _light != null:
			_light.enabled = false

	# ── SFX & VFX Saat Mesin Selesai (Ready) ──
	if _was_running and not is_running and is_ready:
		Juice.play(&"sparkle", global_position)

	# ── Stardew-Style Ready Product Floating Bubble ──
	if ready_bubble_enabled and is_ready and not record.ready.is_empty():
		_ready_bubble.visible = true
		var pid := str(record.ready.get("id", ""))
		var pitem := GameState._resolve_item(pid)
		if use_product_icon:
			_bubble_icon.texture = pitem.icon if pitem != null else null
			_bubble_icon.region_enabled = false
			if pitem != null and pitem.icon != null:
				var icon_texture: Texture2D = pitem.icon
				var frame_size := Vector2i(maxi(1, product_frame_size.x), maxi(1, product_frame_size.y))
				var source_size := Vector2i(icon_texture.get_width(), icon_texture.get_height())
				if crop_product_sheet and not icon_texture is AtlasTexture and source_size.x % frame_size.x == 0 and source_size.y % frame_size.y == 0 and source_size != frame_size:
					var columns := source_size.x / frame_size.x
					var rows := source_size.y / frame_size.y
					var frame_cell := Vector2i(clampi(product_frame.x, 0, columns - 1), clampi(product_frame.y, 0, rows - 1))
					_bubble_icon.region_enabled = true
					_bubble_icon.region_rect = Rect2(Vector2(frame_cell * frame_size), Vector2(frame_size))
				var max_dim := maxf(_bubble_icon.get_rect().size.x, _bubble_icon.get_rect().size.y)
				_bubble_icon.scale = _icon_base_scale * (ready_icon_size / maxf(1.0, max_dim))

		var bob := sin(_bubble_age * ready_bob_speed) * ready_bob_amplitude
		var h: float = _sprite.get_rect().size.y if _sprite.texture != null else 32.0
		_ready_bubble.position = _bubble_origin + Vector2(0, _sprite.position.y - h * ready_height_factor + bob)
		_update_bubble_juice(delta, true)
	else:
		_update_bubble_juice(delta, false)

	# Animasi lembut saat produk sedang diproses atau siap diambil
	var is_tweening: bool = _squash_tween != null and _squash_tween.is_valid()
	if not is_tweening:
		if is_running:
			_ready_bounce_time += delta
			var motion := sin(_ready_bounce_time * 9.0) * 0.025
			_sprite.scale = Vector2(1 + motion, 1 - motion)
		elif is_ready:
			_ready_bounce_time += delta
			var pulse := sin(_ready_bounce_time * 5.0) * 0.05
			_sprite.scale = Vector2(1.0 + pulse, 1.0 - pulse)
		elif not (record.get("item") in StructureManager.RANCHES or record.get("item") == "pasture_grass" or (record.get("item") in StructureManager.CHESTS and _lid_tween != null and _lid_tween.is_valid())):
			_sprite.scale = Vector2.ONE
			_ready_bounce_time = 0.0

	_was_running = is_running

	if record.get("item") in StructureManager.CHESTS:
		_update_chest_lid()
	_animate_art(str(record.get("item", "")))

## Animasi relatif terhadap transform scene, tanpa tween yang bertumpuk saat refresh.
func _update_bubble_juice(delta: float, present: bool) -> void:
	if not ready_bubble_enabled or not bubble_juice_enabled:
		_bubble_present = present and ready_bubble_enabled
		_bubble_departing = false
		_bubble_age = _bubble_age + maxf(0.0, delta) if _bubble_present else 0.0
		_ready_bubble.visible = _bubble_present
		_ready_bubble.scale = _bubble_base_scale
		_ready_bubble.rotation = _bubble_base_rotation
		_ready_bubble.modulate = _bubble_base_modulate
		return
	if present:
		if not _bubble_present:
			_bubble_age = 0.0
		_bubble_present = true
		_bubble_departing = false
		_bubble_age += maxf(0.0, delta)
		var progress := clampf(_bubble_age / maxf(0.001, bubble_pop_seconds), 0.0, 1.0)
		var back := progress - 1.0
		var eased := 1.0 + (bubble_pop_overshoot + 1.0) * back * back * back + bubble_pop_overshoot * back * back
		var pop := lerpf(bubble_pop_start_scale, 1.0, eased)
		var stretch := sin(progress * TAU) * (1.0 - progress) * bubble_pop_stretch
		var idle := 1.0 + sin(_bubble_age * bubble_pulse_speed) * bubble_idle_pulse * progress
		_ready_bubble.scale = _bubble_base_scale * Vector2(pop * (1.0 + stretch), pop * (1.0 - stretch)) * idle
		_ready_bubble.rotation = _bubble_base_rotation + deg_to_rad(bubble_sway_degrees) * sin(_bubble_age * bubble_sway_speed) * progress
		_ready_bubble.modulate = _bubble_base_modulate
		_ready_bubble.visible = true
		return
	if _bubble_present:
		_bubble_present = false
		_bubble_departing = true
		_bubble_departure_age = 0.0
		_bubble_exit_position = _ready_bubble.position
	if _bubble_departing:
		_bubble_departure_age += maxf(0.0, delta)
		var progress := clampf(_bubble_departure_age / maxf(0.001, bubble_collect_seconds), 0.0, 1.0)
		_ready_bubble.position = _bubble_exit_position + Vector2.UP * bubble_collect_rise * progress
		_ready_bubble.scale = _bubble_base_scale * lerpf(1.0, bubble_collect_scale, progress)
		_ready_bubble.rotation = _bubble_base_rotation
		_ready_bubble.modulate = _bubble_base_modulate * Color(1, 1, 1, 1.0 - progress)
		if progress < 1.0:
			return
		_bubble_departing = false
	_ready_bubble.hide()
	_ready_bubble.scale = _bubble_base_scale
	_ready_bubble.rotation = _bubble_base_rotation
	_ready_bubble.modulate = _bubble_base_modulate

## Dekorasi/mesin baru: frame animasi, frame malam (lampu), dan cahaya saat malam.
func _animate_art(item_id: String) -> void:
	var art := _art(item_id)
	if art.is_empty():
		return
	var night := DayCycle.night_intensity() > 0.0
	if art.has("night_frame"):
		_sprite.frame = int(art.night_frame) if night else 0
	elif int(art.get("frames", 1)) > 1:
		_sprite.frame = int(Time.get_ticks_msec() / 140) % int(art.frames)
	if art.get("light", false):
		_light.enabled = night
		# Cahaya kuat mengusir Leak/Kuyang (GDD 4.1, Progres Horor Tahap 5).
		if art.get("strong_light", false) and not _light.is_in_group(&"horror_strong_light"):
			_light.add_to_group(&"horror_strong_light")
		_light.position = Vector2(0, _sprite.position.y - 6)
		_light.energy = 0.6 + sin(Time.get_ticks_msec() * 0.006) * 0.08

func _update_chest_lid() -> void:
	var record := StructureManager.record_for(uid)
	var item := GameState._resolve_item(record.item)
	var world: Node = get_parent().get_meta("world").get_ref() if get_parent().has_meta("world") else null
	var nearby := false
	if is_instance_valid(world):
		for candidate in world.find_children("*", "", true, false):
			if candidate is Player and is_instance_valid(candidate):
				var feet: Vector2 = candidate.global_position + Player.FEET_OFFSET
				var center := global_position + Vector2(item.placement_size - Vector2i.ONE) * 8
				if feet.distance_to(center) <= item.chest_open_distance:
					nearby = true
					break
	if nearby == _chest_open:
		return
	_chest_open = nearby
	_apply_chest_texture(item)
	if Time.get_ticks_msec() >= _quiet_until_ms:
		Juice.play_sound(&"bin_open" if _chest_open else &"bin_close")
	if _lid_tween != null and _lid_tween.is_valid():
		_lid_tween.kill()
	_sprite.scale = Vector2(0.9, 1.12) if _chest_open else Vector2(1.12, 0.88)
	_lid_tween = create_tween()
	_lid_tween.tween_property(_sprite, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _apply_chest_texture(item: ItemData) -> void:
	_sprite.region_enabled = false
	var closed: Texture2D = item.chest_closed_texture if item.chest_closed_texture != null else item.icon
	_sprite.texture = item.chest_open_texture if _chest_open and item.chest_open_texture != null else closed
