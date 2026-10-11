class_name Weed
extends StaticBody2D
## Rumput liar. Ditebas dengan sabit (HarvestEffect) -> kadang menjatuhkan Fiber.
## Dibuat oleh WeedSpawner; posisinya disimpan lewat ForageManager.

const GROUP := &"weed"

var data: WeedData
var area_key: String = ""
var cell: Vector2i
var _sprite: Sprite2D
var _cut: bool = false


func setup(p_data: WeedData, p_area_key: String, p_cell: Vector2i) -> void:
	data = p_data
	area_key = p_area_key
	cell = p_cell
	name = "Weed_%d_%d" % [cell.x, cell.y]


func _ready() -> void:
	add_to_group(GROUP)
	_sprite = Sprite2D.new()
	_sprite.texture = data.texture if data else null
	_sprite.region_enabled = true
	_sprite.offset = Vector2(0, -4)
	add_child(_sprite)
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"  # dipakai FarmManager._hit_origin
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	shape.shape = circle
	add_child(shape)
	DayCycle.season_changed.connect(_on_season_changed)
	_apply_season()


func _on_season_changed(_season: int) -> void:
	_apply_season()


func _apply_season() -> void:
	if data == null or _sprite == null:
		return
	var regions := data.regions_for(DayCycle.get_current_season())
	if regions.is_empty():
		return
	# Pilihan gambar tetap sama untuk sel yang sama.
	var idx := absi(hash(cell)) % regions.size()
	_sprite.region_rect = regions[idx]
	_sprite.flip_h = (cell.x + cell.y) % 2 == 0


func play_appear() -> void:
	if _sprite == null:
		return
	_sprite.scale = Vector2(0.2, 0.2)
	create_tween().tween_property(_sprite, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Dipanggil sabit. Satu tebasan langsung putus.
func take_hit(_damage: int = 1) -> void:
	if _cut:
		return
	_cut = true
	collision_layer = 0
	collision_mask = 0
	var pos := global_position
	Juice.play(&"cut_break", pos)
	if data and data.drop_item and randf() < data.drop_chance:
		ItemPickup.spawn(get_parent(), pos, data.drop_item.item_id, data.drop_count)
	ForageManager.remove_item(area_key, cell)
	if DiscoveryManager.discover("weed_cut_tip"):
		Notify.say("Rumput liar ditebas! Kadang menjatuhkan Fiber.")
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", Vector2(1.3, 0.2), 0.12)
	tw.tween_callback(queue_free)


## Hilang tanpa efek (mis. tanahnya dicangkul).
func remove_quietly() -> void:
	if _cut:
		return
	_cut = true
	ForageManager.remove_item(area_key, cell)
	queue_free()
