extends Node2D

## GDD 8.2-B: node Behavior Tree, kerucut pandang + cahaya + garis pandang, pendengaran,
## status waspada, token serang bergiliran, mengepung, feint, mundur + panggil bantuan.
## Tidak menulis save ke disk.

const BT := preload("res://scripts/ai/behavior_tree.gd")

var failures := 0

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _process(_delta: float) -> void:
	if get_tree().paused:
		get_tree().paused = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DayCycle.is_running = false
	DayCycle.hour = 12
	await get_tree().process_frame
	_test_tree_nodes()
	GameState.new_game()
	DayCycle.hour = 12
	var rig := (load("res://scenes/player/Player.tscn") as PackedScene).instantiate()
	add_child(rig)
	var player := rig.get_node("CharacterBody2D") as Player
	await get_tree().process_frame
	player.global_position = Vector2(400, 300)
	player.update_facing_direction(Vector2.RIGHT, true)
	player.data.max_hp = 9999
	player.data.hp = 9999
	await get_tree().create_timer(0.5).timeout
	await _test_vision(player)
	await _test_light()
	await _test_hearing(player)
	await _test_memory(player)
	await _test_tickets(player)
	await _test_feint(player)
	await _test_retreat(player)
	await _test_hit_from_behind(player)
	rig.queue_free()
	print("AI REGRESSION COMPLETE: failures=%d" % failures)
	await get_tree().create_timer(30.0).timeout
	get_tree().quit(1 if failures > 0 else 0)

func _wait_until(condition: Callable, timeout: float) -> bool:
	var waited := 0.0
	while not condition.call() and waited < timeout:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	return condition.call()

func _feet(player: Player) -> Vector2:
	return player.global_position + Player.FEET_OFFSET

## Musuh uji: tidak melukai lewat sentuhan, tanpa feint/mundur kecuali tes memintanya.
func _spawn(id: String, player: Player, offset: Vector2, face: Vector2, parent: Node = null) -> Enemy:
	var data: EnemyData = (load("res://resources/enemies/%s.tres" % id) as EnemyData).duplicate()
	data.contact_damage = false
	data.feint_chance = 0.0
	data.retreat_hp_ratio = 0.0
	data.patrol_radius = 0.0
	data.idle_time_min = 30.0
	data.idle_time_max = 30.0
	var enemy := Enemy.spawn(data, parent if parent != null else self, _feet(player) + offset)
	enemy._face(face)
	enemy._look_timer = 30.0
	return enemy

func _clear_enemies() -> void:
	for node in get_tree().get_nodes_in_group(&"enemies"):
		node.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	AttackTickets.clear()

#region Behavior Tree

func _test_tree_nodes() -> void:
	var bb := BT.Blackboard.new()
	bb.delta = 0.1
	var trace: Array = []
	var ok := func(tag: String) -> BT.Action:
		return BT.Action.new(func(_b):
			trace.append(tag)
			return BT.SUCCESS)
	var fail := BT.Condition.new(func(_b): return false)
	var selector := BT.Selector.new([fail, ok.call("a"), ok.call("b")])
	check(selector.tick(bb) == BT.SUCCESS and trace == ["a"], "Selector: first child that does not fail wins")

	trace.clear()
	var gate := [true]
	var running := BT.Action.new(func(_b):
		trace.append("run")
		return BT.RUNNING)
	var sequence := BT.Sequence.new([BT.Condition.new(func(_b): return gate[0]), ok.call("once"), running])
	sequence.tick(bb)
	sequence.tick(bb)
	check(trace == ["once", "run", "run"], "Sequence: finished actions are not repeated while running")
	gate[0] = false
	check(sequence.tick(bb) == BT.FAILURE, "Sequence: conditions are re-checked and abort a running sequence")

	var parallel := BT.Parallel.new([ok.call("p1"), BT.Action.new(func(_b): return BT.RUNNING)], 2)
	check(parallel.tick(bb) == BT.RUNNING, "Parallel: waits for enough children to succeed")
	var parallel_fail := BT.Parallel.new([fail, BT.Action.new(func(_b): return BT.RUNNING)], 2)
	check(parallel_fail.tick(bb) == BT.FAILURE, "Parallel: fails once success is impossible")

	check(BT.Inverter.new(fail).tick(bb) == BT.SUCCESS, "Inverter flips the result")

	trace.clear()
	var repeater := BT.Repeater.new(ok.call("r"), 3)
	var results := [repeater.tick(bb), repeater.tick(bb), repeater.tick(bb)]
	check(results == [BT.RUNNING, BT.RUNNING, BT.SUCCESS] and trace.size() == 3, "Repeater runs the child 3 times")

	trace.clear()
	var cooldown := BT.Cooldown.new(ok.call("c"), 1.0)
	bb.time = 0.0
	var first := cooldown.tick(bb)
	bb.time = 0.5
	var blocked := cooldown.tick(bb)
	bb.time = 1.2
	var again := cooldown.tick(bb)
	check(first == BT.SUCCESS and blocked == BT.FAILURE and again == BT.SUCCESS and trace.size() == 2, "Cooldown blocks the child for its duration")

	var limit := BT.Limit.new(ok.call("l"), 1)
	check(limit.tick(bb) == BT.SUCCESS and limit.tick(bb) == BT.FAILURE, "Limit lets the child finish only once")

	var wait := BT.Wait.new(0.25)
	check(wait.tick(bb) == BT.RUNNING and wait.tick(bb) == BT.RUNNING and wait.tick(bb) == BT.SUCCESS, "Wait succeeds after its time")

	var reset_calls := [0]
	var interrupted := BT.Action.new(func(_b): return BT.RUNNING, func():
		reset_calls[0] += 1)
	var flag := [false]
	var priority := BT.Selector.new([BT.Condition.new(func(_b): return flag[0]), interrupted])
	priority.tick(bb)
	flag[0] = true
	priority.tick(bb)
	check(reset_calls[0] == 1, "Selector interrupts a running lower branch when a higher one succeeds")


