extends Node

const FOREST := "res://scenes/world/Forest.tscn"
var failures := 0

func check(ok: bool, label: String) -> void:
	if ok: print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func settle() -> void:
	await get_tree().create_timer(0.8, true).timeout
	DayCycle.is_running = false

func _ready() -> void:
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	get_tree().current_scene = null
	GameState.new_game()
	ForageManager.reset()
	seed(20261015)
	Coop.start([PlayerInput.DEVICE_KEYBOARD, PlayerInput.DEVICE_NUMPAD])
	await settle()
	var first: Player = Coop.root.body_of(0)
	var second: Player = Coop.root.body_of(1)
	Coop.root.move_player(second, FOREST, Vector2(741, 539))
	await settle()
	var world := second.world_root()
	var spawner = world.get_node("OreSpawner")
	var initial := ForageManager.get_items("forest#ore").duplicate()
	check(initial.size() == 6 and first.world_root() != world, "Forest creates its starter metal while P1 stays in Farm")
	Coop.root.move_player(first, FOREST, Vector2(741, 539))
	await settle()
	check(first.world_root() == world and ForageManager.get_items("forest#ore") == initial, "second entrant shares the world without doubling ore")
	var target: Choppable
	for rock in spawner._nodes.values():
		if rock.drop_item_id == "copper_ore":
			target = rock
			break
	check(target != null, "a copper source is available to P2")
	if target != null:
		var action := GameState._resolve_item("pickaxe_wood").action_data
		var cell := second.world_to_cell(FarmManager._hit_origin(target))
		second.tool_controller.action_state.start(action, cell)
		second.bind_context()
		var first_stamina := first.data.stamina
		var second_stamina := second.data.stamina
		var hits := ceili(float(target.health) / action.tool_data.damage)
		for i in hits:
			GameState.use_player(first)
			action.effect.apply(second, cell)
			target._finish_chop()
		check(target.is_destroyed and second.data.stamina == second_stamina - hits * action.tool_data.stamina_cost and first.data.stamina == first_stamina, "P2 mining charges only P2 even when global context points at P1")
		await get_tree().create_timer(0.6, true).timeout
		for pickup in world.get_node("YSortEntities").get_children():
			if pickup is ItemPickup and pickup.item_id == "copper_ore":
				pickup._on_body_entered(second)
		check(second.data.get_item_count("copper_ore") == 4 and first.data.get_item_count("copper_ore") == 0, "all mined ore belongs to the player who collects it")
		check(ForageManager.get_items("forest#ore").size() == initial.size() - 1, "mined shared node is removed exactly once")
	var remaining := ForageManager.get_items("forest#ore").duplicate()
	Coop.root.move_player(first, "res://scenes/world/farm.tscn", Vector2(320, 151))
	Coop.root.move_player(second, "res://scenes/world/farm.tscn", Vector2(340, 151))
	await settle()
	Coop.root.move_player(second, FOREST, Vector2(741, 539))
	await settle()
	check(ForageManager.get_items("forest#ore") == remaining, "unloading and reentering Forest on the same day cannot respawn ore")
	await get_tree().create_timer(0.6, true).timeout
	var old_root: Node = Coop.root
	Coop.stop()
	get_tree().current_scene = null
	old_root.queue_free()
	await get_tree().process_frame
	for voice in Juice._voices:
		voice.stop()
		voice.stream = null
	print("FOREST ORE COOP COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
