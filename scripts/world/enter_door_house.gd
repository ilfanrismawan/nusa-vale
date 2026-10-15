extends Area2D

@export var interior_scene_path: String = "res://scenes/world/interior/interior_house.tscn"
@export var target_spawn_pos: Vector2 = Vector2(310.0, 193.0)

func _ready() -> void:
	add_to_group("scene_door")

func interact(actor: Player = null) -> void:
	_on_body_entered(actor if actor != null else RoomDoor.player())

func _on_body_entered(body: Node2D) -> void:
	if Transition.on_transition:
		return
	if body is Player:
		GameState.next_spawn_position = target_spawn_pos
		GameState.has_spawn_point = true
		Transition.scene_transition.call_deferred(interior_scene_path, body)
