class_name Forageable
extends Area2D
## Barang liar di tanah. Hadap ke barang lalu tekan tombol interact (E) untuk memungut.
## Dibuat oleh ForageSpawner; jangan ditaruh manual di scene.

const LAYER_BIT := 1 << 10

var item: ItemData
var location_id: String = ""
var cell: Vector2i = Vector2i.ZERO
var _sprite: Sprite2D
var _taken: bool = false


func setup(p_item: ItemData, p_location_id: String, p_cell: Vector2i) -> void:
	item = p_item
	location_id = p_location_id
	cell = p_cell
	name = "Forage_%d_%d" % [cell.x, cell.y]

	collision_layer = LAYER_BIT
	collision_mask = 0
	monitoring = false
	monitorable = true

	_sprite = Sprite2D.new()
	_sprite.texture = item.icon
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.offset = Vector2(0, -4)
	add_child(_sprite)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	add_child(shape)


## Muncul dengan "pop" kecil (dipakai untuk barang yang baru tumbuh hari ini).
func play_appear() -> void:
	if _sprite == null:
		return
	_sprite.scale = Vector2(0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func interact() -> void:
	if _taken or item == null:
		return
	var leftover: int = int(GameState.add_item(item, 1))
	if leftover > 0:
		Notify.say("Tas penuh!")
		return
	_taken = true
	set_deferred("monitorable", false)
	ForageManager.take_item(location_id, cell)
	Notify.say("+1 %s" % item.display_name)
	Juice.collect(item.item_id, item.icon, global_position)
	queue_free()
