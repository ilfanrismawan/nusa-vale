extends Area2D

const FARM_SCENE := "res://scenes/world/farm.tscn"
# Posisi keluar di Farm, dekat jembatan / ForestEntrance (971, 600)
const SPAWN_POSITION := Vector2(51, 878.0)

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if Transition.on_transition:
		return
	if not body is Player:
		return
	GameState.next_spawn_position = SPAWN_POSITION
	GameState.has_spawn_point = true
	Transition.scene_transition.call_deferred(FARM_SCENE, body)
