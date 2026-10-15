extends Node

## Focus pause and gameplay/menu pause are independent, so returning to the
## window never closes a menu or resumes a transition that was already paused.
var background := false
var requested := false
var _reasons: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _notification(what: int) -> void:
	if Engine.is_editor_hint() or DisplayServer.get_name() == "headless":
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		set_background(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		set_background(false)

func set_background(value: bool) -> void:
	if value and not background and _reasons.is_empty():
		requested = get_tree().paused
	background = value
	_apply()

func set_requested(value: bool) -> void:
	requested = value
	_apply()

func set_reason(reason: StringName, value: bool) -> void:
	if value:
		_reasons[reason] = true
	else:
		_reasons.erase(reason)
	_apply()

func _apply() -> void:
	get_tree().paused = background or requested or not _reasons.is_empty()
