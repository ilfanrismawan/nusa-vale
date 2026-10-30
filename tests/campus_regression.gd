extends Node

## Fungsi ruangan Sekolah & Universitas (Campus / CampusStation): batas harian,
## konfirmasi, biaya, EXP, Kartu Mahasiswa, ujian, lab, pesanan sekolah dan save.

var failures := 0

func check(value: bool, caption: String) -> void:
	if value:
		print("PASS: " + caption)
	else:
		failures += 1
		push_error("FAIL: " + caption)

func stations(room: Node) -> Dictionary:
	var result := {}
	for node in room.find_children("*", "StaticBody2D", true, false):
		if node is CampusStation:
			result[node.name] = node
	return result

func player_in(room: Node) -> Player:
	for node in room.find_children("*", "CharacterBody2D", true, false):
		if node is Player:
			return node
	return null

func open(path: String) -> Node2D:
	var room := load(path).instantiate() as Node2D
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	await get_tree().process_frame
	await get_tree().process_frame
	return room

func press_twice(station: CampusStation, player: Player) -> void:
	station.interact(player)
	station.interact(player)

func hold(player: Player, item_id: String) -> void:
	var data := player.data
	var slot := data.hotbar_page * 8 + player.tool_controller.current_index
	data.inventory[slot] = null
	data.inventory[slot] = {"item": GameState._resolve_item(item_id), "count": 3}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	DayCycle.current_day = 1
	DayCycle.hour = 9
	DayCycle.minute = 0
	GameState.money = 100000

	# ── Universitas ──
	var uni := await open("res://scenes/world/interior/university.tscn")
	var found := stations(uni)
	var player := player_in(uni)
	check(player != null, "university has a player")
	var data := player.data
	var kinds := {}
	for station: CampusStation in found.values():
		kinds[station.station] = true
		check(station.has_method("_" + station.station), "%s has handler %s" % [station.name, station.station])
		if station.station == "shop":
			check(station.shop_data != null and station.shop_data.stock.all(func(item: ItemData): return item.buy_price > 0), "%s sells priced stock" % station.name)
	for kind in ["lecture", "library_read", "self_study", "market_pc", "student_card", "shop", "exam", "database", "lab", "rest"]:
		check(kinds.has(kind), "university room function present: " + kind)

	# Kuliah umum: konfirmasi, biaya, waktu, EXP, sekali sehari.
	var lecture: CampusStation = found["LectureTeacherDesk"]
	var role := Campus.topic_role()
	var money := GameState.money
	var points := data.skills.get_points(role)
	lecture.interact(player)
	check(GameState.money == money and data.skills.get_points(role) == points, "first press only shows the lecture offer")
	lecture.interact(player)
	check(GameState.money == money - Campus.LECTURE_FEE, "lecture charges the fee")
	check(data.skills.get_points(role) == points + Campus.LECTURE_EXP, "lecture grants today's role EXP")
	check(DayCycle.hour == 11, "lecture takes two hours")
	money = GameState.money
	press_twice(found["LectureBoard"], player)
	check(GameState.money == money, "lecture board shares the once-per-day limit")
	DayCycle.hour = 18
	DayCycle.current_day = 2
	press_twice(lecture, player)
	check(GameState.money == money, "lecture closed outside class hours")
	DayCycle.hour = 9

	# Perpustakaan: satu bacaan sehari untuk semua rak.
	var shelf: CampusStation = found["LibShelfTop1"]
	points = data.skills.get_points(shelf.role_id)
	shelf.interact(player)
	check(data.skills.get_points(shelf.role_id) == points + Campus.READ_EXP, "library shelf grants reading EXP")
	var other: CampusStation = found["LibShelfSideL1"]
	points = data.skills.get_points(other.role_id)
	other.interact(player)
	check(data.skills.get_points(other.role_id) == points, "library reading is once per day across shelves")

	# Belajar mandiri: role paling tertinggal, memakai stamina.
	var weakest := Campus.weakest_role(data)
	check(weakest != role, "self study targets a role other than the one just lectured")
	points = data.skills.get_points(weakest)
	var stamina := data.stamina
	press_twice(found["StudyTable1"], player)
	check(data.stamina == stamina - Campus.STUDY_STAMINA and data.skills.get_points(weakest) == points + Campus.STUDY_EXP, "self study spends stamina for weakest-role EXP")

	# Kartu Mahasiswa membuka lab & ujian dan memotong biaya kuliah.
	hold(player, "carrot")
	var lab: CampusStation = found["LabTable1"]
	points = data.skills.get_points(&"farmer")
	press_twice(lab, player)
	check(data.skills.get_points(&"farmer") == points, "lab is locked without a student card")
	money = GameState.money
	press_twice(found["ServicesCounter"], player)
	check(Campus.has_card(data) and GameState.money == money - Campus.CARD_PRICE, "student card bought at services desk")
	check(Campus.lecture_fee(data) == Campus.LECTURE_FEE / 2, "card halves the lecture fee")
	var carrot := GameState._resolve_item("carrot")
	press_twice(lab, player)
	check(data.skills.get_points(&"farmer") == points + Campus.lab_exp(carrot) and Campus.is_analyzed("carrot"), "lab analysis grants EXP once per sample type")
	check(data.get_item_count("carrot") == 2, "lab consumes one sample")
	points = data.skills.get_points(&"farmer")
	press_twice(lab, player)
	check(data.skills.get_points(&"farmer") == points and data.get_item_count("carrot") == 2, "same sample type cannot be analyzed twice")

	# Ujian sertifikasi: Token Talenta sekali per role per tingkat.
	var exam: CampusStation = found["ClassBoard"]
	check(Campus.next_exam(data).is_empty(), "no exam before Lv 5")
	data.skills.add_points(&"miner", SkillSystem.points_for_level(5))
	data.skills.apply_levels()
	var tokens := data.skills.tokens
	money = GameState.money
	press_twice(exam, player)
	check(data.skills.tokens == tokens + 1 and GameState.money == money - Campus.EXAMS[5], "Lv 5 certification costs its fee and grants a talent token")
	press_twice(exam, player)
	check(data.skills.tokens == tokens + 1, "a certification cannot be taken twice")

	# Istirahat: sekali sehari, hanya bila stamina belum penuh.
	data.stamina = 10
	found["AtriumBenchL"].interact(player)
	check(data.stamina == 10 + Campus.REST_STAMINA, "bench restores stamina")
	found["WaitingChair1"].interact(player)
	check(data.stamina == 10 + Campus.REST_STAMINA, "rest is once per day across benches")
	uni.queue_free()
	await get_tree().process_frame

	# ── Sekolah ──
	DayCycle.current_day = 3
	DayCycle.hour = 9
	var school := await open("res://scenes/world/interior/school_v2.tscn")
	found = stations(school)
	player = player_in(school)
	data = player.data
	for kind in ["lesson", "guest_teacher", "library_read", "school_request", "rest"]:
		check(found.values().any(func(s: CampusStation): return s.station == kind), "school room function present: " + kind)
	role = Campus.topic_role()
	points = data.skills.get_points(role)
	found["Blackboard"].interact(player)
	found["Blackboard"].interact(player)
	check(data.skills.get_points(role) == points + Campus.LESSON_EXP, "blackboard lesson grants EXP once per day")

	# Guru tamu: honor per level keahlian terbaik, sekali sepekan.
	data.stamina = data.max_stamina
	money = GameState.money
	press_twice(found["TeacherDesk"], player)
	var level := data.skills.level(Campus.best_role(data))
	check(GameState.money == money + level * Campus.TEACH_PAY_PER_LEVEL, "guest teaching pays per level of best role")
	money = GameState.money
	DayCycle.current_day += 3
	press_twice(found["TeacherDesk"], player)
	check(GameState.money == money, "guest teaching has a weekly cooldown")

	# Pesanan makan siang: musiman, dibayar di atas harga jual.
	var request := Campus.school_request()
	var wanted := GameState._resolve_item(request[0])
	check(wanted != null and wanted.season == "spring", "spring school request asks for a spring crop")
	data.add_item_silent(request[0], request[1])
	money = GameState.money
	press_twice(found["Counter"], player)
	check(GameState.money == money + Campus.request_pay(wanted, request[1]) and data.get_item_count(request[0]) == 0, "school lunch request pays for the delivery")
	check(Campus.request_pay(wanted, request[1]) > wanted.sell_price * request[1], "request pays more than shipping")
	for season in 4:
		for option in Campus.SCHOOL_REQUESTS[season]:
			check(GameState._resolve_item(option[0]) != null, "request item exists: " + str(option[0]))

	# Save/load.
	var save := SaveManager._build_save_data()
	check(Campus.valid_save(save.get("campus")), "campus progress is saved")
	GameState.campus = {}
	Campus.load_save(save["campus"])
	check(Campus.has_card(data) and Campus.is_analyzed("carrot"), "campus progress survives save/load")
	check(not Campus.valid_save({"x": "bad"}) and not Campus.valid_save([]), "invalid campus save is rejected")
	school.queue_free()

	print("CAMPUS REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
