class_name PetActor
extends CharacterBody2D
## Peliharaan pilihan pemain 1 (kucing/anjing) yang tinggal di rumah ladang.
## Siang (06.00-19.59) bermain di depan pintu rumah ladang, malam di dalam rumah. Dielus sekali
## sehari oleh pemain mana pun: kasih sayang naik. Dibuat/dihapus sync_all() dari StructureManager;
## posisinya tidak disimpan.
## Badan fisik di kaki (layer 0, mask 1): terhalang bangunan/pagar/objek seperti pemain, tetapi
## tidak menghalangi pemain. Area anak di layer interaksi untuk dielus.
const AnimalPhysics := preload("res://scripts/world/animal_physics.gd")
const GroundShadow := preload("res://scripts/effects/ground_shadow.gd")
const GROUP := &"pet_actor"
const MAX_AFFECTION := 100
const PET_GAIN := 5
const DAY_START := 6
const DAY_END := 20
const HOUSE_SCENE := "interior_house.tscn"
## Titik main di dalam rumah: dekat titik masuk pemain (enter_door_house.gd target_spawn_pos 310, 193).
const INDOOR_HOME := Vector2(284, 204)
## Titik main di ladang relatif terhadap node pintu rumah (pusat bangunan; ambang pintu di y+30).
const FARM_OFFSET := Vector2(34, 56)
const WANDER_RADIUS := 26.0
const SPEED := 22.0
const FEET_RADIUS := 4.0
static var _frames: Dictionary = {}
var home := Vector2.ZERO
var _sprite: AnimatedSprite2D
var _badge: Label
var _target := Vector2.ZERO
var _wait := 0.0
var _facing := "down"
var _day := -1

func _ready() -> void:
	add_to_group(GROUP)
	set_meta("player_interaction", true)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	collision_layer = 0
	collision_mask = AnimalPhysics.OBSTACLE_MASK
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var feet := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = FEET_RADIUS
	feet.shape = circle
	add_child(feet)
	var area := Area2D.new()
	area.collision_layer = 1 << 9
	area.collision_mask = 0
	area.monitoring = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 12)
	shape.shape = rect
	shape.position = Vector2(0, -5)
	area.add_child(shape)
	add_child(area)
	_sprite = AnimatedSprite2D.new()
	# Kaki di sheet ada di sekitar y=28 dari sel 32.
	_sprite.position.y = -12
	add_child(_sprite)
	GroundShadow.attach(self, 5.0)
	_badge = Label.new()
	_badge.position = Vector2(-20, -32)
	_badge.size = Vector2(40, 10)
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.add_theme_font_override("font", preload("res://assets/fonts/m5x7.ttf"))
	_badge.add_theme_font_size_override("font_size", 12)
	_badge.add_theme_color_override("font_color", Color("fff1c9"))
	_badge.add_theme_color_override("font_outline_color", Color("302333"))
	_badge.add_theme_constant_override("outline_size", 2)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_badge)
	_target = home
	_wait = randf_range(1.0, 3.0)
	refresh()

func owner_data() -> PlayerData:
	return GameState.p1()

func refresh() -> void:
	var data := owner_data()
	var frames := pet_frames(data.pet_id)
	if frames == null:
		queue_free()
		return
	_sprite.sprite_frames = frames
	_play(false)
	_badge.text = data.pet_name + (" ♥" if data.pet_day != DayCycle.current_day else "")

func _physics_process(delta: float) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if _day != DayCycle.current_day:
		_day = DayCycle.current_day
		refresh()
	if _wait > 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_target = _pick_target()
		return
	var step := _target - position
	if step.length() <= 1.0:
		_rest()
		return
	_facing = "side" if absf(step.x) > absf(step.y) else ("up" if step.y < 0 else "down")
	# Sheet menghadap kiri; balik saat berjalan ke kanan.
	_sprite.flip_h = _facing == "side" and step.x > 0
	velocity = step.normalized() * minf(SPEED, step.length() / delta)
	move_and_slide()
	# Menabrak bangunan/pagar/objek: berhenti, nanti pilih tujuan lain.
	if get_slide_collision_count() > 0:
		_rest()
		return
	_play(true)

func _rest() -> void:
	velocity = Vector2.ZERO
	_target = position
	_wait = randf_range(2.5, 6.0)
	_play(false)

## Titik main acak di sekitar rumah yang kosong dan bisa dicapai lurus tanpa menembus objek.
func _pick_target() -> Vector2:
	var parent := get_parent() as Node2D
	for attempt in 8:
		var candidate := home + Vector2.from_angle(randf() * TAU) * randf_range(6.0, WANDER_RADIUS)
		if parent == null:
			return candidate
		var global_candidate := parent.to_global(candidate)
		if AnimalPhysics.is_free(self, global_candidate, FEET_RADIUS, [get_rid()]) \
				and not AnimalPhysics.is_blocked(self, global_position, global_candidate, [get_rid()]):
			return candidate
	return position

