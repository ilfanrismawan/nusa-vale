extends Node

var failures := 0

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func settle() -> void:
	for i in 6:
		await get_tree().physics_frame

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	seed(20261015)
	GameState.new_game()
	DayCycle.current_day = 1
	DayCycle.is_running = false
	ForageManager.reset()
	# Static stock is derived from authored scenes, not assumed from old balance tables.
	var wood := 0
	var stone := 0
	var wood_energy := 0
	var stone_energy := 0
	var axe := GameState._resolve_item("axe_wood").action_data.tool_data
	var pick := GameState._resolve_item("pickaxe_wood").action_data.tool_data
	for entry in preload("res://scripts/world/farm_cleanup_spawner.gd").objects():
		var node := load(entry.scene).instantiate() as Choppable
		if node.accepts_tool(axe):
			wood += node.drop_count
			wood_energy += ceili(float(node.health) / axe.damage) * axe.stamina_cost
		elif node.accepts_tool(pick):
			stone += node.drop_count
			stone_energy += ceili(float(node.health) / pick.damage) * pick.stamina_cost
		node.free()
	check(wood >= BrokenBridge.REQUIRED_WOOD + 10, "starter wood can fund bridge and first copper order")
	check(stone >= BrokenBridge.REQUIRED_STONE + 25, "starter stone can fund bridge and furnace before upgrading")
	print("EARLY STOCK: wood=%d (%d stamina), stone=%d (%d stamina)" % [wood, wood_energy, stone, stone_energy])
	var gross := 5 * 2 * GameState._resolve_item("strawberry").sell_price + 3 * GameState._resolve_item("carrot").sell_price
	var reseed := 5 * GameState._resolve_item("seed_strawberry").buy_price + 3 * GameState._resolve_item("seed_carrot").buy_price
	var cost := int(ToolUpgradeManager.get_upgrade_data("pickaxe_wood").cost)
	check(GameState.money + gross >= cost, "starter crops can pay one copper order")
	print("EARLY CASHFLOW: initial=%d, gross=%d, copper=%d, balance_after_order=%d, reseed_8=%d" % [GameState.money, gross, cost, GameState.money + gross - cost, reseed])
	for team in [1, 2, 4]:
		print("TEAM CASHFLOW: players=%d, starter_gross=%d, one_pick_order_balance=%d, all_pick_orders_balance=%d, reseed=%d" % [team, gross * team, 100 + gross * team - cost, 100 + gross * team - cost * team, reseed * team])
	var forest := load("res://scenes/world/Forest.tscn").instantiate() as Node2D
	get_tree().root.add_child(forest)
	get_tree().current_scene = forest
	await settle()
	DayCycle.is_running = false
	var player := forest.get_node("Player/CharacterBody2D") as Player
	player.set_process(false)
	player.set_physics_process(false)
	var spawner = forest.get_node("OreSpawner")
	var items := ForageManager.get_items("forest#ore")
	check(items.values().has("copper") and items.values().has("iron_small"), "actual Forest starts with renewable copper and small iron")
	check(items.size() == 6, "starter ore fills six of ten available slots")
	var probe := preload("res://tests/starter_routes_regression.gd").new()
	var forest_routes: Dictionary = probe.accessible_counts(player)
	probe.free()
	print("FOREST STARTER ROUTES: cells=%d, copper=%d" % [forest_routes.cells, forest_routes.copper])
	check(forest_routes.copper >= 10, "reachable starter copper can build a furnace without mature tree access")
	var first := items.duplicate()
	spawner._sync(false)
	check(items == first, "same-day reentry cannot reroll or duplicate ore")
	# Mine via real nodes, collect their actual drops. Pop/chop animation waits are accelerated.
	var copper_action := GameState._resolve_item("pickaxe_copper").action_data
	var wood_action := GameState._resolve_item("pickaxe_wood").action_data
	var copper_count := 0
	for key in spawner._nodes.keys():
		var rock := spawner._nodes[key] as Choppable
		if rock.drop_item_id == "iron_ore":
			check(not rock.accepts_tool(wood_action.tool_data) and rock.accepts_tool(copper_action.tool_data), "small iron bridges Copper to Iron without requiring its own metal")
			continue
		check(rock.accepts_tool(wood_action.tool_data), "renewable copper remains available to wooden tools")
		copper_count += rock.drop_count
		rock.take_hit(rock.health, int(wood_action.tool_data.tier))
		rock._finish_chop()
	await get_tree().create_timer(0.5, true).timeout
	check(ForageManager.get_items("forest#ore").size() == 3, "harvest removes only mined ore from shared persistence")
	for pickup in forest.get_node("YSortEntities").get_children():
		if pickup is ItemPickup and pickup.item_id == "copper_ore":
			pickup._on_body_entered(player)
	check(player.data.get_item_count("copper_ore") == copper_count and copper_count >= 10, "real starter drops can fund the furnace's ten copper ore")
	# Exhausting copper while leaving iron must not fill the cap with an inaccessible metal.
	for step in 4:
		DayCycle.current_day += 1
		spawner._sync(false)
		await settle()
	check(ForageManager.get_items("forest#ore").size() <= 10 and ForageManager.get_items("forest#ore").values().has("copper"), "daily replenishment preserves copper access under the resource cap")
	probe = preload("res://tests/starter_routes_regression.gd").new()
	var replenished: Dictionary = probe.accessible_counts(player)
	var copper_tier: Dictionary = probe.accessible_counts(player, "pickaxe_copper")
	probe.free()
	print("RENEWED STARTER ROUTES: held_copper=%d, accessible_copper=%d, accessible_iron_with_copper=%d" % [player.data.get_item_count("copper_ore"), replenished.copper, copper_tier.iron])
	check(player.data.get_item_count("copper_ore") + int(replenished.copper) >= 20, "reachable renewed copper covers furnace and five bars together")
	# Harvest reachable iron and allow daily replenishment; the upgrade need not be funded in one visit.
	for visit in 3:
		for rock in copper_tier.resources:
			if rock.drop_item_id == "iron_ore":
				rock.take_hit(rock.health, int(copper_action.tool_data.tier))
				rock._finish_chop()
		await get_tree().create_timer(0.5, true).timeout
		for pickup in forest.get_node("YSortEntities").get_children():
			if pickup is ItemPickup and pickup.item_id == "iron_ore":
				pickup._on_body_entered(player)
		if player.data.get_item_count("iron_ore") >= 10:
			break
		DayCycle.current_day += 1
		spawner._sync(false)
		await settle()
		probe = preload("res://tests/starter_routes_regression.gd").new()
		copper_tier = probe.accessible_counts(player, "pickaxe_copper")
		probe.free()
	var harvested_iron := player.data.get_item_count("iron_ore")
	check(harvested_iron >= 10, "reachable small iron can fund an Iron upgrade across renewable visits")
	var saved_items := ForageManager.to_save()
	check(SaveManager.save_game() and SaveManager.load_game() and ForageManager.to_save() == saved_items, "ore positions, types and last spawn day survive save/load")
	spawner._sync(false)
	check(ForageManager.to_save() == saved_items, "reload on the same day cannot create extra ore")
	var foreign := GameState.ensure_player(1)
	check(foreign.get_item_count("copper_ore") == 0, "P1 pickup never credits P2 inventory")
	var shared := ForageManager.get_items("forest#ore").duplicate()
	GameState.use_player(foreign)
	spawner._sync(false)
	check(ForageManager.get_items("forest#ore") == shared, "changing co-op owner never rerolls the shared ore supply")
	GameState.use_player(player)
	# Downstream smelting/upgrades use controlled fixtures; this is not a timed campaign run.
	var data := player.data
	data.inventory.fill(null)
	data.add_item_silent("pickaxe_wood", 1)
	data.add_item_silent("wood", 25)
	data.add_item_silent("copper_ore", 20)
	data.add_item_silent("stone", 25)
	GameState.money = 1350
	var furnace_recipe: CraftingRecipe
	for recipe in CraftingSystem.CATALOG.recipes:
		if recipe.output_item_id == "furnace":
			furnace_recipe = recipe
	check(CraftingSystem.craft(data, furnace_recipe).ok and data.get_item_count("copper_ore") == 10, "furnace recipe leaves enough ore from a twenty-ore budget for first upgrade")
	data.remove_item("furnace", 1)
	StructureManager.records.assign([{"uid": 1, "item": "furnace", "cell": [1, 1], "storage": [], "open": false, "job": {}, "ready": {}}])
	await smelt_five(data, "copper_bar")
	check(ToolUpgradeManager.upgrade_tool("pickaxe_wood"), "first copper order consumes smelted copper, wood and cash")
	check(not data.has_item("pickaxe_wood") and not data.has_item("pickaxe_copper"), "tool remains unavailable during the two-day order")
	DayCycle.current_day += ToolUpgradeManager.WORK_DAYS
	check(ToolUpgradeManager.collect_tool(data), "copper pickaxe can be collected after two day boundaries")
	data.add_item_silent("iron_ore", harvested_iron)
	await smelt_five(data, "iron_bar")
	check(ToolUpgradeManager.upgrade_tool("pickaxe_copper"), "small iron output funds the next metal tier without a circular dependency")
	DayCycle.current_day += ToolUpgradeManager.WORK_DAYS
	check(ToolUpgradeManager.collect_tool(data) and data.has_item("pickaxe_iron") and GameState.money == 0, "Wood to Copper to Iron chain uses exact total 1350 G")
	var big := load("res://scenes/objects/RockIron.tscn").instantiate() as Choppable
	check(big.accepts_tool(GameState._resolve_item("pickaxe_iron").action_data.tool_data) and not big.accepts_tool(copper_action.tool_data), "large iron still rewards the completed iron upgrade")
	big.free()
	# Let all existing pickup/reward tweens complete, including the freed-HUD callback path.
	await get_tree().create_timer(1.0, true).timeout
	StructureManager.records.clear()
	var old_hotbar := get_tree().get_first_node_in_group("hotbar_ui")
	Juice.fly_to_hotbar(GameState._resolve_item("copper_ore").icon, player.global_position, "copper_ore")
	get_tree().current_scene = self
	forest.queue_free()
	await settle()
	await get_tree().create_timer(0.6, true).timeout
	check(not is_instance_valid(old_hotbar), "pickup feedback survives the original HUD being freed during travel")
	for voice in Juice._voices:
		voice.stop()
		voice.stream = null
	print("EARLY PROGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)

func smelt_five(data: PlayerData, id: String) -> void:
	var recipe: FurnaceRecipe
	for candidate in StructureManager.furnace_recipes():
		if candidate.output_item_id == id:
			recipe = candidate
	for i in 5:
		check(StructureManager.smelt(data, 1, recipe).ok, "furnace accepts " + id)
		DayCycle.is_running = true
		StructureManager._process(recipe.process_time)
		DayCycle.is_running = false
		check(StructureManager.collect(data, 1).ok, "furnace delivers " + id)
