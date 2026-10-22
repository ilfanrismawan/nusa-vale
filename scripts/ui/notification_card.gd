extends PanelContainer

@export_range(0.2, 12.0) var display_seconds := 3.2
@export_range(0.05, 2.0) var fade_seconds := 0.3
@export_range(0.0, 0.5) var entrance_seconds := 0.14
var text := ""
var _animation: Tween

func present(message: String) -> void:
	text = message
	%Message.text = message
	modulate.a = 0.0
	%Lifetime.value = 100
	_animation = create_tween()
	_animation.tween_property(self, "modulate:a", 1.0, entrance_seconds)
	_animation.tween_property(%Lifetime, "value", 0.0, display_seconds)
	_animation.tween_property(self, "modulate:a", 0.0, fade_seconds)
	_animation.tween_callback(queue_free)
