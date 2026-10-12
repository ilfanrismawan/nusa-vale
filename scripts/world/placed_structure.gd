extends StaticBody2D

var uid := 0
var _sprite: Sprite2D
var _collision: CollisionShape2D
var _chest_open := false
var _quiet_until_ms := 0
var _lid_tween: Tween
const CHEST_DISTANCE := 34.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite = Sprite2D.new()
	add_child(_sprite)
	_collision = CollisionShape2D.new()
	add_child(_collision)
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
	_sprite.frame = 0
	_sprite.texture = item.icon
	_sprite.region_enabled = false
	if record.item in StructureManager.CHESTS and item.icon is AtlasTexture:
		_sprite.region_enabled = true
		_sprite.texture = (item.icon as AtlasTexture).atlas
		_sprite.region_rect = Rect2(40 if _chest_open else 8, 1, 15, 15)
	_sprite.modulate = Color(1, 1, 1, 0.45) if record.item == "wooden_gate" and record.open else Color.WHITE
	var shape := RectangleShape2D.new()
	shape.size = Vector2(item.placement_size * 16) - Vector2(2, 2)
	_collision.shape = shape
	_collision.set_deferred("disabled", record.item == "wooden_gate" and record.open)
	if record.item == "furnace":
		_sprite.texture = (item.icon as AtlasTexture).atlas
		_sprite.hframes = 5

func _process(_delta: float) -> void:
	var record := StructureManager.record_for(uid)
	if record.get("item") == "furnace":
		_sprite.frame = 0 if record.job.is_empty() else int(Time.get_ticks_msec() / 125) % 5
	if record.get("item") in StructureManager.CHESTS:
		_update_chest_lid()

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
				if feet.distance_to(center) <= CHEST_DISTANCE:
					nearby = true
					break
	if nearby == _chest_open:
		return
	_chest_open = nearby
	if _sprite != null and item.icon is AtlasTexture:
		_sprite.region_rect = Rect2(40 if _chest_open else 8, 1, 15, 15)
	if Time.get_ticks_msec() >= _quiet_until_ms:
		Juice.play_sound(&"bin_open" if _chest_open else &"bin_close")
	if _lid_tween != null and _lid_tween.is_valid():
		_lid_tween.kill()
	_sprite.scale = Vector2(0.9, 1.12) if _chest_open else Vector2(1.12, 0.88)
	_lid_tween = create_tween()
	_lid_tween.tween_property(_sprite, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
