extends Area2D

var _icon: Sprite2D
var _hint: Label

func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 32
	shape.shape = circle
	add_child(shape)
	collision_layer = 1
	collision_mask = 2
	var icon := Sprite2D.new()
	_icon = icon
	icon.scale = Vector2(0.4, 0.4)
	icon.texture = preload("res://assets/ui/biji_daya.svg")
	add_child(icon)
	var hint := Label.new()
	_hint = hint
	hint.text = "Akar Keramat · Interaksi"
	hint.position = Vector2(-45, -24)
	hint.scale = Vector2(0.5, 0.5)
	hint.custom_minimum_size = Vector2(180, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", preload("res://assets/fonts/m5x7.ttf"))
	hint.add_theme_constant_override("outline_size", 3)
	hint.add_theme_color_override("font_outline_color", Color("263529"))
	hint.add_theme_font_size_override("font_size", 16)
	add_child(hint)
	GameState.daya.state_changed.connect(_refresh)
	_refresh()

func interact(actor: Player = null) -> void:
	if actor == null or not WorldState.has_flag("bridge_repaired"):
		Notify.say("Akar ini menanti jalan pulau yang tersambung kembali.")
		return
	if GameState.daya.obtained.has("forest"):
		Notify.say("Hangat akar keramat kini menetap bersamamu.")
		return
	GameState.daya.unlock("forest", actor.data)

func _refresh() -> void:
	var found := GameState.daya.obtained.has("forest")
	_icon.modulate = Color("8eaa87") if found else Color.WHITE
	_hint.text = "Akar Keramat · Hening" if found else "Akar Keramat · Interaksi"
