extends Node2D

## Boss lantai 20 (GDD 8.2-C): data Raja Slime Emas, save v16, arena + pintu kabut, bar HP,
## kebal saat meraung, serangan tak bisa ditahan, roll menghindar, parry terjangan, fase 2-3,
## murka, anti-kiting, anak slime, pertarungan diulang, dan hadiah pertama.
## Tidak menulis save ke disk.

const CAVE_SCENE := "res://scenes/world/cave/cave.tscn"

var failures := 0
var _player: Player

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _process(_delta: float) -> void:
	if get_tree().paused:
		get_tree().paused = false
	# Pemain tes tidak boleh tumbang (DefeatSequence akan pindah scene).
	if is_instance_valid(_player) and _player.data.hp < 30:
		_player.data.restore_hp()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.current_day = 3
	_test_data()
	_test_save()
	await _test_arena()
	print("BOSS REGRESSION COMPLETE: failures=%d" % failures)
	await get_tree().create_timer(30.0).timeout
	get_tree().quit(1 if failures > 0 else 0)

func _wait_until(condition: Callable, timeout: float) -> bool:
	var waited := 0.0
	while not condition.call() and waited < timeout:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	return condition.call()

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _test_data() -> void:
	var boss := CaveManager.DATA.boss_for(20)
	check(boss != null and boss.title == "Raja Slime Emas" and boss.floor_number == 20, "floor 20 boss is Raja Slime Emas")
	check(CaveManager.DATA.boss_for(19) == null, "floor 19 has no boss")
	check(boss.sprite_folder.contains("Golden/Big Slime") and ResourceLoader.exists(boss.sprite_folder.path_join("Idle.png")), "boss uses the golden big slime art")
	check(boss.minion != null and boss.minion.sprite_folder.contains("Golden"), "boss splits into golden slimes")
	check(boss.phase_count() == 3, "three phases")
	check(boss.phase_for_ratio(1.0) == 1 and boss.phase_for_ratio(0.5) == 2 and boss.phase_for_ratio(0.2) == 3, "phase thresholds at 50% and 20% HP")
	check(boss.tempo_for(3) < boss.tempo_for(2) and boss.tempo_for(2) < boss.tempo_for(1), "later phases are faster")
	check(boss.slam_combo_for(1) == 1 and boss.slam_combo_for(3) == 3 and boss.spit_count_for(3) > boss.spit_count_for(1), "later phases combo more")
	check(boss.reward_money > 0 and boss.reward_items.size() == boss.reward_counts.size(), "first-clear reward is set")
	for item_id in boss.reward_items:
		check(GameState._resolve_item(item_id) != null, "reward item exists: " + item_id)

func _test_save() -> void:
	var cave := GameState.cave
	cave.reset()
	check(not cave.is_boss_defeated(20), "new game: boss not defeated")
	check(cave.mark_boss_defeated(20) and not cave.mark_boss_defeated(20), "boss clear is recorded once")
	var saved := SaveManager._build_save_data()
	check(int(SaveManager.SAVE_VERSION) >= 16 and saved["cave"].has("bosses"), "save v16+ stores defeated bosses")
	check(SaveManager._is_valid_save(saved), "save with bosses is valid")
	cave.reset()
	SaveManager._apply_save(JSON.parse_string(JSON.stringify(saved)))
	check(cave.is_boss_defeated(20), "defeated boss survives save/load (through JSON)")
	var bad := saved.duplicate(true)
	bad["cave"]["bosses"] = "rusak"
	check(not SaveManager._is_valid_save(bad), "broken boss list is rejected")
	var old := saved.duplicate(true)
	old["cave"].erase("bosses")
	old["version"] = 15
	check(SaveManager._is_valid_save(old), "v15 save stays valid")
	SaveManager._apply_save(old)
	check(not cave.is_boss_defeated(20), "v15 save loads with the boss not yet defeated")
	cave.reset()

