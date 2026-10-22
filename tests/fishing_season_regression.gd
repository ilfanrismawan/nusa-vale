extends Node

## GDD 5: musim ikan (FishData.seasons) dan air beku di Musim Dingin.
var failures := 0

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func _fish(item_id: String) -> FishData:
	return load("res://resources/fish_data/%s.tres" % item_id) as FishData

func _ready() -> void:
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	DayCycle.hour = 12

	var bone := _fish("fish_bone_fish")
	check(bone.seasons == PackedStringArray(["fall", "winter"]), "bone fish punya musim gugur + dingin")
	check(not bone.is_available("farm_pond", 12, "spring"), "bone fish tidak ada di musim semi")
	check(bone.is_available("farm_pond", 12, "fall"), "bone fish ada di musim gugur")
	check(bone.is_available("farm_pond", 12), "tanpa musim = abaikan musim (kompatibel)")

	var carp := _fish("fish_carp")
	for season in DayCycle.SEASONS:
		check(carp.is_available("farm_pond", 12, season), "carp sepanjang tahun: " + season)

	check(_fish("fish_mas").locations.has("forest_river"), "lokasi ikan mas tanpa spasi")

	# Hari 1 = musim semi: roll tidak boleh memberi ikan di luar musim.
	DayCycle.current_day = 1
	for i in 200:
		var f := FishingManager.roll_catch("farm_pond")
		check(f != null and f.is_in_season("spring"), "roll musim semi hanya ikan musim semi")
		if failures > 0:
			break

	# Spot beku hanya di Musim Dingin, kecuali freezes_in_winter = false.
	var spot := FishingSpot.new()
	add_child(spot)
	var hot := FishingSpot.new()
	hot.freezes_in_winter = false
	add_child(hot)
	check(not spot.is_frozen(), "musim semi: air tidak beku")
	DayCycle.current_day = DayCycle.DAYS_PER_SEASON * 3 + 1
	check(DayCycle.get_season() == DayCycle.Season.WINTER, "hari 85 = musim dingin")
	check(spot.is_frozen(), "musim dingin: air luar beku")
	check(not hot.is_frozen(), "spot khusus tidak beku")
	check(FishingManager.roll_catch("farm_pond") != null, "musim dingin tetap ada ikan di tabel (untuk spot khusus)")

	# Spot khusus musim dingin punya ikan di Musim Dingin.
	for hour in [8, 12, 23]:
		DayCycle.hour = hour
		check(FishingManager.roll_catch("mountain_hot_spring") != null, "air panas Gunung ada ikan dingin jam %d" % hour)
		check(FishingManager.roll_catch("cave_lake") != null, "danau gua ada ikan dingin jam %d" % hour)
	DayCycle.hour = 12

	# Kolam air panas di scene Gunung tidak beku dan bisa ditemukan sebagai spot.
	var mountain: Node2D = load("res://scenes/world/mountain.tscn").instantiate()
	add_child(mountain)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var player: Player = mountain.get_node("Player/CharacterBody2D")
	var spring := mountain.get_node_or_null("HotSpring/FishingSpot") as FishingSpot
	# Gunung tersimpan sebagai node di .tscn (bisa diedit di editor), bukan dibangun dari kode.
	var ground := mountain.get_node_or_null("BaseLayerGround") as TileMapLayer
	var walls := mountain.get_node_or_null("MountainWalls") as TileMapLayer
	check(ground != null and ground.get_used_cells().size() == 40 * 24, "lantai Gunung tersimpan di scene (40x24 ubin)")
	check(walls != null and walls.get_cell_atlas_coords(Vector2i(0, 5)) == Vector2i(11, 1) and walls.get_cell_source_id(Vector2i(19, 23)) == -1, "dinding Gunung tersimpan dan celah ke Hill terbuka")
	check(mountain.get_node("Walls").get_child_count() == 6 and mountain.get_node_or_null("CaveSign") is Label, "tabrakan batas dan papan nama ada sebagai node")
	var mouth := mountain.get_node_or_null("CaveEntrance") as Area2D
	check(mouth != null and mouth.is_in_group("scene_door"), "mulut gua Gunung bisa dimasuki dari dekat (grup scene_door)")
	check(mountain.get_node("HotSpring").get_child_count() == 5, "kolam air panas tidak menggandakan bagian buatan kode")
	check(spring != null, "Gunung punya kolam air panas")
	if spring != null:
		check(spring.location_id == "mountain_hot_spring" and not spring.is_frozen(), "air panas tidak beku di musim dingin")
		check(FishingManager.find_spot_at(player, (spring.get_child(0) as Node2D).global_position) == spring, "tengah kolam air panas bisa dipancing")
	mountain.queue_free()
	await get_tree().process_frame

	# Danau bawah tanah di lantai CaveData.lake_floor.
	var cave_data: CaveData = load("res://resources/cave/cave_data.tres")
	GameState.cave.current_floor = cave_data.lake_floor
	var cave: Node2D = load("res://scenes/world/cave/cave.tscn").instantiate()
	add_child(cave)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var lake := cave.find_child("CaveLake", true, false)
	check(lake != null, "lantai %d punya danau bawah tanah" % cave_data.lake_floor)
	if lake != null:
		var lake_spot := lake.get_node("FishingSpot") as FishingSpot
		check(lake_spot.location_id == "cave_lake" and not lake_spot.is_frozen(), "danau gua tidak beku")
		var cave_player: Player = cave.find_children("*", "CharacterBody2D", true, false).filter(func(n): return n is Player)[0]
		check(FishingManager.find_spot_at(cave_player, (lake_spot.get_child(0) as Node2D).global_position) == lake_spot, "tengah danau gua bisa dipancing")
	cave.build_floor(cave_data.lake_floor - 1)
	check(cave.find_child("CaveLake", true, false) == null or cave.find_child("CaveLake", true, false).is_queued_for_deletion(), "danau hanya di lantai danau")
	cave.queue_free()
	await get_tree().process_frame

	print("FISHING SEASON COMPLETE: failures=%d" % failures)
	# Beri waktu pembaca log (Godot MCP) sebelum keluar.
	await get_tree().create_timer(5.0).timeout
	get_tree().quit(1 if failures else 0)
