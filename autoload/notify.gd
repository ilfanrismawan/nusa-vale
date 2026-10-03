extends CanvasLayer

var _box: VBoxContainer


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.position = Vector2(8, 290)
	add_child(_box)

func say(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", preload("res://assets/fonts/m5x7.ttf"))
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	_box.add_child(label)
	if _box.get_child_count() > 4:
		_box.get_child(0).queue_free()
	
	var tw := label.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(label.queue_free)
	
