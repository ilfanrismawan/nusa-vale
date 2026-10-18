extends Node

const DEFINITIONS := {
	&"kirana": preload
	("res://resources/npc_data/characters/npc_kirana.tres")
}

func get_definition(id: StringName) -> NPCDefinition:
	return DEFINITIONS.get(id) as NPCDefinition

# JSON definitions are shared by every loaded map, including co-op rooms.
var residents: Dictionary = {}

func _ready() -> void:
	for id in ["wira", "ubay"]:
		var path := "res://data/npc/%s.json" % id
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if value is Dictionary and value.get("id") == id:
			residents[id] = value
		else:
			push_error("Invalid NPC definition: " + path)

func schedule_entry(id: String, hour: int, minute: int, rainy: bool) -> Dictionary:
	var data: Dictionary = residents.get(id, {})
	var schedules: Dictionary = data.get("schedules", {})
	var entries: Array = schedules.get("rainy", schedules.get("default", [])) if rainy else schedules.get("default", [])
	if entries.is_empty():
		return {}
	var active: Dictionary = entries.back()
	for entry: Dictionary in entries:
		var parts := str(entry.time).split(":")
		if int(parts[0]) * 60 + int(parts[1]) <= hour * 60 + minute:
			active = entry
	return active
