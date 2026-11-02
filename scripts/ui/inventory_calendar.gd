extends PanelContainer
## Tab Kalender di buku inventory: halaman kiri grid 4 pekan satu musim (dengan progres musim dan
## ringkasan), halaman kanan detail tanggal terpilih (acara, layanan tutup) dan acara mendatang.
## Data acara dari CalendarEvents; halaman ini hanya menampilkan. Semua warna/gaya ada di scene.

@export var cell_scene: PackedScene = preload("res://scenes/ui/calendar_cell.tscn")
@export var event_row_scene: PackedScene = preload("res://scenes/ui/calendar_event_row.tscn")
@export var upcoming_row_scene: PackedScene = preload("res://scenes/ui/calendar_upcoming_row.tscn")
@export var season_icons: Array[Texture2D] = []
## Ikon per jenis acara untuk daftar di halaman kanan (kunci = CalendarEvents.KIND_*).
@export var event_icons: Dictionary = {}
## Warna nama hari Sabtu/Minggu di pita merah.
@export var weekend_color := Color(1, 0.8, 0.7, 1)
@export_range(1, 8) var upcoming_limit := 4
@export_group("Kotak layanan")
@export var style_services_open: StyleBox
@export var style_services_closed: StyleBox
@export var services_open_color := Color(0.27, 0.47, 0.2, 1)
@export var services_closed_color := Color(0.63, 0.24, 0.2, 1)
@export_group("Animasi")
## Jarak geser grid saat ganti musim (piksel); 0 = tanpa animasi.
@export var season_slide := 10.0
@export var anim_time := 0.14

const SEASON_SHORT := ["Semi", "Panas", "Gugur", "Dingin"]

var inventory_ui: CanvasLayer
var _view_serial := 0
var _selected_day := 1
var _cells: Array[CalendarCell] = []
var _group := ButtonGroup.new()
var _days_home := Vector2.ZERO
var _anim: Tween
var _upcoming_room := 4


func data() -> PlayerData:
	return inventory_ui.data if is_instance_valid(inventory_ui) else GameState.p1()


func _ready() -> void:
	_days_home = %Days.position
	%PrevSeason.pressed.connect(_change_season.bind(-1))
	%NextSeason.pressed.connect(_change_season.bind(1))
	%TodayButton.pressed.connect(_jump_today)
	for index in CalendarEvents.WEEKDAY_SHORT.size():
		var label := %WeekdayTemplate.duplicate() as Label
		label.text = CalendarEvents.WEEKDAY_SHORT[index]
		label.visible = true
		if index >= 5:
			label.add_theme_color_override("font_color", weekend_color)
		%Weekdays.add_child(label)
	for index in DayCycle.DAYS_PER_SEASON:
		var cell := cell_scene.instantiate() as CalendarCell
		cell.button_group = _group
		cell.pressed.connect(func():
			_select(cell.abs_day)
			cell.pop())
		%Days.add_child(cell)
		_cells.append(cell)
	DayCycle.day_passed.connect(func(_day: int):
		if is_visible_in_tree():
			refresh())


## Dipanggil buku inventory setiap kali tab dibuka: kembali ke hari ini.
func refresh() -> void:
	_view_serial = CalendarEvents.season_serial(DayCycle.current_day)
	_selected_day = DayCycle.current_day
	_build()
	_focus_selected.call_deferred()


func _jump_today() -> void:
	var direction := signi(CalendarEvents.season_serial(DayCycle.current_day) - _view_serial)
	refresh()
	if direction != 0:
		_slide_in(direction)


func _change_season(direction: int) -> void:
	var serial := maxi(0, _view_serial + direction)
	if serial == _view_serial:
		return
	var day_in_season := CalendarEvents.day_of_season(_selected_day)
	_view_serial = serial
	_selected_day = CalendarEvents.first_day_of(serial) + day_in_season - 1
	_build()
	_slide_in(direction)


