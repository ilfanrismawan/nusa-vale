extends Node

var failures := 0

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _ready() -> void:
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	DayCycle.is_running = false
	GameState.new_game()
	FarmManager.farm_data.clear()
	for kind in ToolUpgradeManager.TOOL_TYPES:
		var previous: ToolData
		for tier in ToolUpgradeManager.TIERS:
			var id: String = kind + "_" + tier
			var item := GameState._resolve_item(id)
			var stats := load("res://resources/tool_data/%s.tres" % id) as ToolData
			check(item != null and item.action_data.tool_data == stats, id + " uses authoritative stats")
			for facing in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				var cells := stats.get_cells(Vector2i.ZERO, facing)
				var unique := {}
				for cell in cells:
					unique[cell] = true
				check(cells.size() == stats.area_size and unique.size() == cells.size(), id + " area unique " + str(facing))
			if previous != null:
				if stats is RodData:
					check(stats.max_cast_tiles > previous.max_cast_tiles, id + " extends cast")
				else:
					check(stats.reach_tiles > previous.reach_tiles and stats.action_speed > previous.action_speed and stats.stamina_cost <= previous.stamina_cost, id + " improves reach/speed/efficiency")
			previous = stats
	var ground := TileMapLayer.new()
	ground.name = "BaseLayerGround"
	ground.tile_set = TileSet.new()
	add_child(ground)
	var watered := TileMapLayer.new()
	watered.name = "WateredLayer"
	watered.tile_set = TileSet.new()
	watered.tile_set.add_terrain_set()
	watered.tile_set.add_terrain(0)
	add_child(watered)
	var rig := (load("res://scenes/player/Player.tscn") as PackedScene).instantiate()
	add_child(rig)
	var player := rig.get_node("CharacterBody2D") as Player
	player.set_process(false)
	player.set_physics_process(false)
	FarmManager.initialize(self)
	var action := GameState._resolve_item("watering_can_obsidian").action_data
	player.tool_controller.action_state.start(action, Vector2i.ZERO)
	player.tool_controller.action_state.enter()
	check(is_equal_approx(player.animation_controller.sprite.speed_scale, 2.2), "upgraded animation uses action speed")
	player.tool_controller.action_state.exit()
	check(is_equal_approx(player.animation_controller.sprite.speed_scale, 1.0), "movement animation speed resets after action")
	var cells := action.tool_data.get_cells(Vector2i.ZERO, player.facing_direction)
	for cell in cells:
		FarmManager.farm_data[cell] = {"state": "tilled", "crop": null, "watered": false}
	player.data.watering_water = 3
	player.data.stamina = 100
	action.effect.apply(player, Vector2i.ZERO)
	var count := 0
	for cell in cells:
		if FarmManager.farm_data[cell].watered:
			count += 1
	check(count == 3 and player.data.watering_water == 0, "partial tank waters exactly available tiles")
	check(player.data.stamina == 99, "area watering charges stamina once")
	action.effect.apply(player, Vector2i.ZERO)
	check(player.data.stamina == 99, "empty tank spends no stamina")
	player.data.watering_water = 50
	for cell in cells:
		FarmManager.farm_data[cell].watered = true
	action.effect.apply(player, Vector2i.ZERO)
	check(player.data.stamina == 98 and player.data.watering_water == 25, "pouring on wet soil charges once and uses water per tile")
	player.data.stamina = 99
	player.tool_controller.action_state.start(GameState._resolve_item("shovel_iron").action_data, Vector2i.ZERO)
	player.tool_controller.action_state.action.effect.apply(player, Vector2i.ZERO)
	check(FarmManager.farm_data.size() == 22 and player.data.stamina == 95, "shovel removes three empty plots for one stamina charge")
	var sickle := GameState._resolve_item("sickle_iron").action_data
	player.tool_controller.action_state.start(sickle, Vector2i.ZERO)
	var crop := load("res://resources/crop_data/carrot.tres") as CropData
	for cell in sickle.tool_data.get_cells(Vector2i.ZERO, player.facing_direction):
		FarmManager.farm_data[cell] = {"state": "planted", "crop": crop, "stage": crop.get_total_stages() - 1, "days_in_stage": 0, "watered": false}
	sickle.effect.apply(player, Vector2i.ZERO)
	check(player.data.stamina == 95 and not FarmManager.can_harvest(Vector2i.ZERO), "sickle harvests three mature crops without stamina cost")
	var spot := FishingSpot.new()
	spot.position = ground.map_to_local(Vector2i(10, 10))
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	spot.add_child(shape)
	add_child(spot)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var water := action.effect as WaterEffect
	check(water.try_refill(player, Vector2i(10, 10), action.tool_data) and player.data.watering_water == 350 and player.data.stamina == 94, "water source refills to tier capacity and charges stamina once")
	player.data.watering_water = 0
	player.data.stamina = 100
	player.tool_controller.action_state.start(action, Vector2i(10, 10))
	player.state_machine.change_state(player.tool_controller.action_state)
	check(player.data.watering_water == 0 and str(player.animation_controller.sprite.animation).begins_with("refill") and player.animation_controller.sprite.get_playing_speed() > 0, "refill starts a separate non-pouring dipping animation before changing water")
	player.tool_controller.action_state._perform()
	check(player.data.watering_water == 350 and player.data.stamina == 99, "refill completes at animation hit and charges once")
	player.tool_controller.action_state._perform()
	check(player.data.stamina == 99, "animation completion cannot double charge refill")
	player.state_machine.change_state(player.tool_controller.action_state.idle_state)
	spot.queue_free()
	GameState.money = 1000
	player.data.add_item_silent("copper_bar", 5)
	player.data.add_item_silent("wood", 10)
	check(ToolUpgradeManager.upgrade_tool("axe_wood") and not player.data.has_item("axe_copper") and not player.data.has_item("axe_wood") and GameState.money == 500, "upgrade holds tool and charges materials/money")
	check(not ToolUpgradeManager.upgrade_tool("hoe_wood") and GameState.money == 500, "one order per player, no repeated charges")
	check(not ToolUpgradeManager.collect_tool(player.data), "tool cannot be collected immediately")
	player.data.watering_water = 47
	check(SaveManager.save_game(), "tool state saves")
	player.data.watering_water = 0
	check(SaveManager.load_game() and player.data.watering_water == 47, "water survives solo save/load")
	check(not player.data.tool_order.is_empty() and not player.data.has_item("axe_wood"), "pending order and tool absence survive save/load")
	DayCycle.current_day += 1
	check(not ToolUpgradeManager.collect_tool(player.data), "one day is too early")
	DayCycle.current_day += 1
	for slot in player.data.bag_size:
		if player.data.inventory[slot] == null:
			player.data.inventory[slot] = {"item": GameState._resolve_item("wood"), "count": 999}
	check(not ToolUpgradeManager.collect_tool(player.data) and not player.data.tool_order.is_empty(), "full bag keeps finished tool safely at blacksmith")
	player.data.inventory[0] = null
	check(ToolUpgradeManager.collect_tool(player.data) and player.data.has_item("axe_copper") and player.data.tool_order.is_empty(), "finished order collected after two days")
	check(not ToolUpgradeManager.collect_tool(player.data), "finished tool cannot be claimed twice")
	var second := PlayerData.new(1)
	second.watering_water = 88
	second.tool_order = {"old": "hoe_wood", "next": "hoe_copper", "ready_day": DayCycle.current_day + 2}
	var restored := PlayerData.new(1)
	restored.load_dict(second.to_dict())
	check(restored.watering_water == 88 and player.data.watering_water == 47, "co-op water serializes independently")
	check(restored.tool_order == second.tool_order and player.data.tool_order.is_empty(), "co-op upgrade orders serialize independently")
	# Biarkan feedback/drop selesai sebelum menghentikan scene uji.
	await get_tree().create_timer(2.0).timeout
	FarmManager.clear_references()
	rig.queue_free()
	await get_tree().process_frame
	print("TOOL PROGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