#endregion

#region Persepsi

func _test_vision(player: Player) -> void:
	var away := _spawn("slime_green", player, Vector2(50, 0), Vector2.RIGHT)
	var facing := _spawn("slime_green", player, Vector2(-50, 0), Vector2.RIGHT)
	check(away.brain != null and away.brain.root is BT.Selector and away.brain.root.children.size() == 5, "enemy brain: retreat, combat, investigate, return, patrol")
	await get_tree().create_timer(0.4).timeout
	check(away.target == null, "an enemy looking away does not see the player (vision cone)")
	check(facing.target == player and facing.alert == Enemy.Alert.AGGRO, "an enemy looking at the player spots it (Aggro)")
	await _clear_enemies()

	var behind := _spawn("slime_green", player, Vector2(14, 0), Vector2.RIGHT)
	await get_tree().create_timer(0.3).timeout
	check(behind.target == player, "a player right behind an enemy is sensed")
	await _clear_enemies()

	var glimpse := _spawn("slime_green", player, Vector2(-100, 0), Vector2.RIGHT)
	var start := glimpse.global_position.distance_to(_feet(player))
	await get_tree().create_timer(0.3).timeout
	check(glimpse.target == null and glimpse.alert == Enemy.Alert.SUSPICIOUS, "a silhouette just beyond sight makes the enemy Suspicious")
	await get_tree().create_timer(0.6).timeout
	check(glimpse.ai_state == Enemy.AiState.INVESTIGATE or glimpse.target == player, "a suspicious enemy investigates")
	check(glimpse.global_position.distance_to(_feet(player)) < start, "investigating walks toward the disturbance")
	await _clear_enemies()

	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 80)
	shape.shape = rect
	wall.add_child(shape)
	add_child(wall)
	wall.global_position = _feet(player) + Vector2(-25, 0)
	# Tembok baru masuk ruang fisika setelah satu langkah fisika.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var blocked := _spawn("slime_green", player, Vector2(-50, 0), Vector2.RIGHT)
	await get_tree().create_timer(0.4).timeout
	check(blocked.target == null and blocked.alert == Enemy.Alert.CALM, "walls block line of sight")
	wall.queue_free()
	await _clear_enemies()

func _test_light() -> void:
	var data: EnemyData = (load("res://resources/enemies/slime_green.tres") as EnemyData).duplicate()
	data.ai_enabled = false
	var day := Enemy.spawn(data, self, Vector2(100, 100))
	var cave := Node2D.new()
	cave.add_to_group(Perception.DARK_GROUP)
	add_child(cave)
	var underground := Enemy.spawn(data, cave, Vector2(140, 100))
	await get_tree().physics_frame
	check(is_equal_approx(day.vision_range(), data.aggro_radius), "daylight: full sight range")
	check(is_equal_approx(underground.vision_range(), data.aggro_radius * data.dark_vision_scale), "caves shorten sight range")
	DayCycle.hour = 23
	check(day.vision_range() < data.aggro_radius * 0.85, "night shortens sight range")
	DayCycle.hour = 12
	cave.queue_free()
	await _clear_enemies()

func _test_hearing(player: Player) -> void:
	var listener := _spawn("slime_green", player, Vector2(60, 0), Vector2.RIGHT)
	await get_tree().create_timer(0.2).timeout
	var source := listener.global_position + Vector2(-40, 30)
	var heard := Perception.noise(player, source, 70.0, player)
	check(heard == 1 and listener.alert == Enemy.Alert.SUSPICIOUS, "a nearby noise makes the enemy Suspicious")
	check(listener.facing_vector().dot((source - listener.global_position).normalized()) > 0.3, "the enemy turns toward the noise")
	await _clear_enemies()
	var far := _spawn("slime_green", player, Vector2(200, 0), Vector2.RIGHT)
	await get_tree().physics_frame
	check(Perception.noise(player, _feet(player), Perception.RULES.run_noise_radius, player) == 0 and far.alert == Enemy.Alert.CALM, "a noise out of earshot is ignored")
	await _clear_enemies()

