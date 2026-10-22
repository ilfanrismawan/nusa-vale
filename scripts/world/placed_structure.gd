extends StaticBody2D

var uid := 0
var _sprite: Sprite2D
var _collision: CollisionShape2D
var _chest_open := false
var _quiet_until_ms := 0
var _lid_tween: Tween
var _coop_status: Label
var _egg_icon: Sprite2D
var _particles: CPUParticles2D
var _light: PointLight2D
var _audio_loop: AudioStreamPlayer2D
var _was_running := false
var _ready_bounce_time := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite = Sprite2D.new()
	add_child(_sprite)
	_collision = CollisionShape2D.new()
	add_child(_collision)
	_coop_status = Label.new()
	_coop_status.position = Vector2(-24, 25)
	_coop_status.add_theme_font_override("font", preload("res://assets/fonts/m5x7.ttf"))
	_coop_status.add_theme_font_size_override("font_size", 12)
	_coop_status.add_theme_color_override("font_color", Color("fff1c9"))
	_coop_status.add_theme_color_override("font_outline_color", Color("302333"))
	_coop_status.add_theme_constant_override("outline_size", 2)
	_coop_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_coop_status)
	_egg_icon = Sprite2D.new()
	_egg_icon.position = Vector2(28, 27)
	_egg_icon.texture = preload("res://assets/farm_rpg/icons/Food Icons/Chicken Egg.png")
	add_child(_egg_icon)

	# ── VFX: Partikel buatan prosedural (CC0) ──
	_particles = CPUParticles2D.new()
	_particles.emitting = false
	_particles.amount = 14
	_particles.lifetime = 0.85
	_particles.position = Vector2(0, -6)
	_particles.direction = Vector2.UP
	_particles.spread = 22.0
	_particles.gravity = Vector2(0, -28)
	_particles.initial_velocity_min = 16.0
	_particles.initial_velocity_max = 34.0
	_particles.scale_amount_min = 1.5
	_particles.scale_amount_max = 2.5
	add_child(_particles)

	# ── VFX: Cahaya hangat prosedural (CC0) ──
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1.0, 0.65, 0.2, 0.8), Color(1.0, 0.35, 0.0, 0.0)])
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = gradient
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(1.0, 0.5)
	grad_tex.width = 64
	grad_tex.height = 64

	_light = PointLight2D.new()
	_light.texture = grad_tex
	_light.enabled = false
	_light.texture_scale = 1.3
	add_child(_light)

	# ── SFX: Audio loop spasial saat mesin running (CC0) ──
	_audio_loop = AudioStreamPlayer2D.new()
	_audio_loop.bus = &"SFX"
	_audio_loop.volume_db = -14
	_audio_loop.max_distance = 180.0
	_audio_loop.attenuation = 1.5
	add_child(_audio_loop)

	_quiet_until_ms = Time.get_ticks_msec() + 400
	refresh()

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
		_sprite.hframes = _sprite.texture.get_width() / 32
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
	var is_machine: bool = record.get("item") in ["furnace", "preserves_jar", "dehydrator", "sawmill", "beehive", "keg", "oil_maker", "fish_smoker", "lightning_rod"] or record.get("item") in StructureManager.ARTISANS
	# Sarang lebah selalu punya job (hari panen), jadi tidak dihitung "berjalan".
	var is_running: bool = is_machine and not record.job.is_empty() and DayCycle.is_running and record.get("item") != "beehive"
	var is_ready: bool = is_machine and not record.ready.is_empty()

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
		Juice.sfx(load("res://assets/audio/sfx/machines/machine_ready.wav"), -4.0)
		Juice.play(&"sparkle", global_position)

	# Animasi lembut saat produk siap diambil
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