## Rumah peliharaan bisa tertutup objek yang ditaruh pemain: geser ke titik kosong terdekat.
func settle_home() -> void:
	var parent := get_parent() as Node2D
	if parent == null:
		return
	home = parent.to_local(AnimalPhysics.nearest_free(self, parent.to_global(home), FEET_RADIUS, 48.0, [get_rid()]))
	position = home
	_target = home

func _play(walking: bool) -> void:
	var anim := StringName("walk_" + _facing) if walking else &"sit"
	if not walking:
		_sprite.flip_h = false
	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)

func interact(player: Node) -> void:
	if not player is Player:
		return
	var result := pet()
	Notify.say(result.message)
	if result.ok:
		_wait = maxf(_wait, 2.0)
		_play(false)
		var heart := Label.new()
		heart.text = "♥"
		heart.position = Vector2(-4, -34)
		heart.add_theme_color_override("font_color", Color("ff6b7a"))
		heart.add_theme_color_override("font_outline_color", Color("302333"))
		heart.add_theme_constant_override("outline_size", 2)
		add_child(heart)
		var tween := heart.create_tween()
		tween.tween_property(heart, "position:y", -48.0, 0.8)
		tween.parallel().tween_property(heart, "modulate:a", 0.0, 0.8)
		tween.tween_callback(heart.queue_free)
	var squash := create_tween()
	squash.tween_property(_sprite, "scale", Vector2(1.12, 0.88), 0.08)
	squash.tween_property(_sprite, "scale", Vector2.ONE, 0.14)

## Elus peliharaan pemain 1: {"ok", "message"}.
static func pet() -> Dictionary:
	var data := GameState.p1()
	if data.pet_id.is_empty():
		return {"ok": false, "message": "Belum ada peliharaan."}
	if data.pet_day == DayCycle.current_day:
		return {"ok": false, "message": "%s sudah dielus hari ini." % data.pet_name}
	data.pet_day = DayCycle.current_day
	data.pet_affection = mini(MAX_AFFECTION, data.pet_affection + PET_GAIN)
	Juice.play_sound(&"pickup")
	for actor in (Engine.get_main_loop() as SceneTree).get_nodes_in_group(GROUP):
		actor.refresh()
	return {"ok": true, "message": "%s senang dielus! (Kasih sayang %d/%d)" % [data.pet_name, data.pet_affection, MAX_AFFECTION]}

static func option(pet_id: String) -> Resource:
	var path := "res://resources/pets/%s.tres" % pet_id
	return load(path) if not pet_id.is_empty() and ResourceLoader.exists(path) else null

## Animasi dari sheet Pets: walk_side/down/up (baris 0-2, 4 frame) dan sit (baris 4, kolom 2-3).
static func pet_frames(pet_id: String) -> SpriteFrames:
	if _frames.has(pet_id):
		return _frames[pet_id]
	var choice := option(pet_id)
	var sheet: Texture2D = choice.get("sheet") if choice != null else null
	if sheet == null:
		return null
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var cells := {"walk_side": [0, 0, 1, 2, 3], "walk_down": [1, 0, 1, 2, 3], "walk_up": [2, 0, 1, 2, 3], "sit": [4, 2, 3]}
	for anim in cells:
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 2.0 if anim == "sit" else 8.0)
		for column in cells[anim].slice(1):
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(int(column) * 32, int(cells[anim][0]) * 32, 32, 32)
			frame.filter_clip = true
			frames.add_frame(anim, frame)
	_frames[pet_id] = frames
	return frames

static func is_daytime() -> bool:
	return DayCycle.hour >= DAY_START and DayCycle.hour < DAY_END

## Titik rumah peliharaan di `world`, atau null bila peliharaan tidak berada di area ini sekarang.
static func home_in(world: Node) -> Variant:
	if is_daytime():
		if world.get_meta("structure_area", "") != "farm":
			return null
		for door in world.get_tree().get_nodes_in_group("scene_door"):
			var script: Script = door.get_script()
			if script != null and script.resource_path.ends_with("enter_door_house.gd") and world.is_ancestor_of(door):
				return world.to_local((door as Node2D).global_position) + FARM_OFFSET
		return null
	return INDOOR_HOME if str(world.scene_file_path).ends_with(HOUSE_SCENE) else null

## Memunculkan/menghapus peliharaan di setiap dunia yang sedang dibuka pemain.
static func sync_all(tree: SceneTree) -> void:
	var has_pet := not GameState.p1().pet_id.is_empty()
	var seen := {}
	for node in tree.get_nodes_in_group(Combat.PLAYER_GROUP):
		if not node is Player:
			continue
		var world: Node = node.world_root()
		if not world is Node2D or seen.has(world):
			continue
		seen[world] = true
		var holder := world.get_node_or_null("YSort")
		if holder == null:
			holder = world
		var actor := holder.get_node_or_null("PetActor") as PetActor
		if actor != null and actor.is_queued_for_deletion():
			actor = null
		var spot: Variant = home_in(world) if has_pet else null
		if spot == null:
			if actor != null:
				actor.queue_free()
			continue
		if actor != null:
			continue
		actor = PetActor.new()
		actor.name = "PetActor"
		actor.home = holder.to_local(world.to_global(spot))
		actor.position = actor.home
		holder.add_child(actor)
		actor.settle_home()
