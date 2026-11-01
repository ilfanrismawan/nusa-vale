extends PanelContainer
## Tab Kalender di buku inventory: halaman kiri grid 4 pekan satu musim, halaman kanan detail
## tanggal terpilih (ulang tahun, Malam Jumat Kliwon, layanan tutup) dan acara mendatang.
## Data acara dari CalendarEvents; halaman ini hanya menampilkan.

@export var cell_scene: PackedScene = preload("res://scenes/ui/calendar_cell.tscn")
@export var event_row_scene: PackedScene = preload("res://scenes/ui/calendar_event_row.tscn")
@export var season_icons: Array[Texture2D] = []
## Ikon per jenis acara untuk daftar di halaman kanan (kunci = CalendarEvents.KIND_*).
@export var event_icons: Dictionary = {}
@export var weekend_color := Color(0.62, 0.22, 0.14, 1)
@export_range(1, 8) var upcoming_limit := 4

var inventory_ui: CanvasLayer
var _view_serial := 0
var _selected_day := 1
var _cells: Array[CalendarCell] = []
var _group := ButtonGroup.new()


func data() -> PlayerData:
	return inventory_ui.data if is_instance_valid(inventory_ui) else GameState.p1()


func _ready() -> void:
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
		cell.pressed.connect(func(): _select(cell.abs_day))
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
	refresh()


func _change_season(direction: int) -> void:
	var serial := maxi(0, _view_serial + direction)
	if serial == _view_serial:
		return
	var day_in_season := CalendarEvents.day_of_season(_selected_day)
	_view_serial = serial
	_selected_day = CalendarEvents.first_day_of(serial) + day_in_season - 1
	_build()


func _build() -> void:
	var first := CalendarEvents.first_day_of(_view_serial)
	var season := CalendarEvents.season_of(first)
	%SeasonTitle.text = "%s · Tahun %d" % [CalendarEvents.SEASON_NAMES[season], CalendarEvents.year_of(first)]
	%SeasonIcon.texture = season_icons[season] if season < season_icons.size() else null
	%PrevSeason.disabled = _view_serial <= 0
	var birthdays := CalendarEvents.resident_birthdays()
	var show_kliwon := CalendarEvents.kliwon_known()
	var today := DayCycle.current_day
	for index in _cells.size():
		var day := first + index
		var events := CalendarEvents.events_for(data(), day, birthdays, show_kliwon)
		_cells[index].setup(day, day == today, day < today, CalendarEvents.weekday_index(day) >= 5, events)
	%LegendKliwon.visible = show_kliwon
	_select(_selected_day)
	_build_upcoming()


func _select(day: int) -> void:
	_selected_day = day
	for cell in _cells:
		cell.set_pressed_no_signal(cell.abs_day == day)
		cell._apply_style()
	%DateTitle.text = CalendarEvents.date_text(day).to_upper()
	%DateSub.text = "Tahun %d · %s" % [CalendarEvents.year_of(day), _relative_text(day)]
	for child in %Events.get_children():
		%Events.remove_child(child)
		child.queue_free()
	var events := CalendarEvents.events_for(data(), day, [], CalendarEvents.kliwon_known())
	for event in events:
		_add_event_row(event_icons.get(str(event.kind)), str(event.title), str(event.get("detail", "")))
	if events.is_empty():
		_add_event_row(null, "Tidak ada acara.", "Hari biasa untuk bertani dan menjelajah.")
	var closed := CalendarEvents.closed_services(day)
	%Closed.text = "Tutup: " + ", ".join(closed) if not closed.is_empty() else "Semua layanan buka sesuai jam."


func _add_event_row(icon: Texture2D, title: String, detail: String) -> void:
	var row := event_row_scene.instantiate()
	%Events.add_child(row)
	row.setup(icon, title, detail)


func _build_upcoming() -> void:
	for child in %Upcoming.get_children():
		%Upcoming.remove_child(child)
		child.queue_free()
	var entries := CalendarEvents.upcoming(data(), DayCycle.current_day + 1, DayCycle.DAYS_PER_SEASON, upcoming_limit)
	for entry in entries:
		var day := int(entry.day)
		var event: Dictionary = entry.event
		var label := %UpcomingTemplate.duplicate() as Label
		label.visible = true
		label.text = "%s %d %s · %s" % [CalendarEvents.WEEKDAY_SHORT[CalendarEvents.weekday_index(day)], CalendarEvents.day_of_season(day), _season_short(day), str(event.title)]
		label.tooltip_text = "%s · %s" % [CalendarEvents.date_text(day), _relative_text(day)]
		%Upcoming.add_child(label)
	%UpcomingEmpty.visible = entries.is_empty()


func _season_short(day: int) -> String:
	return ["Semi", "Panas", "Gugur", "Dingin"][CalendarEvents.season_of(day)]


func _relative_text(day: int) -> String:
	var diff := day - DayCycle.current_day
	if diff == 0:
		return "Hari ini"
	if diff == 1:
		return "Besok"
	if diff == -1:
		return "Kemarin"
	return "%d hari lagi" % diff if diff > 0 else "%d hari lalu" % -diff


func _focus_selected() -> void:
	if not is_visible_in_tree():
		return
	for cell in _cells:
		if cell.abs_day == _selected_day:
			cell.grab_focus()
			return
