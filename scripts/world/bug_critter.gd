extends Node2D
## Serangga liar (dibuat BugSpawner, jangan ditaruh manual). Terbang atau merayap di sekitar
## titik asalnya, kabur dari pemain yang terlalu dekat, dan masuk tas saat kena ayunan jaring.

signal caught

## Tinggi terbang di atas tanah (px). Bayangan kecil tetap di tanah.
const FLY_HEIGHT := 12.0
const FLY_RANGE := 36.0
const CRAWL_RANGE := 14.0
const FLEE_DISTANCE := 44.0

var data: Resource  # BugData
var anchor := Vector2.ZERO
var _sprite: Sprite2D
var _target := Vector2.ZERO
var _wait := 0.0
var _flee := 0.0
var _t := 0.0
var _gone := false


func setup(p_data: Resource) -> void:
	data = p_data
	name = "Bug_%s" % data.item.item_id


## Dipanggil spawner setelah node masuk scene.
func place(at: Vector2) -> void:
	global_position = at
	anchor = at
	_pick_target()


func _ready() -> void:
	add_to_group(&"bug")
	_t = randf() * 10.0
	_sprite = Sprite2D.new()
	_sprite.texture = data.item.icon
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.position = Vector2(0, -FLY_HEIGHT if data.flying else -3.0)
	add_child(_sprite)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)
	queue_redraw()


func _draw() -> void:
	if data != null and data.flying:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 3.0, Color(0, 0, 0, 0.22))


## Titik yang harus kena jaring: sprite-nya (serangga terbang melayang di atas tanah).
func catch_point() -> Vector2:
	return global_position + (_sprite.position if _sprite != null else Vector2.ZERO)


func _physics_process(delta: float) -> void:
	if _gone or data == null:
		return
	_t += delta
	var speed: float = data.speed
	var player := _nearest_player()
	if player != null and data.flee_radius > 0.0 and player.global_position.distance_to(catch_point()) < data.flee_radius:
		var away := (catch_point() - player.global_position).normalized()
		if away == Vector2.ZERO:
			away = Vector2.RIGHT.rotated(randf() * TAU)
		_target = global_position + away * FLEE_DISTANCE
		_flee = 0.7
	if _flee > 0.0:
		_flee -= delta
		speed *= 2.4
		if _flee <= 0.0:
			anchor = global_position
	var to := _target - global_position
	if to.length() < 1.5:
		_wait -= delta
		if _wait <= 0.0:
			_pick_target()
	else:
		global_position += to.normalized() * minf(speed * delta, to.length())
		if absf(to.x) > 0.5:
			_sprite.flip_h = to.x < 0.0
	if data.flying:
		_sprite.position.y = -FLY_HEIGHT + sin(_t * 3.0) * 2.0
		# Kepakan sayap: lebar sprite naik-turun cepat.
		_sprite.scale.x = 0.7 + 0.3 * absf(sin(_t * 14.0))
	else:
		_sprite.rotation = sin(_t * 9.0) * 0.08
	if data.glows:
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		_sprite.self_modulate = Color(1.0 + pulse, 1.0 + pulse, 0.6 + pulse * 0.4)


func _pick_target() -> void:
	var r := FLY_RANGE if data.flying else CRAWL_RANGE
	_target = anchor + Vector2(randf_range(-r, r), randf_range(-r, r) * 0.6)
	_wait = randf_range(0.2, 1.0) if data.flying else randf_range(0.8, 2.5)


func _nearest_player() -> Player:
	var best: Player = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group(&"player"):
		if node is Player and (node as Player).get_world_2d() == get_world_2d():
			var dist := (node as Player).global_position.distance_squared_to(global_position)
			if dist < best_dist:
				best_dist = dist
				best = node
	return best


## Masuk tas pemain yang mengayun jaring. false bila tas penuh.
func catch(player: Player) -> bool:
	if _gone:
		return false
	player.bind_context()
	if player.data.add_item(data.item, 1) > 0:
		Notify.say("Tas penuh!")
		return false
	_gone = true
	remove_from_group(&"bug")
	var first := DiscoveryManager.discover("bug_" + data.item.item_id)
	Notify.say("Dapat %s!" % data.item.display_name)
	Juice.collect(data.item.item_id, data.item.icon, catch_point())
	if first:
		Juice.float_text("BARU!", player.global_position + Vector2(0, -20), Color(1.0, 0.85, 0.3), 1.0)
	caught.emit()
	queue_free()
	return true


## Pergi pelan-pelan (jam atau musimnya sudah lewat).
func despawn() -> void:
	if _gone:
		return
	_gone = true
	remove_from_group(&"bug")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_callback(queue_free)
