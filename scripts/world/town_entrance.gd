extends Area2D

## Pintu masuk ke Kota dari Farm. Pasang ke node EnterTown (Area2D) di farm.tscn.

@export_file("*.tscn") var town_scene: String = "res://scenes/world/town.tscn"
## Posisi pemain di Kota (ujung barat jalan utama).
@export var spawn_position: Vector2 = Vector2(40, 408)

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if Transition.on_transition:
		return
	if not body is Player:
		return
	GameState.next_spawn_position = spawn_position
	GameState.has_spawn_point = true
	Transition.scene_transition.call_deferred(town_scene, body)
