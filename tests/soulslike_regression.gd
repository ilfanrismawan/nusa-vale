extends Node2D

## GDD 8.2-A: stamina tempur + Exhausted, dodge roll + i-frames + beban, block/parry/riposte,
## poise/stagger, frame data, heavy/sprint/roll attack, dan weapon art.
## Tidak menulis save ke disk.

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
	await get_tree().process_frame
	_test_rules()
	GameState.new_game()
	# Kemampuan fakultas Universitas: tes ini menguji gerak/tempur, bukan kursusnya.
	Abilities.grant_all(GameState.p1())
	var rig := (load("res://scenes/player/Player.tscn") as PackedScene).instantiate()
	add_child(rig)
	var player := rig.get_node("CharacterBody2D") as Player
	await get_tree().process_frame
	player.global_position = Vector2(400, 300)
	player.update_facing_direction(Vector2.RIGHT, true)
	await get_tree().create_timer(0.5).timeout
	_hold(player, "sword_wood")
	await _test_stamina(player)
	await _test_roll(player)
	await _test_guard(player)
	await _test_poise(player)
	await _test_attacks(player)
	await _test_arts(player)
	rig.queue_free()
	print("SOULSLIKE REGRESSION COMPLETE: failures=%d" % failures)
	await get_tree().create_timer(30.0).timeout
	get_tree().quit(1 if failures > 0 else 0)

func _hold(player: Player, item_id: String) -> void:
	var data := player.data
	data.hotbar_page = 0
	data.inventory[0] = {"item": GameState._resolve_item(item_id), "count": 1}
	player.tool_controller.select_tool(0, false)

func _wait_until(condition: Callable, timeout: float) -> bool:
	var waited := 0.0
	while not condition.call() and waited < timeout:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	return condition.call()

func _idle(player: Player) -> void:
	await _wait_until(func(): return player.state_machine.current_state is IdleState and not player.animation_controller.item_gesture_playing, 3.0)

func _dummy(id: String, player: Player, offset: Vector2) -> Enemy:
	var data: EnemyData = (load("res://resources/enemies/%s.tres" % id) as EnemyData).duplicate()
	data.contact_damage = false
	data.ai_enabled = false
	return Enemy.spawn(data, self, player.global_position + Player.FEET_OFFSET + offset)

func _test_rules() -> void:
	var rules := Combat.RULES
	check(rules != null and rules.combat_stamina_max == 100 and rules.exhausted_time >= 1.0 and rules.exhausted_time <= 1.5, "combat rules: 100 combat stamina, Exhausted 1-1.5 s")
	PlayerInput.ensure_combat_actions()
	for action in [&"dodge", &"guard", &"weapon_art", &"heavy_attack", &"lock_on"]:
		# Tombol combat hidup di varian konteks (mis. "guard@8"); aksi dasar tetap ada.
		var bound := not PlayerInput.solo().bindings(action, false, InputLayout.MELEE).is_empty() \
			or not PlayerInput.solo().bindings(action, true, InputLayout.MELEE).is_empty()
		check(InputMap.has_action(action) and bound, "input action exists: " + action)
	var light := PlayerData.new(1)
	light.reset_to_starter()
	Abilities.grant_all(light)
	check(Combat.roll_class(light) == 0, "starter gear gives a Fast Roll (load %.2f)" % Combat.equip_load_ratio(light))
	var heavy := PlayerData.new(1)
	heavy.reset_to_starter()
	Abilities.grant_all(heavy)
	for key in ["helmet", "armor", "leggings", "boots"]:
		heavy.equipment[key] = GameState._resolve_item("%s_obsidian" % key)
	check(heavy.equipment["armor"] != null and Combat.roll_class(heavy) == 2, "full obsidian armor gives a Heavy Fat-Roll (load %.2f)" % Combat.equip_load_ratio(heavy))
	check(rules.roll_iframes[2] < rules.roll_iframes[0] and rules.roll_distance[2] < rules.roll_distance[0], "heavy rolls are shorter with fewer i-frames")
	var sword := Combat.style_for(GameState._resolve_item("sword_wood"))
	check(sword.hit_frame_ratio < sword.active_end_ratio and sword.active_end_ratio < sword.recovery_cancel_ratio, "sword frame data: startup < active < recovery cancel")
	check(sword.art_for(0) != null and sword.art_for(9) != null and sword.art_for(9).id == &"sword_obsidian", "every sword tier has a weapon art (Obsidian = dark flame)")
	var staff := Combat.style_for(GameState._resolve_item("staff_wood"))
	check(staff.art_for(8) != null and staff.art_for(8).kind == WeaponArt.Kind.HEAL_CIRCLE, "Fairy staff art is a healing circle")

