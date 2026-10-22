extends Node2D
var failures := 0
func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _ready() -> void:
	await get_tree().process_frame
	GameState.new_game()
	var dungeon_pools: Array = []
	for band in CaveManager.DATA.bands:
		dungeon_pools.append(band.dungeon_scenes.duplicate())
		band.dungeon_scenes = []
	DayCycle.current_day = 3
	var cave: Node2D = load("res://scenes/world/cave/cave.tscn").instantiate()
	add_child(cave)
	await get_tree().physics_frame
	var previous_hp := 0
	for floor_number in [41, 61, 81]:
		var band := CaveManager.DATA.band_for(floor_number)
		check(band.resource_path.begins_with("res://resources/cave/bands/"), "tier has a separate Inspector resource")
		check(band.floor_scenes.size() == 2 and band.enemies.size() == 3, "tier has two layouts and three enemies")
		var hp := 0
		for data in band.enemies:
			hp += data.max_hp
			check(data.scene != null and data.drop_item_id != "" and GameState._resolve_item(data.drop_item_id) != null, "tier enemy has a prefab and valid drop")
			var prefab := data.scene.instantiate() as Enemy
			check(prefab != null and prefab.use_scene_animations and prefab.get_node("AnimatedSprite2D").sprite_frames.get_frame_count(&"idle_down") > 0, "enemy animations are saved for editing before Play")
			prefab.free()
		check(hp > previous_hp, "enemy HP progresses by tier")
		previous_hp = hp
		var weights := band.enemy_weights
		band.enemy_weights = PackedFloat32Array([1, 0, 0])
		cave.build_floor(floor_number)
		await get_tree().physics_frame
		var layout := cave.get_node("FloorContent/TierLayout") as CaveFloorLayout
		check(layout != null, "authored tier layout appears in the cave")
		var reserved := layout.occupied_cells(cave, 16)
		check(not reserved.is_empty(), "layout collider reserves spawn cells")
		for node in cave.get_node("FloorContent").get_children():
			if node is Enemy:
				node.ai_enabled = false
				check(node.data == band.enemies[0] and not reserved.has(cave.cell_of(node.home)), "Inspector weights and obstacle exclusion control enemy spawn")
			elif node is Choppable:
				check(not reserved.has(node.get_meta("cave_cell")), "rocks cannot spawn inside authored obstacles")
		band.enemy_weights = weights
		cave.build_floor(floor_number)
		var normal := _snapshot(cave)
		cave.build_floor(floor_number)
		check(normal == _snapshot(cave), "same seed reproduces layout, resources and enemies")
		var rng := RandomNumberGenerator.new()
		rng.seed = 14
		band.enemy_weights = PackedFloat32Array([0, 0, 0])
		check(band.pick_enemy(rng) == null, "all zero weights disable enemies")
		band.enemy_weights = weights
		# Move authored collider in a packed override; no generator change is needed.
		var template := band.floor_scenes[0].instantiate() as CaveFloorLayout
		check(template.get_node("CrystalOutcrop1/CollisionShape2D").shape != template.get_node("CrystalOutcrop2/CollisionShape2D").shape, "outcrop colliders can be edited independently")
		template.get_node("CrystalOutcrop1").position += Vector2(48, 0)
		var custom := PackedScene.new()
		check(custom.pack(template) == OK, "edited tier layout packs")
		template.free()
		var scenes := band.floor_scenes.duplicate()
		band.floor_scenes = [custom]
		cave.build_floor(floor_number)
		layout = cave.get_node("FloorContent/TierLayout") as CaveFloorLayout
		var shifted := layout.occupied_cells(cave, 16)
		check(shifted.has(Vector2i(11, 10)) and not shifted.has(Vector2i(8, 10)), "moving collider in editor moves reserved spawn space")
		band.floor_scenes = scenes
	for floor_number in [59, 79, 99]:
		cave.build_floor(floor_number)
		check(cave.get_node_or_null("FloorContent/TierLayout") != null and cave.enemies_left > 0, "tier content reaches floor %d" % floor_number)
	for floor_number in [60, 80, 100]:
		cave.build_floor(floor_number)
		check(cave.arena != null and cave.get_node_or_null("FloorContent/TierLayout") == null, "boss arena remains free of mine decorations")
	cave.build_floor(1)
	check(cave.get_node_or_null("FloorContent/TierLayout") == null, "tier layouts are cleared on return to earlier floor")
	# Hit flash must preserve authored palette.
	var archer := Enemy.spawn(load("res://resources/enemies/shadow_archer.tres"), self, Vector2(100, 100))
	archer.ai_enabled = false
	var tint: Color = archer.get_node("AnimatedSprite2D").modulate
	archer.take_hit(1, null)
	var waited := 0.0
	while waited < 2.0 and not archer.get_node("AnimatedSprite2D").modulate.is_equal_approx(tint):
		await get_tree().process_frame
		waited += get_process_delta_time()
	check(archer.get_node("AnimatedSprite2D").modulate.is_equal_approx(tint), "hit flash preserves prefab palette")
	archer.queue_free()
	for i in CaveManager.DATA.bands.size():
		CaveManager.DATA.bands[i].dungeon_scenes.assign(dungeon_pools[i])
	cave.queue_free()
	await get_tree().create_timer(4.0).timeout
	print("CAVE TIERS REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)

func _snapshot(cave: Node2D) -> Array:
	var result: Array = []
	for node in cave.get_node("FloorContent").get_children():
		if node is Enemy:
			node.ai_enabled = false
			result.append([str(node.data.id), node.home])
		elif node is Choppable:
			result.append([node.drop_item_id, node.position])
		elif node is CaveFloorLayout:
			result.append(node.scene_file_path)
	return result
