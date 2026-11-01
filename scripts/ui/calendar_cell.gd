class_name CalendarCell
extends Button
## Satu tanggal di tab Kalender. Gaya kotak diganti lewat StyleBox ekspor (bukan kode warna),
## jadi tampilannya bisa diatur dari scene `calendar_cell.tscn`.

@export var style_normal: StyleBox
@export var style_weekend: StyleBox
@export var style_today: StyleBox
@export var style_selected: StyleBox
@export var style_hover: StyleBox
## Garis fokus keyboard/gamepad (tanpa isi).
@export var style_focus: StyleBox
@export_range(0.2, 1.0, 0.05) var past_alpha := 0.55
@export var marker_icons: Dictionary = {}

var abs_day := 0
var is_today := false
var is_past := false
var is_weekend := false


func setup(day: int, today: bool, past: bool, weekend: bool, events: Array[Dictionary]) -> void:
	abs_day = day
	is_today = today
	is_past = past
	is_weekend = weekend
	%Number.text = str(CalendarEvents.day_of_season(day))
	for child in %Markers.get_children():
		%Markers.remove_child(child)
		child.queue_free()
	var kinds: Array[String] = []
	for event in events:
		var kind := str(event.kind)
		if kind in kinds or not marker_icons.has(kind):
			continue
		kinds.append(kind)
		var icon := TextureRect.new()
		icon.texture = marker_icons[kind]
		icon.custom_minimum_size = Vector2(9, 9)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		%Markers.add_child(icon)
	var titles: PackedStringArray = []
	for event in events:
		titles.append(str(event.title))
	tooltip_text = CalendarEvents.date_text(day) + ("\n" + "\n".join(titles) if not titles.is_empty() else "")
	%TodayTag.visible = today
	modulate.a = past_alpha if past and not today else 1.0
	_apply_style()


func _ready() -> void:
	toggled.connect(func(_on: bool): _apply_style())


func _apply_style() -> void:
	var base: StyleBox = style_weekend if is_weekend and style_weekend != null else style_normal
	if is_today and style_today != null:
		base = style_today
	var pressed_style: StyleBox = style_selected if style_selected != null else base
	add_theme_stylebox_override("normal", pressed_style if button_pressed else base)
	add_theme_stylebox_override("pressed", pressed_style)
	add_theme_stylebox_override("hover_pressed", pressed_style)
	add_theme_stylebox_override("hover", style_hover if style_hover != null and not button_pressed else pressed_style if button_pressed else base)
	if style_focus != null:
		add_theme_stylebox_override("focus", style_focus)
