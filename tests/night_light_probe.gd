extends Node
## Probe: window_light / fountain_light follow day/night. Writes res://tests/night_light_probe.log.

var _log: PackedStringArray = []


func _ready() -> void:
	var w: PointLight2D = load("res://scenes/world/exterior/object/window_light.tscn").instantiate()
	var f: PointLight2D = load("res://scenes/world/exterior/object/fountain_light.tscn").instantiate()
	add_child(w)
	add_child(f)
	for i in 3:
		await get_tree().process_frame
	DayCycle.hour = 12
	await get_tree().process_frame
	_say("noon window=%s fountain=%s" % [w.enabled, f.enabled])
	DayCycle.hour = 21
	await get_tree().process_frame
	_say("21:00 window=%s e=%.2f fountain=%s e=%.2f" % [w.enabled, w.energy, f.enabled, f.energy])
	var fa := FileAccess.open("res://tests/night_light_probe.log", FileAccess.WRITE)
	fa.store_string("\n".join(_log))
	fa.close()
	get_tree().quit()


func _say(t: String) -> void:
	print(t)
	_log.append(t)
