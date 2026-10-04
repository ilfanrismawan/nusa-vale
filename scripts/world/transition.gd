extends CanvasLayer

@onready var rect: ColorRect = $ColorRect

const DURATION := 0.4

var on_transition := false


func _ready() -> void:
	rect.modulate.a = 0.0
	process_mode = Node.PROCESS_MODE_ALWAYS


func scene_transition(path: String) -> void:
	if on_transition or path.is_empty():
		return
	on_transition = true

	_stop_player()
	get_tree().paused = true

	rect.mouse_filter = Control.MOUSE_FILTER_STOP

	var tween := _transition_tween()
	tween.tween_property(rect, "modulate:a", 1.0, DURATION)
	await tween.finished

	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	_stop_player()

	tween = _transition_tween()
	tween.tween_property(rect, "modulate:a", 0.0, DURATION)
	await tween.finished

	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().paused = false
	on_transition = false


func _transition_tween() -> Tween:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


func _stop_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player is CharacterBody2D:
		player.velocity = Vector2.ZERO
