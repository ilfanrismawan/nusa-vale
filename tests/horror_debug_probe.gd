extends Node
## Probe: debug buttons Horor (set jam, munculkan kuntilanak/pocong, jumpscare).
## Writes res://tests/horror_debug_probe.log then quits.

var _log: PackedStringArray = []


func _ready() -> void:
	var world: Node = load("res://scenes/world/balai_nadi/balai.tscn").instantiate()
	add_child(world)
	var dm: Node = load("res://autoload/debug_manager.gd").new()
	add_child(dm)
	for i in 10:
		await get_tree().process_frame
	var horror: Node = dm._night_horror()
	_say("horror=%s" % horror)
	dm._cheat_set_horror_time()
	_say("time=%02d:%02d fear=%.2f" % [DayCycle.hour, DayCycle.minute, horror.fear if horror else -1.0])
	dm._cheat_spawn_stalker(0)
	await get_tree().process_frame
	_say("kuntilanak=%s" % (horror.current_stalker().name if horror and horror.current_stalker() else "null"))
	dm._cheat_spawn_stalker(1)
	await get_tree().process_frame
	_say("pocong=%s" % (horror.current_stalker().name if horror and horror.current_stalker() else "null"))
	dm._cheat_jumpscare()
	await get_tree().process_frame
	var js: CanvasItem = horror.get("_jumpscare") if horror else null
	_say("jumpscare_visible=%s" % (js.visible if js else "null"))
	var f := FileAccess.open("res://tests/horror_debug_probe.log", FileAccess.WRITE)
	f.store_string("\n".join(_log))
	f.close()
	get_tree().quit()


func _say(t: String) -> void:
	print(t)
	_log.append(t)
