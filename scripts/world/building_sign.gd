@tool
class_name BuildingSign
extends Node2D
## Local origin is the mounting point (wall/hanging) or foot of the posts.

enum Mount { WALL, HANGING, POSTS }
const FONT = preload("res://assets/fonts/m5x7.ttf")

@export var caption := "Sekolah":
	set(value):
		caption = value
		queue_redraw()
@export var mount: Mount = Mount.WALL:
	set(value):
		mount = value
		queue_redraw()
@export_range(32, 192, 1) var minimum_width: int = 56:
	set(value):
		minimum_width = value
		queue_redraw()
@export_range(8, 24, 1) var font_size: int = 12:
	set(value):
		font_size = value
		queue_redraw()
@export var icon: Texture2D:
	set(value):
		icon = value
		queue_redraw()
@export_range(12, 32, 1) var minimum_height: int = 20:
	set(value):
		minimum_height = value
		queue_redraw()
@export var wood_color := Color("7d452b"):
	set(value):
		wood_color = value
		queue_redraw()
@export var text_color := Color("ffe6aa"):
	set(value):
		text_color = value
		queue_redraw()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()

func board_rect() -> Rect2:
	var text_width := FONT.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var width := ceilf(maxf(minimum_width, text_width + 16 + (20 if icon != null else 0)))
	var height := ceilf(maxf(minimum_height, FONT.get_height(font_size) + 6))
	return Rect2(Vector2(-width * 0.5, -height * 0.5 - (20 if mount == Mount.POSTS else 0)), Vector2(width, height))

func _draw() -> void:
	var board := board_rect()
	var dark := Color("3c2521")
	var light := Color("b97943")
	for x in [board.position.x + 7, board.end.x - 9]:
		if mount == Mount.POSTS:
			draw_rect(Rect2(x, board.position.y + 4, 3, -board.position.y + 4), dark)
			draw_rect(Rect2(x + 1, board.position.y + 4, 1, -board.position.y + 3), light)
		elif mount == Mount.HANGING:
			draw_line(Vector2(x + 1, board.position.y - 9), Vector2(x + 1, board.position.y + 1), Color("c5b69b"), 1)
			draw_rect(Rect2(x - 1, board.position.y - 10, 5, 2), dark)
	draw_rect(board, dark)
	draw_rect(board.grow(-1), wood_color)
	draw_rect(Rect2(board.position + Vector2(1, 1), Vector2(board.size.x - 2, 1)), light)
	draw_rect(Rect2(board.position + Vector2(2, board.size.y - 3), Vector2(board.size.x - 4, 1)), wood_color.darkened(0.25))
	for corner in [board.position + Vector2(3, 3), Vector2(board.end.x - 4, board.position.y + 3), Vector2(board.position.x + 3, board.end.y - 4), board.end - Vector2(4, 4)]:
		draw_rect(Rect2(corner, Vector2.ONE), Color("dac389"))
	var text_width := FONT.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var content_width := text_width + (20 if icon != null else 0)
	var text_position := Vector2(-content_width * 0.5, board.get_center().y - FONT.get_height(font_size) * 0.5 + FONT.get_ascent(font_size))
	text_position = text_position.round()
	if icon != null:
		draw_texture_rect(icon, Rect2(Vector2(text_position.x, board.get_center().y - 8), Vector2(16, 16)), false)
		text_position.x += 20
	draw_string_outline(FONT, text_position, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 1, dark)
	draw_string(FONT, text_position, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
