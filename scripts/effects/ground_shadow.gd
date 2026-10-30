extends Node2D
## Bayangan oval di kaki karakter/hewan supaya terlihat menapak di tanah (seperti Stardew).
## Dipakai lewat preload: GroundShadow.attach(node, radius). Titik asal node = kaki.
## lift > 0 (lompat, terbang, kendaraan melayang): bayangan tetap di tanah, mengecil dan memudar.

const DEFAULT_RADIUS := 6.0
const ALPHA := 0.28
## Elips: tinggi = lebar x SQUASH.
const SQUASH := 0.45

var radius := DEFAULT_RADIUS:
	set(value):
		radius = value
		queue_redraw()
var lift := 0.0:
	set(value):
		lift = value
		queue_redraw()


## Pasang bayangan sebagai anak pertama `parent` (digambar di bawah sprite), di titik `at`.
static func attach(parent: Node2D, p_radius: float = DEFAULT_RADIUS, at: Vector2 = Vector2.ZERO) -> Node2D:
	var shadow: Node2D = load("res://scripts/effects/ground_shadow.gd").new()
	shadow.name = "GroundShadow"
	shadow.radius = p_radius
	shadow.position = at
	parent.add_child(shadow)
	parent.move_child(shadow, 0)
	return shadow


func _draw() -> void:
	var scale_by := clampf(1.0 - lift / 30.0, 0.55, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, SQUASH))
	draw_circle(Vector2.ZERO, radius * scale_by, Color(0, 0, 0, ALPHA * scale_by))
