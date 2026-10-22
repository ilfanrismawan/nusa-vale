extends Node

signal crop_planted(cell: Vector2i, crop: CropData)
signal crop_harvested(cell: Vector2i, item_id: String, count: int)

const ItemPickupScript = preload("res://scripts/world/item_pickup.gd")

var base_layer_ground: TileMapLayer
var soil_layer: TileMapLayer
var watered_layer: TileMapLayer
var crop_layer: TileMapLayer

var farm_data: Dictionary = {}
## World yang layer-nya sedang dipakai. Co-op bisa memuat beberapa area sekaligus,
## jadi Player memanggil bind_world() sebelum aksi.
var _bound_world: Node

const TERRAIN_SET_SOIL := 0
const TERRAIN_TILLED := 0

func _ready() -> void:
	DayCycle.season_changed.connect(_on_season_changed)

func initialize(world: Node) -> void:
	if world == null:
		clear_references()
		return
	_bind_layers(world)
	
	if not DayCycle.day_passed.is_connected(_on_day_passed):
		DayCycle.day_passed.connect(_on_day_passed)
	
	_restore_tiles()
	if GameState.weather != null and GameState.weather.is_raining():
		apply_rain()

## Pakai layer dari world ini tanpa memulihkan tile (sudah dipulihkan saat area dimuat).
func bind_world(world: Node) -> void:
	if world == null:
		clear_references()
		return
	if world == _bound_world and is_instance_valid(base_layer_ground):
		return
	_bind_layers(world)

func _bind_layers(world: Node) -> void:
	_bound_world = world
	base_layer_ground = world.get_node_or_null("BaseLayerGround")
	watered_layer = world.get_node_or_null("WateredLayer")
	soil_layer = world.get_node_or_null("SoilLayer")
	crop_layer = world.get_node_or_null("Crop")
	if crop_layer and crop_layer.tile_set and not crop_layer.has_meta(&"crop_sources_ready"):
		# Source runtime milik layer ini; jangan ubah resource scene yang dibagi world lain.
		crop_layer.tile_set = crop_layer.tile_set.duplicate()
		crop_layer.set_meta(&"crop_sources_ready", true)
	
	if base_layer_ground:
		if soil_layer:
			soil_layer.position = base_layer_ground.position
		if watered_layer:
			watered_layer.position = base_layer_ground.position
		if crop_layer:
			crop_layer.position = base_layer_ground.position

func clear_references() -> void:
	_bound_world = null
	base_layer_ground = null
	watered_layer = null
	soil_layer = null
	crop_layer = null

func area_id() -> String:
	return str(_bound_world.get_meta("farm_area", "farm")) if is_instance_valid(_bound_world) else "farm"

func _visible_plot(data: Dictionary) -> bool:
	return str(data.get("area", "farm")) == area_id()

func _can_access_plot(data: Dictionary) -> bool:
	return _visible_plot(data) and (area_id() != "greenhouse" or GameState.balai_nadi.completed("greenhouse_restoration"))

func _set_ground_tile(layer: TileMapLayer, cell: Vector2i) -> void:
	if area_id() == "greenhouse":
		layer.set_cell(cell, 0, Vector2i.ZERO)
	else:
		layer.set_cells_terrain_connect([cell], TERRAIN_SET_SOIL, 0)
	
func _restore_tiles() -> void:
	var can_soil := is_instance_valid(soil_layer)
	var can_water := is_instance_valid(watered_layer)
	var can_crop := is_instance_valid(crop_layer)
	
	for cell in farm_data:
		var data: Dictionary = farm_data[cell]
		if not _visible_plot(data):
			continue
		
		if can_soil:
			_set_ground_tile(soil_layer, cell)
		
		if can_water and data["watered"]:
			_set_ground_tile(watered_layer, cell)
		
		if can_crop and data["crop"] != null:
			_update_crop_tile(cell, data["crop"], data["stage"])
	
	if not farm_data.is_empty():
		print("Restore tile: %d petak dikembalikan" % farm_data.size())
	
func hoe(cell: Vector2i) -> bool:
	if not is_instance_valid(soil_layer):
		return false
	if not is_tile_farmable(cell):
		return false
	if farm_data.has(cell):
		return false
	_set_ground_tile(soil_layer, cell)
	farm_data[cell] = {
		"area": area_id(),
		"state": "tilled",
		"crop": null,
		"stage": 0,
		"days_in_stage": 0,
		"watered": false
	}
	print("Tanah dicangkul: ", cell)
	if GameState.weather.is_raining():
		apply_rain()
	return true
	
