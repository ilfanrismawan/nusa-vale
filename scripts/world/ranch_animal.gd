extends CharacterBody2D
## A farm-world view only. All care and production live in shared save records.
const AnimalPhysics := preload("res://scripts/world/animal_physics.gd")
const FEET_RADIUS := 4.0
const GroundShadow := preload("res://scripts/effects/ground_shadow.gd")
var uid := 0
var animal_id := 0
var home := Vector2.ZERO
var indoors := false
var roam_rect := Rect2()
var _sprite: AnimatedSprite2D
var _badge: Label
var _product_icon: Sprite2D
var _target := Vector2.ZERO
var _pasture_uid := 0
var _timer := 0.0
var _facing := "down"
var _carried_by: Player
var _shadow: Node2D

func _ready() -> void:
	add_to_group(&"ranch_animal")
	collision_layer = 0
	collision_mask = AnimalPhysics.OBSTACLE_MASK
	# Top-down: tanpa lantai/dinding ala platformer, supaya meluncur rata di sepanjang pagar.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = FEET_RADIUS
	shape.shape = circle
	add_child(shape)
	_sprite = AnimatedSprite2D.new()
	_sprite.position.y = -8
	add_child(_sprite)
	_shadow = GroundShadow.attach(self)
	_badge = Label.new()
	_badge.position = Vector2(-23, 10) if indoors else Vector2(-18, -28)
	if indoors:
		_badge.size = Vector2(46, 12)
		_badge.clip_text = true
	_badge.add_theme_font_override("font", preload("res://assets/fonts/m5x7.ttf"))
	_badge.add_theme_font_size_override("font_size", 12)
	_badge.add_theme_color_override("font_color", Color("fff1c9"))
	_badge.add_theme_color_override("font_outline_color", Color("302333"))
	_badge.add_theme_constant_override("outline_size", 2)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_badge)
	_product_icon = Sprite2D.new()
	_product_icon.position = Vector2(10, -20)
	_product_icon.scale = Vector2(0.75, 0.75)
	add_child(_product_icon)
	# Titik rumah (depan kandang) bisa tertutup objek yang ditaruh pemain: geser ke titik kosong.
	home = AnimalPhysics.nearest_free(self, home, FEET_RADIUS, 24.0 if indoors else 48.0, [get_rid()])
	_target = home
	global_position = home
	refresh()

func animal() -> Dictionary:
	var record := StructureManager.record_for(uid)
	return {} if record.is_empty() else RanchHusbandry.animal_by_id(StructureManager.coop_state(record), animal_id)

func refresh() -> void:
	var record := StructureManager.record_for(uid)
	var bird := animal()
	if record.is_empty() or bird.is_empty():
		queue_free()
		return
	if is_instance_valid(_carried_by):
		return
	visible = not StructureManager.coop_state(record).door if indoors else StructureManager.coop_state(record).door
	# Kuda gaya Stardew berdiri di dunia sebagai HorseActor (horse_actor.gd), bukan di kandang/padang.
	if RanchHusbandry.species(bird) == "horse" and RanchHusbandry.is_adult(bird):
		visible = false
	# Anak tanpa sheet anak memakai sprite dewasa yang diperkecil.
	_sprite.scale = Vector2.ONE * (1.0 if RanchHusbandry.is_adult(bird) or RanchVisual.has_baby_sheet(RanchHusbandry.species(bird)) else 0.65)
	_badge.text = "Siap" if not str(bird.ready).is_empty() else ("Lapar" if int(bird.fed_day) != DayCycle.current_day else str(bird.name))
	if indoors:
		_badge.text = str(bird.name) + (" !" if bird.sick or int(bird.fed_day) != DayCycle.current_day else "")
	_product_icon.visible = not str(bird.ready).is_empty()
	if _product_icon.visible:
		_product_icon.texture = GameState._resolve_item(str(bird.ready)).icon
	if not visible:
		global_position = home
		_timer = 0
	_set_frames(bird, false)

func _set_frames(bird: Dictionary, walking: bool) -> void:
	if walking:
		_facing = "side" if absf(velocity.x) > absf(velocity.y) else ("up" if velocity.y < 0 else "down")
	var frames := RanchVisual.frames(RanchHusbandry.species(bird), str(bird.variant), walking, _facing, not RanchHusbandry.is_adult(bird))
	if _sprite.sprite_frames != frames:
		_sprite.sprite_frames = frames
		_sprite.play()
		_fit_feet()

## Kaki di baris terbawah sel (16 px ayam/bebek, 32 px lainnya): geser sprite supaya kaki tepat di
## titik badan (collision dan y-sort), lalu ukur bayangan sesuai lebar hewan.
func _fit_feet() -> void:
	var names := _sprite.sprite_frames.get_animation_names()
	if names.is_empty() or _sprite.sprite_frames.get_frame_count(names[0]) == 0:
		return
	var height := float(_sprite.sprite_frames.get_frame_texture(names[0], 0).get_height())
	# Posisi sprite (-8) ditambah offset ini = -height/2: dasar sel tepat di titik badan.
	_sprite.offset.y = 8.0 - height * 0.5
	if is_instance_valid(_shadow):
		_shadow.radius = 4.0 if height <= 16.0 else 8.0

