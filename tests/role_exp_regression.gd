extends Node

## GDD 13: Role & EXP (level, perk, cabang A/B, token, buku, save v22).
var failures := 0

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: " + label)

func _ready() -> void:
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	var p1 := GameState.p1()

	# Data role.
	var roles := SkillSystem.roles()
	check(roles.size() == 7, "7 role dimuat")
	for role in roles:
		check(role.icon != null and not role.title.is_empty(), "role %s punya ikon dan judul" % role.role_id)
		check(role.has_choice(5) and role.has_choice(10), "role %s punya cabang Lv5 dan Lv10" % role.role_id)
		check(not role.perks_at(1).is_empty(), "role %s punya perk Lv1" % role.role_id)
	check(SkillSystem.level_for_points(99) == 0 and SkillSystem.level_for_points(100) == 1, "ambang Lv1 = 100 EXP")
	check(SkillSystem.level_for_points(2150) == 5 and SkillSystem.level_for_points(15000) == 10, "ambang Lv5 dan Lv10")
	check(SkillSystem.level_for_points(999999) == 10, "level maksimal 10")

	# EXP langsung, level aktif setelah tidur.
	SkillSystem.gain(p1, &"farmer", 120)
	check(p1.skills.get_points(&"farmer") == 120 and p1.skills.level(&"farmer") == 0, "EXP masuk, level belum aktif sebelum tidur")
	check(p1.skills.ready_to_level(&"farmer"), "siap naik level")
	SkillSystem.gain(p1, &"farmer", 0.4)
	SkillSystem.gain(p1, &"farmer", 0.7)
	check(p1.skills.get_points(&"farmer") == 121, "EXP pecahan dijumlah")
	DayCycle.advance_day()
	check(p1.skills.level(&"farmer") == 1, "tidur menaikkan level")
	var hoe := ToolData.new()
	hoe.tool_type = ToolData.ToolType.HOE
	check(SkillSystem.tool_cost(p1, hoe, 10) == 9, "Farmer Lv1: stamina cangkul -10%")

	# Cabang Lv5.
	p1.skills.points["farmer"] = 2150
	p1.skills.apply_levels()
	check(p1.skills.level(&"farmer") == 5, "Lv5 aktif")
	check(p1.skills.pending_choices().size() == 1, "Lv5 menunggu pilihan cabang")
	check(SkillSystem.stat(p1, &"crop_growth") == 0.0, "cabang belum aktif sebelum dipilih")
	check(p1.skills.choose(&"farmer", 5, "a"), "pilih Agronomist")
	check(not p1.skills.choose(&"farmer", 5, "b"), "cabang tidak bisa diganti")
	check(is_equal_approx(SkillSystem.stat(p1, &"crop_growth"), 0.15), "Agronomist aktif")
	check(is_equal_approx(SkillSystem.stat(p1, &"farm_tool_stamina"), 0.25), "Farmer Lv1-4 total -25%")

	# Combat: HP maks naik.
	p1.skills.points["combat"] = 6900
	p1.skills.apply_levels()
	check(p1.max_hp == PlayerData.MAX_HP + 60, "Combat Lv8: HP maks +60")

	# Harga.
	var fish := ItemData.new()
	fish.item_id = "audit_fish"
	fish.category = ItemData.Category.FISH
	fish.sell_price = 100
	fish.buy_price = 100
	p1.skills.points["economist"] = 770
	p1.skills.points["merchant"] = 770
	p1.skills.apply_levels()
	check(SkillSystem.sell_price(p1, fish, true) == 110, "Economist Lv3: Shipping Bin +10%")
	check(SkillSystem.sell_price(p1, fish, false) == 105, "Merchant Lv2: jual di toko +5%")
	check(SkillSystem.buy_price(p1, fish, 1, 100) == 90, "Merchant Lv3: diskon 10%")
	check(SkillSystem.facility_price(p1, 1000) == 1000, "diskon fasilitas belum ada sebelum Lv6")

	# Shipping Bin: harga terkunci memakai bonus + EXP Economist.
	var before := p1.skills.get_points(&"economist")
	GameState.shipping.deposit(fish, 4, p1)
	check(int(GameState.shipping.pending[0].price) == 110, "kiriman memakai harga role")
	check(p1.skills.get_points(&"economist") == before + 29, "440 G shipment gives 29 Economist EXP with fractional carry")

	# Token Talenta.
	p1.skills.tokens = 1
	check(p1.skills.use_token(&"fisher") and p1.skills.get_points(&"fisher") == 100 and p1.skills.tokens == 0, "token = EXP sampai level berikutnya")
	check(not p1.skills.use_token(&"fisher"), "token habis")

	# Buku riset.
	var book := GameState._resolve_item("skill_book_miner")
	check(book != null and book.skill_book_role == "miner" and book.skill_book_exp == 250, "buku riset Miner ada")
	GameState.add_item(book, 1)
	var slot := -1
	for i in p1.bag_size:
		if p1.inventory[i] != null and p1.inventory[i]["item"] == book:
			slot = i
	check(SkillSystem.read_book(p1, slot) and p1.skills.get_points(&"miner") == 250 and not p1.has_item("skill_book_miner"), "membaca buku: +250 EXP dan buku terpakai")
	var library := load("res://resources/shop/library_books.tres") as ShopData
	check(library != null and library.stock.size() == 7, "Perpustakaan menjual 7 buku")

	# Co-op: tiap pemain terpisah.
	var p2 := PlayerData.new(1)
	SkillSystem.gain(p2, &"fisher", 400)
	check(p2.skills.get_points(&"fisher") == 400 and p1.skills.get_points(&"fisher") == 100, "EXP co-op per pemain")
	var copy := PlayerData.new(1)
	copy.load_dict(p2.to_dict())
	check(copy.skills.get_points(&"fisher") == 400, "karakter co-op menyimpan skills")

	# Save v22.
	check(SaveManager.SAVE_VERSION >= 25, "current save includes household and permanent friendships")
	var saved := SaveManager._build_save_data()
	check(saved.player.has("skills"), "save memuat skills")
	p1.skills.reset()
	SaveManager._apply_save(saved)
	check(p1.skills.level(&"farmer") == 5 and p1.skills.choice(&"farmer", 5) == "a", "skills kembali setelah load")
	check(p1.skills.get_points(&"miner") == 250, "EXP kembali setelah load")
	var old_save: Dictionary = saved.duplicate(true)
	old_save.player.erase("skills")
	SaveManager._apply_save(old_save)
	check(p1.skills.level(&"farmer") == 0 and p1.skills.get_points(&"farmer") == 0, "save lama = Lv0")
	var broken := {"points": {"farmer": -5, "fisher": "x"}, "levels": {"farmer": 9}, "choices": {"farmer:5": "c"}, "tokens": -2}
	p1.skills.load_dict(broken)
	check(p1.skills.get_points(&"farmer") == 0 and p1.skills.level(&"farmer") == 0 and p1.skills.tokens == 0, "nilai save rusak diabaikan")

	# Balai Nadi: Village Treasurer.
	p1.skills.points["economist"] = 2150
	p1.skills.apply_levels()
	p1.skills.choose(&"economist", 5, "a")
	check(SkillSystem.balai_requirement("wood", 100) == 85 and SkillSystem.balai_requirement("money", 1000) == 1000, "Treasurer: bahan -15%, uang tetap")

	GameState.skills.reset()
	GameState.new_game()
	check(GameState.p1().skills.get_points(&"farmer") == 0, "game baru mengosongkan skills")
	print("ROLE EXP REGRESSION COMPLETE: failures=%d" % failures)
	# Beri waktu pembaca log (Godot MCP) sebelum keluar.
	await get_tree().create_timer(5.0).timeout
	get_tree().quit(1 if failures else 0)
