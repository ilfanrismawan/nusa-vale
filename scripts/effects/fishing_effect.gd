class_name FishingEffect
extends ActionEffect

func _init() -> void:
	stamina_cost = 3
	
func apply(
	_player: Player,
	_cell: Vector2i
) -> void:
	# Marker effect: ToolController routes this action to FishingState,
	# which owns casting, stamina, bite timing, minigame, and catch rewards.
	pass
