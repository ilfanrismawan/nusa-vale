extends Node

var failures := 0

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _ready() -> void:
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	DayCycle.is_running = false
	GameState.new_game()
	FarmManager.farm_data.clear()
	var world := Node2D.new()
	add_child(world)
	# Gunakan tileset Crop asli, tanpa player/UI dan terrain tanah yang tidak diuji di sini.
	var scene := (load("res://scenes/world/farm.tscn") as PackedScene).get_state()
	for i in scene.get_node_count():
		var node_name := String(scene.get_node_name(i))
		if node_name != "Crop":
			continue
		var layer := TileMapLayer.new()
		layer.name = node_name
		for p in scene.get_node_property_count(i):
			if scene.get_node_property_name(i, p) == &"tile_set":
				layer.tile_set = scene.get_node_property_value(i, p)
		world.add_child(layer)
	var watered := TileMapLayer.new()
	watered.name = "WateredLayer"
	watered.tile_set = TileSet.new()
	world.add_child(watered)
	FarmManager.initialize(world)
	# 39 tanaman tanpa Orang-orangan Sawah: matikan gagak agar pertumbuhan diuji secara pasti.
	FarmManager.crows_enabled = false
	var files := DirAccess.get_files_at("res://resources/crop_data")
	var tested := 0
	for file in files:
		if not file.ends_with(".tres"):
			continue
		var crop := load("res://resources/crop_data/" + file) as CropData
		var cell := Vector2i(tested * 3, 0)
		tested += 1
		DayCycle.current_day = {"spring": 1, "summer": 29, "fall": 57, "winter": 85}.get(crop.season, 1)
		var seed := GameState._resolve_item("seed_" + crop.crop_id)
		var effect := seed.action_data.effect as SeedEffect
		check(effect != null and effect.crop == crop and effect.seed_item_id == seed.item_id, crop.crop_id + " seed targets correct crop")
		FarmManager.farm_data[cell] = {"state": "tilled", "crop": null, "stage": 0, "days_in_stage": 0, "watered": false}
		check(FarmManager.plant(cell, crop), crop.crop_id + " plants in its season")
		var source_id := FarmManager.crop_layer.get_cell_source_id(cell)
		var source := FarmManager.crop_layer.tile_set.get_source(source_id) as TileSetAtlasSource
		check(source != null and source.texture == crop.get_growth_texture(), crop.crop_id + " uses own growth texture")
		var frames_valid := true
		for stage in crop.get_total_stages():
			var coords := crop.get_growth_coords(stage)
			var size := crop.get_growth_frame_size()
			var image := source.texture.get_image()
			var region := Rect2i(coords * size, size)
			frames_valid = frames_valid and source.has_tile(coords) and Rect2i(Vector2i.ZERO, image.get_size()).encloses(region)
			if frames_valid:
				frames_valid = not image.get_region(region).is_invisible()
		check(frames_valid, crop.crop_id + " all growth poses exist and are visible")
		var mature := crop.get_total_stages() - 1
		for day in mature * crop.days_per_stage:
			FarmManager.farm_data[cell].watered = true
			FarmManager._on_day_passed(DayCycle.current_day + day + 1)
		check(FarmManager.farm_data[cell].stage == mature and FarmManager.crop_layer.get_cell_atlas_coords(cell) == crop.get_growth_coords(mature), crop.crop_id + " grows to its own mature pose")
		FarmManager.crop_layer.erase_cell(cell)
		FarmManager._restore_tiles()
		check(FarmManager.crop_layer.get_cell_source_id(cell) == source_id and FarmManager.crop_layer.get_cell_atlas_coords(cell) == crop.get_growth_coords(mature), crop.crop_id + " restores correct pose")
	check(tested == 39, "all 39 crop resources covered")
	check(SaveManager.save_game(), "mixed crops save")
	var saved_size := FarmManager.farm_data.size()
	FarmManager.farm_data.clear()
	check(SaveManager.load_game() and FarmManager.farm_data.size() == saved_size, "mixed crops load")
	FarmManager._restore_tiles()
	var restored := true
	for cell in FarmManager.farm_data:
		var plot: Dictionary = FarmManager.farm_data[cell]
		var crop: CropData = plot.crop
		var source := FarmManager.crop_layer.tile_set.get_source(FarmManager.crop_layer.get_cell_source_id(cell)) as TileSetAtlasSource
		restored = restored and source.texture.get_image().get_data() == crop.get_growth_texture().get_image().get_data() and FarmManager.crop_layer.get_cell_atlas_coords(cell) == crop.get_growth_coords(plot.stage)
	check(restored, "save round trip preserves each crop visual")
	FarmManager.clear_references()
	world.queue_free()
	await get_tree().process_frame
	print("CROP REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
