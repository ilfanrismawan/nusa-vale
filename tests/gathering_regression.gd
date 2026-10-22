extends Node2D

## Fase 4A-3 Gathering (GDD 7): jaring serangga 4 tier, 15 serangga, toko tukar-tambah jaring,
## umpan pancing, Bundel Serangga Balai Nadi, tapper, biji pohon, forage Kota/Gunung/Pantai, save v18.
## Tidak menulis save ke disk.

const MOUNTAIN_SCENE := "res://scenes/world/mountain.tscn"
const CAVE_SCENE := "res://scenes/world/cave/cave.tscn"
const BUG_SPAWNER := preload("res://scripts/world/bug_spawner.gd")
const PLANTED := preload("res://scripts/world/planted_tree_spawner.gd")
const SHOP_UI := preload("res://scripts/ui/shop_ui.gd")
const SEASONS := ["spring", "summer", "fall", "winter"]

var failures := 0
var _log: PackedStringArray = []
var world: Node2D
var player: Player

func check(value: bool, label: String) -> void:
	_log.append(("PASS: " if value else "FAIL: ") + label)
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	GameState.new_game()
	_test_data()
	_test_forage()
	world = (load(MOUNTAIN_SCENE) as PackedScene).instantiate()
	add_child(world)
	await _frames(4)
	player = world.get_node("Player/CharacterBody2D") as Player
	check(world.get_node_or_null("BugSpawner") != null and world.get_node_or_null("ForageSpawner") != null, "mountain.tscn has BugSpawner and ForageSpawner nodes")
	await _test_net_catch()
	_test_shop_trade_in()
	_test_bait()
	_test_balai_bundle()
	await _test_tapper()
	await _test_planted_tree()
	_test_save()
	world.queue_free()
	await _frames(2)
	await _test_cave_bugs()
	print("GATHERING REGRESSION COMPLETE: failures=%d" % failures)
	_log.append("COMPLETE: failures=%d" % failures)
	var f := FileAccess.open("res://tests/gathering_regression.log", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_log))
		f.close()
	if DisplayServer.get_name() != "headless":
		await get_tree().create_timer(20.0).timeout
	get_tree().quit(1 if failures > 0 else 0)

func _test_data() -> void:
	var bugs := BUG_SPAWNER.all_data()
	check(bugs.size() == 15, "15 bug species load (got %d)" % bugs.size())
	var icons_ok := true
	for data in bugs:
		icons_ok = icons_ok and data.item.icon != null and data.item.bait_bonus == 0.0 and data.item.sell_price > 0
	check(icons_ok, "every bug item has an icon and a sell price, and is not bait by itself")
	for season in SEASONS:
		var found := 0
		for loc in ["farm", "forest", "town", "mountain"]:
			for hour in [10, 22]:
				found += BUG_SPAWNER.candidates(loc, season, hour).size()
		check(found > 0, "overworld has bugs in %s" % season)
	check(BUG_SPAWNER.candidates("cave", "winter", 12).size() == 2, "cave has ant and cinnabar moth all year")
	check(BUG_SPAWNER.candidates("forest", "summer", 22).any(func(d): return d.item.item_id == "firefly"), "fireflies at forest summer night")
	check(not BUG_SPAWNER.candidates("forest", "summer", 12).any(func(d): return d.item.item_id == "firefly"), "no fireflies at noon")
	for tier in 4:
		var net := GameState._resolve_item(["bug_net_wood", "bug_net_copper", "bug_net_iron", "bug_net_gold"][tier])
		check(net != null and net.icon != null and net.action_data.tool_data.tool_type == ToolData.ToolType.BUG_NET and int(net.action_data.tool_data.tier) == tier, "net tier %d item is a BUG_NET tool" % tier)
	var catalog := load("res://resources/crafting/catalog.tres")
	var outputs: Array = catalog.recipes.map(func(r): return r.output_item_id)
	check(outputs.has("bug_net_wood") and outputs.has("tapper"), "wood net and tapper are craftable")
	var stock: Array = (load("res://resources/shop/general_store.tres") as ShopData).stock.map(func(i): return i.item_id)
	check(stock.has("bug_net_copper") and stock.has("bug_net_gold") and not stock.has("bug_net_wood"), "general store sells copper..gold nets, not the wood net")
	for id in ["tapper", "resin", "pine_tar", "maple_syrup", "maple_seed", "pine_cone", "birch_seed", "mahogany_seed"]:
		var item := GameState._resolve_item(id)
		check(item != null and item.icon != null, "%s has an icon" % id)

func _test_forage() -> void:
	var saved_day := DayCycle.current_day
	for i in SEASONS.size():
		DayCycle.current_day = 1 + i * DayCycle.DAYS_PER_SEASON
		for loc in ["town", "mountain", "beach"]:
			var count := ForageManager.candidates(loc).size()
			check(count >= 4, "%s forage in %s: %d" % [loc, SEASONS[i], count])
	DayCycle.current_day = saved_day

