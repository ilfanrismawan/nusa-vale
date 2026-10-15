class_name FootstepAudio
extends RefCounted

var distance := 0.0
var variation := 0
var _surface_cache: Dictionary = {}
var _images: Dictionary = {}

func update(player: Node2D, moved: float, running: bool) -> void:
	if moved < 0.01 or player.is_input_locked():
		distance = 0.0
		return
	distance += minf(moved, 8.0) # Scene teleports do not trigger a burst of footsteps.
	var stride := 16.0 if running else 12.0
	if distance < stride:
		return
	distance = fmod(distance, stride)
	variation = (variation + randi_range(1, 4)) % 5
	Juice.play_footstep(surface_at(player), running, variation)

func surface_at(player: Node2D) -> String:
	var world: Node = player.world_root()
	var feet: Vector2 = player.global_position + Vector2(0, 8)
	# Explicit overlays beat the ground below. Decorative/collision layers are excluded.
	for layer_name in ["Road", "Plaza", "Ruins", "Stairs", "WateredLayer", "SoilLayer", "DirtPath", "ForestFloor", "BaseLayerGround", "TileMapLayer2", "TileMapLayer"]:
		var layer := world.get_node_or_null(NodePath(layer_name)) as TileMapLayer
		if layer == null or layer.tile_set == null:
			continue
		var cell := layer.local_to_map(layer.to_local(feet))
		var tile := layer.get_cell_tile_data(cell)
		if tile == null:
			continue
		if layer.tile_set.get_custom_data_layer_by_name("footstep_surface") >= 0:
			var explicit: String = str(tile.get_custom_data("footstep_surface"))
			if explicit in ["wood", "grass", "snow", "concrete", "carpet", "dirt"]:
				return explicit
		if layer_name in ["SoilLayer", "WateredLayer", "DirtPath"]:
			return "dirt"
		if layer_name in ["Plaza", "Ruins"]:
			return "concrete"
		var source := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
		if source != null and source.texture != null:
			return _atlas_surface(source, layer.get_cell_atlas_coords(cell), world.scene_file_path.contains("/interior/"))
	return "grass"

func _atlas_surface(source: TileSetAtlasSource, cell: Vector2i, indoor: bool) -> String:
	var path := source.texture.resource_path.to_lower()
	if "plank" in path or "bridge" in path:
		return "wood"
	if "soil" in path or "road" in path or "dirt" in path or "path" in path or "tilled" in path:
		return "dirt"
	if "grass" in path and not indoor:
		return "grass"
	var identity := path if not path.is_empty() else str(source.texture.get_instance_id())
	var key := "%s:%s:%s" % [identity, cell, indoor]
	if _surface_cache.has(key):
		return _surface_cache[key]
	if not _images.has(identity):
		_images[identity] = source.texture.get_image()
	var image: Image = _images[identity]
	var votes := {"grass": 0, "dirt": 0, "snow": 0, "concrete": 0}
	if image != null:
		var region := source.get_tile_texture_region(cell)
		for y in range(region.position.y, region.end.y, 2):
			for x in range(region.position.x, region.end.x, 2):
				var pixel := image.get_pixel(x, y)
				if pixel.a < 0.5:
					continue
				if pixel.g > pixel.r * 1.08 and pixel.g > pixel.b * 1.08:
					votes.grass += 1
				elif pixel.r > pixel.b * 1.25:
					votes.dirt += 1
				elif pixel.v > 0.68 and pixel.s < 0.3:
					votes.snow += 1
				else:
					votes.concrete += 1
	var surface := "concrete"
	for candidate in votes:
		if int(votes[candidate]) > int(votes[surface]):
			surface = candidate
	if indoor:
		surface = "wood" if surface == "dirt" else "carpet" if surface == "grass" else "concrete"
	_surface_cache[key] = surface
	return surface