## Tanaman tanpa season (kosong) boleh ditanam kapan saja.
func is_crop_in_season(crop: CropData) -> bool:
	if area_id() == "greenhouse" and GameState.balai_nadi.completed("greenhouse_restoration"):
		return true
	return crop.season.is_empty() or crop.season == DayCycle.get_current_season()

func plant(cell: Vector2i, crop: CropData) -> bool:
	if not farm_data.has(cell):
		return false
	if not _can_access_plot(farm_data[cell]):
		return false
	if not is_crop_in_season(crop):
		return false
	var data: Dictionary = farm_data[cell]
	if data["state"] != "tilled":
		return false
	
	data["state"] = "planted"
	data["crop"] = crop
	data["stage"] = 0
	data["days_in_stage"] = 0
	data["watered"] = false
	
	_update_crop_tile(cell, crop, 0)
	if GameState.weather.is_raining():
		apply_rain()
	crop_planted.emit(cell, crop)
	print("Ditanam: %s di %s" % [crop.display_name, cell])
	return true

func can_water(cell: Vector2i) -> bool:
	return is_instance_valid(watered_layer) and farm_data.has(cell) and _can_access_plot(farm_data[cell])

func water(cell: Vector2i) -> bool:
	if not is_instance_valid(watered_layer):
		return false
	if not farm_data.has(cell):
		return false
	if not _can_access_plot(farm_data[cell]):
		return false
	var data: Dictionary = farm_data[cell]
	if data.get("watered", false):
		return false
	
	data["watered"] = true
	print("Disiram: ", cell)
	
	_set_ground_tile(watered_layer, cell)
	return true

func apply_rain() -> void:
	# Update saved plots even if nobody is visiting the farm. Greenhouse stays dry.
	var rain_layer: TileMapLayer = watered_layer if area_id() != "greenhouse" else null
	if Coop.has_root():
		var outside: Node = Coop.root.world_of(Coop.root.START_AREA)
		if outside != null:
			rain_layer = outside.get_node_or_null("WateredLayer") as TileMapLayer
	for cell in farm_data:
		var plot: Dictionary = farm_data[cell]
		if str(plot.get("area", "farm")) == "greenhouse":
			continue
		if plot.get("watered", false):
			continue
		plot.watered = true
		if is_instance_valid(rain_layer):
			rain_layer.set_cells_terrain_connect([cell], TERRAIN_SET_SOIL, 0)
	
func can_harvest(cell: Vector2i) -> bool:
	if not farm_data.has(cell):
		return false
	if not _can_access_plot(farm_data[cell]):
		return false
	var data: Dictionary = farm_data[cell]
	if data.get("crop") == null:
		return false
	var crop: CropData = data["crop"]
	return crop.is_harvestable(data["stage"])


func harvest(cell: Vector2i) -> bool:
	if not can_harvest(cell):
		return false
	var data: Dictionary = farm_data[cell]
	var crop: CropData = data["crop"]
	
	var item_id: String = crop.harvest_item_id
	var count: int = crop.harvest_count
	# Role Farmer (GDD 13): EXP dari harga hasil panen, Bountiful Harvest panen ganda.
	var farmer := GameState.current
	if SkillSystem.roll(farmer, &"harvest_double"):
		count *= 2
		Notify.say("Panen ganda!")

	# Kualitas panen (GDD 5.2 & Farmer Perk 8-9)
	var quality := ""
	var gold_chance := SkillSystem.stat(farmer, &"crop_gold")
	var silver_chance := SkillSystem.stat(farmer, &"crop_silver")
	var farmer_lvl := SkillSystem.level_for_points(farmer.skills.points.get(&"farmer", 0)) if farmer and farmer.skills != null else 0
	if gold_chance > 0.0 or farmer_lvl >= 9:
		var g_chance := maxf(gold_chance, 0.20 + (farmer_lvl - 9) * 0.05)
		if randf() < g_chance:
			quality = "_gold"
	if quality.is_empty() and (silver_chance > 0.0 or farmer_lvl >= 8):
		var s_chance := maxf(silver_chance, 0.35 + (farmer_lvl - 8) * 0.05)
		if randf() < s_chance:
			quality = "_silver"

	var harvest_item_id := item_id + quality
	var produce := GameState._resolve_item(harvest_item_id)
	if produce == null:
		produce = GameState._resolve_item(item_id)
		harvest_item_id = item_id

	SkillSystem.gain(farmer, &"farmer", SkillSystem.scaled_exp(produce.sell_price * crop.harvest_count if produce != null else 0, SkillSystem.RULES.harvest_exp_per_price, SkillSystem.RULES.harvest_exp_min, SkillSystem.RULES.harvest_exp_max))
	crop_harvested.emit(cell, harvest_item_id, count)
	print("Panen: %s x%d" % [harvest_item_id, count])
	
	if crop.is_fruit_tree():
		var max_stage = crop.get_total_stages() - 1
		data["stage"] = maxi(0, max_stage - 1)
		data["days_in_stage"] = 0
		data["watered"] = false
		if is_instance_valid(crop_layer) and _visible_plot(data):
			_update_crop_tile(cell, crop, data["stage"])
	else:
		if is_instance_valid(crop_layer):
			crop_layer.erase_cell(cell)
		data["state"] = "tilled"
		data["crop"] = null
		data["stage"] = 0
		data["days_in_stage"] = 0
		data["watered"] = false
	_spawn_harvest_drop(cell, harvest_item_id, count)
	return true


