extends Node

const Actions = preload("res://scripts/system/cooking_debug_actions.gd")

var failures := 0

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	await get_tree().process_frame
	var config := load("res://resources/cooking/debug/cooking_debug_config.tres")
	var recipe := config.catalog.recipes.recipes[0] as RecipeData
	var data := PlayerData.new(-1)
	var second := PlayerData.new(-1)
	check(Actions.prepare_ingredients(data, recipe, 3, config).ok, "recipe ingredients can be prepared from data")
	check(Actions.prepare_ingredients(data, recipe, 3, config).ok, "preparation is repeatable without piling up ingredients")
	for id in recipe.ingredients:
		check(data.get_item_count(id) == recipe.ingredients[id] * 3, "exact batch supply: " + id)
	check(second.serialize_inventory().is_empty(), "supplies are isolated to selected player")
	check(Actions.unlock_recipe(data, recipe, config).ok and CookingManager.knows(data, recipe.id), "selected recipe unlocks")
	check(Actions.unlock_all(data, config).ok, "catalog recipes unlock without an ID list")
	var before := data.serialize_inventory()
	check(not CookingManager.cook(data, recipe.id).ok and before == data.serialize_inventory(), "cheats do not bypass equipment requirements")
	check(CookingManager.cook(data, recipe.id, config.catalog.equipment).ok, "normal cooking accepts debug supplies and installed equipment")
	var full := PlayerData.new(-1)
	var filler := GameState._resolve_item("axe_wood")
	for slot in full.bag_size:
		full.inventory[slot] = {"item": filler, "count": 1}
	before = full.serialize_inventory()
	check(not Actions.prepare_ingredients(full, recipe, 3, config).ok and full.serialize_inventory() == before, "full-bag supply request rolls back")
	check(not Actions.give_output(full, recipe, config).ok and full.serialize_inventory() == before, "full-bag output request rolls back")
	for candidate in config.catalog.recipes.recipes:
		if candidate.ingredients.size() > 1:
			full.inventory[0] = null
			before = full.serialize_inventory()
			check(not Actions.prepare_ingredients(full, candidate, 1, config).ok and full.serialize_inventory() == before, "partial ingredient transfer rolls back all additions")
			break
	check(Actions.expand_bag(full, config).ok and full.bag_size == PlayerData.BAG_SIZES.back(), "bag expansion preserves existing inventory")
	check(Actions.set_stamina(data, 25.0, config).ok and data.stamina == roundi(data.max_stamina * 0.25), "stamina target uses maximum capacity")
	var disabled := config.duplicate()
	disabled.enabled = false
	before = data.serialize_inventory()
	var money := GameState.money
	check(not Actions.prepare_ingredients(data, recipe, 1, disabled).ok and data.serialize_inventory() == before, "disabled debug cannot add supplies")
	check(not Actions.unlock_all(second, disabled).ok and second.learned_recipes.is_empty(), "disabled debug cannot unlock recipes")
	check(not Actions.grant_gold(disabled).ok and GameState.money == money, "disabled debug cannot grant money")
	var town: Node2D = load("res://scenes/world/town.tscn").instantiate()
	get_tree().root.add_child(town)
	get_tree().current_scene = town
	await get_tree().process_frame
	var player: Player = town.get_node("Player/CharacterBody2D")
	player.set_physics_process(false)
	var menu: CanvasLayer = load("res://scenes/ui/cooking_ui.tscn").instantiate()
	menu.player = player
	menu.available_equipment.assign(config.catalog.equipment)
	Coop.ui_parent(player).add_child(menu)
	var panel = menu._debug_panel
	check(menu._debug_toggle.visible and panel.is_enabled(), "debug cooking controls are available in debug builds")
	menu._debug_toggle.button_pressed = true
	check(panel.visible and not menu.get_node("Panel/Layout/Scroll").visible, "debug panel replaces recipe scroll")
	panel._equipment(&"none")
	check(menu.available_equipment.is_empty(), "debug can remove equipment for negative tests")
	panel._equipment(&"restore")
	check(menu.available_equipment.size() == config.catalog.equipment.size(), "equipment snapshot restores without editing the scene")
	panel._expand_bag()
	panel._unlock()
	panel._prepare()
	panel._cook()
	check(player.data.has_item(recipe.result_item().item_id, recipe.output_count), "UI performs real cooking")
	panel._set_stamina()
	panel._eat()
	check(not player.data.active_food_effects.is_empty(), "UI performs real eating and applies food effects")
	panel._clear_effects()
	check(player.data.active_food_effects.is_empty(), "debug clears active food effects")
	menu._close()
	get_tree().current_scene = self
	town.queue_free()
	await get_tree().process_frame
	print("COOKING DEBUG COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
