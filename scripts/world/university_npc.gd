extends StaticBody2D

## NPC sederhana: diam di tempat, menghadap pemain saat diajak bicara,
## dan menampilkan baris dialog bergiliran lewat Notify.

@export var npc_name: String = ""
@export var lines: PackedStringArray = []

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _line_index := 0

func interact() -> void:
	if lines.is_empty():
		return
	_face_player()
	Notify.say("%s: %s" % [npc_name, lines[_line_index]])
	_line_index = (_line_index + 1) % lines.size()

func _face_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not (player is CharacterBody2D):
		return
	var dir: Vector2 = player.global_position - global_position
	if abs(dir.x) > abs(dir.y):
		sprite.play("idle_side")
		sprite.flip_h = dir.x < 0
	else:
		sprite.flip_h = false
		sprite.play("idle_down" if dir.y > 0 else "idle_up")
