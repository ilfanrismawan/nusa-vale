class_name ActionState
extends State

signal action_performed(action: ActionData, cell: Vector2i)

@export var idle_state: State

var action: ActionData
var target_cell := Vector2i.ZERO
var target_facing := Vector2.DOWN
var _performed := false
var _refilling := false

func start(_action: ActionData, cell: Vector2i) -> void:
	action = _action
	animation_name = action.animation_name
	target_cell = cell
	target_facing = player.facing_direction
	_refilling = action.effect is WaterEffect and action.tool_data != null and FishingManager.find_spot_at(player, Juice.cell_center(player, cell)) != null
	if _refilling:
		var frames := animation_controller.sprite.sprite_frames
		for suffix in ["down", "up", "right", "left"]:
			var source: String = "water_" + suffix
			if not frames.has_animation(source):
				source = "watering_" + suffix
			if not frames.has_animation(source):
				continue
			var refill: String = "refill_" + suffix
			if frames.has_animation(refill):
				frames.remove_animation(refill)
			frames.add_animation(refill)
			frames.set_animation_loop(refill, false)
			frames.set_animation_speed(refill, 8.0)
			# Preparatory poses dip and lift the can without the pouring-water frames.
			for index in [0, 1, 2, 1, 0]:
				frames.add_frame(refill, frames.get_frame_texture(source, mini(index, frames.get_frame_count(source) - 1)))
		animation_name = &"refill"

func enter() -> void:
	_performed = false
	player.velocity = Vector2.ZERO
	super.enter()
	animation_controller.sprite.speed_scale = action.tool_data.action_speed if action.tool_data != null else 1.0
	animation_controller.frame_changed.connect(_on_frame_changed)
	animation_controller.animated_finished.connect(_on_animation_finished)

func exit() -> void:
	animation_controller.sprite.speed_scale = 1.0
	if animation_controller.frame_changed.is_connected(_on_frame_changed):
		animation_controller.frame_changed.disconnect(_on_frame_changed)
	if animation_controller.animated_finished.is_connected(_on_animation_finished):
		animation_controller.animated_finished.disconnect(_on_animation_finished)
		
func _on_frame_changed(frame: int) -> void:
	if frame == (2 if _refilling else action.hit_frame):
		_perform()
				
func _on_animation_finished() -> void:
	_perform()
	transitioned.emit(idle_state)

func _perform() -> void:
	if _performed:
		return
	_performed = true
	if action.tool_data != null:
		Juice.play_tool_tier(action.tool_data)
	action_performed.emit(action, target_cell)
