class_name ActionState
extends State

signal action_performed(action: ActionData, cell: Vector2i)

@export var idle_state: State

var action: ActionData
var target_cell := Vector2i.ZERO
var target_facing := Vector2.DOWN
var _performed := false

func start(_action: ActionData, cell: Vector2i) -> void:
	action = _action
	animation_name = action.animation_name
	target_cell = cell
	target_facing = player.facing_direction

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
	if action.hit_frame >= 0 and frame == action.hit_frame:
		_perform()
				
func _on_animation_finished() -> void:
	_perform()
	transitioned.emit(idle_state)

func _perform() -> void:
	if _performed:
		return
	_performed = true
	action_performed.emit(action, target_cell)
