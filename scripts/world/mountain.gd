extends Node2D

## Kawasan Gunung (GDD 9): dataran batu kecil di utara Hill dengan mulut Gua Tambang.
## Semua isi kawasan ada sebagai node di mountain.tscn supaya bisa diedit langsung di editor:
## - BaseLayerGround / MountainWalls: TileMapLayer (tileset resources/world/mountain_rock_tileset.tres).
## - Walls: tabrakan batas peta; CaveEntrance: mulut gua; ExitToHill: jalan pulang ke Hill.
## - HotSpring: kolam air panas (winter_pond.gd), ukur lewat size_tiles di Inspector.

func _ready() -> void:
	DayCycle.is_running = true
	for candidate in find_children("*", "CharacterBody2D", true, false):
		if candidate is Player:
			candidate.refresh_world()
			var camera := candidate.get_node_or_null("Camera2D") as Camera2D
			if camera != null and not Coop.has_root():
				if camera.has_method("set_default_zoom"):
					camera.set_default_zoom(2.0)
				camera.reset_smoothing()
	if DiscoveryManager.discover("mountain"):
		Notify.say("Gunung: mulut Gua Tambang ada di tebing utara. Toko Combat menunggu di lobi gua.")
