extends Node2D

var failures := 0

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func plot(crop: CropData = null, area: String = "farm") -> Dictionary:
	return {"state": "tilled" if crop == null else "planted", "crop": crop, "stage": 0, "days_in_stage": 0, "watered": false, "area": area}

func _ready() -> void:
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	for layer_name in ["BaseLayerGround", "SoilLayer", "WateredLayer", "Crop"]:
		var layer := TileMapLayer.new()
		layer.name = layer_name
		layer.tile_set = TileSet.new()
		layer.tile_set.add_terrain_set()
		layer.tile_set.add_terrain(0)
		add_child(layer)
	var rig := preload("res://scenes/player/Player.tscn").instantiate()
	add_child(rig)
	var player := rig.get_node("CharacterBody2D") as Player
	player.set_process(false)
	player.set_physics_process(false)
	FarmManager.initialize(self)
	FarmManager.farm_data.clear()
	var water := GameState._resolve_item("watering_can_wood").action_data
	FarmManager.farm_data[Vector2i.ZERO] = plot()
	player.data.stamina = 100
	player.data.watering_water = 20
	player.tool_controller.action_state.start(water, Vector2i.ZERO)
	player.state_machine.change_state(player.tool_controller.action_state)
	player.tool_controller.action_state._perform()
	check(player.data.stamina == 98 and player.data.watering_water == 19, "wood can charges stamina and water through the action event")
	player.tool_controller.action_state._perform()
	check(player.data.stamina == 98, "animation completion cannot double-charge pouring")
	player.state_machine.change_state(player.tool_controller.action_state.idle_state)
	water.effect.apply(player, Vector2i.ZERO)
	check(player.data.stamina == 96 and player.data.watering_water == 18, "wet soil still costs effort and water")
	player.data.stamina = 1
	water.effect.apply(player, Vector2i.ZERO)
	check(player.data.stamina == 1 and player.data.watering_water == 18, "insufficient stamina cannot pour or use water")
	player.data.stamina = 100
	water.effect.apply(player, Vector2i(500, 500))
	check(player.data.stamina == 100 and player.data.watering_water == 18, "invalid ground spends neither stamina nor water")
	for entry in [
		["small_pine_tree", "axe_wood", "axe_wood", 0],
		["pine_tree", "axe_wood", "axe_copper", 1],
		["mahogany_tree", "axe_copper", "axe_iron", 2],
		["small_rock", "pickaxe_wood", "pickaxe_wood", 0],
		["rock", "pickaxe_wood", "pickaxe_copper", 1],
		["large_rock", "pickaxe_copper", "pickaxe_iron", 2],
		["RockIron", "pickaxe_copper", "pickaxe_iron", 2],
		["RockGold", "pickaxe_iron", "pickaxe_gold", 3]
	]:
		var resource := load("res://scenes/objects/%s.tscn" % entry[0]).instantiate() as Choppable
		resource.persistent = false
		resource.health = 100
		resource.position = Vector2(160, 160)
		add_child(resource)
		var weak: ActionData = GameState._resolve_item(entry[1]).action_data
		var strong: ActionData = GameState._resolve_item(entry[2]).action_data
		var target := player.world_to_cell(FarmManager._hit_origin(resource))
		player.tool_controller.action_state.start(weak, target)
		var before := player.data.stamina
		if entry[3] > 0:
			weak.effect.apply(player, target)
			check(resource.health == 100 and player.data.stamina == before, entry[0] + " rejects weak tools without charge")
			resource.take_hit(999)
			check(resource.health == 100, entry[0] + " cannot bypass tier by damage alone")
		player.tool_controller.action_state.start(strong, target)
		strong.effect.apply(player, target)
		check(resource.health == 100 - strong.tool_data.damage and player.data.stamina == before - strong.tool_data.stamina_cost, entry[0] + " accepts required tool and charges the actor")
		resource.queue_free()
		await get_tree().process_frame
	var carrot := load("res://resources/crop_data/carrot.tres") as CropData
	FarmManager.farm_data[Vector2i.ONE] = plot(carrot)
	FarmManager.farm_data[Vector2i(2, 2)] = plot(null, "greenhouse")
	FarmManager._on_day_passed(DayCycle.current_day + 1)
	check(not FarmManager.farm_data.has(Vector2i.ZERO), "wet empty soil resets overnight")
	check(not FarmManager.farm_data.has(Vector2i(2, 2)), "empty plots reset even in an unloaded area")
	check(FarmManager.farm_data.has(Vector2i.ONE) and FarmManager.farm_data[Vector2i.ONE].crop == carrot, "unwatered planted soil survives the next day")
	var saved := SaveManager.save_game()
	FarmManager.farm_data[Vector2i.ZERO] = plot()
	check(saved and SaveManager.load_game() and not FarmManager.farm_data.has(Vector2i.ZERO), "overnight removal survives save/load")
	await get_tree().create_timer(1.0).timeout
	print("FARM RULES REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
