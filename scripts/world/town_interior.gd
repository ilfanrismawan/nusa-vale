extends Node2D
## Interior prosedural lama (rumah warga, warung, perpustakaan, rumah Wira). Lantai, dinding, judul,
## perabot dan layanan kini node biasa di town_room.tscn / scene turunannya, jadi diedit di editor.
## Warga yang tinggal di sini dihidupkan oleh node ResidentRoom (map = nama file scene).

func _ready() -> void:
	DayCycle.is_running = true
	for candidate in find_children("*", "CharacterBody2D", true, false):
		if candidate is Player:
			candidate.refresh_world()
			var camera := candidate.get_node_or_null("Camera2D") as Camera2D
			if camera != null and not Coop.has_root():
				camera.set_default_zoom(2.0)
				camera.reset_smoothing()
