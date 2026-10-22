extends Node2D
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
	else:
		print("PASS: " + label)

func _ready() -> void:
	await get_tree().process_frame
	GameState.new_game()
	var cave: Node2D = load("res://scenes/world/cave/cave.tscn").instantiate()
	add_child(cave)
	await get_tree().physics_frame
	await _test_editor_overrides(cave)
	for floor_number in [21, 30, 39, 41, 61, 81]:
		cave.build_floor(floor_number)
		await get_tree().physics_frame
		check(cave.rocks_left > 0 and cave.enemies_left > 0, "floor %d has rocks and enemies" % floor_number)
	for floor_number in [20, 40, 60, 80, 100]:
		cave.build_floor(floor_number)
		await get_tree().physics_frame
		var arena: BossArena = cave.arena
		check(arena != null and cave.stairs == null, "guardian blocks floor %d" % floor_number)
		check(arena.boss.has_animation("idle"), "guardian has a valid sprite")
		arena.boss.awake = true
		arena.boss._invulnerable = 0.0
		arena.boss.move = Boss.Move.NONE
		arena.boss.take_hit(99999, null)
		await get_tree().process_frame
		check(GameState.cave.is_boss_defeated(floor_number), "guardian clear persists")
		check((cave.stairs != null) == (floor_number < 100), "stairs after guardian clear")
		var money := GameState.money
		arena._on_boss_died(arena.boss)
		check(GameState.money == money, "guardian reward cannot repeat")
	var saved := GameState.cave.to_save()
	GameState.cave.load_save(saved)
	check(GameState.cave.bosses_defeated.size() == 5, "all guardians survive save round trip")
	for id in ["cave_archer", "cave_mage"]:
		var data: EnemyData = load("res://resources/enemies/%s.tres" % id)
		var enemy := Enemy.spawn(data, self, Vector2(100, 100))
		enemy.ai_enabled = false
		check(enemy.has_animation("idle") and data.attack_style == EnemyData.AttackStyle.RANGED, "ranged enemy sprite and style")
		var shot := EnemyProjectile.launch(enemy, Vector2.RIGHT)
		check(shot.damage == data.attack and shot.direction == Vector2.RIGHT, "ranged projectile uses enemy stats")
		shot.queue_free()
		var wall := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(8, 40)
		shape.shape = rect
		wall.add_child(shape)
		add_child(wall)
		wall.position = Vector2(125, 100)
		await get_tree().physics_frame
		shot = EnemyProjectile.launch(enemy, Vector2.RIGHT)
		for i in 20:
			await get_tree().physics_frame
		check(not is_instance_valid(shot), "projectile is blocked by solid wall")
		wall.queue_free()
		enemy._attack_dir = Vector2.RIGHT
		enemy._enter(Enemy.AiState.ATTACK)
		enemy._think(0.01)
		check(enemy.ai_state == Enemy.AiState.RECOVER, "ranged attack fires then recovers")
		for child in get_children():
			if child is EnemyProjectile:
				child.queue_free()
		enemy.queue_free()
	var entrance := CaveEntrance.new()
	check(entrance.required_unlock == "cave" and not UnlockManager.is_unlocked("cave"), "new game cave is locked")
	check(not UnlockManager.try_unlock_cave(), "locked forest blocks cave access")
	UnlockManager.unlock("forest")
	check(UnlockManager.try_unlock_cave(), "forest bridge unlocks cave")
	var unlocks := UnlockManager.get_unlocks()
	UnlockManager.reset()
	UnlockManager.load_unlocks(unlocks)
	check(UnlockManager.is_unlocked("cave"), "cave access survives save round trip")
	entrance.free()
	cave.queue_free()
	await get_tree().process_frame
	print("DEEP CAVE REGRESSION COMPLETE: failures=%d" % failures)
	await get_tree().create_timer(4.0).timeout
	get_tree().quit(1 if failures else 0)


func _test_editor_overrides(cave: Node2D) -> void:
	var old_dungeons := CaveManager.DATA.band_for(5).dungeon_scenes.duplicate()
	CaveManager.DATA.band_for(5).dungeon_scenes = []
	var arrival: Marker2D = cave.get_node("Layout/Arrival")
	var original := arrival.position
	arrival.position += Vector2(16, 0)
	cave.build_floor(5)
	await get_tree().physics_frame
	check(cave.arrival_position() == cave.to_global(arrival.position), "arrival follows editor marker")
	check(not cave._free_cells().has(cave.ARRIVAL_CELL), "moved arrival is reserved from random spawn")
	var lift: Area2D = cave.get_node("FloorContent/Lift")
	check(lift.scene_file_path.ends_with("lift.tscn"), "lift uses editable prefab")
	check(lift.position == cave.get_node("Layout/Lift").position, "lift follows its editor marker")
	check(cave.get_node("FloorContent/LadderUp").scene_file_path.ends_with("ladder_up.tscn"), "ladder uses editable prefab")
	arrival.position = original
	var layout: Node2D = cave.get_node("Layout")
	layout.position = Vector2(16, 0)
	cave.build_floor(5)
	await get_tree().physics_frame
	check(cave.get_node("FloorContent/Lift").global_position == cave.get_node("Layout/Lift").global_position, "moving Layout group also moves generated lift")
	layout.position = Vector2.ZERO
	var band := CaveManager.DATA.band_for(5)
	var old_min := band.pillar_min
	var old_max := band.pillar_max
	band.pillar_min = 0
	band.pillar_max = 0
	cave.build_floor(5)
	await get_tree().physics_frame
	check(cave.get_node("PillarWalls").get_child_count() == 0, "band Inspector can disable pillars")
	band.pillar_min = old_min
	band.pillar_max = old_max
	var prefab: PackedScene = load("res://scenes/combat/enemy.tscn")
	var template: Enemy = prefab.instantiate()
	template.use_scene_collision = true
	var shape: CollisionShape2D = template.get_node("CollisionShape2D")
	(shape.shape as CircleShape2D).radius = 11.0
	var extra := Marker2D.new()
	extra.name = "EditorAttachment"
	template.add_child(extra)
	extra.owner = template
	var custom := PackedScene.new()
	check(custom.pack(template) == OK, "custom enemy prefab packs")
	template.free()
	var data := (load("res://resources/enemies/slime_green.tres") as EnemyData).duplicate() as EnemyData
	data.scene = custom
	var enemy := Enemy.spawn(data, self, Vector2(100, 100))
	enemy.ai_enabled = false
	check(enemy.has_node("EditorAttachment") and enemy.get_node("CollisionShape2D").shape.radius == 11.0, "EnemyData scene override preserves authored collision and children")
	var ordinary := Enemy.spawn(load("res://resources/enemies/slime_green.tres"), self, Vector2(160, 100))
	ordinary.ai_enabled = false
	check(ordinary.get_node("CollisionShape2D").shape.radius == ordinary.data.body_radius, "scene override cannot change other enemy collision")
	enemy.queue_free()
	ordinary.queue_free()
	await get_tree().process_frame
	CaveManager.DATA.band_for(5).dungeon_scenes.assign(old_dungeons)
