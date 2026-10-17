extends Node2D

@export var default_zoom := 1.35

func _ready() -> void:
	DayCycle.is_running = true
	for candidate in find_children("*", "CharacterBody2D", true, false):
		if candidate is Player:
			candidate.refresh_world()
			var camera := candidate.get_node_or_null("Camera2D")
			if camera != null and camera.has_method("set_default_zoom"):
				camera.set_default_zoom(default_zoom)
