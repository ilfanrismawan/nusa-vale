class_name WildAnimal
extends CharacterBody2D
## Satwa liar (GDD 4.10.13): diam/berkeliaran di sekitar titik muncul, kabur dari pemain.
## Pemain berjalan mengejutkan dari flee_radius, pemain berlari dari 2x jarak itu.
## Satwa yang kabur jauh atau tidak lagi cocok jam/musimnya menghilang perlahan (despawn).
## Pemain yang memegang makanan kesukaan (favorite_foods) tidak membuatnya kabur saat berjalan dan
## memancingnya mendekat; interaksi memberi makan (1 item) sehingga satwa itu jinak. Burung (flies)
## kabur dengan terbang menjauh lalu menghilang.

const GROUP := &"wild_animal"
const WANDER_RADIUS := 48.0
const FLEE_SECONDS := 2.5
## Jarak dari titik muncul yang membuat satwa kabur menghilang (diganti spawner di tempat lain).
const LOST_DISTANCE := 200.0
## Catatan Satwa: pemain tidak berlari, di luar jarak kabur tapi dalam OBSERVE_RANGE x jarak itu,
## selama OBSERVE_SECONDS. Pemain berlari mengejutkan dari 2x jarak, jadi harus mengendap.
const OBSERVE_RANGE := 1.8
const OBSERVE_SECONDS := 2.0
## Jarak berhenti satwa yang terpancing makanan dari pemain.
const LURE_STOP := 14.0
## Hadiah (gift_item) ditinggalkan beberapa detik setelah diberi makan.
const GIFT_DELAY := 3.0
const ItemPickupScript := preload("res://scripts/world/item_pickup.gd")
const GroundShadow := preload("res://scripts/effects/ground_shadow.gd")

enum Mode { IDLE, WANDER, FLEE, HIDE }

var data: Resource
var home := Vector2.ZERO
var mode := Mode.IDLE
var _sprite: AnimatedSprite2D
var _timer := 0.0
var _target := Vector2.ZERO
var _facing := "down"
var _leaving := false
var _threat_position := Vector2.ZERO
var observed := false
## Sudah diberi makan: tidak kabur dari pemain yang berjalan.
var tame := false
var _watch := 0.0


func setup(p_data: Resource) -> void:
	data = p_data


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = 0
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 3.0
	shape.shape = circle
	add_child(shape)
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.sprite_frames = data.frames()
	# Kaki di sekitar 3 px dari dasar sel.
	_sprite.position.y = -data.frame_size / 2.0 + 3.0
	add_child(_sprite)
	GroundShadow.attach(self, clampf(data.frame_size * 0.22, 3.0, 8.0))
	# Area interaksi (memberi makan): lapisan interaksi pemain seperti hewan ternak/kuda.
	set_meta("player_interaction", true)
	var area := Area2D.new()
	area.collision_layer = 1 << 9
	area.collision_mask = 0
	area.monitoring = false
	var hit := CollisionShape2D.new()
	var hit_circle := CircleShape2D.new()
	hit_circle.radius = maxf(6.0, data.frame_size * 0.3)
	hit.shape = hit_circle
	hit.position = _sprite.position
	area.add_child(hit)
	add_child(area)
	_set_mode(Mode.IDLE)


func place(at: Vector2) -> void:
	global_position = at
	home = at
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)


func despawn() -> void:
	if _leaving:
		return
	_leaving = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_callback(queue_free)


func is_leaving() -> bool:
	return _leaving


