extends RefCounted
## Build editor-visible water dressing and fishable water from the town map.
const PROPS = preload("res://assets/farm_rpg/objects/Props/Spring/props water.png")
const DETAILS = preload("res://assets/farm_rpg/objects/Props/Water props.png")

static func build(town: Node2D) -> void:
	var water := town.get_node("Water") as TileMapLayer
	var cells: Dictionary = {}
	for cell in water.get_used_cells():
		var point := water.to_global(water.map_to_local(cell))
		var covered := false
		for bridge in town.get_node("Bridge").get_children():
			if bridge is Sprite2D and bridge.get_rect().has_point(bridge.to_local(point)):
				covered = true
			elif bridge is TileMapLayer and bridge.get_cell_source_id(bridge.local_to_map(bridge.to_local(point))) >= 0:
				covered = true
		if not covered:
			cells[cell] = true
	var decor := TileMapLayer.new()
	decor.name = "WaterDecoration"
	decor.position = water.position
	decor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	decor.tile_set = TileSet.new()
	decor.tile_set.tile_size = water.tile_set.tile_size
	var props := TileSetAtlasSource.new()
	props.texture = PROPS
	props.texture_region_size = Vector2i(16, 16)
	decor.tile_set.add_source(props, 0)
	for x in [0, 3, 4, 5, 6, 9]:
		var coord := Vector2i(x, 0)
		props.create_tile(coord)
		props.set_tile_animation_columns(coord, 1)
		props.set_tile_animation_frames_count(coord, 4)
		props.set_tile_animation_speed(coord, 4.0)
	var details := TileSetAtlasSource.new()
	details.texture = DETAILS
	details.texture_region_size = Vector2i(16, 16)
	decor.tile_set.add_source(details, 1)
	for x in [0, 1, 2, 3]:
		details.create_tile(Vector2i(x, 0))
	town.add_child(decor)
	decor.owner = town
	var variants := [0, 3, 4, 5, 6, 9]
	for cell: Vector2i in cells:
		# Sparse, deterministic clusters; leave open water between props.
		var seed_value := absi(cell.x * 73 + cell.y * 137)
		var interior := cells.has(cell + Vector2i.LEFT) and cells.has(cell + Vector2i.RIGHT) and cells.has(cell + Vector2i.UP) and cells.has(cell + Vector2i.DOWN)
		if interior and seed_value % 11 == 0:
			decor.set_cell(cell, 0, Vector2i(variants[seed_value % variants.size()], 0))
		elif not interior and seed_value % 17 == 0:
			decor.set_cell(cell, 1, Vector2i(seed_value % 4, 0))
	var spot := FishingSpot.new()
	spot.name = "TownRiverSpot"
	spot.location_id = "town_river"
	town.add_child(spot)
	spot.owner = town
	var bounds := water.get_used_rect()
	for y in range(bounds.position.y, bounds.end.y):
		var start := bounds.position.x - 1
		for x in range(bounds.position.x, bounds.end.x + 1):
			if cells.has(Vector2i(x, y)):
				if start < bounds.position.x:
					start = x
			elif start >= bounds.position.x:
				var collision := CollisionPolygon2D.new()
				var half_size := Vector2((x - start) * 8, 8)
				collision.polygon = PackedVector2Array([-half_size, Vector2(half_size.x, -half_size.y), half_size, Vector2(-half_size.x, half_size.y)])
				collision.position = spot.to_local(water.to_global(water.map_to_local(Vector2i(start, y)))) + Vector2((x - start - 1) * 8, 0)
				spot.add_child(collision)
				collision.owner = town
				start = bounds.position.x - 1
