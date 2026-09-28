extends CharacterBody2D
@export var speed: float = 90.0

var last_direction: String = "down"

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(_delta: float) -> void:
	var input_vector := _get_input_vector()
	velocity = input_vector * speed
	move_and_slide()
	
	_update_animation(input_vector)

func _get_input_vector() -> Vector2:
	var input_vector:= Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return input_vector

func _update_animation(input_vector: Vector2) -> void:
	var is_moving := input_vector.length() > 0.1
	
	if is_moving:
		if abs(input_vector.x) > abs(input_vector.y):
			last_direction = "right" if input_vector.x > 0 else "left"
		else:
			last_direction = "down" if input_vector.y > 0 else "up"
	
	var anim_name := _resolve_animation_name(is_moving)
	_play_animation(anim_name)

	
func _resolve_animation_name(is_moving: bool) -> String:
	var state := "walk" if is_moving else "idle"
	
	match last_direction:
		"left", "right":
			animated_sprite.flip_h = (last_direction == "left")
			return "%s_right" % state
			
		_:
			animated_sprite.flip_h = false
			return "%s_%s" % [state, last_direction]

func _play_animation(anim_name: String) -> void:
	if animated_sprite.animation and animated_sprite.sprite_frames.has_animation(anim_name):
		if animated_sprite.animation != anim_name:
			animated_sprite.play(anim_name)
	else:
		push_warning("Animasi '%s' belum ada di SpriteFrames player." % anim_name)
	
