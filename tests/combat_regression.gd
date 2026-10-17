extends Node2D

## Phase 4B-1 Combat: HP, rumus damage, senjata, amunisi, i-frames, musuh, denda tumbang.
## Tidak menulis save ke disk (round trip lewat to_dict/load_dict), jadi aman dijalankan
## tanpa NUSA_SAVE_AUDIT.

var failures := 0

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

## Jendela tes yang tidak fokus bisa memicu jeda otomatis game; tes ini butuh fisika tetap jalan.
func _process(_delta: float) -> void:
	if get_tree().paused:
		get_tree().paused = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DayCycle.is_running = false
	await get_tree().process_frame
	_test_formula()
	_test_player_data()
	_test_penalty()
	await _test_enemy()
	await _test_player_combat()
	print("COMBAT REGRESSION COMPLETE: failures=%d" % failures)
	# Beri waktu pembaca log (debugger MCP) menangkap hasil sebelum jendela tertutup.
	await get_tree().create_timer(4.0).timeout
	get_tree().quit(1 if failures > 0 else 0)

func _test_formula() -> void:
	check(Combat.damage_after_defense(10, 3) == 7, "damage = ATK - DEF")
	check(Combat.damage_after_defense(2, 9) == 1, "damage never drops below 1")
	check(Combat.damage_after_defense(5, -4) == 5, "negative DEF is ignored")
	check(Combat.is_weapon(GameState._resolve_item("sword_wood")) and Combat.is_weapon(GameState._resolve_item("bow_wood")) and Combat.is_weapon(GameState._resolve_item("staff_wood")), "sword, bow and staff are weapons")
	check(not Combat.is_weapon(GameState._resolve_item("arrow_wood")) and not Combat.is_weapon(GameState._resolve_item("axe_wood")), "arrows and tools are not weapons")
	var bow := Combat.style_for(GameState._resolve_item("bow_wood"))
	var staff := Combat.style_for(GameState._resolve_item("staff_wood"))
	var sword := Combat.style_for(GameState._resolve_item("sword_wood"))
	check(bow.uses_ammo and bow.stamina_cost == 0 and is_equal_approx(bow.projectile_range_tiles, 8.0), "bow: arrows, no stamina, 8 tiles")
	check(not staff.uses_ammo and staff.stamina_cost == 3 and is_equal_approx(staff.projectile_range_tiles, 6.0), "staff: no ammo, 3 stamina, 6 tiles")
	check(sword.melee_radius > 0.0 and sword.stamina_cost == 0, "sword: melee, no stamina")

func _test_player_data() -> void:
	var data := PlayerData.new(1)
	data.reset_to_starter()
	check(data.hp == PlayerData.MAX_HP and data.max_hp == 100, "new players start with 100 HP")
	check(data.has_item("sword_wood") and data.equipment_stats() == Vector2i(0, 3) and not data.equipment.has("weapon"), "starter sword sits in the bag; armor gives DEF 3")
	data.damage_hp(30)
	check(data.hp == 70, "damage_hp lowers HP")
	data.damage_hp(500)
	check(data.hp == 0 and data.is_defeated(), "HP clamps at 0")
	data.restore_hp(25)
	check(data.hp == 25, "restore_hp adds HP")
	data.restore_hp()
	check(data.hp == 100, "restore_hp() fills HP")
	data.hp = 42
	var saved := data.to_dict()
	var copy := PlayerData.new(1)
	copy.load_dict(saved)
	check(int(saved.get("hp", -1)) == 42 and copy.hp == 42, "HP survives to_dict/load_dict")
	saved.erase("hp")
	copy.load_dict(saved)
	check(copy.hp == PlayerData.MAX_HP, "old saves without HP load with full HP")
	var old := PlayerData.new(1)
	old.load_equipment({"weapon": "sword_iron", "armor": "armor_wood"})
	check(old.has_item("sword_iron") and old.equipment["armor"] != null and not old.equipment.has("weapon"), "old equipped weapon moves into the bag")
	var archer := PlayerData.new(1)
	archer.add_item_silent("arrow_wood", 5)
	archer.add_item_silent("arrow_iron", 2)
	var slot := Combat.best_arrow_slot(archer)
	check(slot >= 0 and archer.inventory[slot]["item"].item_id == "arrow_iron", "bow uses the strongest arrow in the bag")
	check(Combat.best_arrow_slot(PlayerData.new(1)) == -1, "no arrows found in an empty bag")