func _physics_process(delta: float) -> void:
	if data == null or _leaving:
		return
	var threat := _nearest_threat()
	if threat != null and mode != Mode.FLEE and mode != Mode.HIDE:
		_spook(threat)
	elif mode == Mode.IDLE or mode == Mode.WANDER:
		if not observed:
			_update_watch(delta)
		var lure := _lure_player()
		if lure != null:
			var offset := global_position - lure.global_position
			_target = lure.global_position + (offset.normalized() if offset.length() > 0.1 else Vector2.RIGHT) * LURE_STOP
			if mode == Mode.IDLE and global_position.distance_to(_target) > 3.0:
				_set_mode(Mode.WANDER)
			_timer = maxf(_timer, 1.0)
	_timer -= delta
	match mode:
		Mode.IDLE:
			velocity = Vector2.ZERO
			if _timer <= 0.0:
				_target = home + Vector2.from_angle(randf() * TAU) * randf_range(8.0, WANDER_RADIUS)
				_set_mode(Mode.WANDER)
		Mode.WANDER:
			var step := _target - global_position
			if step.length() < 2.0 or _timer <= 0.0:
				_set_mode(Mode.IDLE)
			else:
				_move(step.normalized() * data.walk_speed, "walk")
		Mode.FLEE:
			if _timer <= 0.0:
				if data.flies or global_position.distance_to(home) > LOST_DISTANCE:
					despawn()
				else:
					_set_mode(Mode.IDLE)
			elif data.flies:
				# Terbang: menjauh dan naik, menembus pagar/pohon. Bayangan tidak ikut ke udara.
				$GroundShadow.hide()
				var flight: Vector2 = (_away_direction() + Vector2(0, -0.8)).normalized() * data.run_speed
				if absf(flight.x) > 0.01:
					_sprite.flip_h = (flight.x > 0) != data.faces_right
				_play("run")
				global_position += flight * delta
			else:
				var away := _away_direction()
				_move(away * data.run_speed, "run")
		Mode.HIDE:
			velocity = Vector2.ZERO
			if threat != null:
				_timer = 2.0
			elif _timer <= 0.0:
				_set_mode(Mode.IDLE)


func _move(motion: Vector2, action: String) -> void:
	velocity = motion
	if motion.length() > 0.01:
		_facing = "side" if absf(motion.x) > absf(motion.y) else ("up" if motion.y < 0 else "down")
		if absf(motion.x) > 0.01:
			_sprite.flip_h = (motion.x > 0) != data.faces_right
	_play(action)
	move_and_slide()
	# Terhalang dinding/air: ganti arah atau berhenti.
	if get_slide_collision_count() > 0 and mode == Mode.WANDER:
		_set_mode(Mode.IDLE)


func _play(action: String) -> void:
	var anim := StringName("%s_%s" % [action, _facing])
	if _sprite.animation != anim:
		_sprite.play(anim)


func _set_mode(next: Mode) -> void:
	mode = next
	match next:
		Mode.IDLE:
			_timer = randf_range(2.0, 6.0)
			velocity = Vector2.ZERO
			_play("idle")
		Mode.WANDER:
			_timer = 5.0
		Mode.FLEE:
			_timer = FLEE_SECONDS
		Mode.HIDE:
			_timer = 2.0
			velocity = Vector2.ZERO
			_play("run")


func _spook(threat: Node2D) -> void:
	_threat_position = threat.global_position
	_set_mode(Mode.HIDE if data.run_speed <= 0.0 else Mode.FLEE)
	if mode == Mode.FLEE:
		var away := _away_direction()
		_facing = "side" if absf(away.x) > absf(away.y) else ("up" if away.y < 0 else "down")


func _away_direction() -> Vector2:
	var away := global_position - _threat_position
	return away.normalized() if away.length() > 0.1 else Vector2.RIGHT


func _update_watch(delta: float) -> void:
	var watcher: Player = null
	for node in get_tree().get_nodes_in_group(&"player"):
		if not node is Player or (node as Node2D).get_world_2d() != get_world_2d():
			continue
		var player := node as Player
		var distance := player.global_position.distance_to(global_position)
		if distance < data.flee_radius * OBSERVE_RANGE and player.velocity.length() <= player.speed * 1.2:
			watcher = player
			break
	if watcher == null:
		_watch = maxf(0.0, _watch - delta)
		return
	_watch += delta
	if _watch < OBSERVE_SECONDS:
		return
	observed = true
	WildlifeJournal.observe(data, watcher.data)
	var mark := Label.new()
	mark.text = "!"
	mark.position = Vector2(-3, -data.frame_size - 6)
	mark.add_theme_color_override("font_color", Color("fff1c9"))
	mark.add_theme_color_override("font_outline_color", Color("302333"))
	mark.add_theme_constant_override("outline_size", 2)
	add_child(mark)
	var tween := mark.create_tween()
	tween.tween_property(mark, "position:y", mark.position.y - 10, 0.9)
	tween.parallel().tween_property(mark, "modulate:a", 0.0, 0.9)
	tween.tween_callback(mark.queue_free)


