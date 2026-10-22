@tool
class_name CaveSpawnZone
extends Node2D

## Kotak penempatan yang bisa digeser/diubah di editor. Koordinat mengikuti grid 16 px.
enum Kind { ROCK, ORE, GEM, ENEMY, SAFE }
@export var kind: Kind = Kind.ROCK:
	set(value):
		kind = value
		queue_redraw()
@export var size_tiles: Vector2i = Vector2i(5, 4):
	set(value):
		size_tiles = Vector2i(maxi(1, value.x), maxi(1, value.y))
		queue_redraw()
@export_range(0.0, 20.0) var spawn_weight: float = 1.0
## Minimum per zona mengambil bagian dari budget CaveBand; bukan tambahan budget.
@export_range(0, 80) var minimum_count: int = 0
@export_range(0, 80) var maximum_count: int = 80
## Kosong mengikuti jenis mineral tier. Isi untuk membatasi jenis di zona ini.
@export var item_ids: PackedStringArray = []
@export var enemy_pool: Array[EnemyData] = []
@export var clustered: bool = false
@export_range(1, 8) var cluster_radius: int = 2

func cells(space: Node2D, tile_size: int = 16) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in size_tiles.x:
		for y in size_tiles.y:
			var point := space.to_local(to_global(Vector2(x + 0.5, y + 0.5) * tile_size))
			var cell := Vector2i((point / tile_size).floor())
			if not result.has(cell):
				result.append(cell)
	return result

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var colors := [Color.GRAY, Color.ORANGE, Color.CYAN, Color.RED, Color.GREEN]
	var color: Color = colors[kind]
	var rect := Rect2(Vector2.ZERO, Vector2(size_tiles * 16))
	draw_rect(rect, Color(color, 0.16))
	draw_rect(rect, Color(color, 0.9), false, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(3, 13), Kind.keys()[kind], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)
