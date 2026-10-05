extends Node

signal discovered(discovery_id: String)

var discoveries: Dictionary = {}


func discover(discovery_id: String) -> bool:
	if discoveries.get(discovery_id, false):
		return false

	discoveries[discovery_id] = true
	discovered.emit(discovery_id)

	return true


func has_discovered(discovery_id: String) -> bool:
	return bool(discoveries.get(discovery_id, false))


func reset() -> void:
	discoveries.clear()
