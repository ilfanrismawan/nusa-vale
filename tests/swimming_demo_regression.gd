extends Node

func _ready() -> void:
	var demo = load("res://scenes/examples/swimming_demo.tscn").instantiate()
	add_child(demo)
	demo.set_physics_process(false)
	demo.actor.position = Vector2(300, 220)
	demo._physics_process(0.0)
	assert(demo.mode == demo.Mode.SWIM, "Entering water must start swimming")
	assert(String(demo.sprite.animation).begins_with("swim_idle_"))
	var dive_key := InputEventKey.new()
	dive_key.physical_keycode = KEY_SPACE
	dive_key.pressed = true
	demo._unhandled_input(dive_key)
	demo._physics_process(0.0)
	assert(demo.mode == demo.Mode.DIVE, "Holding Space in water must dive")
	assert(String(demo.sprite.animation).begins_with("dive_"))
	Input.action_press("move_right")
	demo._physics_process(0.0)
	assert(is_equal_approx(demo.actor.velocity.x, demo.DIVE_SPEED))
	Input.action_release("move_right")
	dive_key.pressed = false
	demo._unhandled_input(dive_key)
	demo._physics_process(0.0)
	assert(demo.mode == demo.Mode.SWIM, "Releasing Space must surface")
	dive_key.pressed = true
	demo._unhandled_input(dive_key)
	demo._physics_process(0.0)
	demo.actor.position = Vector2(180, 220)
	demo._physics_process(0.0)
	assert(demo.mode == demo.Mode.CLIMB, "Leaving water must play climb")
	await get_tree().create_timer(0.6).timeout
	assert(demo.mode == demo.Mode.WALK, "Climb must finish in walking mode")
	assert(String(demo.sprite.animation).begins_with("idle_"))
	demo._physics_process(0.0)
	assert(demo.mode == demo.Mode.WALK, "Holding Space on land must not dive")
	demo.actor.position = Vector2(300, 220)
	demo._physics_process(0.0)
	assert(demo.mode == demo.Mode.DIVE, "Entering water while holding Space must dive")
	demo._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	demo._physics_process(0.0)
	assert(demo.mode == demo.Mode.SWIM, "Losing focus must release dive input")
	print("PASS: swim idle, dive input, underwater movement, surfacing, climb, land guard, focus reset")
	get_tree().quit()
