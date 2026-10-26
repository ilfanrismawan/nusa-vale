extends Node2D

## Crafting lanjutan (GDD 4.13): resep senjata/armor/panah semua tier, peti Fairy/Obsidian,
## dekorasi, sarang lebah, penggergajian, meja alkimia, landasan perhiasan, slot kalung/cincin/aksesori, save v20.
## Tidak menulis save ke disk.

const CATALOGS := ["res://resources/crafting/catalog.tres", "res://resources/crafting/alchemy.tres", "res://resources/crafting/anvil.tres"]
const NEW_ITEMS := ["fairy_chest", "obsidian_chest", "scarecrow", "street_lamp", "bonfire", "candle", "stacked_barrels", "beehive", "sawmill", "alchemy_table", "anvil", "plank", "rope", "leather", "lure", "potion_health", "potion_stamina", "potion_speed", "potion_regen", "ring_wood", "ring_obsidian", "amulet_wood", "amulet_obsidian", "gloves_leather", "gloves_iron", "gloves_gold", "quiver", "garden_well", "water_fountain", "twin_lamp", "hanging_lantern", "xmas_tree", "dog_house", "picnic_blanket", "ring_prismatic", "amulet_prismatic", "potion_greater"]

var failures := 0
var _log: PackedStringArray = []

func check(value: bool, label: String) -> void:
	_log.append(("PASS: " if value else "FAIL: ") + label)
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	GameState.new_game()
	StructureManager.reset()
	_test_catalogs()
	_test_items()
	_test_equipment()
	_test_beehive()
	_test_sawmill()
	_test_station()
	_test_save()
	StructureManager.reset()
	print("CRAFTING EXPANSION REGRESSION COMPLETE: failures=%d" % failures)
	_log.append("COMPLETE: failures=%d" % failures)
	var f := FileAccess.open("res://tests/crafting_expansion_regression.log", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_log))
		f.close()
	await get_tree().create_timer(2.0).timeout
	get_tree().quit(1 if failures > 0 else 0)

func _exists(id: String) -> bool:
	return ResourceLoader.exists("res://resources/item_data/%s.tres" % id)

func _test_catalogs() -> void:
	for path in CATALOGS:
		var catalog := load(path) as CraftingCatalog
		check(catalog != null and not catalog.recipes.is_empty(), "%s loads" % path)
		if catalog == null:
			continue
		var missing: PackedStringArray = []
		var ids := {}
		for recipe in catalog.recipes:
			if ids.has(recipe.recipe_id):
				missing.append("duplicate " + recipe.recipe_id)
			ids[recipe.recipe_id] = true
			if not _exists(recipe.output_item_id):
				missing.append(recipe.output_item_id)
			for id in recipe.ingredients:
				if not _exists(id):
					missing.append(id)
		check(missing.is_empty(), "%s: every output/ingredient exists %s" % [path.get_file(), missing])
	var main := load(CATALOGS[0]) as CraftingCatalog
	check(main.recipes.size() >= 147, "main catalog has the new recipes (%d)" % main.recipes.size())
	for id in ["sword_obsidian", "bow_fairy", "staff_crimson", "armor_gold", "arrow_obsidian", "obsidian_chest", "scarecrow", "beehive", "garden_well", "dog_house", "picnic_blanket", "twin_lamp"]:
		check(main.recipes.any(func(r): return r.output_item_id == id), "recipe makes %s" % id)

func _test_items() -> void:
	for id in NEW_ITEMS:
		var item := GameState._resolve_item(id)
		check(item != null and item.icon != null and not item.display_name.is_empty(), "item %s resolves with icon" % id)
	check("obsidian_chest" in StructureManager.CHESTS, "obsidian chest is a chest")
	check(StructureManager.IDS.has("water_fountain") and StructureManager.DECOR.has("hanging_lantern"), "batch 5 decor is placeable")
	check(StructureManager.IDS.has("street_lamp") and StructureManager.DECOR.has("street_lamp"), "street lamp is placeable decor")
	check(StructureManager.sawmill_recipes().size() >= 1, "sawmill recipe loads")

