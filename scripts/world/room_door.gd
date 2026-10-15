class_name RoomDoor
extends RefCounted

static var town_returns: Dictionary = {}

static func player() -> Player:
	var current := Coop.current_player()
	if current != null:
		return current
	for candidate in GameState.get_tree().get_nodes_in_group("player"):
		if candidate is Player and candidate.data == GameState.current:
			return candidate
	return null

static func travel(actor: Player, path: String, spawn: Vector2) -> void:
	if actor == null or actor.is_input_locked() or Transition.on_transition or path.is_empty():
		return
	if Coop.has_root():
		# Pass the spawn with this player's request. A shared deferred spawn
		# can be overwritten when two players leave different rooms together.
		actor.release_carried_animal()
		Coop.root.move_player(actor, path, spawn)
		return
	GameState.next_spawn_position = spawn
	GameState.has_spawn_point = true
	Transition.scene_transition.call_deferred(path, actor)
