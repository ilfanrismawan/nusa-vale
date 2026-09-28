extends Node

signal day_passed(day_number: int)

var current_day: int = 1

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_N:
		advance_day()

func advance_day() -> void:
	current_day += 1
	day_passed.emit(current_day)
	print("Hari baru: ", current_day)
