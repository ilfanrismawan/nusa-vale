class_name Choppable
extends StaticBody2D

const ItemPickupScript = preload("res://scripts/world/item_pickup.gd")

@export var health: int = 3
@export var drop_item_id: String = "wood"
@export var drop_count: int = 3
@export var object_group: StringName = &"choppable"
## Jika false, node tidak disimpan ke save saat dihancurkan (selalu respawn tiap hari baru).
@export var persistent: bool = true

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_chopping: bool = false
var is_destroyed: bool = false


func _ready() -> void:
	if persistent and _removed_ids().has(str(get_path())):
		queue_free()
		return
	add_to_group(object_group)
	_play(&"idle")


func take_hit(damage: int) -> void:
	if is_destroyed or is_chopping:
		return
	health -= damage
	is_chopping = true
	_play(&"chopping")
	var anim_time := _chop_duration()
	get_tree().create_timer(anim_time).timeout.connect(_on_chop_timeout)


func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation != &"chopping":
		return
	_finish_chop()


func _on_chop_timeout() -> void:
	if is_chopping:
		_finish_chop()


func _finish_chop() -> void:
	if is_destroyed or not is_chopping:
		return
	is_chopping = false
	if health <= 0:
		_destroy_tree()
	else:
		_play(&"idle")


func _destroy_tree() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	_spawn_wood_drop()
	if persistent:
		var path_id := str(get_path())
		var removed := _removed_ids()
		if not removed.has(path_id):
			removed.append(path_id)
	collision_layer = 0
	collision_mask = 0
	_play(&"stump")
	await get_tree().create_timer(0.35).timeout
	queue_free()


func _spawn_wood_drop() -> void:
	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene
	var origin := global_position + Vector2(0, -8)
	for i in drop_count:
		var offset := Vector2(randf_range(-12.0, 12.0), randf_range(-6.0, 6.0))
		ItemPickupScript.spawn(parent, origin + offset, drop_item_id, 1)


func _play(anim: StringName) -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	if not animated_sprite.sprite_frames.has_animation(anim):
		push_warning("Tree: animasi '%s' tidak ada" % anim)
		return
	animated_sprite.stop()
	animated_sprite.animation = anim
	animated_sprite.set_frame_and_progress(0, 0.0)
	animated_sprite.play(anim)


func _removed_ids() -> Array[String]:
	if object_group == &"mineable":
		return GameState.mined_rocks
	return GameState.chopped_trees


func _chop_duration() -> float:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return 0.6
	var frames := animated_sprite.sprite_frames.get_frame_count(&"chopping")
	var fps := animated_sprite.sprite_frames.get_animation_speed(&"chopping")
	if fps <= 0.0:
		return 0.6
	return (float(frames) / fps) + 0.05
