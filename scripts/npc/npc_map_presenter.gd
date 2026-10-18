extends Node

@export var map_id := "town"
@export var actors_root: NodePath = ^"../NPCActors"
@export var points_root: NodePath = ^"../NPCPoints"
const ACTOR = preload("res://scenes/npc/ScheduledNPC.tscn")
var actors: Dictionary = {}
var active_entries: Dictionary = {}

func _ready() -> void:
	DayCycle.time_tick.connect(_on_time_tick)
	GameState.weather.changed.connect(refresh)
	refresh()

func _on_time_tick(_hour: int, _minute: int) -> void:
	refresh()

func refresh() -> void:
	var points := get_node(points_root)
	var root := get_node(actors_root)
	for id: String in NPCDatabase.residents:
		var entry := NPCDatabase.schedule_entry(id, DayCycle.hour, DayCycle.minute, GameState.weather.is_raining())
		if entry.get("map", "") != map_id:
			if actors.has(id):
				actors[id].queue_free()
				actors.erase(id)
				active_entries.erase(id)
			continue
		var marker := points.get_node_or_null(NodePath(str(entry.point))) as Node2D
		if marker == null:
			push_error("Missing NPC point %s/%s" % [map_id, entry.point])
			continue
		var initial := not actors.has(id)
		if initial:
			var actor := ACTOR.instantiate()
			actor.npc_id = id
			actor.name = id.capitalize()
			root.add_child(actor)
			actors[id] = actor
		if not initial and active_entries.get(id) == entry:
			continue
		var npc: VillageNPC = actors[id]
		var data: Dictionary = NPCDatabase.residents[id]
		npc.schedule = [{"hour": 0, "target_pos": marker.global_position, "activity": entry.activity,
			"dialog_lines": PackedStringArray(data.dialogue.get(entry.activity, data.dialogue.default))}]
		npc._apply_schedule(0, initial)
		active_entries[id] = entry
