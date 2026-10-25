extends Node

## Regresi kendaraan (GDD 10): data sepeda/sapu/skuter/mobil bak, toko, resep, tampilan, tile air.
## Jalankan scene ini (F6). Hasil di Output: "VEHICLE_TEST failures=N".

const IDS := ["bicycle", "flying_broom", "electric_scooter", "pickup_truck"]
const RUN_MULTIPLIER := 3.0

var _failures := 0

func _ready() -> void:
	for id in IDS:
		var item := GameState._resolve_item(id)
		_check(item != null and item.vehicle != null, "%s punya ItemData + VehicleData" % id)
		if item == null or item.vehicle == null:
			continue
		_check(not item.stackable and item.max_stack == 1, "%s tidak bertumpuk" % id)
		_check(item.vehicle.speed_multiplier > RUN_MULTIPLIER, "%s lebih cepat dari lari" % id)
		if not item.vehicle.rider_idle_animation.is_empty():
			_check_rider_animation(id, item.vehicle)
			continue
		_check(item.vehicle.visual_scene != null, "%s punya scene tampilan" % id)
		var visual := item.vehicle.visual_scene.instantiate() as VehicleVisual
		_check(visual != null and visual.sprite != null, "%s scene memakai VehicleVisual + Sprite" % id)
		if visual != null and visual.sprite != null:
			add_child(visual)
			visual.set_facing(Vector2.UP)
			var up_frame := visual.sprite.frame
			visual.set_facing(Vector2.LEFT)
			_check(visual.sprite.frame != up_frame and visual.sprite.flip_h, "%s ganti baris per arah" % id)
			visual.queue_free()
	var bike := GameState._resolve_item("bicycle").vehicle
	var broom := GameState._resolve_item("flying_broom").vehicle
	_check(broom.speed_multiplier > bike.speed_multiplier, "sapu lebih cepat dari sepeda")
	_check(bike.speed_multiplier <= RUN_MULTIPLIER * 1.15, "sepeda hanya sedikit di atas lari (keputusan 2026-10-25)")
	_check(broom.crosses_water and not bike.crosses_water, "hanya sapu yang melintasi air")
	_check(Vehicles.is_unlocked(bike) and Vehicles.is_unlocked(broom), "sepeda dan sapu tidak terkunci")
	_check(not Vehicles.is_unlocked(GameState._resolve_item("electric_scooter").vehicle), "skuter terkunci sampai Kota Modern")
	_check(not Vehicles.is_unlocked(GameState._resolve_item("pickup_truck").vehicle), "mobil bak terkunci sampai Kota Modern")
	var store := load("res://resources/shop/general_store.tres") as ShopData
	_check(store.stock.any(func(i: ItemData) -> bool: return i != null and i.item_id == "bicycle"), "toko desa menjual sepeda")
	var alchemy := load("res://resources/crafting/alchemy.tres") as CraftingCatalog
	var recipe: CraftingRecipe
	for r in alchemy.recipes:
		if r.output_item_id == "flying_broom":
			recipe = r
	_check(recipe != null, "Meja Alkimia punya resep sapu terbang")
	if recipe != null:
		for id in recipe.ingredients:
			_check(GameState._resolve_item(id) != null, "bahan sapu ada: %s" % id)
	_check_water_tiles()
	print("VEHICLE_TEST failures=%d" % _failures)
	await get_tree().create_timer(5.0).timeout
	get_tree().quit(1 if _failures > 0 else 0)

func _check_water_tiles() -> void:
	var tiles := TileSet.new()
	var source := TileSetAtlasSource.new()
	source.texture = PlaceholderTexture2D.new()
	(source.texture as PlaceholderTexture2D).size = Vector2(16, 16)
	source.texture_region_size = Vector2i(16, 16)
	tiles.add_source(source, 0)
	source.create_tile(Vector2i.ZERO)
	var water := TileMapLayer.new()
	water.name = "Water"
	water.tile_set = tiles
	water.set_cell(Vector2i.ZERO, 0, Vector2i.ZERO)
	add_child(water)
	_check(Vehicles.is_water_tile(water, Vector2i.ZERO), "layer bernama Water dianggap air")
	var ground := TileMapLayer.new()
	ground.name = "BaseLayerGround"
	ground.tile_set = tiles
	ground.set_cell(Vector2i.ZERO, 0, Vector2i.ZERO)
	add_child(ground)
	_check(not Vehicles.is_water_tile(ground, Vector2i.ZERO), "tile tanah biasa bukan air")
	water.queue_free()
	ground.queue_free()

## Sepeda/sapu memakai animasi karakter berlayer (PNG/15. Bicycle, PNG/25. Broomstick)
## dengan layer kendaraan di belakang badan.
func _check_rider_animation(id: String, vehicle: VehicleData) -> void:
	var catalog: CharacterCatalog = CharacterVisual.CATALOG
	var appearance := catalog.sanitize(CharacterAppearance.new())
	var names: PackedStringArray = []
	for anim in [vehicle.rider_idle_animation, vehicle.rider_move_animation]:
		for suffix in ["down", "up", "right", "left"]:
			names.append("%s_%s" % [anim, suffix])
	var frames: SpriteFrames = CharacterSpriteBuilder.build(catalog, appearance, {}, names)["frames"]
	for anim_name in names:
		_check(frames.has_animation(anim_name) and frames.get_frame_count(anim_name) > 0, "%s animasi %s ada" % [id, anim_name])
	for sheet in catalog.sheets:
		if sheet == null or sheet.animation_name != vehicle.rider_move_animation:
			continue
		var layers := sheet.background_layers
		if layers.is_empty():
			layers = PackedStringArray(CharacterSpriteBuilder.DEFAULT_BACKGROUND_LAYERS.get(sheet.animation_name, []))
		_check(not layers.is_empty(), "%s punya layer kendaraan" % id)
		for relative in layers:
			_check(ResourceLoader.exists(sheet.part_folder.path_join(relative)), "%s layer %s ada" % [id, relative])

func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ok   ", label)
	else:
		_failures += 1
		push_error("  GAGAL " + label)