func _test_stamina(player: Player) -> void:
	var combat := player.combat
	var data := player.data
	combat.reset()
	data.stamina = 60
	check(combat.stamina == 100.0, "combat stamina starts full")
	check(player.tool_controller.attack(), "sword attack starts")
	check(combat.stamina < 100.0 and data.stamina == 60, "attacks use combat stamina, daily stamina untouched")
	await _idle(player)
	var low := combat.stamina
	await get_tree().create_timer(Combat.RULES.regen_delay + 0.4).timeout
	check(combat.stamina > low, "combat stamina regenerates after a short delay")
	combat.spend(999.0)
	check(combat.is_exhausted() and combat.stamina == 0.0, "draining combat stamina causes Exhausted")
	check(not player.tool_controller.attack() and not combat.request_dodge(), "Exhausted: no attack and no roll")
	check(is_equal_approx(player.combat_speed_scale(), Combat.RULES.exhausted_speed_scale), "Exhausted slows movement")
	check(not player.is_defeated, "Exhausted does not faint (daily stamina rule unchanged)")
	await get_tree().create_timer(Combat.RULES.exhausted_time + 0.1).timeout
	check(not combat.is_exhausted(), "Exhausted wears off")
	combat.reset()

func _test_roll(player: Player) -> void:
	var combat := player.combat
	await _idle(player)
	var start := player.global_position
	check(combat.request_dodge(), "dodge roll starts")
	check(player.state_machine.current_state is DodgeState, "roll enters DodgeState")
	check(combat.stamina < 100.0, "roll costs combat stamina")
	check(not player.take_hit(30, null) and player.data.hp == player.data.max_hp, "i-frames avoid damage during the roll")
	await _wait_until(func(): return not (player.state_machine.current_state is DodgeState), 2.0)
	check(player.global_position.distance_to(start) > 20.0, "roll moves the player (%.0f px)" % player.global_position.distance_to(start))
	check(player.state_machine.current_state is IdleState and combat.rolled_recently(), "roll ends in idle; roll attack window opens")
	combat.reset()

