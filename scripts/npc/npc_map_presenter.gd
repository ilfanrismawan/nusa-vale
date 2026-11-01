extends Node

@export var map_id := "town"
@export var actors_root: NodePath = ^"../NPCActors"
@export var points_root: NodePath = ^"../NPCPoints"
@export var paths_root: NodePath = ^"../NPCPaths"
@export var actor_scene: PackedScene = preload("res://scenes/npc/ScheduledNPC.tscn")
## Saat pemain masuk peta, warga yang jadwalnya sudah berjalan selama ini (menit game)
## langsung berdiri di titik aktivitasnya, bukan berjalan dari pintu.
@export_range(0, 120, 1) var settle_after_minutes := 10
var actors: Dictionary = {}
## id -> entri yang rutenya gagal; peringatan dicetak sekali per entri.
var _route_failures: Dictionary = {}
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

## Menit game sejak entri jadwal dimulai (melewati tengah malam dihitung benar).
static func minutes_since(entry: Dictionary, hour: int, minute: int) -> int:
	var parts := str(entry.get("time", "")).split(":")
	if parts.size() != 2:
		return 24 * 60
	return posmod(hour * 60 + minute - (int(parts[0]) * 60 + int(parts[1])), 24 * 60)

## Arah hadap di titik: entri jadwal, lalu metadata `npc_facing` pada Marker2D (bisa diisi di editor),
## kosong = NPC mempertahankan arah langkah terakhirnya.
static func facing_for(entry: Dictionary, marker: Node) -> String:
	var facing := str(entry.get("facing", ""))
	if facing.is_empty() and marker != null and marker.has_meta("npc_facing"):
		facing = str(marker.get_meta("npc_facing"))
	return facing

func _warn_route_once(id: String, entry: Dictionary, message: String) -> void:
	if _route_failures.get(id) == entry:
		return
	_route_failures[id] = entry
	push_warning(message)

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
						# Rute keluar putus: lepaskan aktor daripada tertahan di peta selamanya.
						_warn_route_once(id, entry, "NPC %s tidak punya rute keluar ke %s; aktor dilepas." % [id, entry.map])
						leaving.queue_free()
						actors.erase(id)
						active_entries.erase(id)
						departures.erase(id)
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
		var anchored := bool(NPCDatabase.residents[id].get("anchored", false))
		var settled := anchored or network == null or minutes_since(entry, DayCycle.hour, DayCycle.minute) >= settle_after_minutes
		if initial:
			var actor := actor_scene.instantiate()
			actor.npc_id = id
			actor.name = id.capitalize()
			root.add_child(actor)
			if settled:
				actor.global_position = marker.global_position
			else:
				actor.global_position = network.gateway(NPCDatabase.arrival_from(id, entry, GameState.weather.is_raining()), id)
			actors[id] = actor
		if not initial and not departures.has(id) and active_entries.get(id) == entry:
			continue
		var npc: VillageNPC = actors[id]
		departures.erase(id)
		var facing := facing_for(entry, marker)
		var place_now := initial and settled
		var path: Array = []
		if anchored or place_now:
			path = [marker.global_position]
		elif network != null:
			path = network.route(npc.global_position, marker.global_position, id)
		if path.is_empty():
			# Rute putus: taruh langsung di titik dan catat sekali, jangan dicoba ulang tiap menit.
			_warn_route_once(id, entry, "NPC %s tidak punya rute ke %s/%s; ditaruh langsung di titik." % [id, map_id, entry.point])
			path = [marker.global_position]
			place_now = true
		npc.schedule = [
			{
				"hour": 0, "target_pos": marker.global_position, "activity": entry.activity,
			"path": path, "facing": facing,
			"dialog_lines": PackedStringArray()
			}
		]
		npc._apply_schedule(0, place_now)
		active_entries[id] = entry
		if _route_failures.has(id) and _route_failures[id] != entry:
			_route_failures.erase(id)
