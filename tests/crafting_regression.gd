extends Node

var failures := 0

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func recipe(id: String) -> CraftingRecipe:
	for entry in CraftingSystem.CATALOG.recipes:
		if entry.recipe_id == id:
			return entry
	return null

func _ready() -> void:
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	DayCycle.is_running = false
	check(CraftingSystem.CATALOG.recipes.size() == 21, "Crafting catalog contains equipment, ammunition, buildings, and four chest tiers")
	for entry in CraftingSystem.CATALOG.recipes:
		var fixture := PlayerData.new()
		for id in entry.ingredients:
			fixture.add_item_silent(id, entry.ingredients[id])
		check(CraftingSystem.craft(fixture, entry)["ok"] and fixture.get_item_count(entry.output_item_id) == entry.output_amount, "Recipe produces the expected item: " + entry.recipe_id)
		var consumed := true
		for id in entry.ingredients:
			consumed = consumed and fixture.get_item_count(id) == 0
		check(consumed, "Recipe consumes all required materials: " + entry.recipe_id)
	var sword := recipe("sword_wood")
	var arrows := recipe("arrow_wood")
	var data := PlayerData.new()
	data.inventory[0] = {"item": GameState._resolve_item("wood"), "count": 5}
	data.inventory[1] = {"item": GameState._resolve_item("wood"), "count": 3}
	var before := data.serialize_inventory()
	check(CraftingSystem.preview(data, sword)["ok"] and data.serialize_inventory() == before, "Preview does not mutate inventory")
	check(CraftingSystem.craft(data, sword)["ok"] and data.get_item_count("wood") == 0 and data.get_item_count("sword_wood") == 1, "Craft consumes split material stacks once")
	check(data.equipment["weapon"] == null, "Crafted equipment enters the bag without auto-equipping")
	before = data.serialize_inventory()
	check(not CraftingSystem.craft(data, sword)["ok"] and data.serialize_inventory() == before, "Insufficient materials cannot consume items")
	check(not CraftingSystem.craft(data, sword, 0)["ok"] and not CraftingSystem.craft(data, sword, 100)["ok"], "Invalid batch quantities are rejected")
	var full := PlayerData.new()
	for slot in full.bag_size:
		full.inventory[slot] = {"item": GameState._resolve_item("stone"), "count": 99}
	full.inventory[0] = {"item": GameState._resolve_item("wood"), "count": 9}
	before = full.serialize_inventory()
	check(not CraftingSystem.craft(full, sword)["ok"] and full.serialize_inventory() == before, "Full bag failure leaves every material unchanged")
	full.inventory[0]["count"] = 8
	check(CraftingSystem.craft(full, sword)["ok"] and full.get_item_count("sword_wood") == 1, "Space freed by consuming ingredients can hold the output")
	full.inventory[0] = {"item": GameState._resolve_item("wood"), "count": 16}
	before = full.serialize_inventory()
	check(not CraftingSystem.craft(full, sword, 2)["ok"] and full.serialize_inventory() == before, "Partial output capacity cannot consume any materials")
	var batch := PlayerData.new()
	batch.add_item_silent("wood", 4)
	batch.add_item_silent("stone", 2)
	batch.add_item_silent("arrow_wood", 94)
	check(CraftingSystem.craft(batch, arrows, 2)["ok"] and batch.get_item_count("arrow_wood") == 114, "Batch output merges and splits at max stack size")
	for slot in batch.bag_size:
		if batch.inventory[slot] != null:
			check(batch.inventory[slot]["count"] <= batch.inventory[slot]["item"].max_stack, "Every output stack respects its limit")
	var multiple := PlayerData.new()
	multiple.add_item_silent("wood", 24)
	check(CraftingSystem.craft(multiple, sword, 3)["ok"] and multiple.get_item_count("sword_wood") == 3, "Non-stackable outputs receive separate slots")
	var blocked := PlayerData.new()
	blocked.inventory[12] = {"item": GameState._resolve_item("wood"), "count": 8}
	before = blocked.serialize_inventory()
	check(not CraftingSystem.craft(blocked, sword)["ok"] and blocked.serialize_inventory() == before, "Locked bag slots cannot supply ingredients")
	var other := PlayerData.new(1)
	other.add_item_silent("wood", 8)
	before = GameState.p1().serialize_inventory()
	check(CraftingSystem.craft(other, sword)["ok"] and GameState.p1().serialize_inventory() == before, "Co-op crafting consumes only the requesting player's bag")
	var invalid := CraftingRecipe.new()
	invalid.output_item_id = "sword_wood"
	invalid.ingredients = {"wood": -1}
	check(not CraftingSystem.craft(other, invalid)["ok"], "Malformed recipes are rejected")
	var restore := PlayerData.new(1)
	restore.load_dict(other.to_dict())
	check(restore.get_item_count("sword_wood") == 1, "Crafted items use existing inventory save serialization")
	print("CRAFTING REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
