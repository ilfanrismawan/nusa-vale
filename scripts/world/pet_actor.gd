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
const StatusMarker := preload("res://scripts/ui/animal_status_marker.gd")
const GROUP := &"pet_actor"
## Angka rawat (kasih sayang, makanan, jam main, siulan) di resources/animals/pet_care.tres.
## Makan sekali sehari: pegang ikan atau masakan lalu interaksi dengan peliharaan (GDD 4.10.12).
const CARE: PetCareData = preload("res://resources/animals/pet_care.tres")
const HOUSE_SCENE := "interior_house.tscn"
## Titik main di dalam rumah: dekat titik masuk pemain (enter_door_house.gd target_spawn_pos 310, 193).
const INDOOR_HOME := Vector2(284, 204)
## Titik main di ladang relatif terhadap node pintu rumah (pusat bangunan; ambang pintu di y+30).
const FARM_OFFSET := Vector2(34, 56)
const FEET_RADIUS := 4.0
## Peliharaan sedekat ini dari kaki pemain bisa diajak interaksi tanpa tepat menghadapnya.
const NEAR_RADIUS := 16.0
static var _frames: Dictionary = {}
var home := Vector2.ZERO
var _sprite: AnimatedSprite2D
var _badge: Label
## Gelembung makan dan elus di atas kepala.
var _status: Node2D
var _target := Vector2.ZERO
var _wait := 0.0
var _facing := "down"
var _day := -1
## Sisa waktu main di dekat titik siulan; 0 = kembali main di sekitar rumah.
var _call_left := 0.0
var _call_spot := Vector2.ZERO
var _running := false

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
	_badge.add_theme_font_size_override("font_size", 16)
	_badge.add_theme_color_override("font_color", Color("fff1c9"))
	_badge.add_theme_color_override("font_outline_color", Color("302333"))
	_badge.add_theme_constant_override("outline_size", 2)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Nama di bawah kaki, hanya saat pemain dekat.
	_badge.position = Vector2(-20, 2)
	_badge.visible = false
	add_child(_badge)
	_status = StatusMarker.new()
	# Puncak gambar peliharaan (sel 32 px, kepala di baris ~16) ada di sekitar y -12.
	_status.position = Vector2(0, -20)
	_status.provider = func() -> Array:
		var data := owner_data()
		if data.pet_id.is_empty():
			return []
		return [{"kind": "feed", "done": data.pet_fed_day == DayCycle.current_day}, {"kind": "pet", "done": data.pet_day == DayCycle.current_day}]
	_status.near_changed.connect(func(near: bool) -> void: _badge.visible = near)
	add_child(_status)
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
	_badge.text = data.pet_name
	_status.update_now()

func _physics_process(delta: float) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if _day != DayCycle.current_day:
		_day = DayCycle.current_day
		refresh()
	_call_left = maxf(0.0, _call_left - delta)
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
	velocity = step.normalized() * minf(CARE.call_speed if _running else CARE.speed, step.length() / delta)
	move_and_slide()
	# Menabrak bangunan/pagar/objek: berhenti, nanti pilih tujuan lain.
	if get_slide_collision_count() > 0:
		_rest()
		return
	_play(true)

func _rest() -> void:
	velocity = Vector2.ZERO
	_target = position
	# Terhalang saat berlari menjawab siulan: cepat coba jalan lain.
	_wait = randf_range(0.3, 0.8) if _running and _call_left > 0.0 else randf_range(2.5, 6.0)
	_running = false
	_play(false)

## Titik main acak di sekitar rumah (atau titik siulan) yang kosong dan bisa dicapai lurus
## tanpa menembus objek. Jauh dari pusat dan tidak ada yang lurus: jalan ke pusat sambil menyusur.
func _pick_target() -> Vector2:
	var center := _call_spot if _call_left > 0.0 else home
	var parent := get_parent() as Node2D
	for attempt in 8:
		var candidate := center + Vector2.from_angle(randf() * TAU) * randf_range(6.0, CARE.wander_radius)
		if parent == null:
			return candidate
		var global_candidate := parent.to_global(candidate)
		if AnimalPhysics.is_free(self, global_candidate, FEET_RADIUS, [get_rid()]) \
				and not AnimalPhysics.is_blocked(self, global_position, global_candidate, [get_rid()]):
			return candidate
	return center if position.distance_to(center) > CARE.wander_radius * 2.0 else position

## Jawab siulan `player`: berlari ke titik kosong di sisinya, lalu main di sana CARE.call_seconds.
func come_to(player: Player) -> void:
	var parent := get_parent() as Node2D
	if parent == null:
		return
	var feet := player.global_position + Player.FEET_OFFSET
	var side := (global_position - feet).normalized() if global_position.distance_to(feet) > 1.0 else Vector2.DOWN
	_call_spot = parent.to_local(AnimalPhysics.nearest_free(self, feet + side * CARE.call_gap, FEET_RADIUS, 24.0, [get_rid()]))
	_call_left = CARE.call_seconds
	_running = true
	_target = _call_spot
	_wait = 0.0
	_pop("!", Color("ffd36e"))

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
	var data := owner_data()
	var result: Dictionary
	var fed_now := false
	if data.pet_fed_day != DayCycle.current_day and is_pet_food(player.tool_controller.current_item):
		result = feed(player)
		fed_now = result.ok
	elif data.pet_day != DayCycle.current_day:
		result = pet()
	elif data.pet_fed_day != DayCycle.current_day:
		result = {"ok": false, "message": "%s lapar. Pegang ikan atau masakan, lalu interaksi untuk memberi makan." % data.pet_name}
	else:
		result = {"ok": false, "message": "%s sudah makan dan dielus hari ini." % data.pet_name}
	Notify.say(result.message)
	if fed_now:
		Juice.play(&"sparkle", global_position)
	elif result.ok:
		_wait = maxf(_wait, 2.0)
		_play(false)
		_pop("♥", Color("ff6b7a"))
	var squash := create_tween()
	squash.tween_property(_sprite, "scale", Vector2(1.12, 0.88), 0.08)
	squash.tween_property(_sprite, "scale", Vector2.ONE, 0.14)

