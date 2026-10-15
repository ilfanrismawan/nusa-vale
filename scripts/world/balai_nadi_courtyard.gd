extends Node2D
## Layout, textures, collisions, and motion are authored in exterior.tscn.
## This script only binds the existing day cycle and player camera to the scene.
@export var camera_bounds := Rect2(0, 0, 864, 640)
@export_range(1.0, 3.0) var camera_zoom := 1.5
@export var camera_offset := Vector2.ZERO

func _ready() -> void:
	DayCycle.is_running = true
	for candidate in find_children("*", "CharacterBody2D", true, false):
		if candidate is Player:
			var camera := candidate.get_node_or_null("Camera2D") as Camera2D
			if camera != null:
				camera.limit_left = floori(camera_bounds.position.x)
				camera.limit_top = floori(camera_bounds.position.y)
				camera.limit_right = ceili(camera_bounds.end.x)
				camera.limit_bottom = ceili(camera_bounds.end.y)
				if not Coop.has_root():
					camera.set_default_zoom(camera_zoom)
					camera.offset = camera_offset
					camera.reset_smoothing()