func _build() -> void:
	var first := CalendarEvents.first_day_of(_view_serial)
	var season := CalendarEvents.season_of(first)
	var today := DayCycle.current_day
	var today_serial := CalendarEvents.season_serial(today)
	%SeasonTitle.text = "%s · Tahun %d" % [CalendarEvents.SEASON_NAMES[season], CalendarEvents.year_of(first)]
	%SeasonIcon.texture = _season_icon(season)
	%PrevSeason.disabled = _view_serial <= 0
	var days := DayCycle.DAYS_PER_SEASON
	if _view_serial == today_serial:
		var day_now := CalendarEvents.day_of_season(today)
		%SeasonSub.text = "Hari %d dari %d" % [day_now, days]
		%SeasonProgress.value = day_now
	elif _view_serial < today_serial:
		%SeasonSub.text = "Sudah lewat"
		%SeasonProgress.value = days
	else:
		%SeasonSub.text = "Mulai %d hari lagi" % (first - today)
		%SeasonProgress.value = 0
	%SeasonProgress.max_value = days

	var birthdays := CalendarEvents.resident_birthdays()
	var show_kliwon := CalendarEvents.kliwon_known()
	var birthday_count := 0
	var kliwon_count := 0
	for index in _cells.size():
		var day := first + index
		var events := CalendarEvents.events_for(data(), day, birthdays, show_kliwon)
		for event in events:
			if event.kind == CalendarEvents.KIND_KLIWON:
				kliwon_count += 1
			else:
				birthday_count += 1
		_cells[index].setup(day, day == today, day < today, CalendarEvents.weekday_index(day) >= 5, events)
	%LegendKliwon.visible = show_kliwon
	_build_season_note(season, first, today, birthday_count, kliwon_count)
	_select(_selected_day, false)
	_build_upcoming()


func _build_season_note(season: int, first: int, today: int, birthday_count: int, kliwon_count: int) -> void:
	var parts: PackedStringArray = []
	if birthday_count > 0:
		parts.append("%d ulang tahun" % birthday_count)
	if kliwon_count > 0:
		parts.append("%d Kliwon" % kliwon_count)
	var prefix := "Musim ini: " if today >= first and today < first + DayCycle.DAYS_PER_SEASON else "Acara musim: "
	%SeasonSummary.text = prefix + (", ".join(parts) if not parts.is_empty() else "tanpa acara")
	var next_first := first + DayCycle.DAYS_PER_SEASON
	var next_season := CalendarEvents.season_of(next_first)
	if today >= next_first:
		%SeasonNext.text = "Musim ini sudah selesai"
		%SeasonNextIcon.texture = _season_icon(season)
	elif today >= first:
		var left := next_first - today
		%SeasonNext.text = ("Besok" if left == 1 else "%d hari lagi" % left) + " ke " + CalendarEvents.SEASON_NAMES[next_season]
		%SeasonNextIcon.texture = _season_icon(next_season)
	else:
		%SeasonNext.text = "Dimulai %s" % _relative_text(first).to_lower()
		%SeasonNextIcon.texture = _season_icon(season)


