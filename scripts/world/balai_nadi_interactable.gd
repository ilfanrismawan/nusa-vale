extends Area2D

@export_enum("Table", "Door") var interaction_type := 0
@export_file("*.tscn") var target_scene: String
@export var spawn_position := Vector2.ZERO
var _menus: Dictionary = {}

func interact() -> void:
	var player: Player = Coop.current_player()
	if player == null:
		for candidate in get_tree().get_nodes_in_group("player"):
			if candidate is Player and candidate.data == GameState.current:
				player = candidate
				break
	if player == null or player.is_input_locked() or Transition.on_transition:
		return
	if interaction_type == 1:
		if target_scene.is_empty():
			return
		GameState.next_spawn_position = spawn_position
		GameState.has_spawn_point = true
		Transition.scene_transition.call_deferred(target_scene, player)
		return
	var index := player.data.index
	if is_instance_valid(_menus.get(index)):
		return
	var menu := BalaiNadiUI.new()
	menu.player = player
	_menus[index] = menu
	Coop.ui_parent(player).add_child(menu)
