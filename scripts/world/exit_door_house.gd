extends Area2D

@export_file("*.tscn") var target_scene: String

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("Area siap, target: ", target_scene)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body):
	print("Node: ", body.get_path(), " | groups: ", body.get_groups())
	if body is Player or body.is_in_group("player"):
		# Posisi pintu rumah di map Farm (1159, 275)
		GameState.next_spawn_position = Vector2(1159, 295)
		GameState.has_spawn_point = true
		get_tree().change_scene_to_file(target_scene)
