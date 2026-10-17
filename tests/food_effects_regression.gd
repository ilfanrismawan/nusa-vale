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
	var data := PlayerData.new(-1)
	var other := PlayerData.new(-1)
	var effect := FoodEffectData.new()
	effect.id = &"custom_effect"
	effect.display_name = "Custom"
	effect.duration_seconds = 10.0
	effect.movement_multiplier = 1.4
	effect.stamina_cost_multiplier = 0.5
	effect.stamina_per_tick = 3
	effect.tick_interval = 2.0
	data.stamina = 40
	data.apply_food_effect(effect)
	check(is_equal_approx(data.food_movement_multiplier(), 1.4), "movement reads resource magnitude")
	check(other.food_movement_multiplier() == 1.0, "effects are isolated per player")
	check(data.spend_stamina(1) and data.spend_stamina(1) and data.stamina == 39, "fractional savings work for one-stamina actions")
	data.advance_food_effects(4.0)
	check(data.stamina == 45, "regeneration catches up across long frames")
	data.apply_food_effect(effect)
	check(data.active_food_effects.size() == 1 and data.active_food_effects[0].stacks == 1, "refresh does not stack strength")
	effect.movement_multiplier = 2.0
	check(is_equal_approx(data.food_movement_multiplier(), 1.4), "active effects snapshot resource data")
	data.advance_food_effects(100.0)
	check(data.stamina == 60 and data.active_food_effects.is_empty() and data.food_movement_multiplier() == 1.0, "effects stop ticking at expiry and reset movement")
	effect.duration_seconds = 4.0
	effect.movement_multiplier = 0.8
	effect.stamina_cost_multiplier = 1.5
	effect.stamina_per_tick = -5
	effect.stacking = FoodEffectData.Stacking.STACK
	effect.max_stacks = 2
	data.apply_food_effect(effect)
	data.apply_food_effect(effect)
	data.apply_food_effect(effect)
	check(data.active_food_effects[0].stacks == 2 and is_equal_approx(data.food_movement_multiplier(), 0.64), "debuff stacking respects resource cap")
	data.stamina = 10
	data.advance_food_effects(4.0)
	check(data.stamina == 0 and data.active_food_effects.is_empty(), "negative stamina ticks clamp at zero")
	effect.stacking = FoodEffectData.Stacking.REPLACE
	data.apply_food_effect(effect)
	data.advance_food_effects(1.0)
	data.apply_food_effect(effect)
	check(data.active_food_effects[0].remaining == 4.0 and data.active_food_effects[0].elapsed == 0.0, "replace restarts duration and tick clock")
	data.load_dict(data.to_dict())
	check(data.active_food_effects.is_empty(), "temporary effects clear on loading")
	var foods := 0
	var expected_foods := 0
	for recipe in CookingManager.all_recipes():
		if recipe.result_item().category == ItemData.Category.FOOD:
			expected_foods += 1
	for file in DirAccess.get_files_at("res://resources/item_data"):
		if not file.ends_with(".tres"):
			continue
		var item := load("res://resources/item_data/" + file) as ItemData
		check(item != null, "item resource loads: " + file)
		if item == null or item.category != ItemData.Category.FOOD:
			continue
		foods += 1
		check(not item.food_effects.is_empty(), "food has resource effects: " + item.item_id)
		for configured in item.food_effects:
			check(configured != null and configured.is_valid_effect(), "food effect valid: " + item.item_id)
		check(not item.food_summary().is_empty(), "effect description formats: " + item.item_id)
	check(foods >= expected_foods and foods > 0, "all edible recipe outputs were checked")
	print("FOOD EFFECTS COMPLETE: foods=%d failures=%d" % [foods, failures])
	get_tree().quit(1 if failures else 0)
