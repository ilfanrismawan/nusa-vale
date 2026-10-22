extends CanvasLayer

@onready var rect: ColorRect = $ColorRect

const DURATION := 0.4

var on_transition := false
## Arah hadap pemain sebelum pindah scene; dipakai Player._ready di scene baru
## lalu dikosongkan. Hanya runtime (tidak disimpan).
var carry_facing := Vector2.ZERO


func _ready() -> void:
	rect.modulate.a = 0.0
	process_mode = Node.PROCESS_MODE_ALWAYS


## `body` = pemain yang masuk pintu. Co-op: hanya pemain itu yang pindah area (CoopRoot),
## scene utama tidak diganti.
func scene_transition(path: String, body: Node = null) -> void:
	if path.is_empty():
		return
	if body is Player:
		body.release_carried_animal()
	if Coop.request_transition(body, path):
		return
	if on_transition:
		return
	on_transition = true

	_stop_player()
	PauseManager.set_requested(true)

	rect.mouse_filter = Control.MOUSE_FILTER_STOP

	var tween := _transition_tween()
	tween.tween_property(rect, "modulate:a", 1.0, DURATION)
	await tween.finished

	var leaving: Node = body if body is Player else get_tree().get_first_node_in_group("player")
	if leaving is Player:
		carry_facing = leaving.facing_direction
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	_stop_player()

	tween = _transition_tween()
	tween.tween_property(rect, "modulate:a", 0.0, DURATION)
	await tween.finished

	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PauseManager.set_requested(false)
	on_transition = false

func fade_action(action: Callable, hold: float = 0.3) -> void:
	if on_transition:
		action.call()
		return
	on_transition = true
	
	_stop_player()
	PauseManager.set_requested(true)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var tween := _transition_tween()
	tween.tween_property(rect, "modulate:a", 1.0, DURATION)
	await tween.finished
	
	action.call()
	await get_tree().create_timer(hold, true).timeout
	
	tween = _transition_tween()
	tween.tween_property(rect, "modulate:a", 0.0, DURATION)
	await tween.finished
	
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PauseManager.set_requested(false)
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
