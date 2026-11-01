@tool
class_name HouseExterior
extends Node2D

## Root scene tampilan rumah di farm untuk satu tingkat (GDD 4.12). Sprite, collision, pintu,
## dan HouseAnchor diedit langsung di scene ini; origin = origin node House di farm.

## Area (lokal) yang dibersihkan dari pohon/batu cleanup farm saat tingkat ini aktif, supaya
## rumah yang lebih besar tidak menimpa objek. Kotak oranye hanya tampil di editor.
@export var clear_area := Rect2():
	set(value):
		clear_area = value
		queue_redraw()

func _draw() -> void:
	if Engine.is_editor_hint() and clear_area.has_area():
		draw_rect(clear_area, Color(1, 0.55, 0, 0.18))
		draw_rect(clear_area, Color(1, 0.55, 0, 0.9), false, 1.0)

func anchors() -> Array[HouseAnchor]:
	var result: Array[HouseAnchor] = []
	for node in find_children("*", "Marker2D", true, false):
		if node is HouseAnchor:
			result.append(node)
	return result
