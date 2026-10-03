extends CanvasLayer

@onready var rect: ColorRect = $ColorRect

const DURATION := 0.4

var on_transition := false

func _ready() -> void:
	rect.modulate.a = 0.0
	process_mode = Node.PROCESS_MODE_ALWAYS

func scene_transition(path: String) -> void:
	if on_transition:
		return
	on_transition = true
	
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var tween := create_tween()
	tween.tween_property(rect, "modulate:a", 1, DURATION)
	tween.set_trans(Tween.TRANS_SINE).set_ease(tween.EASE_IN_OUT)
	await tween.finished
	
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	
	await get_tree().process_frame
	
	tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(tween.EASE_IN_OUT)
	tween.tween_property(rect, "modulate:a", 0.0, DURATION)
	await tween.finished
	
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	on_transition = false
