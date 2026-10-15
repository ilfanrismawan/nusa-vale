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
	var forest: Node2D = load("res://scenes/world/Forest.tscn").instantiate()
	get_tree().root.add_child(forest)
	get_tree().current_scene = forest
	await get_tree().physics_frame
	await get_tree().physics_frame
	DayCycle.is_running = false
	var player: Player = forest.get_node("Player/CharacterBody2D")
	var spot := forest.get_node("ForestRiverSpot") as FishingSpot
	check(spot.location_id == "forest_river" and spot.get_child_count() > 0, "forest river has fishing collision regions")
	for region in spot.get_children():
		check(FishingManager.find_spot_at(player, region.global_position) == spot, "exposed river resolves fishing spot")
	var ground := forest.get_node("BaseLayerGround") as TileMapLayer
	for cell in ground.get_used_cells():
		check(FishingManager.find_spot_at(player, ground.to_global(ground.map_to_local(cell))) == null, "ground is not fishable")
	for bridge in forest.get_node("Bridges").get_children():
		check(FishingManager.find_spot_at(player, bridge.global_position) == null, "bridge deck is not fishable")
	DayCycle.hour = 12
	check(FishingManager.roll_catch("forest_river") != null, "forest river has available fish")
	get_tree().current_scene = self
	forest.queue_free()
	await get_tree().process_frame
	print("FOREST FISHING COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
