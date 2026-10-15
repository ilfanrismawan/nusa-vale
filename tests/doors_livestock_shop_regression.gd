extends Node
var failures := 0

func check(ok: bool, message: String) -> void:
	if ok: print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func wait_transition() -> void:
	await get_tree().create_timer(1.5, true).timeout

func right_click(player: Player) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	player._input(event)

func door_for(script_name: String) -> Area2D:
	for candidate in get_tree().get_nodes_in_group("scene_door"):
		if candidate.get_script().resource_path.ends_with(script_name):
			return candidate
	return null

func stand_at_door(player: Player, door: Area2D) -> void:
	var shape := door.get_node_or_null("CollisionShape2D") as Node2D
	player.global_position = (shape.global_position if shape != null else door.global_position) - Player.FEET_OFFSET
	player.facing_direction = Vector2.UP
	await get_tree().physics_frame
	await get_tree().physics_frame

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	GameState.money = 20000
	var farm: Node2D = (load("res://scenes/world/farm.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(farm)
	get_tree().current_scene = farm
	await wait_transition()
	var player: Player = farm.get_node("Player/CharacterBody2D")
	var entrance := door_for("enter_door_house.gd")
	check(entrance != null, "house entrance registers as an interaction door")
	if entrance == null:
		get_tree().quit(1)
		return
	await stand_at_door(player, entrance)
	check(get_tree().current_scene == farm, "walking over house entrance no longer enters automatically")
	right_click(player)
	await wait_transition()
	var house := get_tree().current_scene
	check(house.scene_file_path.ends_with("interior_house.tscn"), "right mouse click enters house")
	player = house.find_child("CharacterBody2D", true, false) as Player
	var exit := door_for("exit_door_house.gd")
	await stand_at_door(player, exit)
	await wait_transition()
	farm = get_tree().current_scene as Node2D
	check(farm.scene_file_path.ends_with("farm.tscn"), "walking onto house exit automatically returns to farm")
	player = farm.get_node("Player/CharacterBody2D")
	var barn := {"uid": 10, "item": "barn", "cell": [44, 18], "storage": [], "open": false, "job": {}, "ready": {}}
	var coop := {"uid": 11, "item": "chicken_coop", "cell": [56, 18], "storage": [], "open": false, "job": {}, "ready": {}}
	StructureManager.records.assign([barn, coop])
	StructureManager._next_uid = 12
	StructureManager._sync_all()
	var dealer: VillageNPC = (load("res://scenes/npc/RianNPC.tscn") as PackedScene).instantiate()
	farm.add_child(dealer)
	dealer.interact(player)
	await get_tree().process_frame
	var shop = dealer._shops.get(player.data.index)
	check(is_instance_valid(shop), "Rian opens a dedicated livestock shop")
	shop._select("cow")
	shop._animal_name = "Sari"
	var before := GameState.money
	shop._buy()
	var animals := StructureManager.coop_state(barn)
	check(animals.chickens.size() == 1 and animals.chickens[0].name == "Sari" and GameState.money == before - 2500, "shop charges exact cow price and delivers to selected barn")
	shop._select("chicken")
	shop._variant = "brown"
	shop._buy()
	check(StructureManager.coop_state(coop).chickens[0].variant == "brown", "shop delivers selected chicken variant to coop")
	while animals.chickens.size() < 4:
		StructureManager.buy_animal(10, "cow")
	shop._select("cow")
	before = GameState.money
	shop._buy()
	check(GameState.money == before and animals.chickens.size() == 4, "full barn cannot charge for another shop purchase")
	shop._close()
	await get_tree().process_frame
	player.global_position = player.base_layer_ground.to_global(player.base_layer_ground.map_to_local(Vector2i(47, 22))) - Player.FEET_OFFSET
	player.facing_direction = Vector2.UP
	right_click(player)
	await wait_transition()
	var interior := get_tree().current_scene
	check(interior.scene_file_path.ends_with("barn_interior.tscn") and interior.ranch_uid == 10, "right click directly enters constructed barn instead of purchase menu")
	player = interior.get_node("Player/CharacterBody2D")
	StructureManager.open_ranch_menu(player, 10)
	await get_tree().process_frame
	var care = StructureManager._menus.get(player.data.index)
	check(care._content.find_child("BuyChicken", true, false) == null, "interior care menu has no animal purchase button")
	care._close()
	await get_tree().create_timer(1, true).timeout
	print("DOORS LIVESTOCK SHOP REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
