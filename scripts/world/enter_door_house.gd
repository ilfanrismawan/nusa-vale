extends Area2D

@export var interior_scene_path: String = "res://scenes/world/interior/interior_house.tscn"
@export var target_spawn_pos: Vector2 = Vector2(312, 206)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
func _on_body_entered(body: Node2D) -> void:
	print("Menyentuh pintu masuk: ", body.name)
	
	if body is Player or body.is_in_group("player"):
		GameState.next_spawn_position = target_spawn_pos
		GameState.has_spawn_point = true
		get_tree().change_scene_to_file(interior_scene_path)
