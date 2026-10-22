extends Node2D

## Town buildings are independent scene instances under YSortEntities/Buildings.

@onready var modulate_light: CanvasModulate = $CanvasModulate

func update_camera_limits() -> void:
	# Co-op also calls this before copying the embedded camera's limits.
	var camera := get_node_or_null("Player/CharacterBody2D/Camera2D") as Camera2D
	if camera == null:
		return
	var bounds := Rect2()
	var has_bounds := false
	for layer_name in ["BaseLayerGround", "ForestFloor", "DirtPath", "Plaza", "Water", "GrassWater"]:
		var layer := get_node(layer_name) as TileMapLayer
		var used := layer.get_used_rect()
		if not used.has_area():
			continue
		var top_left := Vector2(used.position * layer.tile_set.tile_size)
		var bottom_right := Vector2(used.end * layer.tile_set.tile_size)
		for corner in [top_left, Vector2(bottom_right.x, top_left.y), bottom_right, Vector2(top_left.x, bottom_right.y)]:
			var point := layer.to_global(corner)
			if not has_bounds:
				bounds = Rect2(point, Vector2.ZERO)
				has_bounds = true
			else:
				bounds = bounds.expand(point)
	if has_bounds:
		camera.limit_left = floori(bounds.position.x)
		# Edge/path/water tiles may extend one column beyond the solid ground.
		# That fringe must not expose the empty strip to the left of town.
		var ground := get_node("BaseLayerGround") as TileMapLayer
		var ground_rect := ground.get_used_rect()
		if ground_rect.has_area():
			var left_top := ground.to_global(Vector2(ground_rect.position * ground.tile_set.tile_size))
			var left_bottom := ground.to_global(Vector2(Vector2i(ground_rect.position.x, ground_rect.end.y) * ground.tile_set.tile_size))
			camera.limit_left = ceili(minf(left_top.x, left_bottom.x))
		camera.limit_top = floori(bounds.position.y)
		camera.limit_right = ceili(bounds.end.x)
		camera.limit_bottom = ceili(bounds.end.y)
		# _ready on the child camera precedes this scene's _ready. Re-clamp
		# persisted zoom immediately, so zoom-out cannot reveal outside the map.
		if camera.is_node_ready():
			if camera.has_method("refresh_limits"):
				camera.call("refresh_limits")
			camera.reset_smoothing()

func _ready() -> void:
	# The Player instance (including Camera2D) is ready by this point. Running
	# this from _enter_tree() could happen before the instance is available,
	# causing the function to return without ever applying the limits.
	update_camera_limits()

	DayCycle.is_running = true
	FarmManager.initialize(self)
	# Serangga liar kota (GDD 7). Forage kota memakai node ForageSpawner di town.tscn.
	preload("res://scripts/world/bug_spawner.gd").attach(self, "town", ^"YSortEntities", 4)

	if DiscoveryManager.discover("town"):
		Notify.say("Selamat datang di Kota Nusa Vale!")
		Notify.say("Sekolah dan Universitas di utara alun-alun, toko di timur.")

func _exit_tree() -> void:
	FarmManager.clear_references()
