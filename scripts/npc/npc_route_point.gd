@tool
extends Marker2D

## Empty means a shared physical entrance; a resident-specific marker wins.
@export var npc_id: StringName

## Maps reached through this doorway/boundary, e.g. town or wira_home.
@export var destination_maps: PackedStringArray = []
@export var default_gateway := false
