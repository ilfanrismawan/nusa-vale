extends Area2D

@export_file("*.tscn") var target_scene: String
@export var spawn_position := Vector2(240, 256)
@export var return_marker: NodePath = ^"../ReturnSpawn"

func _ready() -> void:
	add_to_group("scene_door")

func interact(actor: Player = null) -> void:
	if actor == null:
		actor = RoomDoor.player()
	if actor == null or actor.is_input_locked() or Transition.on_transition:
		return
	var marker := get_node_or_null(return_marker) as Node2D
	RoomDoor.town_returns[actor.data.index] = marker.global_position if marker != null else global_position + Vector2(0, 24)
	RoomDoor.travel(actor, target_scene, spawn_position)
