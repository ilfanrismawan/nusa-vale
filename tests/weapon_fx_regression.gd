extends Node2D

## Efek tier senjata (WeaponTierFx) dan rasa membidik busur/tongkat (AimFx):
## data 10 tier naik bertahap, suara sintetis, tarikan penuh, tembakan charged, tebasan bergema.
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
	_test_tier_data()
	_test_synth()
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
	await _test_aim(player)
	await _test_charged_shot(player)
	await _test_melee(player)
	await _test_status(player)
	rig.queue_free()
	print("WEAPON FX REGRESSION COMPLETE: failures=%d" % failures)
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

func _test_tier_data() -> void:
	var tiers: Array[WeaponTierFx] = []
	var names := {}
	for tier in WeaponTierFx.TIER_FILES.size():
		var path: String = WeaponTierFx.DIR + WeaponTierFx.TIER_FILES[tier] + ".tres"
		check(ResourceLoader.exists(path), "tier fx file exists: " + path)
		var fx := WeaponTierFx.for_tier(tier)
		tiers.append(fx)
		names[fx.display_name] = true
		for layer in fx.impact_layers:
			check(Juice.impact_stream(layer) != null, "%s impact sound loads: %s" % [fx.display_name, layer])
	check(names.size() == 10, "10 distinct tier identities (%d)" % names.size())
	check(WeaponTierFx.for_tier(99) == tiers[9] and WeaponTierFx.for_tier(-3) == tiers[0], "out-of-range tiers clamp to Wood/Obsidian")
	var escalates := true
	var stronger := true
	for i in range(1, tiers.size()):
		var a := tiers[i - 1]
		var b := tiers[i]
		if b.hit_particles < a.hit_particles or b.trail_points < a.trail_points or b.flight_particles < a.flight_particles \
				or b.impact_layers.size() < a.impact_layers.size() or b.chime_notes.size() < a.chime_notes.size() \
				or b.muzzle_scale < a.muzzle_scale or b.shake_bonus < a.shake_bonus or b.aim_motes < a.aim_motes:
			escalates = false
			push_warning("tier %s does not escalate over %s" % [b.display_name, a.display_name])
		if _power(b) <= _power(a):
			stronger = false
	check(escalates, "every VFX/SFX number grows (never shrinks) from Wood to Obsidian")
	check(stronger, "each tier is strictly more intense than the one before")
	check(tiers[0].impact_layers.size() == 1 and tiers[9].impact_layers.size() >= 3, "impact sound layers: Wood 1, Obsidian 3+")
	check(tiers[9].bass_boom and not tiers[8].bass_boom, "only Obsidian has the bass boom")
	var colors := {}
	for fx in tiers:
		colors[fx.color.to_html()] = true
	check(colors.size() == 10, "every tier has its own color")

func _power(fx: WeaponTierFx) -> float:
	return fx.hit_particles + fx.trail_points + fx.flight_particles + fx.hit_ring + fx.shake_bonus * 10.0 + fx.hitstop_bonus_ms + fx.impact_layers.size() * 5.0 + fx.chime_notes.size() * 3.0 + fx.aim_motes + fx.muzzle_scale * 10.0

func _test_synth() -> void:
	var streams := {"bow_creak": SfxSynth.bow_creak(), "staff_hum": SfxSynth.staff_hum(), "chime": SfxSynth.chime(), "whoosh": SfxSynth.whoosh(), "boom": SfxSynth.boom()}
	for key in streams:
		var wav: AudioStreamWAV = streams[key]
		check(wav != null and wav.data.size() > 2000 and wav.get_length() > 0.1, "synth sound %s has audio (%.2f s)" % [key, wav.get_length() if wav != null else 0.0])
	check(SfxSynth.bow_creak().loop_mode == AudioStreamWAV.LOOP_FORWARD and SfxSynth.staff_hum().loop_mode == AudioStreamWAV.LOOP_FORWARD, "draw sounds loop while aiming")
	check(SfxSynth.chime().loop_mode == AudioStreamWAV.LOOP_DISABLED, "chime plays once")
	check(SfxSynth.chime() == streams["chime"], "synth sounds are cached")

