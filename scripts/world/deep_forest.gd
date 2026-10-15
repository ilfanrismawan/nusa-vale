extends Node2D
## Gameplay only. All terrain, scenery, collisions and spawners live in DeepForest.tscn.
var light: CanvasModulate
var resource_spawn_cells: Array[Vector2i] = []
var _resource_cells: Dictionary = {}

func _enter_tree() -> void:
	set_meta("farm_area", "deep_forest")
	var mask := get_node("ResourceSpawnMask") as TileMapLayer
	var ground := get_node("BaseLayerGround") as TileMapLayer
	var paths := get_node("ForestPaths") as TileMapLayer
	mask.visible = false
	resource_spawn_cells.clear()
	_resource_cells.clear()
	for cell: Vector2i in mask.get_used_cells():
		var center := mask.to_global(mask.map_to_local(cell))
		var ground_cell := ground.local_to_map(ground.to_local(center))
		var path_cell := paths.local_to_map(paths.to_local(center))
		if ground.get_cell_source_id(ground_cell) < 0 or paths.get_cell_source_id(path_cell) >= 0:
			continue
		resource_spawn_cells.append(ground_cell)
		_resource_cells[ground_cell] = true

func is_resource_cell(cell: Vector2i) -> bool:
	return _resource_cells.has(cell)

func random_resource_cell() -> Vector2i:
	return resource_spawn_cells[randi() % resource_spawn_cells.size()] if not resource_spawn_cells.is_empty() else Vector2i(-1, -1)

func _ready() -> void:
	light = get_node("CanvasModulate") as CanvasModulate
	var player := get_node("Player/CharacterBody2D") as Player
	var camera := player.get_node("Camera2D") as Camera2D
	var ground := get_node("BaseLayerGround") as TileMapLayer
	var bounds := ground.get_used_rect()
	var top_left := ground.to_global(Vector2(bounds.position * ground.tile_set.tile_size))
	var bottom_right := ground.to_global(Vector2(bounds.end * ground.tile_set.tile_size))
	camera.limit_left = int(top_left.x)
	camera.limit_top = int(top_left.y)
	camera.limit_right = int(bottom_right.x)
	camera.limit_bottom = int(bottom_right.y)
	DayCycle.is_running = true
	FarmManager.initialize(self)
	_relocate_saved_resources()
	if DiscoveryManager.discover("deep_forest"):
		Notify.say("Deep Forest: jalur utara kembali ke Forest. Panen jamur langka, gali truffle, dan tambang bijih. Resource baru muncul setiap hari.")


func _exit_tree() -> void:
	FarmManager.clear_references()

func _relocate_saved_resources() -> void:
	# Keep existing harvest state when upgrading from the old rectangular map.
	# Move displaced resources into glades instead of leaving them under water/trees.
	var occupied: Dictionary = {}
	var keys := ["deep_forest", "deep_forest#weed", "deep_forest#tree", "deep_forest#dig", "deep_forest#ore"]
	for area: String in keys:
		for key: String in ForageManager.get_items(area):
			var cell := ForageManager.cell_from_key(key)
			if is_resource_cell(cell): occupied[cell] = true
	for area: String in keys:
		var items := ForageManager.get_items(area)
		for key: String in items.keys():
			if is_resource_cell(ForageManager.cell_from_key(key)): continue
			for cell: Vector2i in resource_spawn_cells:
				if occupied.has(cell): continue
				items[ForageManager.key_of(cell)] = items[key]
				items.erase(key)
				occupied[cell] = true
				break
