class_name DailyWeather
extends Node

signal changed
const STATES := ["sunny", "rain"]
var current := "sunny"
var seed := 1
var _day := 1

func reset() -> void:
	seed = randi_range(1, 2147483647)
	current = "sunny"
	_day = DayCycle.current_day
	changed.emit()

func weather_for(day: int) -> String:
	if day == 1:
		return "sunny"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + day * 7919
	return "rain" if rng.randf() < 0.3 else "sunny"

func advance_day(day: int) -> void:
	if day != _day:
		current = weather_for(day)
		_day = day
	if is_raining():
		FarmManager.apply_rain()
	changed.emit()

func is_raining() -> bool:
	return current == "rain"

func display_name() -> String:
	return "Hujan" if is_raining() else "Cerah"

func to_save() -> Dictionary:
	return {"current": current, "seed": seed}

static func valid_save(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if value.is_empty():
		return true
	var number: Variant = value.get("seed")
	return value.get("current") in STATES and (number is int or number is float) and is_finite(float(number)) and float(number) == floorf(float(number)) and number >= 1 and number <= 2147483647

func load_save(value: Variant) -> void:
	current = "sunny"
	seed = 1
	_day = DayCycle.current_day
	if valid_save(value) and not value.is_empty():
		current = str(value.current)
		seed = int(value.seed)
	changed.emit()

func attach_player(player: Node) -> void:
	if not is_instance_valid(player) or not player.is_inside_tree():
		return
	var parent := Coop.ui_parent(player)
	if not is_instance_valid(parent):
		return
	var name := "WeatherViewP%d" % player.player_index
	if parent.has_node(NodePath(name)):
		return
	var view = load("res://scripts/effects/weather_view.gd").new()
	view.name = name
	view.player = player
	parent.add_child(view)
