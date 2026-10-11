extends Node

signal flag_changed(flag_id: String, value: bool)

const DEFAULT_FLAGS := {
	"bridge_repaired": false,
	#"forest_unlocked": false,
	#"cave_unlocked": false,
	"school_open": false
}
var flags: Dictionary = {}

func _ready() -> void:
	_load_default_flags()

func _load_default_flags() -> void:
	flags = DEFAULT_FLAGS.duplicate(true)

func set_flag(flag_id: String, value: bool = true) -> void:
	var old_value: bool = bool(flags.get(flag_id, false))
	
	if old_value == value:
		return
	
	flags[flag_id] = value
	
	flag_changed.emit(flag_id, value)
	
func has_flag(flag_id: String) -> bool:
	return bool(flags.get(flag_id, false))
	
func clear_flag(flag_id: String) -> void:
	set_flag(flag_id, false)
	
func reset() -> void:
	_load_default_flags()
	
