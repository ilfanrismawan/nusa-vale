class_name DamageEffect
extends ActionEffect

@export var target_group: StringName = &"choppable"
@export var damage: int = 1

func apply(player: Player, cell: Vector2i) -> void:
	for node in player.get_tree().get_nodes_in_group(target_group):
		if not (node is Node2D and node.has_method("take_hit")):
			continue
		if player.world_to_cell(node.global_position) == cell:
			node.take_hit(damage)
