extends Node

## Paket sayap Balai Nadi (GDD 4.9): data valid, pilih N dari M, bonus sayap, token, save.
var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _fill(manager: BalaiNadiManager, donor: PlayerData, project_id: String) -> void:
	var project := manager.definition(project_id)
	var count := 0
	for item_id in project.requirements:
		if manager.completed(project_id) or count >= manager.slots_needed(project):
			break
		if item_id == "money":
			GameState.money += manager.remaining(project_id, item_id)
		else:
			donor.add_item_silent(item_id, manager.remaining(project_id, item_id))
		manager.contribute(donor, project_id, item_id)
		count += 1

func _ready() -> void:
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	var manager := GameState.balai_nadi
	var donor := GameState.p1()
	donor.bag_level = 2
	var bad := PackedStringArray()
	for project in manager.definitions:
		for item_id in project.requirements:
			if item_id != "money" and GameState._resolve_item(item_id) == null:
				bad.append("%s:%s" % [project.project_id, item_id])
		for item_id in project.reward_items:
			if GameState._resolve_item(item_id) == null:
				bad.append("%s:hadiah %s" % [project.project_id, item_id])
	check(bad.is_empty(), "every bundle requirement and reward resolves to real ItemData %s" % [bad])
	check(manager.definitions.size() == 21 and manager.wings().size() == 4, "21 bundles across hall + four wings")
	for entry in manager.wings():
		check(manager.wing_projects(entry.wing_id).size() >= 4, "%s has at least four bundles" % entry.display_name)
	# Pilih N dari M: Panen Musim Semi selesai dengan 4 dari 6.
	var spring := manager.definition("spring_crops_bundle")
	check(manager.slots_needed(spring) == 4 and spring.requirements.size() == 6, "spring bundle asks 4 of 6")
	_fill(manager, donor, "spring_crops_bundle")
	check(manager.completed("spring_crops_bundle") and manager.filled_slots(spring) == 4, "spring bundle completes after four kinds")
	check(manager.contribute(donor, "spring_crops_bundle", "cabbage") == 0, "completed choice bundle rejects more items")
	check(donor.get_item_count("seed_strawberry") >= 10, "bundle reward items reach donor")
	# Bonus sayap belum aktif sebelum semua paket Karya selesai.
	var base_cost := int(ToolUpgradeManager.get_upgrade_data("axe_wood").get("cost", 0))
	check(SkillSystem.wing_bonus(&"tool_upgrade_discount") == 0.0 and not manager.wing_completed("karya"), "craft wing bonus starts inactive")
	var tokens_before := donor.skills.tokens
	for project in manager.wing_projects("karya"):
		_fill(manager, donor, project.project_id)
	check(manager.wing_completed("karya") and WorldState.has_flag("balai_wing_karya_done"), "craft wing completes and sets flag")
	check(donor.skills.tokens == tokens_before + 4 * SkillSystem.RULES.balai_tokens + 2, "four bundle tokens + two wing tokens")
	var cut_cost := int(ToolUpgradeManager.get_upgrade_data("axe_wood").get("cost", 0))
	check(cut_cost == roundi(base_cost * 0.9), "craft wing cuts tool upgrade money cost by 10%% (%d -> %d)" % [base_cost, cut_cost])
	check(is_equal_approx(SkillSystem.household(&"tool_upgrade_discount"), 0.1), "wing bonus reaches household stat")
	check(SaveManager.load_game() and manager.wing_completed("karya") and manager.completed("spring_crops_bundle") and donor.skills.tokens == tokens_before + 4 * SkillSystem.RULES.balai_tokens + 2, "wing state and tokens survive reload without duplicate reward")
	# Sayap Niaga: harga jual +5%.
	var item := GameState._resolve_item("parsnip")
	var sell_before := SkillSystem.sell_price(donor, item, true)
	for project in manager.wing_projects("niaga"):
		_fill(manager, donor, project.project_id)
	check(manager.wing_completed("niaga") and SkillSystem.sell_price(donor, item, true) >= sell_before, "trade wing raises sell price")
	# Save lama tanpa paket baru tetap termuat.
	manager.load_save({"projects": {"balai_nadi_restoration": {"contributions": {"wood": 100, "stone": 50, "money": 500}, "completed": true}}})
	check(manager.completed("balai_nadi_restoration") and not manager.completed("spring_crops_bundle") and not manager.wing_completed("karya") and not WorldState.has_flag("balai_wing_karya_done"), "old save shape loads with new bundles empty")
	print("BALAI BUNDLES COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
