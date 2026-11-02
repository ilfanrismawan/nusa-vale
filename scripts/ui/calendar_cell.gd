class_name CalendarCell
extends Button
## Satu tanggal di tab Kalender. Gaya kotak diganti lewat StyleBox ekspor (bukan kode warna),
## jadi tampilannya bisa diatur dari scene `calendar_cell.tscn`. Bingkai pilihan (`SelectFrame`),
## panah kecil (`SelectCaret`) dan centang hari lewat (`PastCheck`) adalah node di scene.

@export var style_normal: StyleBox
@export var style_weekend: StyleBox
## Hari Malam Jumat Kliwon (hanya bila Kliwon sudah dikenal pemain).
@export var style_kliwon: StyleBox
@export var style_today: StyleBox
@export var style_hover: StyleBox
## Garis fokus keyboard/gamepad (tanpa isi).
@export var style_focus: StyleBox
@export var number_color := Color(0.25, 0.14, 0.08, 1)
@export var weekend_number_color := Color(0.62, 0.22, 0.14, 1)
## Geser angka ke bawah pada sel hari ini agar tidak tertutup pita merah atasnya.
@export var today_number_shift := 2.0
@export_range(0.2, 1.0, 0.05) var past_alpha := 0.5
@export var marker_icons: Dictionary = {}
@export var marker_size := Vector2(9, 9)
## Panah pilihan hanya untuk tanggal >= nilai ini (baris pertama berbatasan dengan pita nama hari).
@export var caret_from_day := 8

var abs_day := 0
var is_today := false
var is_past := false
var is_weekend := false
var is_kliwon := false
var _number_top := 0.0
var _pop: Tween


func _ready() -> void:
	_number_top = %Number.offset_top
	toggled.connect(func(_on: bool): _apply_style())


func setup(day: int, today: bool, past: bool, weekend: bool, events: Array[Dictionary]) -> void:
	abs_day = day
	is_today = today
	is_past = past
	is_weekend = weekend
	is_kliwon = events.any(func(e: Dictionary): return str(e.kind) == CalendarEvents.KIND_KLIWON)
	%Number.text = str(CalendarEvents.day_of_season(day))
	%Number.add_theme_color_override("font_color", weekend_number_color if weekend else number_color)
	var shift := today_number_shift if today else 0.0
	%Number.offset_top = _number_top + shift
	%Number.offset_bottom = _number_top + 16.0 + shift
	for child in %Markers.get_children():
		%Markers.remove_child(child)
		child.queue_free()
	var kinds: Array[String] = []
	for event in events:
		var kind := str(event.kind)
		if kind in kinds or not marker_icons.has(kind):
			continue
		kinds.append(kind)
		var marker := TextureRect.new()
		marker.texture = marker_icons[kind]
		marker.custom_minimum_size = marker_size
		marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		%Markers.add_child(marker)
	var titles: PackedStringArray = []
	for event in events:
		titles.append(str(event.title))
	tooltip_text = CalendarEvents.date_text(day) + ("\n" + "\n".join(titles) if not titles.is_empty() else "")
	%PastCheck.visible = past and not today
	modulate.a = past_alpha if past and not today else 1.0
	_apply_style()


## Animasi kecil saat sel dipilih pemain (bukan saat halaman dibangun ulang).
func pop() -> void:
	if _pop != null and _pop.is_valid():
		_pop.kill()
	scale = Vector2.ONE
	_pop = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_pop.tween_property(self, "scale", Vector2.ONE * 1.12, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pop.tween_property(self, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _base_style() -> StyleBox:
	if is_today and style_today != null:
		return style_today
	if is_kliwon and style_kliwon != null:
		return style_kliwon
	if is_weekend and style_weekend != null:
		return style_weekend
	return style_normal


func _apply_style() -> void:
	var base := _base_style()
	add_theme_stylebox_override("normal", base)
	add_theme_stylebox_override("pressed", base)
	add_theme_stylebox_override("hover_pressed", base)
	add_theme_stylebox_override("hover", style_hover if style_hover != null and not button_pressed and not is_today else base)
	if style_focus != null:
		add_theme_stylebox_override("focus", style_focus)
	%SelectFrame.visible = button_pressed
	%SelectCaret.visible = button_pressed and CalendarEvents.day_of_season(abs_day) >= caret_from_day
	# Sel terpilih digambar di atas tetangganya agar bingkai & panah tidak tertutup.
	z_index = 1 if button_pressed else 0