func _hold(item_id: String) -> void:
	player.data.hotbar_page = 0
	player.data.inventory[0] = {"item": GameState._resolve_item(item_id), "count": 1}
	player.tool_controller.select_tool(0, false)

func _swing_at(bug_offset: Vector2, net_id: String) -> bool:
	_hold(net_id)
	player.data.stamina = player.data.max_stamina
	player.facing_direction = Vector2.RIGHT
	var spawner = world.get_node("BugSpawner")
	var data = load("res://resources/bugs/caterpillar.tres")
	var before := player.data.get_item_count("caterpillar")
	var bug: Node2D = spawner.spawn(data, player.global_position + bug_offset)
	bug.anchor = bug.global_position
	bug.set_physics_process(false)
	var item: ItemData = player.data.inventory[0]["item"]
	player.tool_controller.use_action(item.action_data)
	await _wait_until(func() -> bool: return player.tool_controller.state_machine.current_state != player.tool_controller.action_state, 3.0)
	await _frames(2)
	var caught := player.data.get_item_count("caterpillar") > before
	if is_instance_valid(bug):
		bug.queue_free()
	return caught

func _test_net_catch() -> void:
	check(player.animation_controller.sprite.sprite_frames.has_animation(&"catch_insect_right") or player.animation_controller.sprite.sprite_frames.has_animation(&"catch_insect_down"), "player has the catch_insect swing animation")
	check(await _swing_at(Vector2(16, 3), "bug_net_wood"), "wood net catches a bug right in front")
	check(not await _swing_at(Vector2(52, 3), "bug_net_wood"), "wood net misses a bug 52 px away")
	check(await _swing_at(Vector2(52, 3), "bug_net_gold"), "gold net reaches a bug 52 px away")
	check(DiscoveryManager.discoveries.has("bug_caterpillar"), "first catch is recorded as a discovery")

func _test_shop_trade_in() -> void:
	var shop = SHOP_UI.new()
	var data := GameState.p1()  # ShopUI tanpa player = P1
	for i in data.inventory.size():
		data.inventory[i] = null
	var copper := GameState._resolve_item("bug_net_copper")
	var iron := GameState._resolve_item("bug_net_iron")
	check(shop._bag_status(copper) == "locked", "copper net is locked without a wood net")
	data.add_item("bug_net_wood")
	check(shop._bag_status(copper) == "" and shop._bag_status(iron) == "locked", "wood net unlocks copper only")
	GameState.money = 100
	shop._buy(copper, 1)
	check(not data.has_item("bug_net_copper"), "cannot buy copper net without 2000 G")
	GameState.money = 3000
	shop._buy(copper, 5)
	check(data.has_item("bug_net_copper") and not data.has_item("bug_net_wood") and GameState.money == 1000, "buying copper trades in the wood net for 2000 G")
	check(shop._bag_status(copper) == "owned" and shop._bag_status(iron) == "", "copper owned, iron now buyable")
	shop.free()

func _test_bait() -> void:
	var data := player.data
	for i in data.inventory.size():
		data.inventory[i] = null
	var catalog: CraftingCatalog = load("res://resources/crafting/catalog.tres")
	var recipes := {}
	for r in catalog.recipes:
		recipes[r.recipe_id] = r
	check(recipes.has("bait") and recipes["bait"].ingredients.has("worm"), "bait is crafted from worms")
	check(recipes.has("bug_bait") and recipes["bug_bait"].ingredients.has("cricket"), "bug bait is crafted from bugs")
	check(recipes.has("glow_bait") and recipes["glow_bait"].ingredients.has("firefly"), "glow bait is crafted from fireflies")
	var fishing = player.tool_controller.fishing_state
	data.add_item("worm", 2)
	data.add_item("caterpillar", 1)
	check(fishing._use_bait() == null and data.get_item_count("worm") == 2 and data.get_item_count("caterpillar") == 1, "raw worms and bugs are not used as bait")
	data.add_item("bug_bait", 1)
	data.add_item("bait", 1)
	var used: ItemData = fishing._use_bait()
	check(used != null and used.item_id == "bait" and data.get_item_count("bug_bait") == 1, "cheapest crafted bait is used first")
	used = fishing._use_bait()
	check(used != null and used.item_id == "bug_bait", "bug bait works")
	check(fishing._use_bait() == null, "no bait left = normal cast")
	var glow: ItemData = GameState._resolve_item("glow_bait")
	check(glow != null and glow.icon != null and int(glow.rarity) >= ItemData.Rarity.RARE, "glow bait boosts rare fish")

func _test_balai_bundle() -> void:
	var balai := GameState.balai_nadi
	var bundle: RestorationProject = balai.definition("bug_bundle")
	check(bundle != null and bundle.wing_id == "alam" and bundle.requirements.size() == 5, "Balai Nadi has a 5-bug bundle in Sayap Alam")
	for id in bundle.requirements:
		check(GameState._resolve_item(id) != null and ResourceLoader.exists("res://resources/bugs/%s.tres" % id), "bundle bug %s exists" % id)
	var donor := GameState.p1()
	for i in donor.inventory.size():
		donor.inventory[i] = null
	balai._give_rewards(donor, bundle)
	check(donor.get_item_count("tapper") == 3, "bundle reward gives 3 tappers")

