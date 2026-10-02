class_name Bed
extends Area2D

var _player_in_range := false
var _sleeping := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_in_range = true

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_in_range = false
		
func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and not _sleeping and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_sleep()

func _sleep() -> void:
	_sleeping = true
	var layer := CanvasLayer.new()
	layer.layer = 50
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	layer.add_child(fade)
	get_tree().current_scene.add_child(layer)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.6)
	tw.tween_callback(_new_day)
	tw.tween_interval(0.5)
	tw.tween_property(fade, "color:a", 0.0, 0.6)
	tw.tween_callback(_end_sleep.bind(layer))

func _new_day() -> void:
	DayCycle.advance_day()
	SaveManager.save_game()
	
func _end_sleep(layer: CanvasLayer) -> void:
	layer.queue_free()
	_sleeping = false
