extends Control
## Native icons for equipment types that are not implemented yet.
var kind := "lock"

func _draw() -> void:
	var gold := Color("e2c078")
	var edge := Color("705332")
	match kind:
		"ring":
			draw_arc(Vector2(12, 14), 7, 0, TAU, 16, edge, 5)
			draw_arc(Vector2(12, 14), 7, 0, TAU, 16, gold, 2)
			draw_rect(Rect2(9, 3, 6, 5), gold)
		"gem":
			draw_arc(Vector2(12, 7), 6, 0, TAU, 16, gold, 2)
			draw_colored_polygon(PackedVector2Array([Vector2(12, 10), Vector2(17, 16), Vector2(12, 22), Vector2(7, 16)]), Color("567f8b"))
		"shield":
			var points := PackedVector2Array([Vector2(4, 4), Vector2(20, 4), Vector2(19, 16), Vector2(12, 22), Vector2(5, 16), Vector2(4, 4)])
			draw_colored_polygon(points, Color("6a8581"))
			draw_polyline(points, gold, 2)
			draw_line(Vector2(12, 6), Vector2(12, 18), gold, 2)
			draw_line(Vector2(7, 11), Vector2(17, 11), gold, 2)
		_:
			draw_arc(Vector2(12, 9), 5, PI, TAU, 12, gold, 3)
			draw_rect(Rect2(5, 10, 14, 11), edge)
			draw_rect(Rect2(7, 11, 10, 9), gold)
			draw_rect(Rect2(11, 14, 2, 4), edge)
