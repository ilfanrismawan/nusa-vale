extends Node2D

## Replace these placeholder children with art; gameplay only depends on their names.
@export var project_id := "balai_nadi_restoration"

func _ready() -> void:
	GameState.balai_nadi.state_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	var restored := GameState.balai_nadi.completed(project_id)
	$Unrestored.visible = not restored
	$Restored.visible = restored
