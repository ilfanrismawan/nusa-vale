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
	var row_scene := load("res://scenes/ui/cooking_recipe_row.tscn") as PackedScene
	var data := PlayerData.new(-1)
	var no_equipment: Array[CookingEquipmentData] = []
	var count := 0
	for recipe in catalog.recipes.recipes:
		var texture := recipe.display_icon()
		check(texture != null and texture.get_width() > 0 and texture.get_height() > 0, "recipe has a usable image: " + recipe.id)
		var row := row_scene.instantiate()
		add_child(row)
		row.setup(recipe, data, catalog.equipment)
		check(row.recipe_icon.texture == texture and row.action_button.icon == texture, "recipe image reaches UI: " + recipe.id)
		check(row.equipment_icons.get_child_count() == recipe.required_equipment.size(), "required equipment has visual badges: " + recipe.id)
		for badge in row.equipment_icons.get_children():
			check(badge.icon.texture != null and badge.status.text == "Tersedia", "installed equipment image and status")
		row.setup(recipe, data, no_equipment)
		check(row.equipment_icons.get_child_count() == recipe.required_equipment.size(), "refresh does not duplicate equipment images")
		for badge in row.equipment_icons.get_children():
			check(badge.status.text == "Belum tersedia", "missing equipment status remains visible")
		row.free()
		count += 1
	var custom_recipe := catalog.recipes.recipes[0].duplicate() as RecipeData
	var original_icon := custom_recipe.result_item().icon
	custom_recipe.icon = GradientTexture2D.new()
	check(custom_recipe.display_icon() == custom_recipe.icon and custom_recipe.result_item().icon == original_icon, "recipe Inspector override leaves inventory art unchanged")
	custom_recipe.icon = null
	check(custom_recipe.display_icon() == original_icon, "clearing override restores output item icon")
	for equipment in catalog.equipment:
		check(equipment.display_icon() != null, "equipment has an image: " + str(equipment.id))
	var custom_equipment := catalog.equipment[0].duplicate() as CookingEquipmentData
	custom_equipment.icon = GradientTexture2D.new()
	check(custom_equipment.display_icon() == custom_equipment.icon, "equipment Inspector icon override is honored")
	await get_tree().process_frame
	print("COOKING ICONS COMPLETE: recipes=%d equipment=%d failures=%d" % [count, catalog.equipment.size(), failures])
	get_tree().quit(1 if failures else 0)