## Pemain terdekat di dunia yang sama yang cukup dekat untuk mengejutkan satwa ini.
func _nearest_threat() -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(&"player"):
		if not node is Player or (node as Node2D).get_world_2d() != get_world_2d():
			continue
		var player := node as Player
		var running := player.velocity.length() > player.speed * 1.2
		# Jinak atau dipancing makanan kesukaan: hanya pemain berlari yang mengejutkan.
		if not running and (tame or holds_favorite(player)):
			continue
		var radius: float = data.flee_radius * (2.0 if running else 1.0)
		var distance := player.global_position.distance_to(global_position)
		if distance < radius and distance < best_distance:
			best = player
			best_distance = distance
	if best != null:
		_threat_position = best.global_position
	return best


func holds_favorite(player: Player) -> bool:
	if data.favorite_foods.is_empty() or player.tool_controller == null:
		return false
	var item: ItemData = player.tool_controller.current_item
	return item != null and data.favorite_foods.has(_base_id(item.item_id))


## Kualitas tidak penting untuk satwa: wortel emas tetap wortel.
static func _base_id(item_id: String) -> String:
	return item_id.trim_suffix("_gold").trim_suffix("_silver")


## Pemain terdekat yang memegang makanan kesukaan dalam jangkauan pancing (tidak berlari).
func _lure_player() -> Player:
	if tame or data.favorite_foods.is_empty():
		return null
	for node in get_tree().get_nodes_in_group(&"player"):
		if not node is Player or (node as Node2D).get_world_2d() != get_world_2d():
			continue
		var player := node as Player
		if holds_favorite(player) and player.velocity.length() <= player.speed * 1.2 and player.global_position.distance_to(global_position) < data.flee_radius * OBSERVE_RANGE * 1.5:
			return player
	return null


func interact(player: Node = null) -> void:
	if not player is Player or _leaving or mode == Mode.FLEE:
		return
	if data.favorite_foods.is_empty():
		Notify.say("%s tidak mau diberi makan." % data.display_name)
		return
	if tame:
		Notify.say("%s sudah kenyang dan jinak padamu." % data.display_name)
		return
	if not holds_favorite(player):
		var names: PackedStringArray = []
		for id in data.favorite_foods:
			var item := GameState._resolve_item(id)
			names.append(item.display_name if item != null else id)
		Notify.say("%s memandangimu penasaran. Ia suka: %s." % [data.display_name, ", ".join(names)])
		return
	var held: ItemData = player.tool_controller.current_item
	if not player.data.remove_item(held.item_id, 1):
		return
	tame = true
	_set_mode(Mode.IDLE)
	if not observed:
		observed = true
		WildlifeJournal.observe(data, player.data)
	WildlifeJournal.feed(data, held, player.data)
	if not data.gift_item.is_empty() and randf() < data.gift_chance:
		get_tree().create_timer(GIFT_DELAY, false).timeout.connect(leave_gift)
	var heart := Label.new()
	heart.text = "♥"
	heart.position = Vector2(-4, -data.frame_size - 6)
	heart.add_theme_color_override("font_color", Color("ff6b7a"))
	heart.add_theme_color_override("font_outline_color", Color("302333"))
	heart.add_theme_constant_override("outline_size", 2)
	add_child(heart)
	var tween := heart.create_tween()
	tween.tween_property(heart, "position:y", heart.position.y - 12, 0.8)
	tween.parallel().tween_property(heart, "modulate:a", 0.0, 0.8)
	tween.tween_callback(heart.queue_free)


## Menjatuhkan hadiah satwa jinak di tanah tempatnya berdiri.
func leave_gift() -> void:
	if not is_instance_valid(self) or _leaving or data.gift_item.is_empty() or get_parent() == null:
		return
	ItemPickupScript.spawn(get_parent(), global_position + Vector2(0, -2), data.gift_item, 1)
	var item := GameState._resolve_item(data.gift_item)
	Notify.say("%s meninggalkan %s untukmu." % [data.display_name, item.display_name if item != null else data.gift_item])
