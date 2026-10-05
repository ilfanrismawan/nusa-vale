extends Node

signal time_tick(hour: int, minute: int)
signal day_passed(day_number: int)
signal player_passed_out

@export var real_seconds_per_10_game_minutes: float = 5.0

var current_day: int = 1
var hour: int = 6
var minute: int = 0

var is_running: bool = false
const TICK_INTERVAL := 0.7
var _timer: float = TICK_INTERVAL
var _is_passing_out: bool = false

func _process(delta: float) -> void:
	if not is_running or get_tree().paused or _is_passing_out:
		return
	_timer += delta
	
	if _timer >= real_seconds_per_10_game_minutes:
		_timer -= real_seconds_per_10_game_minutes
		advance_minute(10)
		
func advance_minute(amount: int) -> void:
	minute += amount
	if minute >= 60:
		minute = 0
		hour += 1
		
		if hour >= 24:
			hour = 0
		
		if hour == 2 and not _is_passing_out:
			trigger_pass_out()
			return
			
	time_tick.emit(hour, minute)	
		
func trigger_pass_out() -> void:
	_is_passing_out = true
	player_passed_out.emit()		
	
	var layer := CanvasLayer.new()
	layer.layer = 100
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(fade)
	add_child(layer)
	
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 1.2)
	tw.tween_callback(func():
		advance_day()
		hour = 8
		minute = 0
		time_tick.emit(hour, minute)
		
		GameState.stamina = int(GameState.MAX_STAMINA * 0.5)
		GameState.stamina_changed.emit(GameState.stamina, GameState.MAX_STAMINA)
		
		GameState.next_spawn_position = Vector2(317, 151)
		GameState.has_spawn_point = true
		get_tree().change_scene_to_file("res://scenes/world/interior/interior_house.tscn")
		SaveManager.save_game()
		Notify.say("Kamu pingsan kelelahan jam 2 malam! Bangun jam 8 dengan energi 50%")
		)
	tw.tween_interval(1.0)
	tw.tween_property(fade, "color:a", 0.0, 1.0)
	tw.tween_callback(func ():
		layer.queue_free()
		_is_passing_out = false)
	
func advance_day() -> void:
	hour = 6
	minute = 0
	current_day += 1
	day_passed.emit(current_day)
	time_tick.emit(hour, minute)
	print("Hari baru dimulai: Hari %d" % current_day)
	
	
func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and event.keycode == KEY_N:
		advance_day()
