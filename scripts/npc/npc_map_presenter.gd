extends Node

@export var map_id := "town"
@export var actors_root: NodePath = ^"../NPCActors"
@export var points_root: NodePath = ^"../NPCPoints"
@export var paths_root: NodePath = ^"../NPCPaths"
@export var actor_scene: PackedScene = preload("res://scenes/npc/ScheduledNPC.tscn")
var actors: Dictionary = {}
var active_entries: Dictionary = {}
var departures: Dictionary = {}

func _process(_delta: float) -> void:
	for id: String in departures.keys():
		var actor: VillageNPC = actors.get(id)
		if actor != null and not actor._is_walking:
			actor.queue_free()
			actors.erase(id)
			active_entries.erase(id)
			departures.erase(id)

func _ready() -> void:
	DayCycle.time_tick.connect(_on_time_tick)
	GameState.weather.changed.connect(refresh)
	refresh()

func _on_time_tick(_hour: int, _minute: int) -> void:
	refresh()

func refresh() -> void:
	var points := get_node(points_root)
	var root := get_node(actors_root)
	var network := get_node_or_null(paths_root)
	for id: String in NPCDatabase.residents:
		var entry: Dictionary = NPCDatabase.schedule_entry(id, DayCycle.hour, DayCycle.minute, GameState.weather.is_raining())
		if entry.get("map", "") == "player_home":
			if actors.has(id):
				actors[id].queue_free()
				actors.erase(id)
				active_entries.erase(id)
				departures.erase(id)
			continue
		if entry.get("map", "") != map_id:
			if actors.has(id):
				if departures.get(id) == entry:
					continue
				var leaving: VillageNPC = actors[id]
				if network != null:
					var exit: Vector2 = network.gateway(str(entry.map), id)
					var exit_path: Array = network.route(leaving.global_position, exit, id)
					if exit_path.is_empty():
						continue
					leaving.schedule = [{"hour": 0, "target_pos": exit,
						"path": exit_path,
						"activity": leaving._current_activity, "dialog_lines": leaving._schedule_dialog_lines}]
					leaving._apply_schedule(0, false)
					departures[id] = entry
				else:
					push_error("Missing NPCPaths for " + map_id)
			continue
		var marker := points.get_node_or_null(NodePath(str(entry.point))) as Node2D
		if marker == null:
			push_error("Missing NPC point %s/%s" % [map_id, entry.point])
			continue
		var initial := not actors.has(id)
		if initial:
			var actor := actor_scene.instantiate()
			actor.npc_id = id
			actor.name = id.capitalize()
			root.add_child(actor)
			if network != null:
				actor.global_position = network.gateway(NPCDatabase.arrival_from(id, entry, GameState.weather.is_raining()), id)
			actors[id] = actor
		if not initial and not departures.has(id) and active_entries.get(id) == entry:
			continue
		var npc: VillageNPC = actors[id]
		departures.erase(id)
		var path: Array = network.route(npc.global_position, marker.global_position, id) if network != null else []
		if path.is_empty():
			continue
		npc.schedule = [
			{
				"hour": 0, "target_pos": marker.global_position, "activity": entry.activity,
			"path": path,
			"dialog_lines": PackedStringArray()
			}
		]
		npc._apply_schedule(0, false)
		active_entries[id] = entry
