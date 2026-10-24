extends Node2D

## Both maps are authored scenes; runtime only binds world state and camera limits.
@export var map_size := Vector2i(1152, 768)

func update_camera_limits() -> void:
	for camera in find_children("*", "Camera2D", true, false):
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = map_size.x
		camera.limit_bottom = map_size.y
		if camera.has_method("refresh_limits") and camera.is_node_ready():
			camera.refresh_limits()

func _ready() -> void:
	update_camera_limits()
	DayCycle.is_running = true
	FarmManager.initialize(self)

func _exit_tree() -> void:
	FarmManager.clear_references()