func _spawn_harvest_drop(cell: Vector2i, item_id: String, count: int) -> void:
	var parent: Node = crop_layer.get_parent() if is_instance_valid(crop_layer) else null
	if parent == null:
		parent = Coop.world_parent()
	var world_pos := Vector2.ZERO
	if is_instance_valid(crop_layer):
		world_pos = crop_layer.to_global(crop_layer.map_to_local(cell))
	elif is_instance_valid(base_layer_ground):
		world_pos = base_layer_ground.to_global(base_layer_ground.map_to_local(cell))
	for i in count:
		var offset := Vector2(randf_range(-10.0, 10.0), randf_range(-4.0, 6.0))
		ItemPickupScript.spawn(parent, world_pos + Vector2(0, -8) + offset, item_id, 1)
	
func _on_day_passed(_day: int) -> void:
	var layers_valid := is_instance_valid(crop_layer) and is_instance_valid(watered_layer)
	
	for cell in farm_data.keys():
		var data: Dictionary = farm_data[cell]
		
		if data["crop"] != null and data["watered"]:
			var crop: CropData = data["crop"]
			var max_stage = crop.get_total_stages() - 1
					
			if data["stage"] < max_stage:
				var orchard_active := SkillSystem.household(&"perpetual_orchard") > 0.0
				var can_grow := true
				if crop.is_fruit_tree() and data["stage"] >= max_stage - 1:
					if not is_crop_in_season(crop) and not orchard_active:
						can_grow = false
				if can_grow:
					var growth_bonus := 1
					if SkillSystem.household_roll(&"crop_growth"):
						growth_bonus += 1
					if crop.is_fruit_tree() and orchard_active:
						growth_bonus += 1
					data["days_in_stage"] += growth_bonus
					if data["days_in_stage"] >= crop.days_per_stage:
						data["stage"] += 1
						data["days_in_stage"] = 0
						if layers_valid and _visible_plot(data):
							_update_crop_tile(cell, crop, data["stage"])
						print("%s tumbuh ke stage %d" % [crop.display_name, data["stage"]])
			else:
				print("%s sudah siap panen di %s" % [crop.display_name, cell])
		
		if data.get("crop") == null:
			_erase_empty_plot_visuals(cell, str(data.get("area", "farm")))
			farm_data.erase(cell)
			continue
		# Farmer Lv3: sebagian petak tetap basah keesokan harinya.
		if data["watered"] and SkillSystem.household_roll(&"soil_keep_wet"):
			continue
		data["watered"] = false
		
		if layers_valid and _visible_plot(data):
			watered_layer.erase_cell(cell)

func _erase_empty_plot_visuals(cell: Vector2i, plot_area: String) -> void:
	# Loaded co-op worlds have independent layers; clear both without rebinding context.
	var worlds: Array[Node] = []
	if is_instance_valid(_bound_world):
		worlds.append(_bound_world)
	if Coop.has_root():
		for path in ["res://scenes/world/farm.tscn", "res://scenes/world/interior/greenhouse.tscn"]:
			var world: Node = Coop.root.world_of(path)
			if is_instance_valid(world) and not worlds.has(world):
				worlds.append(world)
	for world in worlds:
		if str(world.get_meta("farm_area", "farm")) != plot_area:
			continue
		for layer_name in ["SoilLayer", "WateredLayer", "Crop"]:
			var layer := world.get_node_or_null(NodePath(layer_name)) as TileMapLayer
			if layer != null:
				layer.erase_cell(cell)
			
