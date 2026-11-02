extends Node
## Seruling Kuda (GDD 4.10.10): item di toko Eep, gagal tanpa kuda/di dalam ruangan,
## kuda berlari datang ke sisi pemain dan horse_spot ikut pindah.

var failures := 0

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.current_day = 1
	DayCycle.hour = 8
	DayCycle.is_running = false
	FarmManager.farm_data.clear()

	var flute := GameState._resolve_item("horse_flute")
	check(flute != null and flute.icon != null and flute.buy_price > 0 and not flute.stackable, "item Seruling Kuda ada dengan ikon dan harga")
	var eep: ShopData = load("res://resources/shop/eep_supplies.tres")
	check(eep.stock.any(func(item: ItemData) -> bool: return item.item_id == "horse_flute"), "Seruling Kuda dijual di toko perlengkapan Eep")
	check(load("res://resources/feedback/horse_flute.tres").sound != null, "SFX seruling terpasang")

	var farm: Node2D = load("res://scenes/world/farm.tscn").instantiate()
	get_tree().root.add_child(farm)
	get_tree().current_scene = farm
	await get_tree().physics_frame
	await get_tree().physics_frame
	var player := farm.find_child("CharacterBody2D", true, false) as Player
	if player == null:
		check(false, "pemain ladang tersedia")
		get_tree().quit(1)
		return
	player.set_process(false)
	player.set_physics_process(false)
	player.data.bag_level = 2
	player.data.add_item_silent("wood", 600)
	player.data.add_item_silent("stone", 400)
	GameState.money = 50000

	check(not StructureManager.call_horse(player).ok, "tanpa kuda seruling tidak memanggil apa pun")
	var built := false
	for cell in player.base_layer_ground.get_used_cells():
		if StructureManager.check_construction(player, "barn", cell).ok and StructureManager.commit_construction(player, "barn", cell, false).ok:
			built = true
			break
	check(built, "barn dibangun")
	StructureManager.debug_spawn_horse(null)
	check(not StructureManager.find_horse().is_empty(), "kuda dewasa tersedia")
	await get_tree().process_frame

	# Pemain menjauh dari kuda lalu meniup seruling.
	player.global_position += Vector2(260, 0)
	player.facing_direction = Vector2.RIGHT
	var feet := player.global_position + Player.FEET_OFFSET
	var result := StructureManager.call_horse(player)
	check(result.ok, "seruling memanggil kuda di area luar: " + str(result.message))
	check(str(StructureManager.horse_spot.get("scene", "")) == farm.scene_file_path, "tempat kuda pindah ke area pemain")
	var actor := StructureManager._horse_actor(farm)
	check(actor != null and actor._galloping, "kuda sedang berlari datang")
	check(actor != null and actor.global_position.distance_to(feet) > 60.0, "kuda mulai dari kejauhan")
	actor.interact(player)
	check(not player.has_meta("riding_horse"), "kuda yang masih berlari belum bisa dinaiki")
	await get_tree().create_timer(1.8, true).timeout
	actor = StructureManager._horse_actor(farm)
	check(actor != null and not actor._galloping and actor.global_position.distance_to(feet) < 30.0, "kuda tiba di sisi pemain")
	check(actor != null and actor.flip, "kuda berhenti menghadap pemain")
	check(StructureManager.call_horse(player).message.contains("sudah di sisimu"), "seruling saat kuda dekat tidak memindahkan kuda")

	# Juice: tiupan memunculkan not di atas kepala; cooldown mencegah spam.
	player.remove_meta(&"horse_flute_ms")
	var sprite_frames := player.animation_controller.sprite.sprite_frames
	check(sprite_frames.has_animation(&"flute_down") and sprite_frames.has_animation(&"flute_right") and not sprite_frames.get_animation_loop(&"flute_right"), "animasi meniup seruling ada dan sekali main")
	check(HorseFlute.play(player), "HorseFlute.play berhasil")
	check(String(player.animation_controller.sprite.animation).begins_with("flute_") and player.animation_controller.item_gesture_playing, "pemain memutar pose meniup seruling")
	check(not player._holds_overhead(flute), "seruling tidak diangkat di atas kepala seperti hasil panen")
	check(player.get_children().any(func(n: Node) -> bool: return n is HorseFlute), "not seruling muncul di atas pemain")
	check(not HorseFlute.play(player), "seruling punya jeda tiup")

	await get_tree().create_timer(1.3, true).timeout
	check(not player.animation_controller.item_gesture_playing, "pose seruling selesai dan input kembali")
	# Saat menunggang, seruling tidak berlaku.
	var horse := StructureManager.find_horse()
	check(StructureManager.mount_horse(player, int(horse.uid), int(horse.id)).ok, "kuda yang tiba bisa dinaiki")
	check(not StructureManager.call_horse(player).ok, "seruling tidak berlaku saat menunggang")
	StructureManager.dismount(player, true)

	get_tree().current_scene = self
	farm.queue_free()
	await get_tree().process_frame

	# Peta luar lain: kuda datang ke peta itu. Interior, gua, dan gunung tidak.
	for path in ["res://scenes/world/town.tscn", "res://scenes/world/beach.tscn", "res://scenes/world/hill.tscn",
			"res://scenes/world/Forest.tscn", "res://scenes/world/DeepForest.tscn", "res://scenes/world/balai_nadi/balai.tscn",
			"res://scenes/world/eep_ranch.tscn", "res://scenes/world/university.tscn", "res://scenes/world/mountain.tscn",
			"res://scenes/world/interior/interior_house.tscn", "res://scenes/world/cave/cave.tscn"]:
		await _check_map(path, not (path.contains("/interior/") or path.contains("/cave/") or path.ends_with("mountain.tscn")))

	GameState.new_game()
	await get_tree().create_timer(0.5, true).timeout
	print("HORSE FLUTE REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)

func _check_map(path: String, expect_ok: bool) -> void:
	var name := path.get_file().get_basename()
	var world: Node = load(path).instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	for frame in 4:
		await get_tree().physics_frame
	var player: Player = null
	for node in get_tree().get_nodes_in_group(Combat.PLAYER_GROUP):
		if node is Player and world.is_ancestor_of(node):
			player = node
	if player == null:
		check(false, "%s: pemain tersedia" % name)
	else:
		player.set_process(false)
		player.set_physics_process(false)
		player.facing_direction = Vector2.RIGHT
		var feet := player.global_position + Player.FEET_OFFSET
		var result := StructureManager.call_horse(player)
		if not expect_ok:
			check(not StructureManager.horse_allowed_in(world), "%s: kuda tidak boleh ditunggangi di sini" % name)
			check(not result.ok and StructureManager._horse_actor(world) == null, "%s: seruling ditolak (%s)" % [name, result.message])
		else:
			await get_tree().create_timer(1.8, true).timeout
			var actor := StructureManager._horse_actor(world)
			check(result.ok and actor != null and actor.global_position.distance_to(feet) < 30.0 and not actor._galloping,
				"%s: kuda dipanggil dan tiba di sisi pemain (%s)" % [name, result.message])
	get_tree().current_scene = self
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
