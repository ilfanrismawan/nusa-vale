extends Node

signal time_tick(hour: int, minute: int)
signal day_passed(day_number: int)

var current_day: int = 1
var hour: int = 6
var minute: int = 0

const TICK_INTERVAL := 0.7
var _timer: float = 0.0

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= TICK_INTERVAL:
		_timer = 0.0
		advance_minute(10)
		
func advance_minute(amount: int) -> void:
	minute += amount
	if minute >= 60:
		minute = 0
		hour += 1
		
		if hour >= 24:
			advance_day()
			return
			
	time_tick.emit(hour, minute)		
		
func advance_day() -> void:
	hour = 6
	minute = 0
	current_day += 1
	day_passed.emit(current_day)
	time_tick.emit(hour, minute)
	print("Hari baru dimulai: Hari", current_day)
	
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_N:
		advance_day()
