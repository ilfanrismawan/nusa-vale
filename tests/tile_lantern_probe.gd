extends Node
## Probe: balai.tscn Bridge lantern lights on at night, off at noon.
## Writes res://tests/tile_lantern_probe.log then quits.

var _log: PackedStringArray = []


func _ready() -> void:
	var balai: Node = load("res://scenes/world/balai_nadi/balai.tscn").instantiate()
	add_child(balai)
	var bridge := balai.get_node_or_null("Bridge")
	_say("bridge=%s script=%s" % [bridge, bridge.get_script() if bridge else null])
	for i in 5:
		await get_tree().process_frame
	_say("hour before=%d:%02d" % [DayCycle.hour, DayCycle.minute])
	DayCycle.hour = 22
	DayCycle.minute = 0
	for i in 3:
		await get_tree().process_frame
	_say("hour after=%d:%02d" % [DayCycle.hour, DayCycle.minute])
	var lights := bridge.find_children("*", "PointLight2D", true, false) if bridge else []
	_say("night_intensity=%.2f lights=%d" % [DayCycle.night_intensity(), lights.size()])
	for l in lights:
		var pl := l as PointLight2D
		_say("  pos=%s enabled=%s energy=%.2f" % [pl.global_position, pl.enabled, pl.energy])
	DayCycle.hour = 12
	for i in 3:
		await get_tree().process_frame
	var on := 0
	for l in lights:
		if (l as PointLight2D).enabled:
			on += 1
	_say("noon lights_on=%d" % on)
	var f := FileAccess.open("res://tests/tile_lantern_probe.log", FileAccess.WRITE)
	f.store_string("\n".join(_log))
	f.close()
	get_tree().quit()


func _say(t: String) -> void:
	print(t)
	_log.append(t)
