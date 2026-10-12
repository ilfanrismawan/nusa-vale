extends Node2D

## Asset preview only. No autoload state, contributions, inventory or saves are changed.
@export var restored := false:
	set(value):
		restored = value
		if is_inside_tree():
			_refresh()
const EXTERIOR_RUINED = preload("res://assets/balai_nadi/v1/exterior_ruined.png")
const EXTERIOR_RESTORED = preload("res://assets/balai_nadi/v1/exterior_restored.png")
const INTERIOR_RUINED = preload("res://assets/balai_nadi/v1/interior_ruined.png")
const INTERIOR_RESTORED = preload("res://assets/balai_nadi/v1/interior_restored.png")
const FONT = preload("res://assets/fonts/m5x7.ttf")

func _ready() -> void:
	_refresh()

func _refresh() -> void:
	$Exterior.texture = EXTERIOR_RESTORED if restored else EXTERIOR_RUINED
	$Interior.texture = INTERIOR_RESTORED if restored else INTERIOR_RUINED
	$UI/State.text = "SETELAH RESTORASI" if restored else "SEBELUM RESTORASI"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		restored = not restored
		get_viewport().set_input_as_handled()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 854, 480), Color("29332b"))
	draw_string(FONT, Vector2(36, 44), "BALAI NADI — ASSET PREVIEW", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("ecd9ae"))
	draw_string(FONT, Vector2(36, 424), "Space: ganti kondisi rusak / pulih", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ecd9ae"))