func _test_penalty() -> void:
	var data := PlayerData.new(1)
	data.reset_to_starter()
	data.add_item_silent("wood", 10)
	data.add_item_silent("biji_daya_harvest", 1)
	var rules := DefeatRules.new()
	rules.money_penalty_percent = 10
	rules.money_penalty_max = 1000
	rules.item_loss_stacks = 10
	rules.item_loss_fraction = 0.5
	var money_before := GameState.money
	GameState.money = 2000
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var result := DefeatSequence.apply_penalty(data, rules, rng)
	check(int(result.money) == 200 and GameState.money == 1800, "clinic fee takes 10% of shared money")
	check(data.get_item_count("wood") == 5, "lost stacks lose half (rounded up)")
	check(data.has_item("axe_wood") and data.has_item("sword_wood") and data.has_item("biji_daya_harvest"), "tools, weapons and Biji Daya are never lost")
	GameState.money = 50000
	result = DefeatSequence.apply_penalty(data, rules, rng)
	check(int(result.money) == 1000, "clinic fee is capped")
	GameState.money = money_before
	check(Combat.DEFEAT_RULES.clinic_scene.ends_with("clinic.tscn") and Combat.DEFEAT_RULES.respawn_scene.ends_with("interior_house.tscn"), "defeat goes through the clinic and wakes at home")

func _test_enemy() -> void:
	var data: EnemyData = load("res://resources/enemies/slime_green.tres")
	var enemy := Enemy.spawn(data, self, Vector2(200, 200))
	await get_tree().physics_frame
	check(enemy.hp == data.max_hp and enemy.is_in_group(Combat.DAMAGEABLE_GROUP), "enemy spawns with full HP")
	check(enemy.take_hit(5, null), "enemy takes a hit")
	check(enemy.hp == data.max_hp - Combat.damage_after_defense(5, data.defense), "enemy damage uses its DEF")
	check(not enemy.take_hit(5, null), "enemy has brief invulnerability")
	# i-frames musuh dihitung per physics frame; tunggu sampai pukulan diterima lagi (frame lambat saat startup).
	var waited := 0.0
	while not enemy.take_hit(999, null) and waited < 3.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	check(enemy.is_dead() and not enemy.is_in_group(Combat.DAMAGEABLE_GROUP), "enemy dies at 0 HP")
	for enemy_id in ["slime_blue", "myconid_red"]:
		var other: EnemyData = load("res://resources/enemies/%s.tres" % enemy_id)
		check(other != null and ResourceLoader.exists(other.sprite_folder.path_join("Idle.png")), "enemy art exists: " + enemy_id)
	var gel := GameState._resolve_item("slime_gel")
	check(data.drop_item_id == "slime_gel" and gel != null and gel.icon != null, "slimes drop Slime Gel")
	check(data.hit_feedback == &"slime_hit" and Juice.get_feedback(&"slime_hit") != null, "slimes have their own hit sound")
	var weapon_layers := {}
	for sheet in CharacterVisual.CATALOG.sheets:
		if sheet != null and sheet.animation_name in [&"sword", &"archer", &"mage"]:
			weapon_layers[sheet.animation_name] = sheet.tool_type >= CharacterVisual.WEAPON_TIER_KEY_BASE or not sheet.extra_layers.is_empty()
	check(weapon_layers.get(&"sword", false) and weapon_layers.get(&"archer", false) and weapon_layers.get(&"mage", false), "attack animations draw the weapon")

