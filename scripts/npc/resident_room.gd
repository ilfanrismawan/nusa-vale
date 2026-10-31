class_name ResidentRoom
extends Node2D
## Membuat interior bisa dihuni warga berjadwal: NPCPoints, NPCActors, NPCPaths (pintu -> lorong -> titik)
## dan NPCMapPresenter dibangun saat runtime, jadi interior prosedural (town_room) tidak perlu disusun manual.
## Titik yang dipakai jadwal NPCDatabase untuk map ini otomatis dibuat bila tidak ada di `points`.

const Presenter := preload("res://scripts/npc/npc_map_presenter.gd")
const Network := preload("res://scripts/npc/npc_route_network.gd")
const Gateway := preload("res://scripts/npc/npc_route_point.gd")
const WalkPath := preload("res://scripts/npc/npc_walk_path.gd")

## Kosong = nama file scene induk (mis. "warung").
@export var map_id := ""
## Peta di balik pintu (gateway NPC).
@export var outside_map := "town"
@export var door_position := Vector2(240, 296)
## Titik belok antara pintu dan titik aktivitas.
@export var hall_position := Vector2(240, 220)
## Posisi titik eksplisit: nama titik -> posisi. Titik lain dari jadwal diletakkan berjajar.
@export var points: Dictionary = {}
## Titik otomatis diletakkan berjajar mulai dari sini ke kanan.
@export var auto_origin := Vector2(312, 150)
@export var auto_spacing := 36.0


## Titik jadwal (default & hujan) warga yang memakai map ini: {point: npc_id}.
static func scheduled_points(target_map: String) -> Dictionary:
	var result := {}
	for id: String in NPCDatabase.residents:
		var schedules: Dictionary = NPCDatabase.residents[id].get("schedules", {})
		for key in schedules:
			for entry: Dictionary in schedules[key]:
				if str(entry.get("map", "")) == target_map:
					result[str(entry.point)] = id
	return result


func _ready() -> void:
	var room := get_parent()
	if map_id.is_empty():
		map_id = room.scene_file_path.get_file().get_basename()
	# Scene yang sudah menyusun NPCPoints/NPCMapPresenter sendiri (mis. rumah Wira) tidak dibangun ulang.
	if room.has_node("NPCMapPresenter"):
		return
	var used := scheduled_points(map_id)
	if used.is_empty():
		return
	var markers := Node2D.new()
	markers.name = "NPCPoints"
	var actors := Node2D.new()
	actors.name = "NPCActors"
	actors.y_sort_enabled = true
	actors.z_index = 1
	var network := Node2D.new()
	network.name = "NPCPaths"
	network.set_script(Network)
	var door := Marker2D.new()
	door.name = "door"
	door.set_script(Gateway)
	door.position = door_position
	door.destination_maps = PackedStringArray([outside_map])
	door.default_gateway = true
	network.add_child(door)
	var names: Array = used.keys()
	names.sort()
	var slot := 0
	for point_name: String in names:
		var marker := Marker2D.new()
		marker.name = point_name
		if points.has(point_name):
			marker.position = points[point_name]
		else:
			marker.position = auto_origin + Vector2(auto_spacing * slot, 0)
			slot += 1
		markers.add_child(marker)
		var path := Path2D.new()
		path.name = "%s_door_to_%s" % [used[point_name], point_name]
		path.set_script(WalkPath)
		path.npc_id = StringName(used[point_name])
		var curve := Curve2D.new()
		for point in [door_position, hall_position, Vector2(marker.position.x, hall_position.y), marker.position]:
			if curve.point_count == 0 or curve.get_point_position(curve.point_count - 1).distance_to(point) > 0.5:
				curve.add_point(point)
		path.curve = curve
		network.add_child(path)
	room.add_child.call_deferred(markers)
	room.add_child.call_deferred(actors)
	room.add_child.call_deferred(network)
	var presenter := Node.new()
	presenter.name = "NPCMapPresenter"
	presenter.set_script(Presenter)
	presenter.map_id = map_id
	room.add_child.call_deferred(presenter)
