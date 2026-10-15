extends Node
var failures := 0

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func _ready() -> void:
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	var town: Node2D = load("res://scenes/world/town.tscn").instantiate()
	get_tree().root.add_child(town)
	get_tree().current_scene = town
	await get_tree().physics_frame
	await get_tree().physics_frame
	DayCycle.is_running = false
	var player: Player = town.get_node("Player/CharacterBody2D")
	var water: TileMapLayer = town.get_node("Water")
	var decor: TileMapLayer = town.get_node("WaterDecoration")
	var spot: FishingSpot = town.get_node("TownRiverSpot")
	var camera: Camera2D = player.get_node("Camera2D")
	var ground: TileMapLayer = town.get_node("BaseLayerGround")
	var ground_left := ground.to_global(Vector2(ground.get_used_rect().position * ground.tile_set.tile_size)).x
	check(camera.limit_left == ceili(ground_left), "camera left stops at solid ground, not sparse fringe tiles")
	for layer_name in ["BaseLayerGround", "ForestFloor", "DirtPath", "Plaza", "Water", "GrassWater"]:
		var layer: TileMapLayer = town.get_node(layer_name)
		var used := layer.get_used_rect()
		var first := layer.to_global(Vector2(used.position * layer.tile_set.tile_size))
		var last := layer.to_global(Vector2(used.end * layer.tile_set.tile_size))
		check(camera.limit_top <= first.y and camera.limit_right >= last.x and camera.limit_bottom >= last.y, "camera covers remaining terrain bounds")
	player.global_position = Vector2(40, 408)
	camera.refresh_limits()
	camera.force_update_scroll()
	check(camera.get_screen_center_position().x - camera.get_viewport_rect().size.x / camera.zoom.x * 0.5 >= float(camera.limit_left) - 1.0, "camera view never exposes empty left strip at town entrance")
	check(decor.get_used_cells().size() > 20, "town water has varied decorations")
	var animated := 0
	for cell in decor.get_used_cells():
		check(water.get_cell_source_id(cell) >= 0, "decoration stays on water")
		var source := decor.tile_set.get_source(decor.get_cell_source_id(cell)) as TileSetAtlasSource
		if source.get_tile_animation_frames_count(decor.get_cell_atlas_coords(cell)) == 4:
			animated += 1
	check(animated > 0, "water props use four-frame asset animation")
	check(spot.location_id == "town_river", "town has its own fishing location")
	for region in spot.get_children():
		check(region is CollisionPolygon2D, "fishing region uses polygon collision")
		check(FishingManager.find_spot_at(player, region.global_position) == spot, "water region resolves fishing spot")
	for bridge in town.get_node("Bridge").get_children():
		if bridge is Sprite2D:
			check(FishingManager.find_spot_at(player, bridge.global_position) == null, "bridge stays non-fishable")
	DayCycle.hour = 12
	check(FishingManager.roll_catch("town_river") != null, "town river has catchable fish")
	get_tree().current_scene = self
	town.queue_free()
	await get_tree().process_frame
	print("TOWN WATER COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
