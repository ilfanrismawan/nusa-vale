@tool
extends Control
## Cincin progres tipis di dalam kelopak kaca Balai Nadi.

@export_range(0.0, 1.0) var value := 0.0:
	set(next):
		value = next
		queue_redraw()
@export var width := 4.0:
	set(next):
		width = next
		queue_redraw()
@export var color := Color(1.0, 0.87, 0.55):
	set(next):
		color = next
		queue_redraw()
@export var track_color := Color(1, 1, 1, 0.22):
	set(next):
		track_color = next
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - width * 0.5
	draw_arc(center, radius, 0.0, TAU, 64, track_color, width, true)
	if value > 0.0:
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * clampf(value, 0.0, 1.0), 64, color, width, true)
