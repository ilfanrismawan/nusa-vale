extends Node
## Probe sementara (tidak di-commit): render tab Kalender dalam buku inventory ke user://calendar_probe_*.png.

const INVENTORY := preload("res://scenes/ui/ui_inventory.tscn")


func shot(name: String) -> void:
	for frame in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := OS.get_user_data_dir().path_join("calendar_probe_%s.png" % name)
	get_viewport().get_texture().get_image().save_png(path)
	print("snapshot: " + path)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().create_timer(0.6, true).timeout
	GameState.new_game()
	DayCycle.is_running = false
	var p1 := GameState.p1()
	p1.player_name = "Sari"
	p1.birthday_season = "fall"
	p1.birthday_day = 10
	GameState.horror.forced_tier = 2
	DayCycle.current_day = 59 # Rabu, 3 Musim Gugur
	var inventory := INVENTORY.instantiate()
	add_child(inventory)
	for frame in 5:
		await get_tree().process_frame
	inventory._open()
	inventory.get_node("%TabCalendar").pressed.emit()
	await shot("today")
	var page: Control = inventory.get_node("%CalendarPage")
	var cells: Array = page.get_node("%Days").get_children()
	(cells[24] as CalendarCell).pressed.emit()
	await shot("kliwon")
	(cells[0] as CalendarCell).pressed.emit()
	page.get_node("%PrevSeason").pressed.emit()
	await shot("summer")
	DayCycle.current_day = 3 # Rabu, 3 Semi: toko tutup + dua ulang tahun
	page.refresh()
	await shot("spring_wed")
	GameState.horror.forced_tier = 0
	get_tree().quit()
