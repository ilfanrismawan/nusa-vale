class_name AnimationController
extends Node

signal animated_finished
signal frame_changed(frame: int)

@onready var sprite: AnimatedSprite2D = $"../AnimatedSprite2D"

var _action := "idle"
var _direction := "down"

func _ready() -> void:
	sprite.animation_finished.connect(animated_finished.emit)	
	sprite.frame_changed.connect(func(): frame_changed.emit(sprite.frame))
	set_direction(Vector2.DOWN)

func restart() -> void:
	sprite.set_frame_and_progress(0, 0.0)
	sprite.play()
		
func play(action: StringName) -> void:	
	_action = String(action).to_lower()
	_apply(false)
	
func set_direction(direction: Vector2) -> void:	
	if direction.x != 0:
		_direction = "right"
	else:
		_direction = "up" if direction.y < 0 else "down"
	sprite.flip_h = direction.x < 0
	_apply(true)

func _apply(keep_frame: bool) -> void:
	var anim_name := "%s_%s" % [_action, _direction]
	
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
