extends PanelContainer
## Satu baris "Akan datang" di tab Kalender: lencana tanggal, ikon acara, nama, jarak hari.
## Baris genap/ganjil memakai StyleBox ekspor agar belang bisa diatur di scene.

@export var style_even: StyleBox
@export var style_odd: StyleBox


func setup(index: int, day_number: int, icon: Texture2D, title: String, relative: String, tooltip: String) -> void:
	var style := style_even if index % 2 == 0 else style_odd
	if style != null:
		add_theme_stylebox_override("panel", style)
	%Day.text = str(day_number)
	%Icon.texture = icon
	%Title.text = title
	%Relative.text = relative
	tooltip_text = tooltip
