extends Node

var failures := 0

func check(value: bool, label: String) -> void:
	print(("PASS: " if value else "FAIL: ") + label)
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func _ready() -> void:
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	var p1 := GameState.p1()
	var p2 := GameState.ensure_player(1)
	for role in SkillSystem.roles():
		for target in range(1, 11):
			p1.skills.reset()
			var threshold := SkillSystem.points_for_level(target)
			p1.skills.add_points(role.role_id, threshold - 1)
			check(p1.skills.earned_level(role.role_id) == target - 1 and p1.skills.level(role.role_id) == 0, "%s Lv%d threshold and sleeping gate" % [role.role_id, target])
			p1.skills.add_points(role.role_id, 1)
			p1.skills.apply_levels()
			check(p1.skills.level(role.role_id) == target, "%s Lv%d activates" % [role.role_id, target])
		for branch in ["a", "b"]:
			p1.skills.reset()
			p1.skills.add_points(role.role_id, SkillSystem.max_points())
			p1.skills.apply_levels()
			for level in [5, 10]:
				var available := role.branch_available(level, branch)
				check(p1.skills.choose(role.role_id, level, branch) == available, "%s Lv%d branch %s availability" % [role.role_id, level, branch])
				check(not p1.skills.choose(role.role_id, level, branch), "branch selection cannot be repeated")
			var expected: Dictionary = {}
			for perk in role.perks:
				if perk.coming_soon:
					check(not p1.skills.is_active(role, perk), "%s deferred perk stays inactive" % perk.title)
					continue
				if not perk.branch.is_empty() and perk.branch != branch:
					continue
				for effect in perk.effects:
					expected[effect] = float(expected.get(effect, 0.0)) + float(perk.effects[effect])
			for effect in expected:
				check(is_equal_approx(p1.skills.stat(effect), expected[effect]), "%s %s effect %s" % [role.role_id, branch, effect])
			var copy := PlayerSkills.new()
			copy.load_dict(JSON.parse_string(JSON.stringify(p1.skills.to_dict())))
			for effect in expected:
				check(is_equal_approx(copy.stat(effect), expected[effect]), "%s %s effect survives JSON save" % [role.role_id, effect])
	# Exercise gameplay consumers rather than just checking summed perk dictionaries.
	p1.skills.reset()
	p1.skills.add_points(&"fisher", 15000)
	p1.skills.apply_levels()
	p1.skills.choose(&"fisher", 5, "b")
	p1.skills.choose(&"fisher", 10, "a")
	var rod := load("res://resources/tool_data/fishing_rod_wood.tres") as RodData
	var base_zone := rod.zone_mult
	var enhanced := SkillSystem.apply_rod(p1, rod)
	check(enhanced != rod and enhanced.zone_mult > base_zone and rod.zone_mult == base_zone, "fisher modifies a personal rod copy without mutating shared Resource")
	check(enhanced.max_cast_tiles == rod.max_cast_tiles + 2 and enhanced.rare_weight_mult > rod.rare_weight_mult, "fisher branch range and rare-catch effects reach the rod")
	p1.skills.reset()
	p1.skills.add_points(&"forager", 15000)
	p1.skills.apply_levels()
	p1.skills.choose(&"forager", 5, "a")
	p1.skills.choose(&"forager", 10, "a")
	var axe := load("res://resources/tool_data/axe_wood.tres") as ToolData
	check(SkillSystem.tool_damage(p1, axe, 4) == 8 and SkillSystem.tree_grow_days(7) == 4, "forager changes actual tool damage and tree growth duration")
	var trees := TreeSpawner.new()
	trees.location_id = "coverage"
	var cut_tree := StaticBody2D.new()
	cut_tree.set_script(load("res://scripts/world/choppable.gd"))
	cut_tree.set("is_destroyed", true)
	cut_tree.set_meta("tree_kind", "maple")
	var cell := Vector2i(1, 2)
	ForageManager.add_item("coverage#tree", cell, "maple|big|1")
	trees._on_tree_removed(cut_tree, cell)
	check(str(ForageManager.get_items("coverage#tree")[ForageManager.key_of(cell)]).begins_with("maple|small|"), "forest whisperer persists a replacement sapling of the felled tree kind")
	cut_tree.free()
	trees.free()
	p1.skills.reset()
	p2.skills.reset()
	p2.skills.add_points(&"economist", 15000)
	p2.skills.apply_levels()
	p2.skills.choose(&"economist", 5, "a")
	p2.skills.choose(&"economist", 10, "b")
	check(SkillSystem.stat(p1, &"ship_bonus") == 0.0 and SkillSystem.stat(p2, &"ship_bonus") > 0.0, "personal role effects do not leak across co-op")
	check(SkillSystem.shared_prosperity() and is_equal_approx(SkillSystem.stamina_mult(p1), 0.9), "active partner grants shared prosperity")
	check(SkillSystem.balai_requirement("wood", 100) == 85, "shared world perk uses active partner")
	p1.skills.load_dict(p2.skills.to_dict())
	check(SkillSystem.balai_requirement("wood", 100) == 85, "shared discounts use maximum instead of stacking")
	GameState.players.erase(p2)
	p1.skills.reset()
	check(not SkillSystem.shared_prosperity() and SkillSystem.balai_requirement("wood", 100) == 100, "offline roster does not grant active-session perks")
	check(p1.skills.add_points(&"missing_role", 100) == 0 and p1.skills.points.is_empty(), "unknown role cannot receive EXP")
	p1.skills.add_points(&"farmer", 1.0e100)
	check(p1.skills.get_points(&"farmer") == SkillSystem.max_points(), "huge EXP caps without integer overflow")
	p1.skills.reset()
	p1.skills.add_points(&"economist", 3300)
	p1.skills.apply_levels()
	var item := GameState._resolve_item("wood")
	var before := GameState.money
	GameState.shipping.deposit(item, 2, p1)
	var locked_price := int(GameState.shipping.pending[0].price)
	GameState.shipping._on_time_tick(11, 50)
	check(GameState.money == before, "courier does not settle before noon")
	GameState.shipping._on_time_tick(12, 0)
	check(GameState.money == before + locked_price * 2, "courier pays noon shipment using locked price")
	var after_noon := GameState.money
	GameState.shipping.deposit(item, 3, p1)
	GameState.shipping._on_time_tick(12, 10)
	check(GameState.money == after_noon and GameState.shipping.pending.size() == 1, "same courier slot cannot pay twice")
	var state: Dictionary = JSON.parse_string(JSON.stringify(GameState.shipping.to_save()))
	check(ShippingManager.valid_save(state), "courier save validates")
	GameState.shipping.load_save(state)
	GameState.shipping._on_time_tick(17, 0)
	check(GameState.money == after_noon + locked_price * 3, "evening pickup survives save reload")
	var after_evening := GameState.money
	GameState.shipping.settle(DayCycle.current_day + 1)
	check(GameState.money == after_evening and GameState.shipping.last_report.total == locked_price * 5, "morning report includes collected shipments without paying twice")
	state.pickup_mask = 4
	check(not ShippingManager.valid_save(state), "invalid pickup bitmask rejected")
	print("ROLE COVERAGE COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