func _select(day: int, rebuild_upcoming := true) -> void:
	_selected_day = day
	for cell in _cells:
		cell.set_pressed_no_signal(cell.abs_day == day)
		cell._apply_style()
	%DateTitle.text = CalendarEvents.date_text(day)
	%DateWeekday.text = CalendarEvents.WEEKDAY_SHORT[CalendarEvents.weekday_index(day)].to_upper()
	%DateNumber.text = str(CalendarEvents.day_of_season(day))
	%DateSub.text = _relative_text(day)
	%DateChip.tooltip_text = "Tahun %d" % CalendarEvents.year_of(day)
	%DateChip.reset_size()
	%TodayButton.visible = day != DayCycle.current_day
	for child in %Events.get_children():
		%Events.remove_child(child)
		child.queue_free()
	var events := CalendarEvents.events_for(data(), day, [], CalendarEvents.kliwon_known())
	for event in events:
		_add_event_row(event_icons.get(str(event.kind)), str(event.title), str(event.get("summary", event.get("detail", ""))), str(event.kind), str(event.get("detail", "")))
	if events.is_empty():
		_add_event_row(null, "Tidak ada acara", "Hari biasa untuk bertani.", "", "")
	var closed := CalendarEvents.closed_services(day)
	if closed.is_empty():
		%Closed.text = "Semua buka sesuai jam"
		%Closed.add_theme_color_override("font_color", services_open_color)
		if style_services_open != null:
			%ClosedBox.add_theme_stylebox_override("panel", style_services_open)
	else:
		%Closed.text = "Tutup: " + ", ".join(closed)
		%Closed.add_theme_color_override("font_color", services_closed_color)
		if style_services_closed != null:
			%ClosedBox.add_theme_stylebox_override("panel", style_services_closed)
	# Hari dengan 3+ acara memendekkan daftar "Akan datang" agar tetap muat di halaman.
	_upcoming_room = maxi(2, upcoming_limit - maxi(0, events.size() - 2))
	if rebuild_upcoming:
		_build_upcoming()
	_fade_body()


func _add_event_row(icon: Texture2D, title: String, detail: String, kind: String, full_detail: String) -> void:
	var row := event_row_scene.instantiate()
	%Events.add_child(row)
	row.setup(icon, title, detail, kind, full_detail)


func _build_upcoming() -> void:
	for child in %Upcoming.get_children():
		%Upcoming.remove_child(child)
		child.queue_free()
	var entries := CalendarEvents.upcoming(data(), DayCycle.current_day + 1, DayCycle.DAYS_PER_SEASON, mini(upcoming_limit, _upcoming_room))
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var day := int(entry.day)
		var event: Dictionary = entry.event
		var row := upcoming_row_scene.instantiate()
		%Upcoming.add_child(row)
		var date_short := "%s %d %s" % [CalendarEvents.WEEKDAY_SHORT[CalendarEvents.weekday_index(day)], CalendarEvents.day_of_season(day), SEASON_SHORT[CalendarEvents.season_of(day)]]
		row.setup(index, CalendarEvents.day_of_season(day), event_icons.get(str(event.kind)), str(event.get("short", event.title)),
			_relative_short(day), "%s · %s\n%s" % [date_short, _relative_text(day), str(event.title)])
	%UpcomingEmpty.visible = entries.is_empty()


func _season_icon(season: int) -> Texture2D:
	return season_icons[season] if season < season_icons.size() else null


func _relative_text(day: int) -> String:
	var diff := day - DayCycle.current_day
	if diff == 0:
		return "Hari ini"
	if diff == 1:
		return "Besok"
	if diff == -1:
		return "Kemarin"
	return "%d hari lagi" % diff if diff > 0 else "%d hari lalu" % -diff


func _relative_short(day: int) -> String:
	var diff := day - DayCycle.current_day
	if diff == 1:
		return "Besok"
	return "%d hari" % diff


## Grid masuk dari samping saat ganti musim (searah tombol yang ditekan).
func _slide_in(direction: int) -> void:
	if season_slide <= 0.0:
		return
	if _anim != null and _anim.is_valid():
		_anim.kill()
	%Days.position = _days_home + Vector2(season_slide * direction, 0)
	%Days.modulate.a = 0.0
	_anim = create_tween().set_parallel().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_anim.tween_property(%Days, "position", _days_home, anim_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_anim.tween_property(%Days, "modulate:a", 1.0, anim_time)


func _fade_body() -> void:
	if not is_visible_in_tree():
		%Body.modulate.a = 1.0
		return
	%Body.modulate.a = 0.35
	create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(%Body, "modulate:a", 1.0, anim_time)


func _focus_selected() -> void:
	if not is_visible_in_tree():
		return
	for cell in _cells:
		if cell.abs_day == _selected_day:
			cell.grab_focus()
			return