func _test_aim(player: Player) -> void:
	_hold(player, "bow_wood")
	await _idle(player)
	var bow := Combat.style_for(GameState._resolve_item("bow_wood"))
	var fx := AimFx.new()
	player.add_child(fx)
	var fulls := [0]
	fx.fully_drawn.connect(func(): fulls[0] += 1)
	var step := 1.0 / 60.0
	fx.update(step, true, true, Vector2.RIGHT, bow, WeaponTierFx.for_tier(0), 80.0)
	check(fx.aiming and fx.draw_ratio > 0.0 and fx.draw_ratio < 0.2, "aiming starts drawing from 0")
	check(fx._loop.playing and fx._loop.stream == SfxSynth.bow_creak(), "bow string creak plays while drawing")
	var first_pitch := fx._loop.pitch_scale
	for i in int(Combat.RULES.aim_draw_time * 0.5 / step):
		fx.update(step, true, true, Vector2.RIGHT, bow, WeaponTierFx.for_tier(0), 80.0)
	check(not fx.is_full() and fx._loop.pitch_scale > first_pitch, "half drawn: not full yet, creak pitch rises")
	fx.update(step, true, false, Vector2.RIGHT, bow, WeaponTierFx.for_tier(0), 80.0)
	var held := fx.draw_ratio
	fx.update(step, true, false, Vector2.RIGHT, bow, WeaponTierFx.for_tier(0), 80.0)
	check(is_equal_approx(held, fx.draw_ratio), "draw does not grow during the shot animation")
	for i in int(Combat.RULES.aim_draw_time / step) + 2:
		fx.update(step, true, true, Vector2.RIGHT, bow, WeaponTierFx.for_tier(0), 80.0)
	check(fx.is_full() and fulls[0] == 1, "full draw after aim_draw_time, signal fires once (%d)" % fulls[0])
	check(is_equal_approx(fx.release(), 1.0) and fx.draw_ratio == 0.0 and not fx.is_full(), "release returns full power and restarts the draw")
	fx.update(step, false, false, Vector2.RIGHT, null, null, 0.0)
	check(not fx.aiming and not fx._loop.playing, "letting go of aim stops the draw sound")
	var staff := Combat.style_for(GameState._resolve_item("staff_wood"))
	fx.update(step, true, true, Vector2.RIGHT, staff, WeaponTierFx.for_tier(8), 80.0)
	check(fx.is_magic() and fx._loop.stream == SfxSynth.staff_hum(), "staff hums instead of creaking")
	fx.queue_free()

func _projectiles() -> Array[CombatProjectile]:
	var found: Array[CombatProjectile] = []
	for node in get_tree().current_scene.get_children():
		if node is CombatProjectile:
			found.append(node)
	return found

