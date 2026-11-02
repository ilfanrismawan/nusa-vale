extends Node
## Regresi tab Kalender: logika CalendarEvents, halaman InventoryCalendar, dan tab di buku inventory.
## Tidak menulis save. Snapshot opsional: NUSA_CALENDAR_SCREENSHOT=1 (bukan headless) menyimpan
## gambar ke user://calendar_*.png.

const PAGE := preload("res://scenes/ui/inventory_calendar.tscn")
const INVENTORY := preload("res://scenes/ui/ui_inventory.tscn")

var failures := 0


func check(value: bool, message: String) -> void:
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func settle() -> void:
	for frame in 5:
		await get_tree().process_frame


func capture(node: CanvasItem, file_name: String) -> void:
	if OS.get_environment("NUSA_CALENDAR_SCREENSHOT") != "1" or DisplayServer.get_name() == "headless":
		return
	await settle()
	await RenderingServer.frame_post_draw
	var path := OS.get_user_data_dir().path_join(file_name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("snapshot: " + path)


func _cell_kinds(cell: CalendarCell) -> int:
	return cell.get_node("%Markers").get_child_count()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# SaveManager memuat save secara deferred saat start; tunggu agar state uji tidak tertimpa.
	await get_tree().create_timer(0.6, true).timeout
	GameState.new_game()
	DayCycle.is_running = false
	var p1 := GameState.p1()
	p1.player_name = "Sari"
	p1.birthday_season = "spring"
	p1.birthday_day = 10

	# ── Logika tanggal ──
	check(CalendarEvents.weekday_index(1) == 0 and CalendarEvents.weekday_name(1) == "Senin", "hari 1 = Senin")
	check(CalendarEvents.weekday_index(29) == 0, "tanggal 1 tiap musim selalu Senin")
	check(CalendarEvents.season_of(29) == 1 and CalendarEvents.day_of_season(29) == 1, "hari 29 = 1 Musim Panas")
	check(CalendarEvents.year_of(113) == 2 and CalendarEvents.season_serial(113) == 4, "hari 113 = Semi tahun 2")
	check(CalendarEvents.date_text(25) == "Kamis, 25 Musim Semi", "teks tanggal lengkap")

	# ── Acara ──
	check(NPCSocialService.birthday_of("kirana") == {"season": "spring", "day": 17}, "ulang tahun Kirana terbaca dari data JSON")
	var kirana_day := CalendarEvents.events_for(p1, 17)
	check(kirana_day.any(func(e): return e.kind == CalendarEvents.KIND_BIRTHDAY and e.id == "kirana"), "17 Semi menampilkan ulang tahun Kirana")
	check(CalendarEvents.events_for(p1, 10).any(func(e): return e.kind == CalendarEvents.KIND_PLAYER_BIRTHDAY), "ulang tahun pemain tampil di 10 Semi")
	check(CalendarEvents.events_for(p1, 3).filter(func(e): return e.kind == CalendarEvents.KIND_BIRTHDAY).size() == 2, "dua warga berulang tahun di 3 Semi")
	check(CalendarEvents.events_for(p1, 2).is_empty(), "2 Semi tanpa acara")
	check("Toko Umum" in CalendarEvents.closed_services(3) and CalendarEvents.closed_services(5).is_empty(), "Rabu: Toko Umum tutup; Jumat: semua buka")

	GameState.horror.forced_tier = 1
	check(not CalendarEvents.kliwon_known(), "Kliwon tersembunyi sebelum tingkat gaib 2")
	GameState.horror.forced_tier = 2
	var kliwon_visible := CalendarEvents.kliwon_known()
	check(kliwon_visible == not GameState.horror.difficulty().ambience_only, "Kliwon terlihat mulai tingkat gaib 2 (kecuali mode suasana)")
	check(CalendarEvents.is_kliwon(25) and not CalendarEvents.is_kliwon(18), "Kliwon jatuh di Kamis 25, bukan Kamis 18")
	var upcoming := CalendarEvents.upcoming(p1, 1, 28, 3)
	check(upcoming.size() == 3 and int(upcoming[0].day) == 3, "acara mendatang urut tanggal dan dibatasi")

	# ── Halaman ──
	DayCycle.current_day = 31 # 3 Musim Panas (Rabu)
	var page := PAGE.instantiate()
	page.position = Vector2(20, 20)
	page.scale = Vector2.ONE * 2.0
	add_child(page)
	page.refresh()
	await settle()
	var cells: Array = page.get_node("%Days").get_children()
	check(cells.size() == 28, "grid musim berisi 28 sel")
	check(page.get_node("%SeasonTitle").text == "Musim Panas · Tahun 1", "judul musim mengikuti hari ini")
	check((cells[2] as CalendarCell).is_today and cells[2].button_pressed, "sel hari ini terpilih saat tab dibuka")
	check((cells[0] as CalendarCell).is_past and not (cells[5] as CalendarCell).is_past, "hari lewat ditandai")
	check(_cell_kinds(cells[2]) == 1, "3 Panas (Ubay) punya penanda ulang tahun")
	check(page.get_node("%DateTitle").text == "Rabu, 3 Musim Panas", "detail menampilkan tanggal terpilih")
	check(page.get_node("%Closed").text.contains("Toko Umum"), "detail menampilkan layanan tutup")
	check(page.get_node("%Upcoming").get_child_count() > 0, "daftar akan datang terisi")
	await capture(page, "calendar_summer")

	page.get_node("%NextSeason").pressed.emit()
	await settle()
	check(page.get_node("%SeasonTitle").text == "Musim Gugur · Tahun 1", "tombol musim berikutnya")
	cells = page.get_node("%Days").get_children()
	(cells[24] as CalendarCell).pressed.emit()
	await settle()
	check(_cell_kinds(cells[24]) == (2 if kliwon_visible else 1), "25 Gugur: ulang tahun Baskoro + Kliwon")
	check(page.get_node("%Events").get_child_count() == (2 if kliwon_visible else 1), "detail 25 Gugur menampilkan semua acara")
	check(page.get_node("%DateSub").text.contains("hari lagi"), "detail menyebut jarak hari")
	await capture(page, "calendar_fall_kliwon")

	page.get_node("%PrevSeason").pressed.emit()
	page.get_node("%PrevSeason").pressed.emit()
	await settle()
	check(page.get_node("%PrevSeason").disabled, "tidak bisa mundur sebelum Semi tahun 1")
	page.get_node("%TodayButton").pressed.emit()
	await settle()
	check(page.get_node("%SeasonTitle").text == "Musim Panas · Tahun 1", "tombol Hari ini kembali ke musim berjalan")
	page.queue_free()

	# ── Integrasi buku inventory ──
	var inventory := INVENTORY.instantiate()
	add_child(inventory)
	await settle()
	inventory._open()
	inventory.get_node("%TabCalendar").pressed.emit()
	await settle()
	var calendar_page: Control = inventory.get_node("%CalendarPage")
	check(calendar_page.visible and not inventory.get_node("%RelationshipPage").visible, "tab Kalender membuka halaman kalender")
	check(inventory.get_node("%TabCalendar").texture_normal == inventory.TEX_TAB_ACTIVE, "tab Kalender disorot aktif")
	await capture(inventory.get_node("%BookRoot"), "calendar_inventory")
	inventory.get_node("%TabNPC").pressed.emit()
	await settle()
	check(not calendar_page.visible, "pindah tab menyembunyikan kalender")
	inventory._close()

	GameState.horror.forced_tier = 0
	print("calendar_ui_regression: %d failure(s)" % failures)
	get_tree().quit(1 if failures else 0)
