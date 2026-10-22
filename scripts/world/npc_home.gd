extends Node2D

var actors: Dictionary = {}

func _ready() -> void:
	y_sort_enabled = true
	DayCycle.time_tick.connect(func(_hour: int, _minute: int): refresh())
	refresh()

func refresh() -> void:
	var desired: Array[String] = []
	for id: String in NPCDatabase.residents:
		if not NPCHousehold.home_entry(id, DayCycle.hour).is_empty():
			desired.append(id)
	for id: String in actors.keys():
		if id not in desired:
			actors[id].queue_free()
			actors.erase(id)
	for id in desired:
		if actors.has(id):
			continue
		var actor := preload("res://scenes/npc/ScheduledNPC.tscn").instantiate()
		actor.npc_id = id
		actor.position = Vector2(288 + actors.size() * 22, 180)
		add_child(actor)
		actor._current_activity = "at_home"
		actors[id] = actor
