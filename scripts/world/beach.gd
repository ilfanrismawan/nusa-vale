extends Node2D

## Pantai (GDD 3): pesisir selatan Town. Scene dibuat oleh tools/build_beach.gd lalu bisa diedit di editor:
## - BaseLayerGround (pasir, tanah ForageSpawner "beach"), SeaWater, Grass, Paths, Pier: TileMapLayer.
## - TerrainCollisions: air laut dan batas peta; sel dermaga sengaja tidak diberi tabrakan.
## - SeaFishingSpot: seluruh laut, location_id "beach_sea", tidak membeku di Musim Dingin.
## - ExitToTown: jalan pulang ke tepi selatan Town.
@export var map_size := Vector2i(960, 800)

func update_camera_limits() -> void:
	# Co-op also calls this before copying the embedded camera's limits.
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
	for candidate in find_children("*", "CharacterBody2D", true, false):
		if candidate is Player:
			candidate.refresh_world()
	if DiscoveryManager.discover("beach"):
		Notify.say("Pantai: memancing ikan laut dari dermaga, cari kerang dan kelapa di pasir.")
