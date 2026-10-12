extends Area2D

@export_file("*.tscn") var target_scene: String
@export var target_spawn_pos: Vector2 = Vector2(1000, 290)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body):
	if Transition.on_transition:
		return
	if body is Player or body.is_in_group("player"):
		# Posisi pintu rumah di map Farm (1159, 275)
		GameState.next_spawn_position = target_spawn_pos
		GameState.has_spawn_point = true
		Transition.scene_transition.call_deferred(target_scene, body)
