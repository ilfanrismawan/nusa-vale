extends Node

## Tes regresi otomatis untuk sistem NPC, Schedule, Waypoint Pathing, Animasi, dan Portrait.

var failures := 0

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame

	print("--- MEMULAI TES REGRESI SISTEM NPC & SCHEDULE ---")

	# 1. Tes loading scene-scene NPC
	var rian_scene: PackedScene = load("res://scenes/npc/RianNPC.tscn")
	var bahar_scene: PackedScene = load("res://scenes/npc/BaharNPC.tscn")
	var ratih_scene: PackedScene = load("res://scenes/npc/RatihNPC.tscn")
	var chef_scene: PackedScene = load("res://scenes/npc/ChefNPC.tscn")
	var tori_scene: PackedScene = load("res://scenes/npc/ToriNPC.tscn")
	var ubay_scene: PackedScene = load("res://scenes/npc/UbayNPC.tscn")

	check(rian_scene != null, "Scene RianNPC dapat dimuat")
	check(bahar_scene != null, "Scene BaharNPC dapat dimuat")
	check(ratih_scene != null, "Scene RatihNPC dapat dimuat")
	check(chef_scene != null, "Scene ChefNPC dapat dimuat")
	check(tori_scene != null, "Scene ToriNPC dapat dimuat")
	check(ubay_scene != null, "Scene UbayNPC dapat dimuat")

	var npc_scenes: Array = [rian_scene, bahar_scene, ratih_scene, chef_scene, tori_scene, ubay_scene]
	var required_anims: Array[String] = ["idle_down", "idle_side", "idle_up", "walk_down", "walk_side", "walk_up"]

	for scn in npc_scenes:
		var npc: VillageNPC = scn.instantiate() as VillageNPC
		add_child(npc)
		await get_tree().process_frame

		check(not npc.npc_name.is_empty(), "NPC memiliki nama: " + npc.npc_name)
		check(npc.portrait != null, "NPC %s memiliki texture Portrait" % npc.npc_name)
		check(npc.schedule.size() > 0, "NPC %s memiliki data jadwal harian (schedule)" % npc.npc_name)

		# Verifikasi animasi
		if npc.sprite != null and npc.sprite.sprite_frames != null:
			for anim in required_anims:
				check(npc.sprite.sprite_frames.has_animation(anim), "NPC %s memiliki animasi '%s'" % [npc.npc_name, anim])
		else:
			check(false, "NPC %s memiliki AnimatedSprite2D valid" % npc.npc_name)

		npc.queue_free()
		await get_tree().process_frame

	# 2. Tes Logika Schedule & Pathing Waypoint
	var rian: VillageNPC = rian_scene.instantiate() as VillageNPC
	add_child(rian)
	await get_tree().process_frame

	# Jam 06:00 -> Padang rumput peternakan (450, 490)
	rian._check_schedule_for_time(6, 0, true)
	check(rian.global_position == Vector2(450, 490), "Rian berada di posisi jadwal pagi (450, 490)")
	check(not rian._is_walking, "Rian tidak berjalan saat tiba di tujuan pagi")

	# Jam 11:30 -> Berjalan ke Warung Makan (880, 420) melalui waypoints
	rian._check_schedule_for_time(11, 30, false)
	check(rian._is_walking, "Rian beralih ke state berjalan saat jadwal 11:30 aktif")
	check(rian._active_path.size() > 0, "Rian memiliki daftar waypoint aktif menuju warung")
	check(rian._target_pos == Vector2(880, 420), "Target akhir Rian adalah Vector2(880, 420)")

	# Simulasikan pergerakan physics beberapa langkah
	var initial_pos: Vector2 = rian.global_position
	for i in range(10):
		rian._physics_process(0.1)
	check(rian.global_position != initial_pos, "Posisi Rian berpindah selama proses pergerakan waypoint")

	# 3. Tes Dialog & Interaksi (Pause gerak saat bicara)
	var pre_talk_pos: Vector2 = rian.global_position
	var dialog_npc: VillageNPC = ubay_scene.instantiate() as VillageNPC
	get_tree().root.add_child(dialog_npc)
	dialog_npc.interact(null)
	check(is_instance_valid(dialog_npc._dialog_ui), "NPCDialogUI berhasil dibuka saat pemain berinteraksi")
	dialog_npc._physics_process(0.1)
	check(dialog_npc.velocity == Vector2.ZERO, "Kecepatan NPC menjadi 0 saat sedang diajak bicara")

	# Tutup dialog
	if is_instance_valid(dialog_npc._dialog_ui):
		dialog_npc._dialog_ui._close()
	check(dialog_npc._dialog_ui == null, "Dialog UI tertutup dan state NPC ter-reset")

	rian.queue_free()
	dialog_npc.queue_free()
	await get_tree().process_frame

	print("--- HASIL TES REGRESI SISTEM NPC: failures = %d ---" % failures)
	if failures == 0:
		print("NPC REGRESSION COMPLETE: failures=0")
		get_tree().quit(0)
	else:
		push_error("NPC REGRESSION GAGAL dengan %d error" % failures)
		get_tree().quit(1)
