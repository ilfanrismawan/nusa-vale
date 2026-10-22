extends Node2D

## Interior Toko (General Store). Semua furnitur adalah node di scene ini;
## script ini hanya menyiapkan kamera dan waktu saat masuk ruangan.

## Zoom kamera saat di dalam toko (main sendiri, bukan co-op).
@export var camera_zoom := 2.2
## Jam tetap berjalan selama di dalam toko.
@export var keep_time_running := true

func _ready() -> void:
	if keep_time_running:
		DayCycle.is_running = true
	for candidate in find_children("*", "CharacterBody2D", true, false):
		if candidate is Player:
			candidate.refresh_world()
			var camera := candidate.get_node_or_null("Camera2D") as Camera2D
			if camera != null and not Coop.has_root():
				camera.set_default_zoom(camera_zoom)
				camera.reset_smoothing()