func _physics_process(delta: float) -> void:
	if is_instance_valid(_carried_by):
		if _carried_by.get_world_2d() != get_world_2d():
			_carried_by.set_meta("carried_animal", null)
			_carried_by = null
			global_position = home
			_sprite.position = Vector2(0, -8)
			_sprite.z_as_relative = true
			_sprite.z_index = 0
			collision_mask = 1
			_badge.show()
			_shadow.show()
			refresh()
			return
		global_position = _carried_by.global_position + Player.SPRITE_OFFSET + Vector2(0, -22)
		return
	if not visible or not DayCycle.is_running:
		return
	var bird := animal()
	if bird.is_empty():
		return
	_timer -= delta
	if _timer <= 0:
		_choose_target(bird)
	var offset := _target - global_position
	velocity = offset.normalized() * 13 if offset.length() > 3 else Vector2.ZERO
	_set_frames(bird, velocity.length() > 0)
	if absf(velocity.x) > 0.01:
		_sprite.flip_h = (velocity.x < 0) == RanchVisual.faces_right(RanchHusbandry.species(bird))
	move_and_slide()
	# Menabrak pagar/bangunan/objek dan tidak bisa meluncur: pilih tujuan lain di frame berikutnya.
	if get_slide_collision_count() > 0 and get_real_velocity().length() < 2.0:
		_pasture_uid = 0
		_timer = minf(_timer, 0.4)
		return
	if _pasture_uid > 0 and global_position.distance_to(_target) < 10:
		if StructureManager.graze_animal(uid, animal_id, _pasture_uid).ok:
			Juice.play(&"plant", global_position)
		_pasture_uid = 0
		_timer = 0

func _choose_target(bird: Dictionary) -> void:
	_timer = 3.0
	_pasture_uid = 0
	if indoors:
		_target = Vector2(randf_range(roam_rect.position.x, roam_rect.end.x), randf_range(roam_rect.position.y, roam_rect.end.y))
		return
	var ground := get_parent().get_meta("world").get_ref().get_node_or_null("BaseLayerGround") as TileMapLayer
	if ground == null:
		return
	if int(bird.fed_day) != DayCycle.current_day:
		var nearest := 112.0
		for record in StructureManager.records:
			if record.item != "pasture_grass" or int(record.get("regrow_day", 0)) > DayCycle.current_day:
				continue
			var target := ground.to_global(ground.map_to_local(Vector2i(int(record.cell[0]), int(record.cell[1]))))
			if home.distance_to(target) > 112 or global_position.distance_to(target) >= nearest:
				continue
			var ray := PhysicsRayQueryParameters2D.create(global_position, target, 1, [get_rid()])
			if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
				continue
			_target = target
			_pasture_uid = int(record.uid)
			nearest = global_position.distance_to(target)
		if _pasture_uid > 0:
			return
	for attempt in 8:
		var target := home + Vector2(randf_range(-40, 40), randf_range(4, 36))
		var cell := ground.local_to_map(ground.to_local(target))
		var tile := ground.get_cell_tile_data(cell)
		if tile == null or not tile.get_custom_data("farmable") or StructureManager.occupies(cell):
			continue
		var ray := PhysicsRayQueryParameters2D.create(global_position, target, 1, [get_rid()])
		if get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			_target = target
			return
	_target = global_position

func interact_with(player: Player) -> void:
	if player.input.pressed(&"run"):
		lift_with(player)
	else:
		care_with(player)

func lift_with(player: Player) -> void:
	if is_instance_valid(_carried_by):
		return
	if player.has_meta("carried_animal") and is_instance_valid(player.get_meta("carried_animal")):
		return
	_carried_by = player
	player.set_meta("carried_animal", self)
	visible = true
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	_badge.hide()
	_product_icon.hide()
	_shadow.hide()
	# Diangkat: pusat gambar di atas kepala seperti sebelum offset kaki (_fit_feet).
	_sprite.position = Vector2(0, -_sprite.offset.y)
	_sprite.z_index = 11
	_sprite.z_as_relative = false
	global_position = player.global_position + Player.SPRITE_OFFSET + Vector2(0, -22)
	player.play_item_gesture(true)
	Notify.say("%s diangkat. Tekan interaksi untuk meletakkan." % str(animal().name))

func place_from_player(player: Player) -> void:
	if _carried_by != player:
		return
	_carried_by = null
	player.set_meta("carried_animal", null)
	global_position = player.global_position + Player.FEET_OFFSET + player.facing_direction.normalized() * 12.0
	if indoors:
		global_position = global_position.clamp(Vector2(267, 160), Vector2(587, 326))
	var ray := PhysicsRayQueryParameters2D.create(player.global_position + Player.FEET_OFFSET, global_position, 1, [get_rid(), player.get_rid()])
	if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
		global_position = player.global_position + Player.FEET_OFFSET
	if indoors:
		home = global_position
		roam_rect = Rect2(home - Vector2(10, 6), Vector2(20, 12)).intersection(Rect2(267, 160, 320, 166))
	_sprite.position = Vector2(0, -8)
	_sprite.z_index = 0
	_sprite.z_as_relative = true
	_badge.show()
	_shadow.show()
	collision_layer = 0
	collision_mask = 1
	_target = global_position
	_timer = 0.0
	player.play_item_gesture(false)
	Notify.say("%s diletakkan kembali." % str(animal().name))

func care_with(player: Player) -> void:
	if is_instance_valid(_carried_by):
		return
	var bird := animal()
	if bird.is_empty():
		return
	var result: Dictionary
	if not str(bird.ready).is_empty():
		result = StructureManager.harvest_animal(player.data, uid, animal_id)
	elif int(bird.pet_day) != DayCycle.current_day:
		result = StructureManager.pet_chicken(uid, animal_id)
	elif int(bird.fed_day) != DayCycle.current_day:
		result = StructureManager.feed_chickens(player.data, uid, animal_id)
	elif not RanchHusbandry.species(bird) in ["chicken", "duck"] and int(bird.brush_day) != DayCycle.current_day:
		result = StructureManager.brush_animal(player.data, uid, animal_id)
	else:
		result = {"message": "%s sudah dirawat hari ini." % bird.name}
	Notify.say(result.message)
	if result.get("ok", false):
		Juice.play(&"sparkle", global_position)
