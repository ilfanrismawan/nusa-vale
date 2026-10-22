extends Node
## Only editor play sessions load development tools. Exports never load them,
## including debug exports. No static dependency on excluded scripts.
func _ready() -> void:
	if OS.has_feature("editor") and OS.is_debug_build():
		var script = load("res://autoload/debug_manager.gd")
		if script != null:
			add_child(script.new())
