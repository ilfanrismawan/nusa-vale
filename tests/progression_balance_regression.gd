extends Node

var failures := 0
var recipes: Dictionary = {}
var cash_cost: Dictionary = {}
var visiting: Dictionary = {}

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func procurement(data: PlayerData, id: String) -> float:
	if cash_cost.has(id):
		return float(cash_cost[id])
	if visiting.has(id):
		check(false, "cooking procurement graph must be acyclic: " + id)
		return INF
	visiting[id] = true
	var item := GameState._resolve_item(id)
	var cost := INF
	if item != null and item.buy_price > 0:
		cost = SkillSystem.buy_price(data, item, 10, item.buy_price)
	if recipes.has(id):
		var recipe: RecipeData = recipes[id]
		var ingredients_cost := 0.0
		for key: String in recipe.ingredients:
			ingredients_cost += procurement(data, key) * recipe.ingredients[key]
		cost = minf(cost, ingredients_cost / recipe.output_count)
	visiting.erase(id)
	cash_cost[id] = cost
	return cost

func armor_defense(tier: String) -> int:
	var total := 0
	for piece in ["helmet", "armor", "leggings", "boots"]:
		total += GameState._resolve_item(piece + "_" + tier).defense_bonus
	return total

func _ready() -> void:
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	var data := GameState.p1()
	var seed_budget := 5 * GameState._resolve_item("seed_strawberry").buy_price + 3 * GameState._resolve_item("seed_carrot").buy_price
	var harvest_value := 10 * GameState._resolve_item("strawberry").sell_price + 3 * GameState._resolve_item("carrot").sell_price
	check(GameState.money + harvest_value - 350 - seed_budget >= 35, "first crop cycle funds copper and full replant without outside income")
	var wood_pick := load("res://resources/tool_data/pickaxe_wood.tres") as ToolData
	var copper_pick := load("res://resources/tool_data/pickaxe_copper.tres") as ToolData
	var ore := load("res://resources/cave/ores/copper_ore.tres") as CaveOre
	var old_effort := ceili(float(ore.health) / wood_pick.damage) * wood_pick.stamina_cost
	var upgraded_effort := ceili(float(ore.health) / copper_pick.damage) * copper_pick.stamina_cost
	check(upgraded_effort < old_effort, "first pickaxe upgrade reduces ore stamina per node")
	var harvest_exp: Array[int] = []
	for crop_id in ["carrot", "strawberry", "rice"]:
		var crop := load("res://resources/crop_data/%s.tres" % crop_id) as CropData
		var cell := Vector2i(harvest_exp.size(), 0)
		FarmManager.farm_data[cell] = {"state": "planted", "area": "farm", "crop": crop, "stage": crop.get_total_stages() - 1, "days_in_stage": 0, "watered": true}
		var before := data.skills.get_points(&"farmer")
		check(FarmManager.harvest(cell), "harvest fixture succeeds: " + crop_id)
		harvest_exp.append(data.skills.get_points(&"farmer") - before)
	check(harvest_exp == [9, 10, 9], "harvest EXP values total produce per plot rather than penalizing multi-yield crops")
	FarmManager.farm_data.clear()
	GameState.house._set_level(3)
	data.consumed_daya.assign(PlayerData.DAYA_IDS)
	check(data.max_stamina == 200 and GameState.ensure_player(1).max_stamina == 170, "stamina target 200 requires personal power seeds plus shared completed house")
	for recipe: RecipeData in CookingManager.all_recipes():
		check(recipe.is_valid_recipe(), "recipe remains valid: " + recipe.id)
		recipes[recipe.result_item().item_id] = recipe
	# Check both exclusive Merchant specializations, with all other available bonuses.
	for branch in ["a", "b"]:
		data.skills.reset()
		for role in SkillSystem.roles():
			data.skills.add_points(role.role_id, SkillSystem.max_points())
		data.skills.apply_levels()
		data.skills.choose(&"merchant", 5, branch)
		data.skills.choose(&"fisher", 5, "a")
		data.skills.choose(&"economist", 10, "b")
		cash_cost.clear()
		for filename in DirAccess.get_files_at("res://resources/item_data"):
			if not filename.ends_with(".tres"):
				continue
			var item := load("res://resources/item_data/" + filename) as ItemData
			if item == null or item.buy_price <= 0 or item.sell_price <= 0:
				continue
			var buy := SkillSystem.buy_price(data, item, 10, item.buy_price)
			var sell := maxi(SkillSystem.sell_price(data, item, false), SkillSystem.sell_price(data, item, true))
			check(sell < buy, "buy/resell is not profitable with Merchant " + branch + ": " + item.item_id)
		for id: String in recipes:
			var item := GameState._resolve_item(id)
			var cost := procurement(data, id)
			if is_finite(cost):
				check(SkillSystem.sell_price(data, item, true) <= cost and SkillSystem.sell_price(data, item, false) <= cost, "bought/cooked inputs cannot print money: " + id + " branch " + branch)
	data.skills.reset()
	var bands := [[3, "wood", 0], [8, "copper", 1], [15, "copper", 2], [30, "iron", 4], [50, "gold", 4], [70, "crimson", 4], [90, "shadow", 4]]
	for row in bands:
		var band := CaveManager.DATA.band_for(row[0])
		var defense := armor_defense(row[1])
		data.skills.reset()
		data.skills.add_points(&"combat", SkillSystem.points_for_level(row[2]))
		data.skills.apply_levels()
		var weapon := GameState._resolve_item("sword_" + str(row[1]))
		var attack := weapon.attack_bonus + roundi(SkillSystem.stat(data, &"attack"))
		var total := 0
		for enemy in band.enemies:
			var damage := Combat.damage_after_defense(enemy.attack, defense)
			total += damage
			var hits := ceili(float(enemy.max_hp) / Combat.damage_after_defense(attack, enemy.defense))
			check(hits >= 2 and hits <= 12, "matched weapon/role downs %s in %d basic hits" % [enemy.id, hits])
			check(damage >= 1 and damage <= 35, "matched armor gives meaningful bounded damage on floor %d: %s (%d)" % [row[0], enemy.id, damage])
		check(total >= band.enemies.size() * 2, "matched armor cannot trivialize the entire cave band")
	var bosses := [["boss_slime_king", "copper"], ["boss_iron_guardian", "iron"], ["boss_crystal_guardian", "gold"], ["boss_ember_guardian", "crimson"], ["boss_shadow_guardian", "fairy"]]
	for row in bosses:
		var boss := load("res://resources/enemies/%s.tres" % row[0]) as BossData
		var defense := armor_defense(row[1])
		var weapon := GameState._resolve_item("sword_" + str(row[1]))
		var basic_damage := Combat.damage_after_defense(weapon.attack_bonus + (10 if row[0] == "boss_slime_king" else 20), boss.defense)
		var hits := ceili(float(boss.max_hp) / basic_damage)
		check(hits >= 20 and hits <= 100, "boss durability has a bounded basic-hit budget: %s (%d)" % [row[0], hits])
		for raw in [boss.slam_damage, boss.charge_damage, boss.spit_damage, boss.rain_damage]:
			var damage := Combat.damage_after_defense(raw, defense)
			check(damage >= 10 and damage <= 60, "%s phase-one move is meaningful against %s armor" % [row[0], row[1]])
	# Representative daily work, not a claim about a manually played campaign.
	var rules := SkillSystem.RULES
	var daily := {
		"farmer": (16.0 * rules.plant_exp + 16.0 * 3.5 * rules.water_exp + 16.0 * SkillSystem.scaled_exp(60, rules.harvest_exp_per_price, rules.harvest_exp_min, rules.harvest_exp_max)) / 5.0,
		"forager": 5 * rules.forage_exp + 3 * rules.tree_exp + rules.dig_exp + 5 * rules.weed_exp,
		"fisher": 6 * (0.85 * rules.fish_exp[0] + 0.15 * rules.fish_exp[1]),
		"miner": 16 * rules.rock_exp_min + rules.geode_exp,
		"combat": 4 * (SkillSystem.scaled_exp(40, rules.kill_exp_per_hp, rules.kill_exp_min, rules.kill_exp_max) + 3 * rules.hit_exp) + rules.parry_exp,
		"merchant": 500.0 / rules.shop_gold_per_exp,
		"economist": 750.0 / rules.ship_gold_per_exp
	}
	for role: String in daily:
		var days: float = 2150.0 / float(daily[role])
		check(days >= 25 and days <= 50, "representative %s focus reaches Lv5 in %.1f active days" % [role, days])
	print("PROGRESSION BALANCE COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