func _test_charged_shot(player: Player) -> void:
	var data := player.data
	_hold(player, "staff_fairy")
	await _idle(player)
	var staff_item := GameState._resolve_item("staff_fairy")
	var staff := Combat.style_for(staff_item)
	check(int(staff_item.equipment_tier) == 8, "Fairy Staff is tier Fairy")
	# Tahan klik kanan (aksi "aim") sampai tarikan penuh, lalu tembak.
	Input.action_press(player.input.action(&"aim"))
	check(await _wait_until(func(): return player.is_aiming() and is_instance_valid(player.aim_fx), 1.0), "holding aim with a staff creates the aim effect")
	check(await _wait_until(func(): return is_instance_valid(player.aim_fx) and player.aim_fx.is_full(), Combat.RULES.aim_draw_time + 1.0), "player aim reaches full draw")
	player.combat.reset()
	player.tool_controller.combo_step = 0
	check(player.tool_controller.attack(), "staff shot starts")
	var shot := await _wait_until(func(): return not _projectiles().is_empty(), 2.0)
	var orbs := _projectiles()
	check(shot and orbs.size() == 1, "one orb launched")
	if not orbs.is_empty():
		var orb := orbs[0]
		check(orb.charged and orb.fx == WeaponTierFx.for_tier(8), "full-draw orb is charged and carries the Fairy tier fx")
		check(orb.trail_length() > WeaponTierFx.for_tier(8).trail_points, "charged orb has a longer trail")
		check(orb._flight != null and orb._flight.emitting, "Fairy orb leaves flight particles")
		check(orb.tint_color() != staff.projectile_color, "orb color follows the tier")
	check(is_instance_valid(player.aim_fx) and not player.aim_fx.is_full(), "shooting restarts the draw")
	await _idle(player)
	Input.action_release(player.input.action(&"aim"))
	check(await _wait_until(func(): return not player.aim_fx.aiming, 0.5), "releasing aim hides the aim effect")
	# Busur kayu tanpa bidikan: tidak charged, tanpa partikel terbang.
	data.add_item(GameState._resolve_item("arrow_wood"), 5)
	_hold(player, "bow_wood")
	await _idle(player)
	for p in _projectiles():
		p.queue_free()
	await get_tree().process_frame
	player.combat.reset()
	player.tool_controller.combo_step = 0
	check(player.tool_controller.attack(), "wood bow shot starts")
	await _wait_until(func(): return not _projectiles().is_empty(), 2.0)
	var arrows := _projectiles()
	if not arrows.is_empty():
		var arrow := arrows[0]
		check(not arrow.charged and arrow._flight == null, "plain wood arrow: no charge, no flight particles")
		check(arrow.trail_length() == WeaponTierFx.for_tier(0).trail_points, "wood arrow trail uses the Wood length")
	else:
		check(false, "wood arrow launched")
	await _idle(player)

func _count_arcs() -> int:
	var count := 0
	for node in get_tree().current_scene.get_children():
		if node is CombatJuice.SlashArc:
			count += 1
	return count

func _test_melee(player: Player) -> void:
	_hold(player, "sword_obsidian")
	await _idle(player)
	var data: EnemyData = (load("res://resources/enemies/slime_blue.tres") as EnemyData).duplicate()
	data.contact_damage = false
	data.ai_enabled = false
	data.max_hp = 9999
	var dummy := Enemy.spawn(data, self, player.global_position + Player.FEET_OFFSET + Vector2(14, 0))
	dummy.hp = 9999
	await get_tree().physics_frame
	player.combat.reset()
	player.tool_controller.combo_step = 0
	var before := dummy.hp
	check(player.tool_controller.attack(), "obsidian sword swing starts")
	var max_arcs := [0]
	await _wait_until(func():
		max_arcs[0] = maxi(max_arcs[0], _count_arcs())
		return player.state_machine.current_state is IdleState, 3.0)
	check(dummy.hp < before, "obsidian sword hits the dummy")
	check(max_arcs[0] >= 2, "obsidian slash has an echo arc (%d arcs)" % max_arcs[0])
	check(CombatJuice.hit_fx == null, "tier fx context is cleared after the hit")
	dummy.queue_free()
	await get_tree().physics_frame

func _sure(tier: int) -> WeaponTierFx:
	var fx := WeaponTierFx.for_tier(tier).duplicate() as WeaponTierFx
	fx.status_chance = 1.0
	return fx

func _strike(dummy: Enemy, player: Player, fx: WeaponTierFx, attack: int = 20) -> bool:
	dummy._invulnerable = 0.0
	return Combat.hit(dummy, attack, player, Vector2.ZERO, -1.0, false, false, false, fx)