func _test_player_combat() -> void:
	GameState.new_game()
	var rig := (load("res://scenes/player/Player.tscn") as PackedScene).instantiate()
	add_child(rig)
	var player := rig.get_node("CharacterBody2D") as Player
	await get_tree().process_frame
	player.global_position = Vector2(400, 300)
	player.update_facing_direction(Vector2.RIGHT, true)
	var data := player.data
	check(data.hp == 100, "player starts at full HP")
	await get_tree().create_timer(0.8).timeout
	var hud := rig.get_node("HUD")
	var stamina_rect: Rect2 = hud.stamina_bar.get_global_rect()
	var hp_rect: Rect2 = hud.hp_bar.get_global_rect()
	var view_bottom := hud.get_viewport().get_visible_rect().size.y - 16.0
	check(absf(stamina_rect.end.y - view_bottom) <= 1.0 and absf(hp_rect.end.y - view_bottom) <= 1.0 and hp_rect.end.x < stamina_rect.position.x, "HP and stamina bars sit side by side at the bottom (hp %s, stamina %s)" % [hp_rect, stamina_rect])
	var defense := Combat.player_defense(data)
	check(player.take_hit(13, null), "player takes a hit")
	check(data.hp == 100 - Combat.damage_after_defense(13, defense), "player damage subtracts armor DEF")
	check(not player.take_hit(13, null) and player.is_invulnerable(), "i-frames block a second hit")
	var waited := 0.0
	while player.is_invulnerable() and waited < 3.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	check(not player.is_invulnerable(), "i-frames wear off (%.2fs, paused=%s, physics=%s)" % [waited, get_tree().paused, player.is_physics_processing()])
	check(player.take_hit(13, null), "hits land again after i-frames")
	await get_tree().create_timer(Player.HIT_INVULNERABLE + 0.5).timeout

	# Pedang di slot 0 hotbar, slime tepat di depan.
	data.hotbar_page = 0
	data.inventory[0] = {"item": GameState._resolve_item("sword_wood"), "count": 1}
	player.tool_controller.select_tool(0, false)
	check(player.holds_weapon(), "holding a sword from the hotbar")
	var slime := Enemy.spawn(load("res://resources/enemies/slime_green.tres"), self, player.global_position + Player.FEET_OFFSET + Vector2(14, 0))
	slime.data = slime.data.duplicate() as EnemyData
	slime.data.contact_damage = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	var before := slime.hp
	check(player.tool_controller.attack(), "left click attack starts")
	check(player.state_machine.current_state == player.tool_controller.combat_state, "attack enters CombatState")
	await get_tree().create_timer(1.5).timeout
	check(slime.hp < before, "sword hit damages the enemy in front")
	check(player.state_machine.current_state is IdleState, "attack returns to idle")

	# Combo: klik saat menyerang menyambung pukulan; pukulan ketiga adalah finisher.
	var tools := player.tool_controller
	var sword_style := Combat.style_for(GameState._resolve_item("sword_wood"))
	check(sword_style.combo_length() == 3 and sword_style.is_finisher(2) and is_equal_approx(sword_style.combo_damage_at(2), 1.5), "sword combo: 3 hits, finisher deals 150%")
	check(tools.attack() and tools.combat_state.combo_step == 0, "combo starts at hit 1 after a pause")
	for step in [1, 2]:
		tools.combat_state.combo_queued = true
		waited = 0.0
		while tools.combat_state.combo_step != step and waited < 3.0:
			await get_tree().process_frame
			waited += get_process_delta_time()
		check(tools.combat_state.combo_step == step and player.state_machine.current_state == tools.combat_state, "a click during the swing chains hit %d" % (step + 1))
	check(tools.combat_state.is_finisher(), "hit 3 is the finisher")
	await get_tree().create_timer(1.5).timeout
	check(tools.combo_step == 0 and player.state_machine.current_state is IdleState, "combo resets after the finisher")
	var bow_combo := Combat.style_for(GameState._resolve_item("bow_wood"))
	var staff_combo := Combat.style_for(GameState._resolve_item("staff_wood"))
	check(bow_combo.combo_length() == 3 and bow_combo.finisher_projectiles == 2, "bow finisher shoots 2 arrows")
	check(staff_combo.combo_length() == 3 and staff_combo.finisher_projectile_scale > 1.5, "staff finisher casts a big orb")

	# Busur tanpa panah.
	data.inventory[0] = {"item": GameState._resolve_item("bow_wood"), "count": 1}
	for slot in data.bag_size:
		if data.inventory[slot] != null and data.inventory[slot]["item"].weapon_type == ItemData.WeaponType.ARROW:
			data.inventory[slot] = null
	player.tool_controller.select_tool(0, false)
	check(not player.tool_controller.attack(), "bow without arrows does not shoot")
	data.add_item_silent("arrow_wood", 3)
	var bow_style := Combat.style_for(GameState._resolve_item("bow_wood"))
	check(bow_style.aim_pose_frame == 2, "bow has an aim pose (bow drawn)")
	var anim := player.animation_controller
	anim.hold_pose(bow_style.animation_name, bow_style.aim_pose_frame)
	await get_tree().process_frame
	check(anim.sprite.animation.begins_with(String(bow_style.animation_name)) and anim.sprite.frame == 2 and not anim.sprite.is_playing(), "aiming holds the bow-drawn frame")
	# Membidik sambil berjalan: kaki melangkah (animasi gabungan diputar), bukan pose diam.
	# Tanpa menunggu frame: tanpa klik kanan sungguhan Player melepas pose bidik di frame berikutnya.
	anim.hold_pose(bow_style.animation_name, bow_style.aim_pose_frame)
	anim.play(&"walk")
	var walk_anim := anim.sprite.animation
	var walk_frames := anim.sprite.sprite_frames
	check(String(walk_anim).begins_with("aim_move_walk") and anim.sprite.is_playing() and walk_frames.get_frame_count(walk_anim) == walk_frames.get_frame_count(&"walk_down"), "aiming while walking keeps the legs walking")
	var body_same := true
	var legs_differ := false
	var first := walk_frames.get_frame_texture(walk_anim, 0).get_image()
	for i in range(1, walk_frames.get_frame_count(walk_anim)):
		var other := walk_frames.get_frame_texture(walk_anim, i).get_image()
		for x in first.get_width():
			body_same = body_same and first.get_pixel(x, 8) == other.get_pixel(x, 8)
			legs_differ = legs_differ or first.get_pixel(x, 24) != other.get_pixel(x, 24) or first.get_pixel(x, 23) != other.get_pixel(x, 23)
	check(body_same and legs_differ, "walking aim frames: body holds the bow, legs move")
	anim.play(&"idle")
	check(anim.sprite.animation.begins_with(String(bow_style.animation_name)) and anim.sprite.frame == 2 and not anim.sprite.is_playing(), "standing still returns to the held aim pose")
	check(player.tool_controller.attack() and data.get_item_count("arrow_wood") == 2, "bow uses one arrow per shot")
	check(anim.sprite.is_playing() and not anim.release_pose(), "shooting releases the aim pose")
	await get_tree().create_timer(1.5).timeout

	# Tongkat sihir memakai 3 stamina.
	data.inventory[0] = {"item": GameState._resolve_item("staff_wood"), "count": 1}
	player.tool_controller.select_tool(0, false)
	data.stamina = 50
	var staff_style := Combat.style_for(GameState._resolve_item("staff_wood"))
	check(staff_style.aim_pose_frame == 2, "staff has an aim pose (staff raised)")
	player.animation_controller.hold_pose(staff_style.animation_name, staff_style.aim_pose_frame)
	await get_tree().process_frame
	check(player.animation_controller.sprite.animation.begins_with("mage") and player.animation_controller.sprite.frame == 2, "aiming holds the staff-raised frame")
	player.animation_controller.hold_pose(staff_style.animation_name, staff_style.aim_pose_frame)
	player.animation_controller.play(&"run")
	check(String(player.animation_controller.sprite.animation).begins_with("aim_move_run") and player.animation_controller.sprite.is_playing(), "aiming the staff while running keeps the legs running")
	player.animation_controller.play(&"idle")
	check(player.tool_controller.attack() and data.stamina == 47, "staff costs 3 stamina")
	await get_tree().create_timer(1.5).timeout
	data.stamina = 2
	check(not player.tool_controller.attack(), "staff needs enough stamina")

	# Tombol debug Ctrl+F6 / Ctrl+F10: senjata langsung dipegang di slot hotbar aktif.
	player._debug_hold_weapon("staff_wood")
	check(player.tool_controller.current_item != null and player.tool_controller.current_item.item_id == "staff_wood", "debug key puts the staff in hand")
	player._debug_hold_weapon("bow_wood")
	check(player.tool_controller.current_item != null and player.tool_controller.current_item.item_id == "bow_wood", "debug key puts the bow in hand")

	# Juice: efek hanya visual; pastikan bisa dipanggil tanpa error dan sinyal lelah terkirim.
	var exhausted := [false]
	data.stamina_exhausted.connect(func(): exhausted[0] = true)
	data.stamina = 0
	check(not data.spend_stamina(3) and exhausted[0], "running out of stamina signals the HUD")
	await get_tree().process_frame
	await get_tree().process_frame
	var faint: DefeatSequence
	for node in get_tree().root.get_children():
		if node is DefeatSequence:
			faint = node
	check(player.is_defeated and faint != null and faint.exhausted, "stamina 0 makes the player faint")
	# Hentikan sebelum pindah scene (tes tidak boleh meninggalkan scene ini).
	if faint != null:
		faint.free()
	player.finish_defeat()
	data.stamina = 50
	CombatJuice.blood(player.global_position, Vector2.RIGHT, 10)
	CombatJuice.sweat(player)
	CombatJuice.slash(player, Vector2.RIGHT, 14.0, 14.0, true)
	CombatJuice.combo_text(player, 3, true)
	CombatJuice.damage_number("12!", player.global_position, CombatJuice.HEAVY_COLOR, true)
	CombatJuice.death_burst(player.global_position, Color.GREEN)
	CombatJuice.zoom_punch(player)
	await get_tree().create_timer(0.6).timeout
	check(not CombatJuice.heavy_hit and is_equal_approx(Engine.time_scale, 1.0), "juice leaves no heavy flag or slow motion behind")
	rig.queue_free()
