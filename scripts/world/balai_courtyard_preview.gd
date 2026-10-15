extends Node2D
## Visual preview: no player, travel, donations, or restoration-state writes.
@export var restored := true:
	set(value):
		restored = value
		if is_inside_tree(): _refresh()

func _enter_tree() -> void:
	get_node("Player").free()
	get_node("RestorationVisual").set_script(null)
	for candidate in find_children("*","Area2D",true,false):
		candidate.set_script(null)

func _ready() -> void:
	_refresh()

func _refresh() -> void:
	$RestorationVisual/Restored.visible = restored
	$RestorationVisual/Unrestored.visible = not restored

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and event is InputEventKey and event.keycode == KEY_SPACE:
		restored = not restored
		get_viewport().set_input_as_handled()
