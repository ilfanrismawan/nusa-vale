extends Control
## Pin posisi pemain di Peta Lembah: bulatan berwarna dengan nomor pemain.

@export var fill := Color(0.89, 0.13, 0.17, 1)
@export var outline := Color(0.2, 0.07, 0.12, 1)
@export var number := 1:
	set(value):
		number = value
		var label := get_node_or_null("Number") as Label
		if label != null:
			label.text = str(value)


func _ready() -> void:
	number = number


func _draw() -> void:
	var c := Vector2(size.x * 0.5, 6)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-4, 3), c + Vector2(4, 3), Vector2(c.x, size.y)]), outline)
	draw_circle(c, 6.0, outline)
	draw_circle(c, 5.0, fill)
