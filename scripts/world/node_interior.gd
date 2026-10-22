extends Node2D

## Interior yang disusun sebagai node di editor (lantai/dinding = TileMapLayer, perabot = node
## terpisah). Script ini hanya menyalakan waktu dan mengatur zoom kamera pemain.

## Nama ruangan (untuk catatan/debug).
@export var room_title := "Rumah Warga"
## Zoom kamera pemain saat bermain sendiri (co-op memakai zoom split screen).
@export var default_zoom := 2.0

func _ready() -> void:
	DayCycle.is_running = true
	for candidate in find_children("*", "CharacterBody2D", true, false):
		if candidate is Player:
			candidate.refresh_world()
			var camera := candidate.get_node_or_null("Camera2D") as Camera2D
			if camera != null and camera.has_method("set_default_zoom") and not Coop.has_root():
				camera.set_default_zoom(default_zoom)
				camera.reset_smoothing()
