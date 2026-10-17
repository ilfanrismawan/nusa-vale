extends Node2D

@export var required_flag: String

func _ready() -> void:
	WorldState.flag_changed.connect(_changed)
	_refresh()

func _changed(_flag: String, _value: bool) -> void:
	_refresh()

func _refresh() -> void:
	visible = WorldState.has_flag(required_flag)
