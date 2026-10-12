extends Node2D

@export var interior := false
const FONT = preload("res://assets/fonts/m5x7.ttf")

func _ready() -> void:
	DayCycle.is_running = true
	GameState.balai_nadi.state_changed.connect(queue_redraw)
	queue_redraw()

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
		draw_rect(Rect2(270, 130, 315, 230), Color("709052"))
		draw_rect(Rect2(415, 228, 24, 132), Color("bea275"))
		draw_rect(Rect2(362, 150, 130, 77), Color("b69061") if restored else Color("7a705b"))
		draw_rect(Rect2(350, 132, 154, 27), Color("914a35") if restored else Color("5e5042"))
		draw_rect(Rect2(372, 178, 24, 20), Color("d8c386") if restored else Color("343b37"))
		draw_rect(Rect2(458, 178, 24, 20), Color("d8c386") if restored else Color("343b37"))
		draw_rect(Rect2(415, 202, 24, 25), Color("443023"))
		draw_string(FONT, Vector2(389, 175), "BALAI NADI", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f1dbb4"))