## Tanaman di luar musimnya layu saat musim berganti; tanahnya tetap tercangkul.
func _on_season_changed(_season: int) -> void:
	var withered := 0
	for cell in farm_data:
		var data: Dictionary = farm_data[cell]
		var crop: CropData = data["crop"]
		if crop == null or data.get("area", "farm") == "greenhouse" or crop.season.is_empty() or crop.season == DayCycle.get_current_season():
			continue
		if crop.is_fruit_tree():
			continue
		# Green Thumb Mastery (Farmer Lv10 B): 50% tanaman bertahan melewati pergantian musim.
		if SkillSystem.household_roll(&"season_survive"):
			continue
		if is_instance_valid(crop_layer) and _visible_plot(data):
			crop_layer.erase_cell(cell)
		data["state"] = "tilled"
		data["crop"] = null
		data["stage"] = 0
		data["days_in_stage"] = 0
		withered += 1
	if withered > 0:
		Notify.say("%d tanaman layu karena pergantian musim" % withered)

func _update_crop_tile(cell: Vector2i, crop: CropData, stage: int) -> void:
	if not is_instance_valid(crop_layer):
		return
	var texture := crop.get_growth_texture()
	if texture == null or crop_layer.tile_set == null:
		return
	var sources: Dictionary = crop_layer.get_meta(&"crop_source_ids", {})
	if not sources.has(crop.crop_id):
		var source := TileSetAtlasSource.new()
		source.texture = texture
		var frame_size := crop.get_growth_frame_size()
		source.texture_region_size = frame_size
		for i in crop.get_total_stages():
			var coords := crop.get_growth_coords(i)
			if not source.has_tile(coords):
				source.create_tile(coords)
				source.get_tile_data(coords, 0).texture_origin = Vector2i(0, (frame_size.y - 16) / 2)
		var source_id := crop_layer.tile_set.get_next_source_id()
		crop_layer.tile_set.add_source(source, source_id)
		sources[crop.crop_id] = source_id
		crop_layer.set_meta(&"crop_source_ids", sources)
	crop_layer.set_cell(cell, sources[crop.crop_id], crop.get_growth_coords(stage))
	
func is_tile_farmable(cell: Vector2i) -> bool:
	if area_id() == "greenhouse" and not GameState.balai_nadi.completed("greenhouse_restoration"):
		return false
	if is_instance_valid(_bound_world) and _bound_world.get_meta("structure_area", "") == "farm" and StructureManager.occupies(cell):
		return false
	if not is_instance_valid(base_layer_ground):
		return false
	var tile_data := base_layer_ground.get_cell_tile_data(cell)
	if tile_data == null:
		return false
	return tile_data.get_custom_data("farmable") == true
	
func get_cell_data(cell: Vector2i) -> Dictionary:
	return farm_data.get(cell, {})


func shovel(cell: Vector2i) -> bool:
	if not farm_data.has(cell):
		print("Tidak ada tanah di sini")
		return false
	if not _can_access_plot(farm_data[cell]):
		return false
	var data: Dictionary = farm_data[cell]
	if data["crop"] != null:
		print("Ada tanaman di sini, tidak bisa digali!")
		return false
	if is_instance_valid(soil_layer):
		soil_layer.erase_cell(cell)
	if is_instance_valid(watered_layer):
		watered_layer.erase_cell(cell)
	farm_data.erase(cell)
	print("Tanah dihapus: ", cell)
	return true


func chop(player: Player, cell: Vector2i, damage: int = 1) -> bool:
	return hit_world(player, cell, &"choppable", damage)


func mine(player: Player, cell: Vector2i, damage: int = 1) -> bool:
	return hit_world(player, cell, &"mineable", damage)


func hit_world(player: Player, cell: Vector2i, target_group: StringName, damage: int = 1) -> bool:
	if player == null:
		return false
	var scene_tree := player.get_tree()
	if scene_tree == null:
		return false
	var target_pos := Juice.cell_center(player, cell)
	const REACH := 24.0
	var world := player.get_world_2d()
	for node in scene_tree.get_nodes_in_group(target_group):
		if not is_instance_valid(node) or not (node is Node2D and node.has_method("take_hit")):
			continue
		# Co-op: abaikan pohon/batu di area lain yang kebetulan dimuat.
		if (node as Node2D).get_world_2d() != world:
			continue
		var hit_pos := _hit_origin(node)
		if player.world_to_cell(hit_pos) == cell or hit_pos.distance_to(target_pos) <= REACH:
			if node is Choppable:
				var action: ActionData = player.tool_controller.action_state.action
				var tool: ToolData = action.tool_data if action != null else null
				if not node.accepts_tool(tool):
					Notify.say(node.requirement_text())
					return false
				node.take_hit(damage, int(tool.tier))
			else:
				node.take_hit(damage)
			return true
	return false


func _hit_origin(node: Node2D) -> Vector2:
	var shape := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape:
		return shape.global_position
	return node.global_position
