extends Control
## Satu kelopak kaca di lingkaran Balai Nadi (sayap atau paket).

signal chosen(petal: Control)
signal hovered(petal: Control)

const GOLD := Color(1.0, 0.87, 0.55)
const DONE := Color(0.51, 0.94, 0.75)

@export var selected_scale := 1.14
@export var smoothing := 12.0

var selected := false
## Dorongan keluar saat dipilih (0..1), dihaluskan setiap frame oleh BalaiNadiUI.
var push := 0.0
var _glow := 0.0
var _scale := 1.0

func _ready() -> void:
	pivot_offset = size * 0.5
	mouse_entered.connect(func(): hovered.emit(self))
	%Name.visible = false

func setup(icon: Texture2D, progress: float, count: String, title: String, done: bool) -> void:
	%Icon.texture = icon
	%Ring.value = progress
	%Ring.color = DONE if done else GOLD
	%Count.text = count
	%Count.visible = not count.is_empty()
	%Name.text = title
	%Check.visible = done
	%Name.visible = selected and not title.is_empty()

func set_back(on: bool) -> void:
	%Back.visible = on

func set_selected(on: bool) -> void:
	selected = on
	%Name.visible = on and not %Name.text.is_empty()

func _process(delta: float) -> void:
	var k := 1.0 - exp(-delta * smoothing)
	_glow = lerpf(_glow, 1.0 if selected else 0.0, k)
	_scale = lerpf(_scale, selected_scale if selected else 1.0, k)
	push = lerpf(push, 1.0 if selected else 0.0, k)
	%Glass.glow = _glow
	scale = Vector2.ONE * _scale

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		chosen.emit(self)
