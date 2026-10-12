class_name DigSpot
extends Area2D
## Titik gali (seperti artifact spot di Stardew): ujung cacing bergoyang di tanah.
## Digali dengan Sekop (ShovelEffect) -> barang dig dari ForageData keluar, tanahnya jadi bekas galian.
## Dibuat oleh DigSpotSpawner; jangan ditaruh manual di scene.

const GROUP := &"dig_spot"
const LAYER_BIT := 1 << 10
const TEXTURE := preload("res://assets/farm_rpg/objects/forage/dig_spot.png")
const FRAME_TIME := 0.18
## Sama dengan Forageable.SORT_SHIFT: titik y-sort sejajar dengan pemain.
const SORT_SHIFT := Vector2(0, -4)

var spawner: DigSpotSpawner
var cell: Vector2i
var _sprite: Sprite2D
var _time: float = 0.0
var _dug: bool = false


func setup(p_spawner: DigSpotSpawner, p_cell: Vector2i) -> void:
	spawner = p_spawner
	cell = p_cell
	name = "DigSpot_%d_%d" % [cell.x, cell.y]
	collision_layer = LAYER_BIT
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group(GROUP)

	_sprite = Sprite2D.new()
	_sprite.texture = TEXTURE
	_sprite.hframes = 3
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.position = -SORT_SHIFT
	add_child(_sprite)
	# Tiap titik bergoyang dengan fase berbeda.
	_time = randf() * FRAME_TIME * 3.0

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	shape.position = -SORT_SHIFT
	add_child(shape)


func _process(delta: float) -> void:
	_time += delta
	_sprite.frame = int(_time / FRAME_TIME) % 3


## Dipanggil ForageSpawner setelah node ditaruh di tengah sel.
func apply_sort_shift() -> void:
	position += SORT_SHIFT


func play_appear() -> void:
	_sprite.scale = Vector2(0.2, 0.2)
	create_tween().tween_property(_sprite, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Titik tengah sel ini.
func ground_position() -> Vector2:
	return global_position - SORT_SHIFT


## Dipanggil ShovelEffect. true jika berhasil digali.
func dig(bonus_chance: float = 0.0) -> bool:
	if _dug:
		return false
	_dug = true
	var pos := ground_position()
	var loot: ForageData = ForageManager.pick(spawner.location_id, true) if spawner else null
	if loot and loot.item:
		var amount := randi_range(loot.amount_min, maxi(loot.amount_min, loot.amount_max))
		if randf() < bonus_chance:
			amount += 1
		for i in amount:
			ItemPickup.spawn(get_parent(), pos, loot.item.item_id, 1)
	else:
		Notify.say("Tidak ada apa-apa di sini...")
	if spawner:
		spawner.on_dug(self)
	queue_free()
	return true
