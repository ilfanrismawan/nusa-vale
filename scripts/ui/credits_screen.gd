extends CanvasLayer
## Layar Kredit dari menu utama. Teks kredit diedit langsung di node %CreditsText
## (Inspector > Text). Tab Lisensi diisi otomatis dari Engine (lisensi Godot dan
## pustaka pihak ketiganya) supaya selalu cocok dengan versi engine yang dipakai.

signal closed

@export var design_size := Vector2(1280, 720)

@onready var _design: Control = $Design
@onready var _credits_scroll: ScrollContainer = %CreditsScroll
@onready var _license_scroll: ScrollContainer = %LicenseScroll
@onready var _license_text: RichTextLabel = %LicenseText
@onready var _tab_credits: Button = %TabCredits
@onready var _tab_license: Button = %TabLicense
@onready var _close: Button = %Close

var _license_filled := false


func _ready() -> void:
	get_viewport().size_changed.connect(_resize)
	_resize()
	_tab_credits.pressed.connect(func(): _show_tab(false))
	_tab_license.pressed.connect(func(): _show_tab(true))
	_close.pressed.connect(close)
	_show_tab(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
	queue_free()


func _show_tab(license: bool) -> void:
	if license and not _license_filled:
		_license_text.text = _build_license_text()
		_license_filled = true
	_credits_scroll.visible = not license
	_license_scroll.visible = license
	_tab_credits.disabled = not license
	_tab_license.disabled = license
	(_tab_license if not license else _tab_credits).grab_focus()
	(_license_scroll if license else _credits_scroll).scroll_vertical = 0


func _resize() -> void:
	var view := get_viewport().get_visible_rect().size
	var fit := minf(view.x / design_size.x, view.y / design_size.y)
	_design.scale = Vector2.ONE * fit
	_design.position = (view - design_size * fit) * 0.5


func _build_license_text() -> String:
	var lines: PackedStringArray = []
	lines.append("[font_size=48]Godot Engine[/font_size]")
	lines.append(_esc(Engine.get_license_text()))
	lines.append("")
	lines.append("[font_size=48]Komponen pihak ketiga[/font_size]")
	for info: Dictionary in Engine.get_copyright_info():
		lines.append("")
		lines.append("[color=#5a6b3a]%s[/color]" % _esc(info.get("name", "")))
		for part: Dictionary in info.get("parts", []):
			for holder: String in part.get("copyright", []):
				lines.append("(c) %s" % _esc(holder))
			lines.append("Lisensi: %s" % _esc(part.get("license", "")))
	lines.append("")
	lines.append("[font_size=48]Teks lisensi[/font_size]")
	var licenses: Dictionary = Engine.get_license_info()
	for license_name: String in licenses.keys():
		lines.append("")
		lines.append("[color=#5a6b3a]%s[/color]" % _esc(license_name))
		lines.append(_esc(String(licenses[license_name])))
	return "\n".join(lines)


## Kurung siku di teks lisensi jangan dibaca sebagai BBCode.
func _esc(text: String) -> String:
	return text.replace("[", "[lb]")