func _test_arena() -> void:
	GameState.cave.reset()
	GameState.cave.current_floor = 0
	var cave: Node2D = (load(CAVE_SCENE) as PackedScene).instantiate()
	add_child(cave)
	await get_tree().process_frame
	_player = cave.get_node("Player/CharacterBody2D") as Player
	var content := cave.get_node("FloorContent")
	cave.build_floor(20)
	await get_tree().process_frame
	var arena: BossArena = cave.arena
	check(arena != null and content.has_node("BossArena"), "floor 20 builds the boss arena")
	var boss := arena.boss if arena != null else null
	check(boss != null and boss.boss.title == "Raja Slime Emas" and not boss.awake, "boss waits asleep in the arena")
	if boss == null:
		cave.queue_free()
		return
	var rocks := 0
	for node in content.get_children():
		if node is Choppable:
			rocks += 1
	check(rocks == 0 and content.has_node("LadderUp") and content.has_node("Lift"), "arena floor: no rocks, ladder up and lift stay")
	check(not arena.is_gate_closed() and arena.gate_y() > cave.arrival_position().y + 16.0, "fog gate is open and below the arrival point")
	check(boss.take_hit(50, _player) == false and boss.hp == boss.data.max_hp, "sleeping boss cannot be hurt")

	# Masuk arena: kabut menutup, boss bangun (kebal saat meraung), bar HP muncul.
	_move_player(Vector2(cave.arrival_position().x, arena.gate_y() + 60.0))
	check(await _wait_until(func(): return arena.fighting, 1.0), "stepping past the fog starts the fight")
	check(arena.is_gate_closed() and arena.has_node("FogGate"), "fog gate closes behind the player")
	check(boss.awake and boss.move == Boss.Move.ROAR, "boss wakes with a roar")
	check(boss.take_hit(50, _player) == false, "boss is immune while roaring")
	var bars := 0
	for node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if node is BossHealthBar:
			bars += 1
	check(bars == 1, "one big boss HP bar is shown (%d)" % bars)
	await _wait_until(func(): return boss.move != Boss.Move.ROAR, 3.0)

	# Serangan bertanda bahaya: tidak bisa ditahan; roll tetap lolos.
	boss._rest = 999.0
	_player.data.restore_hp()
	var feet := _player.global_position + Player.FEET_OFFSET
	var hazard: Boss.Hazard = boss._spawn_hazard(feet, 20.0, 5.0, 20, false)
	var spit := Boss.Spit.new()
	spit.damage = 20
	add_child(spit)
	spit.global_position = feet + _player.aim_vector() * 10.0
	spit.set_physics_process(false)
	hazard.global_position = feet + _player.aim_vector() * 4.0
	_player._invulnerable = 0.0
	_player.combat.guarding = true
	var before := _player.data.hp
	_player.take_hit(20, spit)
	var blocked_loss := before - _player.data.hp
	_player._invulnerable = 0.0
	_player.combat.guarding = true
	before = _player.data.hp
	_player.take_hit(20, hazard)
	var unblockable_loss := before - _player.data.hp
	check(hazard.is_unblockable() and unblockable_loss > blocked_loss, "guarding blocks the spit (-%d) but not the danger attack (-%d)" % [blocked_loss, unblockable_loss])
	_player.combat.guarding = false
	spit.queue_free()
	_player._invulnerable = 0.0
	_player.combat.begin_iframes(0.5)
	before = _player.data.hp
	hazard.global_position = feet
	hazard.detonate()
	check(_player.data.hp == before and hazard.detonated, "rolling through the crack explosion evades it")
	await _frames(40)
	_player._invulnerable = 0.0
	_player.combat._iframes = 0.0
	_player.data.restore_hp()
	hazard = boss._spawn_hazard(feet, 20.0, 0.2, 15, true)
	before = _player.data.hp
	await _wait_until(func(): return not is_instance_valid(hazard) or hazard.detonated, 1.0)
	check(_player.data.hp < before, "standing in the cracks when they explode hurts")

	# Hantaman: retakan muncul di titik pemain sebelum boss mendarat.
	_player._invulnerable = 0.0
	boss._rest = 0.0
	boss._far_time = 0.0
	boss._begin(Boss.Move.SLAM)
	check(boss.shows_danger() and is_instance_valid(boss._slam_hazard) and boss._slam_hazard.global_position.distance_to(_player.global_position + Player.FEET_OFFSET) < 40.0, "slam marks the landing spot with cracks and a danger icon")
	check(not boss.can_be_parried(), "slam cannot be parried")
	check(await _wait_until(func(): return boss.move == Boss.Move.SLAM and boss._step == 1, 2.0), "boss leaps into the air")
	check(boss.collision_layer == 0 and not boss._contact_active(), "airborne boss does not touch-damage")
	check(await _wait_until(func(): return boss._step == 2, 2.0) and boss.global_position.distance_to(boss._slam_to) < 2.0, "boss lands on the marked spot")
	await _wait_until(func(): return boss.move == Boss.Move.NONE, 3.0)

	# Terjangan: bisa di-parry hanya saat menerjang.
	boss._rest = 999.0
	boss._begin(Boss.Move.CHARGE)
	check(not boss.can_be_parried(), "charge wind-up is not parryable yet")
	check(await _wait_until(func(): return boss._step == 1, 2.0) and boss.can_be_parried(), "charge dash is parryable")
	boss.on_parried(_player)
	check(boss.is_staggered() and boss.move == Boss.Move.NONE, "parry staggers the boss and cancels the move")
	await _wait_until(func(): return not boss.is_staggered(), 4.0)

	# Anti-kiting: pemain menjaga jarak terlalu lama.
	_move_player(Vector2(480.0, arena.gate_y() + 30.0))
	boss.global_position = Vector2(160.0, arena.gate_y() + 200.0)
	boss.move = Boss.Move.NONE
	boss._rest = 0.0
	boss._far_time = boss.boss.kite_time
	await _frames(2)
	check(boss.kite_response and (boss.move == Boss.Move.SLAM or boss.move == Boss.Move.SPIT), "keeping distance triggers a gap-closer (move %d)" % boss.move)
	boss._cancel_move()
	boss._rest = 999.0

	# Murka bila tidak di-stagger, padam saat di-stagger.
	boss._since_stagger = boss.boss.enrage_time
	await _frames(2)
	check(boss.enraged, "boss enrages when not staggered in time")
	var calm_power := roundi(boss.boss.slam_damage * boss.boss.attack_scale_for(boss.phase))
	check(boss._power(boss.boss.slam_damage) > calm_power and boss._tempo() < boss.boss.tempo_for(boss.phase), "enrage hits harder and faster")
	boss.stagger(0.3)
	check(not boss.enraged, "staggering ends the enrage")
	await _wait_until(func(): return not boss.is_staggered(), 2.0)

	# Fase 2 di 50% HP: raungan + aura + anak slime.
	boss._invulnerable = 0.0
	boss.poise = 9999.0
	boss.take_hit(boss.hp - roundi(boss.data.max_hp * 0.5) + boss.defense(), _player)
	boss._rest = 0.0
	check(await _wait_until(func(): return boss.phase == 2, 2.0) and boss.move == Boss.Move.ROAR, "boss enters phase 2 at half HP with a roar")
	check(boss._aura_color().a > 0.0 and boss._embers != null and boss._embers.emitting, "phase 2 has a visible aura")
	await _wait_until(func(): return boss.move != Boss.Move.ROAR, 3.0)
	boss._cancel_move()
	boss._split_ready = 0.0
	boss._begin(Boss.Move.SPLIT)
	check(await _wait_until(func(): return not boss.minions.is_empty(), 2.0), "phase 2 boss splits off golden slimes (%d)" % boss.minions.size())
	await _wait_until(func(): return boss.move == Boss.Move.NONE, 2.0)

	# Fase 3 di 20% HP: Hujan Emas.
	boss._invulnerable = 0.0
	boss._rest = 0.0
	boss.take_hit(boss.hp - roundi(boss.data.max_hp * 0.15) + boss.defense(), _player)
	check(await _wait_until(func(): return boss.phase == 3, 3.0), "boss enters phase 3 below 20% HP")
	await _wait_until(func(): return boss.move != Boss.Move.ROAR, 3.0)
	boss._cancel_move()
	boss._begin(Boss.Move.RAIN)
	check(await _wait_until(func(): return _count_hazards(content) >= 3, 3.0), "Hujan Emas drops several marked cracks")
	await _wait_until(func(): return boss.move == Boss.Move.NONE, 5.0)

	# Semua pemain keluar arena: pertarungan diulang.
	boss._rest = 999.0
	_move_player(cave.arrival_position())
	arena.reset_fight()
	await _frames(3)
	check(not arena.fighting and not arena.is_gate_closed() and not boss.awake and boss.hp == boss.data.max_hp and boss.phase == 1, "leaving resets the fight: full HP, gate open")
	check(boss.minions.is_empty(), "reset clears the minions")

	# Kemenangan: kabut hilang, hadiah pertama, tercatat di save.
	var money := GameState.money
	_move_player(Vector2(cave.arrival_position().x, arena.gate_y() + 60.0))
	await _wait_until(func(): return arena.fighting, 1.0)
	await _wait_until(func(): return boss.move != Boss.Move.ROAR, 3.0)
	# Pemain menjauh ke tepi arena supaya hadiah tidak langsung terpungut.
	_move_player(Vector2(40.0, arena.gate_y() + 30.0))
	boss.global_position = Vector2(400.0, arena.gate_y() + 160.0)
	boss._invulnerable = 0.0
	boss.take_hit(99999, _player)
	await _frames(10)
	check(boss.is_dead() and arena.cleared and not arena.is_gate_closed(), "defeating the boss lifts the fog")
	check(GameState.cave.is_boss_defeated(20) and GameState.money == money + boss.boss.reward_money, "first clear pays %d G and is recorded" % boss.boss.reward_money)
	var reward_ids := {}
	for node in content.get_children():
		if node is ItemPickup:
			reward_ids[node.item_id] = true
	check(reward_ids.has("gold_ore") and reward_ids.has("iron_ore"), "boss reward drops on the floor")
	await get_tree().create_timer(1.0).timeout
	cave.build_floor(20)
	await get_tree().process_frame
	check(cave.arena == null and not content.has_node("BossArena"), "after the clear, floor 20 is a normal mine floor")
	_player = null
	cave.queue_free()
	await get_tree().process_frame

func _move_player(at: Vector2) -> void:
	var root := _player.get_parent() as Node2D
	root.global_position = at
	_player.position = Vector2.ZERO
	_player.velocity = Vector2.ZERO

func _count_hazards(content: Node) -> int:
	var count := 0
	for node in content.get_children():
		if node is Boss.Hazard and not node.is_queued_for_deletion():
			count += 1
	return count