func _test_status(player: Player) -> void:
	var expected := {5: WeaponTierFx.Status.BURN, 6: WeaponTierFx.Status.CHILL, 7: WeaponTierFx.Status.LIFESTEAL, 8: WeaponTierFx.Status.STAMINA, 9: WeaponTierFx.Status.DARK_FIRE}
	for tier in 10:
		var want: int = expected.get(tier, WeaponTierFx.Status.NONE)
		check(WeaponTierFx.for_tier(tier).status == want, "%s status effect: %s" % [WeaponTierFx.for_tier(tier).display_name, WeaponTierFx.for_tier(tier).status_name() if want != 0 else "none"])
	var data: EnemyData = (load("res://resources/enemies/slime_blue.tres") as EnemyData).duplicate()
	data.contact_damage = false
	data.ai_enabled = false
	data.max_hp = 9999
	data.defense = 4
	data.poise = 9999.0
	var dummy := Enemy.spawn(data, self, player.global_position + Vector2(40, 0))
	dummy.hp = 9999
	await get_tree().physics_frame
	# Kayu: tanpa efek.
	_strike(dummy, player, WeaponTierFx.for_tier(0))
	check(not dummy.is_burning() and not dummy.is_chilled(), "a Wood hit applies no status")
	# Crimson: terbakar, damage berkala tanpa pukulan baru.
	check(_strike(dummy, player, _sure(5)) and dummy.is_burning(), "Crimson hit sets the enemy on fire")
	var after_hit := dummy.hp
	await get_tree().create_timer(1.1, false).timeout
	check(dummy.hp <= after_hit - 2 * 2, "burning deals damage over time (%d -> %d)" % [after_hit, dummy.hp])
	await get_tree().create_timer(2.2, false).timeout
	check(not dummy.is_burning(), "burning wears off after its duration")
	var settled := dummy.hp
	await get_tree().create_timer(0.6, false).timeout
	check(dummy.hp == settled, "no burn damage after it ends")
	# Frost: melambat.
	_strike(dummy, player, _sure(6))
	check(dummy.is_chilled() and is_equal_approx(dummy.status_speed_scale(), 0.6), "Frost hit chills: movement x0.6")
	check(dummy._tempo() > 1.0, "chilled enemies wind up slower")
	await get_tree().create_timer(2.7, false).timeout
	check(not dummy.is_chilled() and dummy.status_speed_scale() == 1.0, "chill wears off")
	# Obsidian: api gelap menurunkan DEF selama terbakar.
	check(dummy.defense() == 4, "enemy DEF starts at 4")
	_strike(dummy, player, _sure(9))
	check(dummy.is_burning() and dummy.defense() == 2, "Obsidian dark fire burns and halves DEF")
	dummy._burn_left = 0.01
	await get_tree().create_timer(0.2, false).timeout
	check(dummy.defense() == 4, "DEF returns when the dark fire ends")
	# Shadow: serap jiwa.
	player.data.restore_hp()
	player.data.damage_hp(30)
	var hp_before := player.data.hp
	_strike(dummy, player, WeaponTierFx.for_tier(7), 20)
	check(player.data.hp == hp_before + 3, "Shadow hit heals 15%% of ATK (%d -> %d)" % [hp_before, player.data.hp])
	player.data.restore_hp()
	# Fairy: berkah peri.
	player.combat.reset()
	player.combat.spend(40.0)
	var st_before := player.combat.stamina
	_strike(dummy, player, WeaponTierFx.for_tier(8))
	check(is_equal_approx(player.combat.stamina, st_before + 6.0), "Fairy hit restores 6 combat stamina (%.1f -> %.1f)" % [st_before, player.combat.stamina])
	player.combat.reset()
	# Terbakar sampai mati tetap memberi kematian normal.
	dummy.hp = 2
	_strike(dummy, player, _sure(5), 1)
	await get_tree().create_timer(1.2, false).timeout
	check(dummy.is_dead(), "burning can finish off an enemy")
	if is_instance_valid(dummy):
		dummy.queue_free()
