extends Node

var failures := 0

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func require_tools(recipe_id: String, expected: PackedStringArray) -> void:
	var recipe := CookingManager.get_recipe(recipe_id)
	check(recipe != null, "recipe exists: " + recipe_id)
	if recipe == null:
		return
	var ids: PackedStringArray = []
	for tool in recipe.required_equipment:
		ids.append(str(tool.id))
	for id in expected:
		check(ids.has(id), "recipe requires " + id + ": " + recipe_id)

func _ready() -> void:
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	var catalog := load("res://resources/cooking/data/cooking_catalog.tres") as CookingCatalog
	var icons := 0
	for file in DirAccess.get_files_at("res://resources/cooking/icons"):
		if not file.begins_with("cookware_") or not file.ends_with(".tres"):
			continue
		var texture := load("res://resources/cooking/icons/" + file) as AtlasTexture
		check(texture != null and texture.atlas != null, "tool atlas loads: " + file)
		if texture == null or texture.atlas == null:
			continue
		var bounds := Rect2(Vector2.ZERO, texture.atlas.get_size())
		check(texture.region.has_area() and bounds.encloses(texture.region), "tool crop is inside original image: " + file)
		check(texture.atlas.resource_path == "res://assets/cooking/cookingware_set.png", "tool uses supplied artwork: " + file)
		icons += 1
	check(icons == 20, "all twenty supplied sprites have editable AtlasTexture resources")
	var sheet_equipment := 0
	for equipment in catalog.equipment:
		var texture := equipment.display_icon() as AtlasTexture
		if texture != null and texture.atlas != null and texture.atlas.resource_path == "res://assets/cooking/cookingware_set.png":
			sheet_equipment += 1
		var used := false
		for recipe in catalog.recipes.recipes:
			for required in recipe.required_equipment:
				used = used or required.id == equipment.id
		check(used, "functional equipment is required by a recipe: " + str(equipment.id))
	check(sheet_equipment == 19, "nineteen cooking tools are functional; dish rack is decoration")
	require_tools("fried_egg", PackedStringArray(["frying_pan", "cooking_stove"]))
	require_tools("grilled_catfish", PackedStringArray(["cooking_grill", "chef_knife", "cutting_board"]))
	require_tools("rice_bowl", PackedStringArray(["rice_cooker", "ceramic_bowl"]))
	require_tools("smoothie", PackedStringArray(["kitchen_blender"]))
	require_tools("mango_sticky_rice", PackedStringArray(["kitchen_steamer", "kitchen_pot", "cooking_stove"]))
	require_tools("apple_pie", PackedStringArray(["cooking_oven", "baking_tray", "ceramic_bowl", "seasoning_set"]))
	require_tools("flour", PackedStringArray(["mortar_pestle"]))
	require_tools("coffee", PackedStringArray(["kitchen_kettle", "mortar_pestle"]))
	var kitchen := load("res://scenes/world/kitchen_station.tscn").instantiate() as KitchenStation
	for equipment in catalog.equipment:
		check(kitchen.installed_equipment.has(equipment), "default kitchen includes catalog tool: " + str(equipment.id))
	kitchen.free()
	var gallery := load("res://scenes/objects/cooking/cooking_equipment_gallery.tscn").instantiate() as Node2D
	check(gallery.get_node_or_null("dish_rack") != null, "dish rack exists in editor gallery")
	check(gallery.get_node_or_null("kitchen_blender") != null, "blender exists in editor gallery")
	gallery.free()
	print("COOKINGWARE COMPLETE: icons=%d tools=%d failures=%d" % [icons, catalog.equipment.size(), failures])
	get_tree().quit(1 if failures else 0)
