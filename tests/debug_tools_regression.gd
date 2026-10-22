extends Node

func _ready() -> void:
	var actions = load("res://development/testing_actions.gd")
	assert(actions != null)
	var data := PlayerData.new(-1)
	data.hp = 1
	data.stamina = 1
	actions.recover(data)
	assert(data.hp == data.max_hp and data.stamina == data.max_stamina)
	assert(actions.give_item(data, "wood", 5).contains("+5"))
	assert(data.get_item_count("wood") == 5)
	assert(actions.give_item(data, "missing_debug_item", 5).contains("tidak ditemukan"))
	var skill_actions = load("res://development/skill_debug_actions.gd")
	var other := PlayerData.new(-1)
	skill_actions.add_exp(data, &"farmer", 100)
	assert(data.skills.get_points(&"farmer") == 100 and data.skills.level(&"farmer") == 0)
	skill_actions.set_level(data, &"farmer", 5, true)
	assert(data.skills.level(&"farmer") == 5)
	assert(skill_actions.set_branch(data, &"farmer", 5, "a"))
	var growth := data.skills.stat(&"crop_growth")
	assert(growth > 0.0)
	assert(skill_actions.set_branch(data, &"farmer", 5, "b"))
	assert(data.skills.choice(&"farmer", 5) == "b" and data.skills.stat(&"crop_growth") == 0.0)
	assert(not skill_actions.set_branch(data, &"farmer", 10, "a"))
	skill_actions.set_level(data, &"miner", 3, true)
	skill_actions.set_level(data, &"farmer", 0, true)
	assert(data.skills.choice(&"farmer", 5).is_empty() and data.skills.level(&"miner") == 3)
	skill_actions.set_level(data, &"farmer", 5, false)
	assert(data.skills.earned_level(&"farmer") == 5 and data.skills.level(&"farmer") == 0)
	skill_actions.add_tokens(data, 10)
	assert(data.skills.tokens == 10 and data.skills.use_token(&"farmer"))
	assert(data.skills.tokens == 9)
	assert(other.skills.get_points(&"farmer") == 0 and other.skills.tokens == 0)
	var saved := data.skills.to_dict()
	skill_actions.set_level(data, &"invalid", 10, true)
	assert(data.skills.to_dict() == saved)
	var presets := ConfigFile.new()
	assert(presets.load("res://export_presets.cfg") == OK)
	for section in presets.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options"):
			var filters: String = presets.get_value(section, "exclude_filter", "")
			assert(filters.contains("development/*"))
			assert(filters.contains("scripts/system/cooking_debug_actions.gd"))
	print("DEBUG TOOLS REGRESSION COMPLETE")
	get_tree().quit()


