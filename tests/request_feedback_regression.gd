extends Node

var failures := 0
func check(ok: bool, label: String) -> void:
	if ok: print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	GameState.new_game()
	var rig := preload("res://scenes/player/Player.tscn").instantiate()
	add_child(rig)
	await get_tree().process_frame
	var player: Player = rig.get_node("CharacterBody2D")
	player.set_physics_process(false)
	player.set_process(false)
	DayCycle.is_running = false
	player.tool_controller.select_tool(0, false)
	var held: ItemData = player.tool_controller.current_item
	player.data.add_item_silent("carrot", 3)
	player.play_item_gesture(true, GameState._resolve_item("carrot").icon, "carrot")
	player._flush_item_gesture()
	check(player.tool_controller.current_item == held and player.data.hotbar_page == 0, "pickup preserves the selected tool and hotbar page")
	await get_tree().create_timer(1.0, true).timeout
	var bin := ShippingBin.new()
	add_child(bin)
	bin._players.append(player)
	bin.global_position = player.global_position + Player.FEET_OFFSET
	var index := -1
	for slot in player.data.bag_size:
		if player.data.inventory[slot] != null and player.data.inventory[slot].item.item_id == "carrot": index = slot
	player.data.hotbar_page = index / 8
	player.tool_controller.select_tool(index % 8, false)
	var money := GameState.money
	check(bin.deposit_selected(player) and player.data.get_item_count("carrot") == 2, "shipping consumes one selected item")
	check(GameState.money == money and int(GameState.shipping.pending[0].count) == 1, "shipping queues one item without immediate payment")
	await get_tree().create_timer(1.0, true).timeout
	var second := bin.deposit_selected(player)
	await get_tree().create_timer(1.0, true).timeout
	var third := bin.deposit_selected(player)
	await get_tree().create_timer(1.0, true).timeout
	check(second and third and not bin.deposit_selected(player), "three clicks deposit exactly three items and empty stack cannot duplicate")
	player.data.hotbar_page = 0
	player.tool_controller.select_tool(0, false)
	check(not bin.deposit_selected(player), "shipping rejects selected tools")
	var town := preload("res://scenes/world/town.tscn").instantiate()
	add_child(town)
	await get_tree().process_frame
	check(town.has_node("BalaiNadiAccess") and town.get_node("BalaiNadiAccess").target_scene.ends_with("balai_nadi/exterior.tscn"), "town provides access to the dedicated Balai Nadi courtyard")
	var hall := preload("res://scenes/world/balai_nadi/exterior.tscn").instantiate()
	add_child(hall)
	check(hall.get_node("ReturnWorld").target_scene.ends_with("town.tscn"), "Balai Nadi returns to town instead of farm")
	await get_tree().create_timer(1.0, true).timeout
	FarmManager.clear_references()
	town.queue_free()
	hall.queue_free()
	bin.queue_free()
	rig.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("REQUEST FEEDBACK COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
