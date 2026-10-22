extends Node

const ResidentProfile = preload("res://scripts/npc/data/resident_profile.gd")
@export var resident_profiles: Array[ResidentProfile] = []
@export_file("*.json") var family_story_file := "res://data/npc/wira_family_story.json"
@export_file("*.json") var gift_profiles_file := "res://data/npc/social/gift_profiles.json"
var family_story: Dictionary = {}
var gift_profiles: Dictionary = {}

func social_definition(id: String) -> Dictionary:
	return residents.get(id, gift_profiles.get(id, {}))

const DEFINITIONS := {
	&"kirana": preload
	("res://resources/npc_data/characters/npc_kirana.tres")
}

func get_definition(id: StringName) -> NPCDefinition:
	return DEFINITIONS.get(id) as NPCDefinition

# JSON definitions are shared by every loaded map, including co-op rooms.
var residents: Dictionary = {}

func _load_family_story() -> void:
	family_story.clear()
	if family_story_file.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(family_story_file))
	if parsed is Dictionary:
		family_story = parsed
	else :
		push_error("Invalid family story JSON: " + family_story_file)

func _ready() -> void:
	_load_family_story()
	var gifts: Variant = JSON.parse_string(FileAccess.get_file_as_string(gift_profiles_file))
	if gifts is Dictionary:
		gift_profiles = gifts
	else:
		push_error("Invalid NPC gift profiles: " + gift_profiles_file)
	for profile in resident_profiles:
		if profile == null:
			continue
		var value := profile.definition()
		if not value.is_empty():
			residents[profile.npc_id] = value

func schedule_entry(id: String, hour: int, minute: int, rainy: bool) -> Dictionary:
	var home := NPCHousehold.home_entry(id, hour)
	if not home.is_empty():
		return home
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

func arrival_from(id: String, entry: Dictionary, rainy: bool) -> String:
	var schedules: Dictionary = residents[id].schedules
	var entries: Array = schedules.get("rainy", schedules.default) if rainy else schedules.default
	var index := entries.find(entry)
	for offset in range(1, entries.size() + 1):
		var previous: Dictionary = entries[posmod(index - offset, entries.size())]
		if previous.map != entry.map:
			return str(previous.map)
	return str(residents[id].home_map)