func _test_equipment() -> void:
	var data: PlayerData = GameState.current
	check(PlayerData.equipment_key(GameState._resolve_item("ring_iron")) == "ring", "ring goes to ring slot")
	check(PlayerData.equipment_key(GameState._resolve_item("amulet_gold")) == "necklace", "amulet goes to necklace slot")
	check(PlayerData.equipment_key(GameState._resolve_item("quiver")) == "accessory", "quiver goes to accessory slot")
	var before := data.equipment_stats()
	data.add_item(GameState._resolve_item("ring_obsidian"), 1)
	data.add_item(GameState._resolve_item("amulet_obsidian"), 1)
	for slot in data.bag_size:
		var entry: Variant = data.inventory[slot]
		if entry != null and str(entry["item"].item_id) in ["ring_obsidian", "amulet_obsidian"]:
			data.equip_from_slot(slot)
	var after := data.equipment_stats()
	check(after.x - before.x == 18 and after.y - before.y == 11, "ring/amulet add ATK 18, DEF 11 (%s)" % [after - before])
	var saved := data.serialize_equipment()
	data.load_equipment(saved)
	check(data.equipment["ring"] != null and data.equipment["necklace"] != null, "new slots survive save/load")
	data.load_equipment({"armor": "", "helmet": ""})
	check(data.equipment.has("accessory") and data.equipment["accessory"] == null, "old save gets empty new slots")

func _record(item: String) -> Dictionary:
	var record := {"uid": 9000 + StructureManager.records.size(), "item": item, "cell": [-50 - StructureManager.records.size() * 4, -50], "storage": [], "open": false, "job": {}, "ready": {}}
	StructureManager.records.append(record)
	return record

func _test_beehive() -> void:
	var data: PlayerData = GameState.current
	var hive := _record("beehive")
	var day := DayCycle.current_day
	StructureManager._advance_beehives(day)
	check(int(hive.job.get("day", -1)) == day + StructureManager.BEEHIVE_DAYS, "beehive starts its 3-day timer")
	if DayCycle.get_current_season() != "winter":
		StructureManager._advance_beehives(day + StructureManager.BEEHIVE_DAYS)
		check(hive.ready.get("id") == "honey" and hive.ready.get("extra", {}).get("id") == "beeswax", "beehive makes honey + beeswax")
		var honey_before := data.has_item("honey", 1)
		StructureManager.collect(data, hive.uid)
		check(hive.ready.is_empty() and data.has_item("beeswax", 1), "collect gives beeswax and restarts")
		check(hive.job.has("day"), "beehive timer restarts after collect (%s)" % hive.job)
		check(data.has_item("honey", 1) or honey_before, "collect gives honey")

func _test_sawmill() -> void:
	var data: PlayerData = GameState.current
	var mill := _record("sawmill")
	var recipe: FurnaceRecipe = StructureManager.sawmill_recipes()[0]
	# Tas awal + barang tes sebelumnya bisa penuh; mulai dari tas kosong.
	data.load_inventory([])
	data.add_item(GameState._resolve_item("wood"), recipe.input_amount)
	check(StructureManager.saw(data, mill.uid, recipe).ok, "sawmill accepts wood")
	var was_running := DayCycle.is_running
	DayCycle.is_running = true
	StructureManager._process(recipe.process_time + 1.0)
	DayCycle.is_running = was_running
	check(mill.ready.get("id") == "plank", "sawmill finishes plank (%s)" % mill.ready)
	StructureManager.collect(data, mill.uid)
	check(data.has_item("plank", 1), "plank collected")

func _test_station() -> void:
	var data: PlayerData = GameState.current
	var alchemy := StructureManager.station_catalog("alchemy_table")
	var anvil := StructureManager.station_catalog("anvil")
	var potions := alchemy.recipes.filter(func(r): return str(r.output_item_id).begins_with("potion_")) if alchemy != null else []
	check(potions.size() == 5, "alchemy table has 5 potions")
	data.load_inventory([])
	check(anvil != null and anvil.recipes.size() == 22, "anvil has 22 jewelry recipes")
	var recipe: CraftingRecipe = alchemy.recipes[0]
	for id in recipe.ingredients:
		data.add_item(GameState._resolve_item(id), int(recipe.ingredients[id]))
	var result := CraftingSystem.craft(data, recipe)
	check(result.ok and data.has_item(recipe.output_item_id, 1), "craft %s at alchemy table" % recipe.output_item_id)

func _test_save() -> void:
	check(SaveManager.SAVE_VERSION >= 20, "SAVE_VERSION bumped (%d)" % SaveManager.SAVE_VERSION)
	var saved := StructureManager.to_save()
	StructureManager.load_save(saved)
	var kinds := StructureManager.records.map(func(r): return r.item)
	check("beehive" in kinds and "sawmill" in kinds, "beehive and sawmill records survive load_save (%s)" % [kinds])
