class_name AnimationController
extends Node

signal animated_finished
signal frame_changed(frame: int)

@onready var sprite: AnimatedSprite2D = $"../AnimatedSprite2D"

var _action := "idle"
var _direction := "down"
var _visual_override: StringName
var _facing_left := false
var item_gesture_playing := false
var carrying_item := false

func set_carrying_item(value: bool) -> void:
	if carrying_item == value:
		return
	carrying_item = value
	_apply(true)

func _ready() -> void:
	sprite.animation_finished.connect(func():
		if item_gesture_playing:
			item_gesture_playing = false
			_visual_override = &""
			_apply(false)
		elif _visual_override.is_empty():
			animated_finished.emit())
	sprite.frame_changed.connect(func():
		if _visual_override.is_empty():
			frame_changed.emit(sprite.frame))
	set_direction(Vector2.DOWN)

func restart() -> void:
	sprite.set_frame_and_progress(0, 0.0)
	sprite.play()
		
func play(action: StringName) -> void:	
	_action = String(action).to_lower()
	_apply(false)

## Pose sementara (tidur) tetap bertahan saat state locomotion diperbarui.
func set_visual_override(action: StringName) -> void:
	item_gesture_playing = false
	_visual_override = action
	_apply(false)

## Cosmetic one-shot without emitting tool hit frames or changing the action state.
func play_item_gesture(action: StringName) -> bool:
	if not _visual_override.is_empty():
		return false
	var found := false
	for suffix in ["down", "up", "right", "left"]:
		found = found or sprite.sprite_frames.has_animation("%s_%s" % [action, suffix])
	if not found:
		return false
	item_gesture_playing = true
	_visual_override = action
	sprite.speed_scale = 1.0
	_apply(false)
	return true
	
func set_direction(direction: Vector2) -> void:	
	if direction.x != 0:
		_direction = "right"
	else:
		_direction = "up" if direction.y < 0 else "down"
	_facing_left = direction.x < 0
	_apply(true)

func _apply(keep_frame: bool) -> void:
	var action := String(_visual_override) if not _visual_override.is_empty() else _action
	if _visual_override.is_empty() and carrying_item and action in ["idle", "walk", "run"]:
		action = "carry_" + action
	var direction := "left" if _facing_left else _direction
	var anim_name := "%s_%s" % [action, direction]
	if sprite.sprite_frames.has_animation(anim_name):
		sprite.flip_h = false
	else:
		anim_name = "%s_%s" % [action, _direction]
		sprite.flip_h = direction == "left"
	if not sprite.sprite_frames.has_animation(anim_name) and sprite.sprite_frames.has_animation(action):
		anim_name = action
		sprite.flip_h = false
	
	if not sprite.sprite_frames.has_animation(anim_name):
		push_warning("Animasi '%s' tidak ada di SpriteFrames." % anim_name)
		return
	
	if sprite.animation == anim_name and keep_frame:
		if not sprite.is_playing():
			sprite.play(anim_name)
		return

	var frame := sprite.frame
	var progress := sprite.frame_progress
	sprite.play(anim_name)
	if keep_frame:
		sprite.set_frame_and_progress(frame, progress)
	else:
		sprite.set_frame_and_progress(0, 0.0)
