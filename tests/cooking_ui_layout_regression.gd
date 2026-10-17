extends Node

var failures := 0

func check(value: bool, caption: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + caption)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	await get_tree().process_frame
	var town: Node2D = load("res://scenes/world/town.tscn").instantiate()
	get_tree().root.add_child(town)
	get_tree().current_scene = town
	await get_tree().process_frame
	var player: Player = town.get_node("Player/CharacterBody2D")
	player.set_physics_process(false)
	var menu = load("res://scenes/ui/cooking_ui.tscn").instantiate()
	menu.player = player
	var catalog := load("res://resources/cooking/data/cooking_catalog.tres") as CookingCatalog
	menu.available_equipment.assign(catalog.equipment)
	Coop.ui_parent(player).add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	var rows: GridContainer = menu.get_node("%Rows")
	check(rows.columns == 7, "reference has seven recipe columns")
	check(rows.get_child_count() == CookingManager.all_recipes().size(), "all recipes are native cards")
	check(menu.get_node("%EquipmentTabs").get_child_count() == catalog.equipment.size() + 1, "equipment tabs come from catalog")
	check(menu.get_node("%EquipmentTabs").get_child(0).get_node("Icon").texture != null, "All tab cookbook icon imports")
	check(menu.get_node("Panel/Layout/Heading/Pot").texture != null, "title pot icon imports")
	check(menu.get_node("Panel/Layout/Detail").position == Vector2(1236, 275), "detail panel matches reference coordinates")
	check(menu.get_node("Panel/Layout/Detail").size == Vector2(484, 710), "detail panel matches reference dimensions")
	var viewport_size := get_viewport().get_visible_rect().size
	var expected_scale := minf(viewport_size.x / 1920.0, viewport_size.y / 1080.0)
	check(menu.get_node("Panel").scale.is_equal_approx(Vector2.ONE * expected_scale), "design canvas fits player viewport")
	var recipe: RecipeData = CookingManager.all_recipes()[1]
	menu._select(recipe)
	check(menu.get_node("%Preview").texture == recipe.display_icon(), "selected recipe supplies preview")
	check(menu.get_node("%RecipeName").text == recipe.display_name, "selected recipe supplies title")
	check(menu.get_node("%Requirements").get_child_count() == recipe.ingredients.size() + recipe.required_equipment.size(), "ingredients and mandatory tools remain visible")
	menu._set_filter(1)
	for card in rows.get_children():
		check(catalog.equipment[0].supports(card.get_meta("recipe")), "tool filter uses resource requirements")
	menu._set_filter(0)
	menu._cycle_sort()
	check(menu._sort_mode == 1 and rows.get_child_count() == CookingManager.all_recipes().size(), "sorting preserves recipe catalog")
	menu._set_filter(menu._filters.size() - 1)
	menu._cycle_filter(1)
	check(menu._filter_index == 0, "equipment navigation wraps")
	menu._sort_mode = 0
	menu._refresh()
	menu._select(CookingManager.all_recipes()[0])
	menu.get_node("%SortButton").text = "≡↓ Default"
	menu.get_node("%EquipmentScroll").set_deferred("scroll_horizontal", 0)
	if OS.get_environment("NUSA_COOKING_SCREENSHOT") == "1" and DisplayServer.get_name() != "headless":
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var screenshot := get_viewport().get_texture().get_image()
		var destination := "res://scratch/cooking-ui-preview.png"
		check(screenshot.save_png(destination) == OK, "native cooking preview renders")
		print("COOKING UI SCREENSHOT: ", ProjectSettings.globalize_path(destination))
	menu._close()
	get_tree().current_scene = self
	town.queue_free()
	await get_tree().process_frame
	print("COOKING UI LAYOUT COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
