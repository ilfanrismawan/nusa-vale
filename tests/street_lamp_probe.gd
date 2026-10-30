extends Node
## Probe: street_lamp.tscn frame + light follow day/night. Writes res://tests/street_lamp_probe.log.

var _log: PackedStringArray = []


func _ready() -> void:
	var lamp: Node2D = load("res://scenes/world/exterior/object/street_lamp.tscn").instantiate()
	add_child(lamp)
	for i in 3:
		await get_tree().process_frame
	DayCycle.hour = 12
	await get_tree().process_frame
	_say("noon frame=%d light=%s" % [lamp.get_node("Art").frame, lamp.get_node("Light").enabled])
	DayCycle.hour = 21
	await get_tree().process_frame
	_say("night frame=%d light=%s energy=%.2f" % [lamp.get_node("Art").frame, lamp.get_node("Light").enabled, lamp.get_node("Light").energy])
	var f := FileAccess.open("res://tests/street_lamp_probe.log", FileAccess.WRITE)
	f.store_string("\n".join(_log))
	f.close()
	get_tree().quit()


func _say(t: String) -> void:
	print(t)
	_log.append(t)