func _test_tapper() -> void:
	var tree: Node2D = (load("res://scenes/objects/maple_tree.tscn") as PackedScene).instantiate()
	world.add_child(tree)
	tree.global_position = player.global_position + Vector2(24, 0)
	await _frames(3)
	var gathering := GameState.gathering
	var key: String = gathering.tree_key(tree)
	check(key.begins_with("mountain@"), "tree key names the area (%s)" % key)
	var donor := player.data
	donor.add_item("tapper", 1)
	var before := donor.get_item_count("tapper")
	check(gathering.place(tree, donor) and gathering.has_tapper(key) and donor.get_item_count("tapper") == before - 1, "tapper placed on a maple tree")
	check(tree.get_node_or_null("Tapper") != null, "tapper sprite attached to the tree")
	check(not gathering.place(tree, donor), "second tapper on the same tree is refused")
	check(not gathering.collect(key, donor), "syrup not ready on day 0")
	DayCycle.current_day += 4
	check(gathering.is_ready(key) and gathering.collect(key, donor) and donor.has_item("maple_syrup"), "maple syrup collected after 4 days")
	check(not gathering.is_ready(key), "tapper refills after collecting")
	var saved: Dictionary = gathering.to_save()
	gathering.load_save({})
	check(not gathering.has_tapper(key), "old saves load without tappers")
	gathering.load_save(saved)
	check(gathering.has_tapper(key), "tapper survives a save round trip")
	check(not gathering.valid_save({"tappers": {"x": {"kind": 5}}}), "corrupt tapper data is rejected")
	var small: Node2D = (load("res://scenes/objects/small_pine_tree.tscn") as PackedScene).instantiate()
	world.add_child(small)
	small.global_position = player.global_position + Vector2(-40, 0)
	donor.add_item("tapper", 1)
	check(not gathering.place(small, donor) and donor.has_item("tapper"), "small trees cannot be tapped")
	small.queue_free()
	gathering.on_tree_destroyed(tree)
	check(not gathering.has_tapper(key), "chopping the tree removes its tapper")
	await _frames(2)
	check(world.find_children("*", "ItemPickup", true, false).any(func(p): return p.get("item_id") == "tapper"), "the tapper drops as a pickup")
	tree.queue_free()

func _test_planted_tree() -> void:
	var spawner = PLANTED.attach_planted(world, "testfarm", NodePath("."))
	await _frames(4)
	var ground := world.get_node("BaseLayerGround") as TileMapLayer
	var origin := ground.local_to_map(ground.to_local(player.global_position))
	var cell := origin
	for r in range(2, 12):
		var found := false
		for dx in range(-r, r + 1):
			for dy in [-r, r]:
				if spawner._is_free(origin + Vector2i(dx, dy)):
					cell = origin + Vector2i(dx, dy)
					found = true
					break
			if found:
				break
		if found:
			break
	check(spawner.plant(cell, "birch"), "birch seed planted on bare ground")
	check(ForageManager.get_items("testfarm#planted").size() == 1, "planted tree stored in ForageManager")
	DayCycle.current_day += 7
	spawner._sync(false)
	await _frames(2)
	var items: Dictionary = ForageManager.get_items("testfarm#planted")
	var entry := str(items.values()[0]) if not items.is_empty() else ""
	check(entry.begins_with("birch|big|"), "planted tree is big after 7 days (%s)" % entry)
	ForageManager.areas.erase("testfarm#planted")
	spawner.queue_free()

func _test_save() -> void:
	check(SaveManager.SAVE_VERSION >= 18, "save supports gathering (v18+)")
	var data: Dictionary = SaveManager._build_save_data()
	check(data.has("gathering") and SaveManager._is_valid_save(data), "save data has a valid gathering key")

func _test_cave_bugs() -> void:
	GameState.cave.current_floor = 0
	var cave: Node2D = (load(CAVE_SCENE) as PackedScene).instantiate()
	add_child(cave)
	await _frames(4)
	check(get_tree().get_nodes_in_group(&"bug").is_empty(), "no bugs in the cave lobby")
	cave.build_floor(1)
	await _frames(6)
	var bugs := get_tree().get_nodes_in_group(&"bug")
	check(bugs.size() > 0 and bugs.all(func(b): return b.data.locations.has("cave")), "cave floor 1 has cave bugs (%d)" % bugs.size())
	cave.queue_free()

func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func _wait_until(condition: Callable, timeout: float) -> bool:
	var waited := 0.0
	while not condition.call() and waited < timeout:
		await get_tree().process_frame
		waited += get_process_delta_time()
	return condition.call()
