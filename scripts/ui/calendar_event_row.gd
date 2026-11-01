extends HBoxContainer
## Satu acara di halaman kanan tab Kalender.

func setup(icon: Texture2D, title: String, detail: String) -> void:
	%Icon.texture = icon
	%Icon.modulate.a = 1.0 if icon != null else 0.0
	%Title.text = title
	%Detail.text = detail
	%Detail.visible = not detail.is_empty()