## Tanda kecil (♥, !) yang naik dari kepala lalu memudar.
func _pop(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = Vector2(-4, -34)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("302333"))
	label.add_theme_constant_override("outline_size", 2)
	add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", -48.0, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)

## Peliharaan yang sedang tampil di area `player`, atau null.
static func actor_for(player: Player) -> PetActor:
	for actor in player.get_tree().get_nodes_in_group(GROUP):
		if actor is PetActor and not actor.is_queued_for_deletion() and actor.get_world_2d() == player.get_world_2d():
			return actor
	return null

## Peliharaan yang berdiri di kaki `player` (NEAR_RADIUS), atau null.
static func near(player: Player) -> PetActor:
	var actor := actor_for(player)
	if actor == null or actor.global_position.distance_to(player.global_position + Player.FEET_OFFSET) > NEAR_RADIUS:
		return null
	return actor

## Siul memanggil peliharaan pemain 1 ke sisi `player`: {"ok", "message"}. Tidak terdengar bila
## peliharaan tidak berada di area ini (siang di depan rumah ladang, malam di dalam rumah).
static func whistle(player: Player) -> Dictionary:
	var now := Time.get_ticks_msec()
	if now - int(player.get_meta(&"pet_whistle_ms", -CARE.whistle_cooldown_ms)) < CARE.whistle_cooldown_ms:
		return {"ok": false, "message": ""}
	player.set_meta(&"pet_whistle_ms", now)
	var data := GameState.p1()
	var actor := actor_for(player)
	var result: Dictionary
	if data.pet_id.is_empty():
		result = {"ok": false, "message": "Tidak ada yang menjawab siulanmu."}
	elif actor == null:
		result = {"ok": false, "message": "%s tidak mendengar. Siang ia main di depan rumah ladang, malam di dalam rumah." % data.pet_name}
	else:
		actor.come_to(player)
		result = {"ok": true, "message": "%s berlari menghampirimu!" % data.pet_name}
	var feet := player.global_position + Player.FEET_OFFSET
	# Nada seruling dinaikkan jadi siulan; tak terjawab = lebih rendah dan not abu-abu.
	Juice.play(&"horse_flute", feet, 7.0 if result.ok else 2.0)
	var fx := HorseFlute.new()
	fx._failed = not result.ok
	player.add_child(fx)
	fx.position = Player.SPRITE_OFFSET + Vector2(0, -22)
	Notify.say(result.message)
	return result

## Ikan atau masakan jadi bisa dimakan peliharaan.
static func is_pet_food(item: ItemData) -> bool:
	return item != null and item.category in CARE.food_categories

## Beri makan peliharaan pemain 1 dari item yang dipegang `player` (tas pemain pelaku): {"ok", "message"}.
static func feed(player: Player) -> Dictionary:
	var data := GameState.p1()
	var item: ItemData = player.tool_controller.current_item if player != null else null
	if data.pet_id.is_empty():
		return {"ok": false, "message": "Belum ada peliharaan."}
	if data.pet_fed_day == DayCycle.current_day:
		return {"ok": false, "message": "%s sudah makan hari ini." % data.pet_name}
	if not is_pet_food(item) or not player.data.remove_item(item.item_id, 1):
		return {"ok": false, "message": "%s mau ikan atau masakan." % data.pet_name}
	data.pet_fed_day = DayCycle.current_day
	data.pet_affection = mini(CARE.max_affection, data.pet_affection + CARE.feed_gain)
	Juice.play_sound(&"plant")
	for actor in (Engine.get_main_loop() as SceneTree).get_nodes_in_group(GROUP):
		actor.refresh()
	return {"ok": true, "message": "%s makan %s dengan lahap! (Kasih sayang %d/%d)" % [data.pet_name, item.display_name, data.pet_affection, CARE.max_affection]}

## Elus peliharaan pemain 1: {"ok", "message"}.
static func pet() -> Dictionary:
	var data := GameState.p1()
	if data.pet_id.is_empty():
		return {"ok": false, "message": "Belum ada peliharaan."}
	if data.pet_day == DayCycle.current_day:
		return {"ok": false, "message": "%s sudah dielus hari ini." % data.pet_name}
	data.pet_day = DayCycle.current_day
	data.pet_affection = mini(CARE.max_affection, data.pet_affection + CARE.pet_gain)
	Juice.play_sound(&"pickup")
	for actor in (Engine.get_main_loop() as SceneTree).get_nodes_in_group(GROUP):
		actor.refresh()
	return {"ok": true, "message": "%s senang dielus! (Kasih sayang %d/%d)" % [data.pet_name, data.pet_affection, CARE.max_affection]}

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
	return DayCycle.hour >= CARE.day_start and DayCycle.hour < CARE.day_end

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