func _test_memory(player: Player) -> void:
	var hunter := _spawn("slime_green", player, Vector2(-50, 0), Vector2.RIGHT)
	hunter.data.memory_time = 0.5
	await _wait_until(func(): return hunter.target == player, 1.0)
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 200)
	shape.shape = rect
	wall.add_child(shape)
	add_child(wall)
	wall.global_position = hunter.global_position + Vector2(12, 0)
	var lost := await _wait_until(func(): return hunter.target == null, 2.0)
	check(lost and hunter.alert == Enemy.Alert.SUSPICIOUS, "out of sight too long: the enemy searches the last seen spot")
	wall.queue_free()
	await _clear_enemies()

#endregion

#region Koordinasi

func _test_tickets(player: Player) -> void:
	var pack: Array[Enemy] = []
	for offset in [Vector2(-40, 0), Vector2(40, 0), Vector2(0, 40)]:
		var enemy := _spawn("slime_blue", player, offset, -offset.normalized())
		enemy.data.attack = 1
		pack.append(enemy)
	var attackers := {}
	var most_at_once := 0
	var flanked := false
	var waited := 0.0
	while waited < 6.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
		var now := 0
		for enemy in pack:
			if enemy.ai_state in [Enemy.AiState.WINDUP, Enemy.AiState.ATTACK]:
				now += 1
				attackers[enemy] = true
			if enemy.alert == Enemy.Alert.FLANK and enemy.brain_path().ends_with("flank"):
				flanked = true
		most_at_once = maxi(most_at_once, now)
	check(pack.all(func(e: Enemy): return e.target == player), "the whole pack is in combat")
	check(AttackTickets.holders(player).size() <= Perception.RULES.max_attackers, "attack tickets cap simultaneous attackers")
	check(most_at_once <= Perception.RULES.max_attackers, "never more than %d enemies wind up or attack at once (%d)" % [Perception.RULES.max_attackers, most_at_once])
	check(flanked, "enemies without a ticket flank the player")
	check(attackers.size() >= 3, "enemies take turns attacking (%d of 3 attacked)" % attackers.size())
	await _clear_enemies()

	var staggered := _spawn("slime_blue", player, Vector2(-15, 0), Vector2.RIGHT)
	await _wait_until(func(): return AttackTickets.holds(staggered, player), 1.0)
	staggered.stagger(0.5)
	check(not AttackTickets.holds(staggered, player), "a staggered enemy gives up its ticket")
	await _clear_enemies()

func _test_feint(player: Player) -> void:
	var trickster := _spawn("myconid_red", player, Vector2(-15, 0), Vector2.RIGHT)
	trickster.data.feint_chance = 1.0
	trickster.data.feint_cooldown = 1.0
	var hp := player.data.hp
	var feinted := await _wait_until(func(): return trickster.ai_state == Enemy.AiState.FEINT, 2.0)
	check(feinted, "an enemy can feint")
	check(not trickster.can_be_parried(), "a feint cannot be parried (it baits the parry)")
	await _wait_until(func(): return trickster.ai_state != Enemy.AiState.FEINT, 2.0)
	check(player.data.hp == hp, "a feint deals no damage")
	await _clear_enemies()

func _test_retreat(player: Player) -> void:
	var leader := _spawn("myconid_red", player, Vector2(-30, 0), Vector2.RIGHT)
	leader.data.retreat_hp_ratio = 0.3
	leader.data.retreat_time = 0.8
	leader.data.calls_for_help = true
	leader.hp = 1
	var ally := _spawn("slime_blue", player, Vector2(-110, 0), Vector2.LEFT)
	var retreated := await _wait_until(func(): return leader.ai_state == Enemy.AiState.RETREAT, 1.5)
	check(retreated and leader.alert == Enemy.Alert.RETREAT, "a badly hurt enemy retreats")
	check(leader.help_called and ally.target == player and ally.alert == Enemy.Alert.AGGRO, "retreating calls a nearby ally for help")
	var recovered := await _wait_until(func(): return leader.ai_state != Enemy.AiState.RETREAT, 2.0)
	check(recovered and leader.desperate, "after retreating the enemy fights on, desperate")
	await get_tree().create_timer(0.5).timeout
	check(leader.ai_state != Enemy.AiState.RETREAT, "an enemy retreats only once")
	await _clear_enemies()

func _test_hit_from_behind(player: Player) -> void:
	var unaware := _spawn("slime_green", player, Vector2(40, 0), Vector2.RIGHT)
	var bystander := _spawn("slime_green", player, Vector2(90, 30), Vector2.RIGHT)
	await get_tree().create_timer(0.2).timeout
	unaware.take_hit(1, player, Vector2.RIGHT)
	check(unaware.target == player and unaware.facing_vector().dot(Vector2.LEFT) > 0.5, "hit from behind: the enemy turns on its attacker")
	check(bystander.alert != Enemy.Alert.CALM, "weapon clashes are heard by nearby enemies")
	await _clear_enemies()

#endregion
