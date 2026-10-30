extends Node

## Progres Horor Tahap 1 (GDD 4.1): Tingkat Gaib dari progres, filter kejadian per tingkat,
## Kesulitan Gaib per save (v27), mode Hanya Suasana, dan aksesibilitas jumpscare/efek layar.

var failures := 0


func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)


func _ready() -> void:
	# Menulis user://settings.cfg: hanya di folder data terisolasi milik tools/verify_mvp.ps1.
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	get_tree().current_scene = null
	await get_tree().process_frame
	var horror := GameState.horror
	GameState.new_game()
	DayCycle.is_running = false
	_check_tiers(horror)
	_check_difficulty(horror)
	_check_save(horror)
	_check_events()
	_check_tuyul(horror)
	await _check_world(horror)
	# Biarkan world, tween, dan suara yang dibebaskan selesai sebelum keluar.
	for i in 10:
		await get_tree().process_frame
	print("HORROR PROGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)


func _check_tiers(horror: HorrorManager) -> void:
	check(horror.tier() == 1 and horror.difficulty().id == &"normal", "new game starts at Tingkat Gaib 1 on Normal")
	check(horror.profile().stalkers.size() == 1 and not horror.profile().fear_effects, "tier 1 only lets the Kuntilanak stalk on its own, fear has no gameplay effect")
	DayCycle.current_day = 57
	check(horror.tier() == 2 and horror.profile().stalkers.size() == 4 and horror.profile().fear_effects, "third season of year 1 reaches tier 2 with Pocong, Genderuwo, Banaspati and fear effects")
	DayCycle.current_day = 1
	UnlockManager.set_unlock("deep_forest", true)
	check(horror.tier() == 2, "Deep Forest unlock reaches tier 2")
	UnlockManager.set_unlock("deep_forest", false)
	GameState.cave.deepest_floor = 50
	check(horror.tier() == 3, "cave floor 50 reaches tier 3")
	GameState.cave.deepest_floor = 80
	check(horror.tier() == 4, "cave floor 80 reaches tier 4")
	GameState.cave.deepest_floor = 0
	DayCycle.current_day = 113
	check(horror.tier() == 3, "year 2 reaches tier 3")
	DayCycle.current_day = 169
	check(horror.tier() == 4, "year 2 fall reaches tier 4")
	DayCycle.current_day = 1
	horror.forced_tier = 3
	check(horror.tier() == 3, "debug can force a tier")
	horror.forced_tier = 0
	check(horror.tier() == 1, "tier follows progress again after debug")
	# Pesan pagi saat tingkat baru tercapai, sekali saja.
	horror.notified_tier = 1
	DayCycle.current_day = 57
	DayCycle.day_passed.emit(57)
	check(horror.notified_tier == 2, "reaching a new tier is announced once")
	DayCycle.day_passed.emit(58)
	check(horror.notified_tier == 2, "the same tier is not announced again")
	DayCycle.current_day = 1


func _check_difficulty(horror: HorrorManager) -> void:
	var night: Node = load("res://scenes/effects/night_horror.tscn").instantiate()
	add_child(night)
	DayCycle.current_day = 57
	var expected := {&"ambience": [0.0, 0], &"calm": [0.15, 10], &"normal": [0.35, 25], &"dread": [0.45, 40], &"nightmare": [0.6, 50]}
	for id: StringName in expected:
		horror.set_difficulty(id)
		var chance: float = night.stalker_chance()
		var penalty: int = night.scaled_penalty(25)
		check(absf(chance - float(expected[id][0])) < 0.01 and penalty == int(expected[id][1]), "%s: tier-2 stalker chance %.2f and Kuntilanak penalty %d" % [id, chance, penalty])
	horror.set_difficulty(&"nightmare")
	check(horror.difficulty().jumpscare_can_faint, "only Mimpi Buruk lets a jumpscare cause fainting")
	horror.set_difficulty(&"calm")
	check(night.fear_rise_scale() < 1.0, "Tenang slows fear")
	horror.set_difficulty(&"normal")
	night.queue_free()
	DayCycle.current_day = 1


func _check_save(horror: HorrorManager) -> void:
	horror.set_difficulty(&"dread")
	horror.notified_tier = 3
	var saved: Dictionary = SaveManager._build_save_data()
	check(int(saved.version) >= 27 and saved.has("horror") and SaveManager._is_valid_save(saved), "save v27 stores the horror state")
	horror.set_difficulty(&"normal")
	horror.load_save(saved.horror)
	check(horror.difficulty().id == &"dread" and horror.notified_tier == 3, "difficulty and announced tier survive a round trip")
	var malformed := saved.duplicate(true)
	malformed.horror = {"difficulty": 5}
	check(not SaveManager._is_valid_save(malformed), "malformed horror data is rejected")
	horror.load_save({})
	check(horror.difficulty().id == &"normal" and horror.notified_tier == horror.tier(), "older saves load as Normal without a late tier message")
	horror.load_save({"difficulty": "unknown"})
	check(horror.difficulty().id == &"normal", "unknown difficulty falls back to Normal")
	# Aksesibilitas berlaku untuk semua save (settings.cfg), bukan bagian save.
	horror.set_jumpscare_mode(HorrorManager.Jumpscare.OFF)
	horror.set_screen_effects(false)
	var config := ConfigFile.new()
	config.load(HorrorManager.SETTINGS_PATH)
	config.set_value("audio", "master_volume", 0.5)
	config.save(HorrorManager.SETTINGS_PATH)
	horror.set_jumpscare_mode(HorrorManager.Jumpscare.NO_FACE)
	config = ConfigFile.new()
	config.load(HorrorManager.SETTINGS_PATH)
	check(int(config.get_value("horror", "jumpscare", -1)) == HorrorManager.Jumpscare.NO_FACE and config.get_value("audio", "master_volume", 0.0) == 0.5, "accessibility saves without wiping other settings")
	horror.jumpscare_mode = HorrorManager.Jumpscare.FULL
	horror.screen_effects = true
	horror.load_accessibility()
	check(horror.jumpscare_mode == HorrorManager.Jumpscare.NO_FACE and not horror.screen_effects, "accessibility reloads from settings")
	check(not saved.horror.has("jumpscare") and not saved.horror.has("screen_effects"), "accessibility is not stored per save")
	horror.set_jumpscare_mode(HorrorManager.Jumpscare.FULL)
	horror.set_screen_effects(true)
	horror.set_difficulty(&"normal")


func _check_events() -> void:
	var night: Node = load("res://scenes/effects/night_horror.tscn").instantiate()
	add_child(night)
	night.fear = 1.0
	var tier_two := {}
	for tier in [1, 2]:
		GameState.horror.forced_tier = tier
		var seen := {}
		for i in 200:
			night._last_fired.clear()
			var e: HorrorEvent = night._pick_event(1.0)
			if e != null:
				seen[e.id] = e.min_tier
		var too_high := seen.values().any(func(min_tier: int) -> bool: return min_tier > tier)
		check(not seen.is_empty() and not too_high, "tier %d only picks events allowed at that tier" % tier)
		if tier == 2:
			tier_two = seen
	check(tier_two.has(&"red_eyes") or tier_two.has(&"shadow_dash") or tier_two.has(&"whisper_name"), "tier 2 unlocks the stronger events")
	GameState.horror.forced_tier = 0
	night.queue_free()


func _check_world(horror: HorrorManager) -> void:
	var world: Node = load("res://scenes/world/balai_nadi/balai.tscn").instantiate()
	# Solo: Player.world_root() = current_scene (harus anak langsung root).
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	for i in 10:
		await get_tree().process_frame
	var night: Node = null
	for node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if node.has_method("spawn_stalker"):
			night = node
			break
	check(night != null and is_instance_valid(night.player), "NightHorror is attached to the player HUD")
	if night == null:
		return
	var data: PlayerData = night.player.data
	DayCycle.hour = 0
	DayCycle.minute = 30
	horror.set_difficulty(&"dread")
	data.stamina = data.max_stamina
	var stalker: Node2D = night.spawn_stalker(0)
	check(stalker != null, "debug spawn still works from the full catalog")
	night.stalker_touched(stalker)
	stalker.queue_free()
	check(data.max_stamina - data.stamina == 40, "Mencekam: Kuntilanak touch costs 40 energy")
	check(night._jumpscare.visible, "full jumpscare shows the face")
	night._jumpscare.visible = false
	night._flash.visible = false
	horror.jumpscare_mode = HorrorManager.Jumpscare.OFF
	horror.screen_effects = false
	horror.set_difficulty(&"ambience")
	data.stamina = data.max_stamina
	night._glitch = 0.0
	stalker = night.spawn_stalker(1)
	night.stalker_touched(stalker)
	stalker.queue_free()
	check(not night._jumpscare.visible and not night._flash.visible and night._glitch == 0.0, "jumpscare OFF shows no face, flash, or glitch")
	check(data.stamina == data.max_stamina, "Hanya Suasana has no energy penalty")
	check(not night.allow_shake(), "screen effects off disables horror camera shake")
	await get_tree().process_frame
	night._safe = false
	night.fear = 1.0
	night._stalker_ready_at = 0.0
	night._stalker_timer = 0.0
	for i in 20:
		night._update_stalker(1.0, 1.0)
		night._stalker_timer = 0.0
	check(night.current_stalker() == null, "Hanya Suasana never spawns stalkers on its own")
	horror.jumpscare_mode = HorrorManager.Jumpscare.FULL
	horror.screen_effects = true
	horror.set_difficulty(&"normal")
	await _check_stage_two(horror, night, world)
	await _check_stage_three(horror, night)
	await _check_stage_five(horror, night, world)
	await _check_stage_six(horror, night, world)
	DayCycle.hour = 12
	world.queue_free()


## Tahap 2: aturan Genderuwo/Banaspati/MOVE_WHEN_WATCHED dan dampak rasa takut tingkat 2.
func _check_stage_two(horror: HorrorManager, night: Node, world: Node) -> void:
	var player: Player = night.player
	var feet := player.global_position + Player.FEET_OFFSET
	# Genderuwo: tidak melihat pemain yang diam, tidak takut cahaya/tatapan.
	var genderuwo := night.spawn_stalker(2) as NightStalker
	check(genderuwo != null and genderuwo.rule == NightStalker.Rule.BLIND_TO_STILL and not genderuwo.repelled_by_light, "Genderuwo is blind to stillness and ignores light")
	check(genderuwo._should_move(true), "Genderuwo keeps moving while watched")
	player.velocity = Vector2(30, 0)
	check(genderuwo._goal(feet, 0.1) == feet and genderuwo._can_grab(), "Genderuwo hunts a moving player")
	player.velocity = Vector2.ZERO
	var goal := genderuwo._goal(feet, 1.5)
	check(goal != feet and goal.distance_to(feet) <= genderuwo.wander_radius + 1.0 and not genderuwo._can_grab(), "a still player is lost: Genderuwo sniffs around and cannot grab")
	genderuwo.free()
	# Banaspati: muncul di cahaya, hanya memburu pemain yang berada di cahaya.
	var lamp := PointLight2D.new()
	lamp.texture = PlaceholderTexture2D.new()
	world.add_child(lamp)
	lamp.global_position = feet + Vector2(80, 0)
	night._collect_lights(world)
	var saved_lights: Array = night._lights.duplicate()
	night._lights.clear()
	check(night._spawn_scene(night.stalker_scenes[3], true) == null, "Banaspati cannot spawn without a lit light nearby")
	night._lights.assign(saved_lights)
	var banaspati := night._spawn_scene(night.stalker_scenes[3], true) as NightStalker
	check(banaspati != null and banaspati.rule == NightStalker.Rule.ATTRACTED_TO_LIGHT and banaspati.home.distance_to(feet) <= banaspati.light_search_radius, "Banaspati spawns at a light near the player")
	night._lit = true
	check(banaspati._goal(feet, 0.1) == feet and banaspati._can_grab(), "Banaspati hunts a player standing in light")
	night._lit = false
	banaspati._goal(feet, 0.1)
	check(not banaspati._can_grab(), "Banaspati cannot grab a player in the dark")
	banaspati._goal(feet, banaspati.lose_track_time)
	check(banaspati._leaving, "Banaspati loses track and leaves after the player stays in the dark")
	banaspati.free()
	lamp.free()
	night._collect_lights(world)
	# Kebalikan Kuntilanak (Sundel Bolong, Tahap 5).
	var reverse := night.stalker_scenes[0].instantiate() as NightStalker
	reverse.rule = NightStalker.Rule.MOVE_WHEN_WATCHED
	check(reverse._should_move(true) and not reverse._should_move(false), "MOVE_WHEN_WATCHED only moves while watched")
	reverse.free()
	# Dampak rasa takut: tingkat 2+, bukan Hanya Suasana, tidak di tingkat 1.
	night.fear = 1.0
	horror.forced_tier = 2
	night._update_fear_effects(0.0)
	check(is_equal_approx(player.data.fear_stamina_multiplier, 1.1) and is_equal_approx(player.fear_run_multiplier, 0.85), "tier 2 full fear: stamina +10%, run -15%")
	night.fear = 0.7
	night._update_fear_effects(0.0)
	check(is_equal_approx(player.data.fear_stamina_multiplier, 1.1) and player.fear_run_multiplier == 1.0, "fear 0.7 costs stamina but running stays normal")
	horror.forced_tier = 1
	night.fear = 1.0
	night._update_fear_effects(0.0)
	check(player.data.fear_stamina_multiplier == 1.0 and player.fear_run_multiplier == 1.0, "tier 1 fear has no gameplay effect")
	horror.forced_tier = 2
	horror.set_difficulty(&"ambience")
	night._update_fear_effects(0.0)
	check(player.data.fear_stamina_multiplier == 1.0, "Hanya Suasana fear has no gameplay effect")
	horror.set_difficulty(&"normal")
	horror.forced_tier = 0
	night.fear = 0.0
	night._update_fear_effects(0.0)
	await get_tree().process_frame


## Tahap 3: Kemenyan, Jimat, makanan penenang, material malam, dan Catatan Gaib.
func _check_stage_three(horror: HorrorManager, night: Node) -> void:
	var player: Player = night.player
	var data := player.data
	var feet := player.global_position + Player.FEET_OFFSET
	horror.set_difficulty(&"normal")
	# Resep: Kemenyan & Jimat di crafting, Wedang Kantil di dapur.
	var catalog: CraftingCatalog = load("res://resources/crafting/catalog.tres")
	var crafted := {}
	for recipe in catalog.recipes:
		crafted[recipe.output_item_id] = recipe.ingredients
	check(crafted.has("kemenyan") and crafted["kemenyan"].has("resin") and crafted.has("jimat_penolak"), "Kemenyan (resin) and Jimat are craftable")
	var wedang := CookingManager.get_recipe("wedang_kantil")
	check(wedang != null and wedang.ingredients.has("bunga_kantil"), "Wedang Kantil is a cooking recipe using Bunga Kantil")
	var jimat: ItemData = load("res://resources/item_data/jimat_penolak.tres")
	var materials := 0
	for id: String in crafted["jimat_penolak"]:
		materials += (load("res://resources/item_data/%s.tres" % id) as ItemData).sell_price * int(crafted["jimat_penolak"][id])
	check(jimat.sell_price <= materials * 1.2, "Jimat sells for at most 1.2x its materials")
	# Kemenyan: zona aman portabel, bukan cahaya.
	data.add_item("kemenyan", 1)
	var slot := -1
	for i in data.bag_size:
		if data.inventory[i] != null and data.inventory[i].item.item_id == "kemenyan":
			slot = i
	check(HorrorWard.ignite(player, slot) and not data.has_item("kemenyan"), "burning Kemenyan consumes it")
	await get_tree().process_frame
	check(night.in_incense(feet) and not night.in_incense(feet + Vector2(200, 0)), "incense covers the area around the player")
	night._safe_check = 0.0
	night._refresh_safe(0.1)
	check(night._safe and night.is_near_light() == night.is_lit(player.global_position), "incense is safe but does not count as light for Banaspati")
	var genderuwo := night.spawn_stalker(2) as NightStalker
	genderuwo.global_position = feet + Vector2(30, 0)
	genderuwo._process(0.1)
	check(genderuwo._leaving, "incense drives off even the light-proof Genderuwo")
	genderuwo.free()
	player.get_node(NodePath(HorrorWard.NODE_NAME)).free()
	# Jimat: makhluk membeku 1 detik setelah pemain berpaling.
	data.equipment["accessory"] = jimat
	check(is_equal_approx(night.charm_delay(), 1.0), "equipped Jimat gives a 1 s charm delay")
	var kunti := night.stalker_scenes[0].instantiate() as NightStalker
	kunti.setup(player, night)
	kunti._unwatched = 0.5
	check(not kunti._should_move(false), "with Jimat the Kuntilanak stays frozen right after you look away")
	kunti._unwatched = 1.2
	check(kunti._should_move(false), "it moves again after the charm delay")
	data.equipment["accessory"] = null
	kunti._unwatched = 0.0
	check(kunti._should_move(false), "without Jimat it moves immediately")
	kunti.free()
	# Makanan penenang.
	night.player.data.clear_food_effects()
	var base_scale: float = night.fear_rise_scale()
	data.apply_food_effect(load("res://resources/cooking/effects/calm.tres"))
	check(is_equal_approx(night.fear_rise_scale(), base_scale * 0.7), "calming tea slows fear by 30%")
	var tea: ItemData = load("res://resources/item_data/chamomile_tea.tres")
	check(tea.food_effects.any(func(e: FoodEffectData) -> bool: return e.id == &"calm"), "herbal teas carry the calm effect")
	data.clear_food_effects()
	# Selamat dari makhluk: material malam + Catatan Gaib; tersentuh = tidak ada.
	horror.journal.clear()
	var before := data.get_item_count("bunga_kantil")
	var survivor := night.spawn_stalker(0) as NightStalker
	survivor._life = survivor.lifetime - survivor.survive_after - 1.0
	night._on_stalker_finished(survivor)
	check(data.get_item_count("bunga_kantil") == before + 1 and horror.survived_count(&"kuntilanak") == 1, "surviving a Kuntilanak gives Bunga Kantil and a journal entry")
	survivor.free()
	var early := night.spawn_stalker(0) as NightStalker
	night._on_stalker_finished(early)
	check(horror.survived_count(&"kuntilanak") == 1, "a stalker that just appeared does not count as survived")
	early.free()
	var grabbed := night.spawn_stalker(1) as NightStalker
	grabbed._life = 0.0
	grabbed.set_meta(&"touched", true)
	night._on_stalker_finished(grabbed)
	check(data.get_item_count("embun_kubur") == 0 and horror.survived_count(&"pocong") == 0, "being touched gives no reward")
	grabbed.free()
	horror.set_difficulty(&"ambience")
	var calm := night.spawn_stalker(2) as NightStalker
	calm._life = 0.0
	night._on_stalker_finished(calm)
	check(data.get_item_count("bulu_genderuwo") == 0, "Hanya Suasana gives no ghost materials")
	calm.free()
	horror.set_difficulty(&"normal")
	var text: String = load("res://scripts/ui/inventory_settings.gd").journal_text()
	check("(1/9)" in text and "Kuntilanak" in text and "???" in text, "Catatan Gaib lists known ghosts and hides unknown ones")
	var saved := horror.to_save()
	horror.journal.clear()
	horror.load_save(saved)
	check(horror.survived_count(&"kuntilanak") == 1, "Catatan Gaib survives a save round trip")
	check(not HorrorManager.valid_save({"journal": {"kuntilanak": -1}}) and not HorrorManager.valid_save({"journal": []}), "malformed journal is rejected")
	horror.journal.clear()
	await get_tree().process_frame


## Tahap 4: Tuyul mencuri sekali per malam, Sesajen mencegahnya, jejak dan laporan pagi.
func _check_tuyul(horror: HorrorManager) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var day := DayCycle.current_day
	var money_before := GameState.money
	GameState.shipping.pending.clear()
	horror.set_difficulty(&"normal")
	horror.forced_tier = 2
	DayCycle.hour = 2
	horror.theft_day = 0
	GameState.money = 1000
	var report := horror.try_tuyul(rng)
	check(GameState.money == 950 and "50 G" in report, "Normal: Tuyul steals 5% of money")
	check(horror.try_tuyul(rng).is_empty() and GameState.money == 950, "Tuyul steals only once per night")
	check(horror.tracks_visible(), "tracks are visible on the night of the theft")
	DayCycle.current_day = day + 1
	DayCycle.hour = 8
	check(horror.tracks_visible(), "tracks remain the next morning")
	DayCycle.hour = 13
	check(not horror.tracks_visible(), "tracks fade after noon")
	DayCycle.current_day = day
	DayCycle.day_passed.emit(day + 1)
	check(horror.theft_report.is_empty(), "the morning report is shown once")
	DayCycle.hour = 2
	horror.theft_day = 0
	GameState.money = 100000
	report = horror.try_tuyul(rng)
	check(GameState.money == 99500, "the money theft is capped at 500 G on Normal")
	# Shipping Bin: satu baris, nilai maksimal 500 G.
	horror.theft_day = 0
	GameState.money = 0
	GameState.shipping.pending.append({"id": "bunga_kantil", "name": "Bunga Kantil", "price": 60, "count": 20})
	report = horror.try_tuyul(rng)
	check(int(GameState.shipping.pending[0].count) == 12 and "8 Bunga Kantil" in report, "Tuyul takes at most 500 G worth from one Shipping Bin row")
	GameState.shipping.pending.clear()
	horror.theft_day = 0
	GameState.shipping.pending.append({"id": "gold_bar", "name": "Gold Bar", "price": 750, "count": 3})
	report = horror.try_tuyul(rng)
	check(int(GameState.shipping.pending[0].count) == 3 and not "Gold Bar" in report, "Tuyul cannot carry a single item worth more than the cap")
	GameState.shipping.pending.clear()
	horror.set_difficulty(&"dread")
	horror.theft_day = 0
	GameState.money = 100000
	horror.try_tuyul(rng)
	check(GameState.money == 99250, "Mencekam raises the cap to 750 G")
	for id: StringName in [&"calm", &"ambience"]:
		horror.set_difficulty(id)
		horror.theft_day = 0
		GameState.money = 1000
		check(horror.try_tuyul(rng).is_empty() and GameState.money == 1000, "%s: Tuyul never steals" % id)
	horror.set_difficulty(&"normal")
	horror.forced_tier = 1
	horror.theft_day = 0
	check(horror.try_tuyul(rng).is_empty() and GameState.money == 1000, "tier 1: no Tuyul yet")
	horror.forced_tier = 2
	DayCycle.hour = 0
	horror.theft_day = 0
	check(horror.try_tuyul(rng).is_empty(), "Tuyul waits until 01.00")
	DayCycle.hour = 2
	StructureManager.records.append({"item": "sesajen_tuyul", "cell": [0, 0], "uid": 999999})
	check(horror.try_tuyul(rng).is_empty() and GameState.money == 1000, "Sesajen Penangkal Tuyul on the farm prevents theft")
	StructureManager.records.pop_back()
	check(StructureManager.IDS.has("sesajen_tuyul") and StructureManager.DECOR.has("sesajen_tuyul") and (load("res://resources/item_data/sesajen_tuyul.tres") as ItemData).placeable, "Sesajen is a placeable decoration")
	var catalog: CraftingCatalog = load("res://resources/crafting/catalog.tres")
	check(catalog.recipes.any(func(r: CraftingRecipe) -> bool: return r.output_item_id == "sesajen_tuyul"), "Sesajen is craftable")
	horror.theft_day = 5
	horror.theft_report = "laporan"
	var saved := horror.to_save()
	horror.load_save(saved)
	check(horror.theft_day == 5 and horror.theft_report == "laporan" and HorrorManager.valid_save(saved), "Tuyul state survives a save round trip")
	check(not HorrorManager.valid_save({"theft_report": 3}), "malformed Tuyul state is rejected")
	horror.theft_day = 0
	horror.theft_report = ""
	horror.forced_tier = 0
	DayCycle.hour = 6
	GameState.money = money_before


## Tahap 5: dua makhluk sekaligus, Sundel Bolong, Leak (cahaya kuat), Keris Pusaka, Pagar Gaib, Nyali.
func _check_stage_five(horror: HorrorManager, night: Node, world: Node) -> void:
	var player: Player = night.player
	var feet := player.global_position + Player.FEET_OFFSET
	horror.set_difficulty(&"normal")
	check(GameState.horror.profiles[1].max_stalkers == 1 and GameState.horror.profiles[2].max_stalkers == 2 and GameState.horror.profiles[3].max_stalkers == 2, "tier 3+ allows two stalkers at once")
	var ids: Array = GameState.horror.profiles[2].stalkers.map(func(p: PackedScene) -> String: return p.resource_path.get_file())
	check("sundel_bolong.tscn" in ids and "leak.tscn" in ids and not "leak.tscn" in GameState.horror.profiles[1].stalkers.map(func(p: PackedScene) -> String: return p.resource_path.get_file()), "Sundel Bolong and Leak appear from tier 3")
	# Dua makhluk sekaligus, tidak lebih.
	for old in night.stalkers():
		old.free()
	horror.forced_tier = 3
	night.fear = 1.0
	night._safe = false
	night._lit = false
	night._stalker_ready_at = 0.0
	var most := 0
	for i in 80:
		night._stalker_timer = 0.0
		night._update_stalker(1.0, 1.0)
		most = maxi(most, night.stalkers().size())
	check(most == 2, "tier 3 spawns up to two stalkers and no more (most=%d)" % most)
	for old in night.stalkers():
		old.free()
	horror.forced_tier = 0
	# Sundel Bolong: hanya bergerak saat ditatap.
	var sundel := night.spawn_stalker(4) as NightStalker
	check(sundel.rule == NightStalker.Rule.MOVE_WHEN_WATCHED and sundel._should_move(true) and not sundel._should_move(false), "Sundel Bolong only moves while watched")
	sundel.free()
	# Leak: lentera biasa ditembus, api besar mengusirnya.
	var lamp := PointLight2D.new()
	lamp.texture = PlaceholderTexture2D.new()
	world.add_child(lamp)
	lamp.global_position = feet
	night._collect_lights(world)
	var leak := night.spawn_stalker(5) as NightStalker
	leak.global_position = feet + Vector2(40, 0)
	check(leak.strong_light_only and not leak._light_repels(), "Leak ignores an ordinary lamp")
	lamp.add_to_group(&"horror_strong_light")
	check(leak._light_repels(), "a strong fire (bonfire/fireplace) repels Leak")
	leak.free()
	lamp.free()
	night._collect_lights(world)
	check(StructureManager.DECOR.bonfire.get("strong_light", false) and StructureManager.DECOR.fireplace_stone.get("strong_light", false), "bonfire and fireplaces count as strong light")
	# Keris Pusaka: tatap 1,5 detik = terusir.
	var keris: ItemData = load("res://resources/item_data/keris_pusaka.tres")
	var data := player.data
	var saved_slot: Variant = data.inventory[0]
	data.inventory[0] = {"item": keris, "count": 1}
	data.hotbar_page = 0
	player.tool_controller.select_tool(0)
	check(is_equal_approx(night.keris_gaze(), 1.5), "holding Keris Pusaka enables the banishing gaze")
	night._lights.clear()
	player.facing_direction = Vector2.RIGHT
	var kunti := night.spawn_stalker(0) as NightStalker
	kunti.global_position = feet + Vector2(40, 0)
	kunti._process(0.8)
	kunti._process(0.8)
	check(kunti._leaving, "staring 1.5 s with the Keris banishes a stalker")
	kunti.free()
	data.inventory[0] = saved_slot
	player.tool_controller.select_tool(0)
	check(night.keris_gaze() == 0.0, "without the Keris the gaze does nothing special")
	var catalog: CraftingCatalog = load("res://resources/crafting/catalog.tres")
	var outputs: Array = catalog.recipes.map(func(r: CraftingRecipe) -> String: return r.output_item_id)
	check("keris_pusaka" in outputs and "tugu_pagar_gaib" in outputs and keris.weapon_type == ItemData.WeaponType.SWORD, "Keris Pusaka and Tugu Pagar Gaib are craftable")
	# Tugu Pagar Gaib: farm aman dari makhluk dan Tuyul.
	StructureManager.records.append({"item": "tugu_pagar_gaib", "cell": [0, 0], "uid": 999998})
	check(horror.has_farm_ward() and horror.has_tuyul_ward() and not night.farm_warded(), "Tugu Pagar Gaib protects the farm (not this map) and stops Tuyul")
	StructureManager.records.pop_back()
	check(StructureManager.DECOR.has("tugu_pagar_gaib") and (load("res://resources/item_data/tugu_pagar_gaib.tres") as ItemData).placeable, "Tugu Pagar Gaib is a placeable decoration")
	# Nyali (Combat Lv6).
	var before_scale: float = night.fear_rise_scale()
	var saved_levels: Dictionary = data.skills.levels.duplicate()
	data.skills.levels[&"combat"] = 6
	data.skills._mark_dirty()
	check(is_equal_approx(night.fear_resist(), 0.25) and is_equal_approx(night.fear_rise_scale(), before_scale * 0.75), "Nyali (Combat Lv6) slows fear by 25%")
	data.skills.levels = saved_levels
	data.skills._mark_dirty()
	check(night.fear_resist() == 0.0, "without the perk there is no fear resistance")
	# Catatan Gaib penuh (6 makhluk + 3 Penunggu) tetap muat di halaman kanan Pengaturan.
	for id in ["kuntilanak", "pocong", "genderuwo", "banaspati", "sundel_bolong", "leak", "penunggu_hutan", "penunggu_gunung", "penunggu_gua"]:
		horror.journal[id] = 1
	var full: String = load("res://scripts/ui/inventory_settings.gd").journal_text()
	var journal: Label = player.ui_inventory._settings_panel._journal
	journal.text = full
	await get_tree().process_frame
	var used := journal.get_line_count() * journal.get_line_height()
	check("(9/9)" in full and used <= journal.size.y, "a full Catatan Gaib fits one page (%d px of %d)" % [used, journal.size.y])
	horror.journal.clear()
	await get_tree().process_frame


## Tahap 6: Malam Jumat Kliwon, ketukan pintu, dan ritual Penunggu di tiga altar.
func _check_stage_six(horror: HorrorManager, night: Node, world: Node) -> void:
	var player: Player = night.player
	var data := player.data
	var day := DayCycle.current_day
	horror.set_difficulty(&"normal")
	# Tas bersih (kecuali alat) agar barang dari tahap sebelumnya tidak memenuhi tas.
	for i in data.bag_size:
		if data.inventory[i] != null and not (data.inventory[i].item as ItemData).is_tool():
			data.inventory[i] = null
	# Kliwon = Kamis minggu ke-4 = hari ke-25 tiap musim.
	check(horror.is_kliwon(25) and horror.is_kliwon(53) and not horror.is_kliwon(24) and not horror.is_kliwon(18), "Malam Jumat Kliwon falls on day 25 of every season")
	DayCycle.current_day = 25
	horror.forced_tier = 1
	check(horror.night_tier() == 1, "Kliwon does not touch early-game (tier 1) players")
	horror.forced_tier = 2
	check(horror.night_tier() == 4 and horror.profile().tier == 4, "on Kliwon a tier-2 player faces every tier-4 ghost")
	horror.journal.clear()
	var before := data.get_item_count("bunga_kantil")
	var survivor := night.spawn_stalker(0) as NightStalker
	survivor._life = 0.0
	night._on_stalker_finished(survivor)
	check(data.get_item_count("bunga_kantil") == before + 2, "Kliwon doubles night materials")
	survivor.free()
	DayCycle.current_day = day
	horror.forced_tier = 0
	horror.journal.clear()
	# Ketukan pintu: hanya di dalam rumah, tingkat malam 4.
	DayCycle.hour = 1
	horror.forced_tier = 4
	check(not night.knock_allowed(), "no knocking outside the house")
	night.knock()
	horror.forced_tier = 0
	# Altar terpasang di tiga area.
	for entry in [["res://scenes/world/DeepForest.tscn", "kayu_keramat"], ["res://scenes/world/mountain.tscn", "batu_keramat"], ["res://scenes/world/cave/cave.tscn", "kristal_keramat"]]:
		var state: SceneState = (load(entry[0]) as PackedScene).get_state()
		var found := false
		for i in state.get_node_count():
			if state.get_node_name(i) == &"AltarPenunggu":
				for p in state.get_node_property_count(i):
					if state.get_node_property_name(i, p) == &"reward_item" and state.get_node_property_value(i, p) == entry[1]:
						found = true
		check(found, "%s has a Penunggu altar rewarding %s" % [entry[0].get_file(), entry[1]])
	# Ritual: syarat, sesajen, tiga titik, bertahan, hadiah.
	var altar := RitualAltar.new()
	altar.penunggu_scene = load("res://scenes/horror/penunggu_hutan.tscn")
	world.add_child(altar)
	altar.global_position = player.global_position + Vector2(0, 40)
	horror.forced_tier = 2
	check(not altar.start_blocker().is_empty(), "the altar sleeps below tier 3")
	horror.forced_tier = 3
	DayCycle.hour = 12
	check(not altar.start_blocker().is_empty(), "rituals only start after midnight")
	DayCycle.hour = 1
	check(altar.start_blocker().is_empty(), "tier 3 after midnight: the altar answers")
	altar.interact(player)
	check(altar.phase == RitualAltar.Phase.IDLE, "without offerings nothing happens")
	data.add_item("kemenyan", 3)
	data.add_item("bunga_kantil", 2)
	var kantil := data.get_item_count("bunga_kantil")
	altar.interact(player)
	check(altar.phase == RitualAltar.Phase.LIGHTING and data.get_item_count("bunga_kantil") == kantil - 2 and not data.has_item("kemenyan") and altar._points.size() == 3, "offerings are consumed and three incense points appear")
	for point in altar._points:
		point.interact(player)
	check(altar.phase == RitualAltar.Phase.ENDURE and is_instance_valid(altar.penunggu) and altar.penunggu in night.stalkers(), "lighting all three points summons the Penunggu")
	check(altar.penunggu.ignores_incense and altar.penunggu.lifetime > altar.endure_seconds, "the Penunggu ignores incense and outlasts the ritual")
	var reward_before := data.get_item_count("kayu_keramat")
	altar.time_left = 0.0
	altar._process(0.1)
	check(altar.phase == RitualAltar.Phase.IDLE and data.get_item_count("kayu_keramat") == reward_before + 1 and horror.survived_count(&"penunggu_hutan") == 1, "enduring the ritual gives Kayu Keramat and a journal entry")
	check(not altar.start_blocker().is_empty(), "one successful ritual per area per night")
	# Gagal: disentuh Penunggu.
	altar.area_id = "uji"
	data.add_item("kemenyan", 3)
	data.add_item("bunga_kantil", 2)
	altar.interact(player)
	for point in altar._points:
		point.interact(player)
	check(is_instance_valid(altar.penunggu), "a second ritual can be started on another altar")
	if not is_instance_valid(altar.penunggu):
		return
	altar.penunggu.set_meta(&"touched", true)
	reward_before = data.get_item_count("kayu_keramat")
	altar._process(0.1)
	check(altar.phase == RitualAltar.Phase.IDLE and data.get_item_count("kayu_keramat") == reward_before and horror.survived_count(&"penunggu_hutan") == 1, "being touched fails the ritual without reward")
	horror.set_difficulty(&"ambience")
	altar.area_id = "uji2"
	check(not altar.start_blocker().is_empty(), "Hanya Suasana has no rituals")
	horror.set_difficulty(&"normal")
	altar.free()
	for old in night.stalkers():
		old.free()
	var catalog: CraftingCatalog = load("res://resources/crafting/catalog.tres")
	var recipes := {}
	for recipe in catalog.recipes:
		recipes[recipe.output_item_id] = recipe.ingredients
	check(recipes["keris_pusaka"].has("kayu_keramat") and recipes["tugu_pagar_gaib"].has("batu_keramat") and recipes["tugu_pagar_gaib"].has("kristal_keramat"), "sacred altar rewards feed the Keris and the Tugu")
	var saved := horror.to_save()
	horror.ritual_day.clear()
	horror.load_save(saved)
	check(horror.ritual_day.has("hutan") and HorrorManager.valid_save(saved) and not HorrorManager.valid_save({"ritual_day": []}), "ritual state survives a save round trip")
	horror.ritual_day.clear()
	horror.journal.clear()
	horror.forced_tier = 0
	DayCycle.hour = 0
	await _check_journal_reward(horror, night)


## Catatan Gaib lengkap (keputusan pemilik: hadiah langsung, tanpa Balai Nadi).
func _check_journal_reward(horror: HorrorManager, night: Node) -> void:
	var data: PlayerData = night.player.data
	var catalog_ids: Array = []
	for scene: PackedScene in night.stalker_scenes:
		var ghost := scene.instantiate() as NightStalker
		catalog_ids.append(String(ghost.ghost_id))
		ghost.free()
	check(catalog_ids == HorrorManager.JOURNAL_GHOSTS, "JOURNAL_GHOSTS matches the stalker catalog")
	horror.journal.clear()
	horror.journal_rewarded = false
	for id in HorrorManager.JOURNAL_GHOSTS + ["penunggu_hutan", "penunggu_gunung"]:
		horror.journal[id] = 1
	horror.record_survival(&"pocong", "Pocong", data)
	check(not horror.journal_rewarded and not data.has_item("mustika_pemberani"), "no reward while an entry is still missing")
	horror.record_survival(&"penunggu_gua", "Penunggu Gua", data)
	check(horror.journal_rewarded and data.get_item_count("mustika_pemberani") == 1, "completing Catatan Gaib (9/9) gives Mustika Pemberani")
	horror.record_survival(&"leak", "Leak", data)
	check(data.get_item_count("mustika_pemberani") == 1, "the completion reward is given only once")
	var saved := horror.to_save()
	horror.journal_rewarded = false
	horror.load_save(saved)
	check(horror.journal_rewarded and not HorrorManager.valid_save({"journal_rewarded": 1}), "the reward flag survives a save round trip")
	var mustika: ItemData = load("res://resources/item_data/mustika_pemberani.tres")
	data.equipment["accessory"] = mustika
	check(is_equal_approx(night.fear_resist(), 0.3) and is_equal_approx(night.charm_delay(), 1.0), "Mustika Pemberani resists fear and delays frozen ghosts")
	data.equipment["accessory"] = null
	data.remove_item("mustika_pemberani", 1)
	horror.journal.clear()
	horror.journal_rewarded = false
	await get_tree().process_frame
