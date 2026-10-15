extends Node2D

@export var interior := false
const FONT = preload("res://assets/fonts/m5x7.ttf")
var _hall_art: Sprite2D

func _ready() -> void:
	DayCycle.is_running = true
	GameState.balai_nadi.state_changed.connect(queue_redraw)
	_hall_art = Sprite2D.new()
	_hall_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hall_art.position = Vector2(427, 232 if interior else 180)
	_hall_art.scale = Vector2.ONE * (0.14 if interior else 0.12)
	add_child(_hall_art)
	GameState.balai_nadi.state_changed.connect(_refresh_art)
	_refresh_art()
	for candidate in find_children("*", "CharacterBody2D", true, false):
		if candidate is Player:
			var camera := candidate.get_node_or_null("Camera2D")
			if camera != null and not Coop.has_root():
				camera.set_default_zoom(1.5)
				camera.offset = Vector2(0, -40)
				camera.reset_smoothing()
	queue_redraw()

func _refresh_art() -> void:
	var state := "restored" if GameState.balai_nadi.completed("balai_nadi_restoration") else "ruined"
	var space := "interior" if interior else "exterior"
	_hall_art.texture = load("res://assets/balai_nadi/v1/%s_%s.png" % [space, state])

func _draw() -> void:
	var restored := GameState.balai_nadi.completed("balai_nadi_restoration")
	if interior:
		draw_rect(Rect2(320, 155, 214, 176), Color("3f3025"))
		draw_rect(Rect2(326, 161, 202, 164), Color("a47b50") if restored else Color("77614c"))
		for y in range(165, 325, 16):
			draw_line(Vector2(326, y), Vector2(528, y), Color("674a32"))
		draw_rect(Rect2(320, 151, 214, 16), Color("66472f"))
		draw_string(FONT, Vector2(378, 162), "BALAI NADI", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("efd9b2"))
	else:
		draw_rect(Rect2(0, 0, 854, 480), Color("536a3d"))
		draw_rect(Rect2(270, 130, 315, 230), Color("709052"))
		draw_rect(Rect2(415, 228, 24, 132), Color("bea275"))
		for y in range(244, 335, 18):
			draw_rect(Rect2(419, y, 16, 10), Color("9c8e72"))
		for x in [292, 558]:
			for y in [170, 235, 300]:
				draw_rect(Rect2(x - 6, y, 12, 10), Color("915733"))
				draw_circle(Vector2(x, y - 4), 11, Color("42673e"))
				draw_line(Vector2(x, y + 2), Vector2(x, y - 18), Color("a4ad56"), 2)