func _test_guard(player: Player) -> void:
	var combat := player.combat
	var data := player.data
	await get_tree().create_timer(Player.HIT_INVULNERABLE + 0.2).timeout
	await _idle(player)
	data.hp = data.max_hp
	var myconid := _dummy("myconid_red", player, Vector2(18, 0))
	await get_tree().physics_frame
	# Block biasa (jendela parry sudah lewat).
	combat.force_guard = true
	await get_tree().process_frame
	await get_tree().create_timer(Combat.RULES.parry_window + 0.1).timeout
	check(combat.guarding and not combat.is_parry_window(), "holding guard blocks")
	var stamina_before := combat.stamina
	check(player.take_hit(20, myconid), "a blocked hit still lands")
	var defense := Combat.player_defense(data)
	var full := Combat.damage_after_defense(20, defense)
	check(data.max_hp - data.hp < full and combat.stamina < stamina_before, "block reduces damage and costs stamina (%d < %d)" % [data.max_hp - data.hp, full])
	combat.force_guard = false
	await get_tree().physics_frame
	await get_tree().create_timer(Player.HIT_INVULNERABLE + 0.6).timeout
	# Parry: tekan block tepat sebelum serangan mendarat.
	data.hp = data.max_hp
	combat.reset()
	myconid._enter(Enemy.AiState.ATTACK)
	check(myconid.can_be_parried(), "an attacking enemy can be parried")
	combat.force_guard = true
	await get_tree().process_frame
	await get_tree().process_frame
	check(combat.is_parry_window(), "pressing guard opens the parry window")
	check(not player.take_hit(20, myconid) and data.hp == data.max_hp, "parry negates the damage")
	check(myconid.is_staggered(), "parry staggers the enemy")
	combat.force_guard = false
	await get_tree().process_frame
	# Riposte: serangan ke musuh terhuyung di depan = pukulan kritis.
	await _idle(player)
	var hp_before := myconid.hp
	check(player.tool_controller.attack() and player.tool_controller.combat_state.kind == CombatState.Kind.RIPOSTE, "attacking a staggered enemy is a riposte")
	await _idle(player)
	var sword := GameState._resolve_item("sword_wood")
	var crit := Combat.damage_after_defense(roundi(sword.attack_bonus * Combat.RULES.riposte_multiplier), myconid.data.defense)
	check(hp_before - myconid.hp >= crit and not myconid.is_staggered(), "riposte deals critical damage and ends the stagger (%d)" % (hp_before - myconid.hp))
	# Contact damage biasa tidak bisa di-parry.
	myconid._enter(Enemy.AiState.IDLE)
	check(not myconid.can_be_parried(), "an idle enemy cannot be parried")
	myconid.queue_free()
	combat.reset()

func _test_poise(player: Player) -> void:
	var combat := player.combat
	var slime := _dummy("slime_green", player, Vector2(14, 0))
	await get_tree().physics_frame
	await _idle(player)
	check(Combat.hit(slime, 1, player, Vector2.ZERO, 5.0) and not slime.is_staggered(), "a light hit chips poise without stagger")
	await get_tree().create_timer(Enemy.HIT_INVULNERABLE + 0.05).timeout
	check(Combat.hit(slime, 1, player, Vector2.ZERO, 999.0) and slime.is_staggered(), "breaking poise staggers the enemy")
	await get_tree().create_timer(Enemy.HIT_INVULNERABLE + 0.05).timeout
	var before := slime.hp
	Combat.hit(slime, 4, player, Vector2.ZERO, 1.0)
	check(before - slime.hp == roundi(Combat.damage_after_defense(4, slime.data.defense) * Combat.RULES.staggered_damage_scale), "staggered enemies take extra damage")
	var ended := await _wait_until(func(): return not slime.is_staggered(), slime.data.stagger_time + 1.0)
	check(ended and is_equal_approx(slime.poise, slime.data.poise), "stagger ends and poise refills")
	slime.queue_free()
	# Poise pemain pecah: serangan terputus.
	await get_tree().create_timer(Player.HIT_INVULNERABLE + 0.2).timeout
	await _idle(player)
	player.data.hp = player.data.max_hp
	combat.reset()
	check(player.tool_controller.attack(), "attack starts before the interrupt")
	check(player.take_hit(5, null) and player.state_machine.current_state == player.tool_controller.combat_state, "a small hit does not interrupt (poise holds)")
	await get_tree().create_timer(Player.HIT_INVULNERABLE + 0.05).timeout
	await _idle(player)
	check(player.tool_controller.attack(), "second attack starts")
	combat.poise = 1.0
	check(player.take_hit(10, null) and not (player.state_machine.current_state is CombatState), "breaking player poise interrupts the attack")
	await get_tree().create_timer(Player.HIT_INVULNERABLE + 0.2).timeout
	player.data.hp = player.data.max_hp
	combat.reset()

