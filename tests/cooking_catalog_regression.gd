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
	var catalog := load("res://resources/cooking/data/cooking_catalog.tres") as CookingCatalog
	check(catalog != null, "editor cooking catalog loads")
	if catalog == null:
		get_tree().quit(1)
		return
	var ids: Dictionary = {}
	for recipe in catalog.recipes.recipes:
		check(recipe != null and recipe.is_valid_recipe(), "recipe has valid inputs and output")
		if recipe == null or not recipe.is_valid_recipe():
			continue
		check(not ids.has(recipe.id), "unique recipe ID: " + recipe.id)
		ids[recipe.id] = true
		var data := PlayerData.new(-1)
		data.bag_level = 2
		data.learned_recipes.append(recipe.id)
		for ingredient in recipe.ingredients:
			data.add_item_silent(ingredient, recipe.ingredients[ingredient])
		var expected := data.get_item_count(recipe.result_item().item_id) + recipe.output_count
		check(not recipe.required_equipment.is_empty(), "recipe declares equipment: " + recipe.id)
		var before := data.serialize_inventory()
		check(not CookingManager.cook(data, recipe.id).ok and data.serialize_inventory() == before, "ingredients alone cannot cook: " + recipe.id)
		if recipe.required_equipment.size() > 1:
			var partial: Array[CookingEquipmentData] = [recipe.required_equipment[0]]
			check(not CookingManager.cook(data, recipe.id, partial).ok and data.serialize_inventory() == before, "all required tools must be installed: " + recipe.id)
		for required in recipe.required_equipment:
			var incomplete: Array[CookingEquipmentData] = []
			for available in catalog.equipment:
				if available.id != required.id:
					incomplete.append(available)
			check(required.supports(recipe), "required tool exposes its recipe: " + str(required.id))
			check(not CookingManager.cook(data, recipe.id, incomplete).ok and data.serialize_inventory() == before, "missing individual tool blocks cooking: " + str(required.id))
		check(CookingManager.cook(data, recipe.id, catalog.equipment).ok, "recipe cooks: " + recipe.id)
		check(data.get_item_count(recipe.result_item().item_id) == expected, "exact output: " + recipe.id)
		var supported := false
		for equipment in catalog.equipment:
			supported = supported or equipment.supports(recipe)
		check(supported, "recipe has an editor-configured station: " + recipe.id)
	for equipment in catalog.equipment:
		check(equipment.item != null, "equipment has inventory data")
		var compatible := 0
		for recipe in catalog.recipes.recipes:
			if equipment.supports(recipe):
				compatible += 1
		check(compatible > 0, "equipment has recipes: " + str(equipment.id))
	for packed in catalog.object_scenes:
		var object := packed.instantiate()
		check(object != null, "equipment scene instantiates")
		if object is KitchenStation:
			check(object.get_node_or_null("Sprite2D") != null, "sprite exists before entering tree")
			check(object.get_node_or_null("CollisionShape2D") != null, "collider exists before entering tree")
		object.free()
	for item in catalog.pantry_items:
		check(item.buy_price > 0 and GameState._resolve_item(item.item_id) == item, "pantry item resolves: " + item.item_id)
	print("COOKING CATALOG COMPLETE: recipes=%d equipment=%d failures=%d" % [ids.size(), catalog.equipment.size(), failures])
	get_tree().quit(1 if failures else 0)
