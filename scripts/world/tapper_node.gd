extends Area2D
## Tapper yang menempel di batang pohon (dibuat GameState.gathering, jangan ditaruh manual).
## Hadap ke pohon lalu tekan E/A untuk mengambil hasilnya; ikon hasil melayang di atasnya saat siap.

const ICON := preload("res://resources/icons/icon_tapper.tres")
const LAYER_BIT := 1 << 10

var key: String = ""
var _bubble: Sprite2D
var _bob := 0.0


func _ready() -> void:
	collision_layer = LAYER_BIT
	collision_mask = 0
	monitoring = false
	monitorable = true
	# player.gd memanggil interact(self) untuk node yang punya meta ini (co-op: tas pemain yang menekan).
	set_meta(&"player_interaction", true)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	shape.shape = circle
	shape.position = Vector2(0, -2)
	add_child(shape)
	var sprite := Sprite2D.new()
	sprite.texture = ICON
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2(0, -7)
	sprite.z_index = 1
	add_child(sprite)
	_bubble = Sprite2D.new()
	_bubble.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bubble.position = Vector2(0, -26)
	_bubble.z_index = 2
	add_child(_bubble)
	GameState.gathering.tapper_changed.connect(_on_changed)
	DayCycle.day_passed.connect(_on_day)
	_refresh()


func _process(delta: float) -> void:
	_bob += delta * 3.0
	_bubble.position.y = -26 + sin(_bob) * 1.5


func interact(player: Player) -> void:
	player.bind_context()
	var product := GameState._resolve_item(GameState.gathering.product_id(key))
	if GameState.gathering.collect(key, player.data) and product != null:
		Juice.collect(product.item_id, product.icon, global_position + Vector2(0, -12))


func _on_changed(changed: String) -> void:
	if changed != key:
		return
	if not GameState.gathering.has_tapper(key):
		queue_free()
		return
	_refresh()


func _on_day(_day: int) -> void:
	_refresh()


func _refresh() -> void:
	var done: bool = GameState.gathering.is_ready(key)
	var product: ItemData = GameState._resolve_item(GameState.gathering.product_id(key)) if done else null
	_bubble.texture = OutlineIcon.get_for(product.icon) if product != null and product.icon != null else null
	_bubble.visible = _bubble.texture != null
	set_process(_bubble.visible)