func _test_attacks(player: Player) -> void:
	var combat := player.combat
	var tools := player.tool_controller
	var sword := Combat.style_for(GameState._resolve_item("sword_wood"))
	var dummy := _dummy("slime_blue", player, Vector2(14, 0))
	dummy.data.poise = 9999.0
	dummy.poise = 9999.0
	dummy.data.max_hp = 9999
	dummy.hp = 9999
	await get_tree().physics_frame
	await _idle(player)
	# Heavy: tahan klik kiri.
	combat.reset()
	var before := dummy.hp
	check(tools.attack(CombatState.Kind.HEAVY) and tools.combat_state.kind == CombatState.Kind.HEAVY, "heavy attack starts")
	check(is_equal_approx(100.0 - combat.stamina, float(sword.heavy_stamina_cost)), "heavy attack costs more stamina")
	check(not tools.combat_state.can_cancel(), "startup cannot be cancelled (attack commitment)")
	check(not combat.request_dodge(), "no roll during startup")
	await _idle(player)
	var heavy_damage := before - dummy.hp
	check(heavy_damage >= Combat.damage_after_defense(roundi(GameState._resolve_item("sword_wood").attack_bonus * sword.heavy_damage), dummy.data.defense), "heavy attack deals heavy damage (%d)" % heavy_damage)
	await get_tree().create_timer(Enemy.HIT_INVULNERABLE + 0.1).timeout
	# Charge lewat input: begin_charge lalu tahan melewati heavy_charge_time.
	combat.begin_charge()
	check(combat.charging and combat.charge_ratio() == 0.0, "pressing attack with a weapon starts charging")
	combat.charging = false
	# Sprint attack.
	combat._last_run_ms = Time.get_ticks_msec()
	check(tools.attack() and tools.combat_state.kind == CombatState.Kind.SPRINT, "attacking right after running is a sprint attack")
	await _idle(player)
	combat._last_run_ms = -100000
	# Roll attack.
	combat.reset()
	combat.request_dodge()
	await _wait_until(func(): return player.state_machine.current_state is IdleState, 2.0)
	check(tools.attack() and tools.combat_state.kind == CombatState.Kind.ROLL, "attacking right after a roll is a roll attack")
	await _idle(player)
	# Recovery akhir boleh dibatalkan dengan roll.
	combat.reset()
	tools.attack()
	var cancelled := await _wait_until(func(): return tools.combat_state.can_cancel(), 2.0)
	check(cancelled and combat.request_dodge() and player.state_machine.current_state is DodgeState, "late recovery can be cancelled with a roll")
	await _idle(player)
	dummy.queue_free()
	combat.reset()

func _test_arts(player: Player) -> void:
	var combat := player.combat
	var tools := player.tool_controller
	var dummy := _dummy("slime_blue", player, Vector2(14, 0))
	dummy.data.max_hp = 9999
	dummy.hp = 9999
	await get_tree().physics_frame
	await _idle(player)
	combat.reset()
	var art := Combat.style_for(GameState._resolve_item("sword_wood")).art_for(0)
	var before := dummy.hp
	check(tools.weapon_art() and tools.combat_state.kind == CombatState.Kind.ART, "weapon art starts (%s)" % art.display_name)
	check(is_equal_approx(100.0 - combat.stamina, float(art.stamina_cost)), "weapon art costs its stamina")
	await _idle(player)
	await get_tree().create_timer(art.interval * art.count + 0.2).timeout
	check(dummy.hp < before, "weapon art damages the enemy")
	check(not tools.weapon_art() and not combat.art_ready(art), "weapon art has a cooldown")
	dummy.queue_free()
	# Fairy staff: lingkaran penyembuh.
	_hold(player, "staff_fairy")
	await get_tree().physics_frame
	combat.reset()
	player.data.hp = 40
	var fairy := Combat.style_for(GameState._resolve_item("staff_fairy")).art_for(8)
	check(GameState._resolve_item("staff_fairy") != null and tools.weapon_art() and tools.combat_state.art == fairy, "Fairy staff casts its healing circle")
	await _idle(player)
	check(player.data.hp == 40 + fairy.heal_amount, "healing circle restores HP")
