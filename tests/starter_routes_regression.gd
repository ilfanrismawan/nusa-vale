extends Node

var failures := 0

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1

func _ready() -> void:
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	seed(20261015)
	var farm := load("res://scenes/world/farm.tscn").instantiate() as Node2D
	get_tree().root.add_child(farm)
	get_tree().current_scene = farm
	for i in 6:
		await get_tree().physics_frame
	DayCycle.is_running = false
	var player := farm.get_node("Player/CharacterBody2D") as Player
	player.set_process(false)
	player.set_physics_process(false)
	var budget := accessible_counts(player)
	print("STARTER ROUTES: reachable_cells=%d, wood=%d, stone=%d" % [budget.cells, budget.wood, budget.stone])
	check(budget.wood >= BrokenBridge.REQUIRED_WOOD + 10, "reachable starter wood covers bridge and first upgrade without Copper axe")
	check(budget.stone >= BrokenBridge.REQUIRED_STONE + 25, "reachable starter stone covers bridge and furnace without Copper pickaxe")
	get_tree().current_scene = self
	farm.queue_free()
	await get_tree().process_frame
	print("STARTER ROUTES COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)

func accessible_counts(player: Player, pick_id: String = "pickaxe_wood") -> Dictionary:
	var farm := player.world_root()
	var ground := player.base_layer_ground
	var small: Array[Choppable] = []
	var excluded: Array[RID] = [player.get_rid()]
	var axe := GameState._resolve_item("axe_wood").action_data.tool_data
	var pick := GameState._resolve_item(pick_id).action_data.tool_data
	for group in [&"choppable", &"mineable"]:
		for node in player.get_tree().get_nodes_in_group(group):
			if node is Choppable and farm.is_ancestor_of(node) and (node.accepts_tool(axe) or node.accepts_tool(pick)):
				small.append(node)
				excluded.append(node.get_rid())
	# A path may clear starter-tier obstacles, but cannot pass through mature locked trees/rocks.
	var shape: Shape2D = player.get_node("CollisionShape2D").shape
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = player.collision_mask
	query.exclude = excluded
	query.collide_with_areas = false
	var start := player.world_to_cell(player.global_position + Player.FEET_OFFSET)
	var queue: Array[Vector2i] = [start]
	var visited := {start: true}
	var reachable := {start: true}
	var index := 0
	var space := player.get_world_2d().direct_space_state
	while index < queue.size():
		var cell := queue[index]
		index += 1
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var target: Vector2i = cell + direction
			if visited.has(target):
				continue
			visited[target] = true
			if not has_surface(farm, ground, target):
				continue
			query.transform = Transform2D(0, ground.to_global(ground.map_to_local(target)) - Player.FEET_OFFSET)
			if not space.intersect_shape(query, 1).is_empty():
				continue
			reachable[target] = true
			queue.append(target)
	var wood := 0
	var stone := 0
	var copper := 0
	var iron := 0
	var resources: Array[Choppable] = []
	for node in small:
		var cell := player.world_to_cell(FarmManager._hit_origin(node))
		var accessible := false
		for offset in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1)]:
			if reachable.has(cell + offset):
				accessible = true
		if accessible:
			resources.append(node)
			if node.drop_item_id == "wood": wood += node.drop_count
			if node.drop_item_id == "stone": stone += node.drop_count
			if node.drop_item_id == "copper_ore": copper += node.drop_count
			if node.drop_item_id == "iron_ore": iron += node.drop_count
	return {"cells": reachable.size(), "wood": wood, "stone": stone, "copper": copper, "iron": iron, "resources": resources}

func has_surface(world: Node, ground: TileMapLayer, cell: Vector2i) -> bool:
	if ground.get_cell_source_id(cell) >= 0:
		return true
	# Forest bridge sprites span water cells with no BaseLayerGround tile.
	var bridges := world.get_node_or_null("Bridges")
	if bridges != null:
		var center := ground.to_global(ground.map_to_local(cell))
		for bridge in bridges.get_children():
			if bridge is Sprite2D and bridge.get_rect().has_point(bridge.to_local(center)):
				return true
	return false
