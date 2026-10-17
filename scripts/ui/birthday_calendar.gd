extends Control

signal date_selected(season_index: int, day: int)
@export var day_scene: PackedScene = preload("res://scenes/ui/calendar_day.tscn")
@export var season_labels := PackedStringArray(["Musim Semi", "Musim Panas", "Musim Gugur", "Musim Dingin"])
@export var season_icons: Array[Texture2D] = []
@export var birthday_icon: Texture2D = preload("res://resources/ui/birthday_cake_icon.tres")
var _season := 0
var _selected_season := -1
var _selected_day := 0

func _ready() -> void:
	hide()
	%PreviousSeason.pressed.connect(_change_season.bind(-1))
	%NextSeason.pressed.connect(_change_season.bind(1))
	%CancelCalendar.pressed.connect(hide)
	%BirthdayIcon.texture = birthday_icon
	%LegendIcon.texture = birthday_icon

func open(season_index: int, day: int) -> void:
	_selected_season = season_index
	_selected_day = day
	_season = season_index if season_index >= 0 else DayCycle.get_season()
	_build_days()
	show()
	%CancelCalendar.grab_focus()

func _change_season(direction: int) -> void:
	_season = posmod(_season + direction, DayCycle.SEASONS.size())
	_build_days()

func _build_days() -> void:
	%SeasonTitle.text = season_labels[_season] if _season < season_labels.size() else DayCycle.SEASONS[_season].capitalize()
	%SeasonIcon.texture = season_icons[_season] if _season < season_icons.size() else null
	%Legend.text = "Ikon kue menandai ulang tahunmu."
	for child in %Days.get_children():
		%Days.remove_child(child)
		child.queue_free()
	for day in range(1, DayCycle.DAYS_PER_SEASON + 1):
		var button := day_scene.instantiate() as Button
		%Days.add_child(button)
		button.text = str(day)
		button.set_pressed_no_signal(_selected_season == _season and _selected_day == day)
		var marker: TextureRect = button.get_node("BirthdayMarker")
		marker.texture = birthday_icon
		marker.visible = button.button_pressed
		button.tooltip_text = "%d · %s%s" % [day, %SeasonTitle.text, " · Ulang tahunmu" if button.button_pressed else ""]
		button.pressed.connect(_pick_day.bind(day))

func _pick_day(day: int) -> void:
	if day < 1 or day > DayCycle.DAYS_PER_SEASON:
		return
	date_selected.emit(_season, day)
	hide()
