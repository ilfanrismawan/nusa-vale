extends PanelContainer
## Satu kartu acara di halaman kanan tab Kalender. Warna kartu per jenis acara diatur lewat
## `kind_styles` di scene (kunci = CalendarEvents.KIND_*); jenis lain memakai gaya panel bawaan.

@export var kind_styles: Dictionary = {}


func setup(icon: Texture2D, title: String, detail: String, kind := "", full_detail := "") -> void:
	%Icon.texture = icon
	%IconTile.visible = icon != null
	%Title.text = title
	%Detail.text = detail
	%Detail.visible = not detail.is_empty()
	tooltip_text = title + ("\n" + full_detail if not full_detail.is_empty() else "")
	if kind_styles.has(kind):
		add_theme_stylebox_override("panel", kind_styles[kind])
