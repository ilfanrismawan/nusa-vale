extends Node2D

@onready var modulate_light: CanvasModulate = $CanvasModulate

func _ready() -> void:
	var gate := Area2D.new()
	gate.name = "DeepForestEntrance"
	gate.set_script(preload("res://scripts/world/deep_forest_gate.gd"))
	gate.position = Vector2(520, 720)
	add_child(gate)
	_build_fishing_spot()
	var shrine := Area2D.new()
	shrine.name = "DayaShrine"
	shrine.set_script(preload("res://scripts/world/daya_shrine.gd"))
	shrine.position = Vector2(672, 480)
	add_child(shrine)
	DayCycle.is_running = true
	FarmManager.initialize(self)
	ForageSpawner.attach(self, "forest")
	WeedSpawner.attach_weeds(self, "forest", ^"YSortEntities", 3, 15)
	TreeSpawner.attach_trees(self, "forest", ^"YSortEntities", 2, 12)
	DigSpotSpawner.attach_dig_spots(self, "forest", ^"YSortEntities", 2, 5)

	Notify.say("Cahaya keemasan berdenyut di akar keramat dekat jalan hutan. Dekati dan berinteraksi.")

func _exit_tree() -> void:
	FarmManager.clear_references()

func _build_fishing_spot() -> void:
	var water := get_node("Water") as TileMapLayer
	var ground := get_node("BaseLayerGround") as TileMapLayer
	var spot := FishingSpot.new()
	spot.name = "ForestRiverSpot"
	spot.location_id = "forest_river"
	add_child(spot)
	# The water layer extends underneath land. Register only exposed water,
	# and merge consecutive cells so the river does not need a shape per tile.
	var used := water.get_used_rect()
	var tile_size := Vector2(water.tile_set.tile_size)
	for y in range(used.position.y, used.end.y):
		var start := -1
		for x in range(used.position.x, used.end.x + 1):
			var cell := Vector2i(x, y)
			var center := water.to_global(water.map_to_local(cell))
			var available := x < used.end.x and water.get_cell_source_id(cell) >= 0 and ground.get_cell_source_id(ground.local_to_map(ground.to_local(center))) < 0
			if available:
				for bridge in get_node("Bridges").get_children():
					if bridge is Sprite2D and bridge.get_rect().has_point(bridge.to_local(center)):
						available = false
						break
			if available and start < 0:
				start = x
			elif not available and start >= 0:
				var collision := CollisionShape2D.new()
				var shape := RectangleShape2D.new()
				shape.size = Vector2((x - start) * tile_size.x, tile_size.y)
				collision.shape = shape
				collision.position = spot.to_local(water.to_global(water.map_to_local(Vector2i(start, y)))) + Vector2((x - start - 1) * tile_size.x * 0.5, 0)
				spot.add_child(collision)
				start = -1

