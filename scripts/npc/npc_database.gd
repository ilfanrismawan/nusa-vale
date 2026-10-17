extends Node

const DEFINITIONS := {
	&"kirana": preload
	("res://resources/npc_data/characters/npc_kirana.tres")
}

func get_definition(id: StringName) -> NPCDefinition:
	return DEFINITIONS.get(id) as NPCDefinition
