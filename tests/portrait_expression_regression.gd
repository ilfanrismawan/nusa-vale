extends Node

func _ready() -> void:
	var npc = load("res://scripts/npc/scheduled_npc.gd").new()
	npc.npc_id = "wira"
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	npc.add_child(sprite)
	add_child(npc)
	assert(npc.portrait_expressions.size() == 5)
	assert(npc.portrait_expressions["happy"].region == Rect2(0, 128, 64, 64))
	var dialog = load("res://scenes/ui/npc_dialog_ui.tscn").instantiate()
	dialog.portrait_texture = npc.portrait
	dialog.portrait_expressions = npc.portrait_expressions
	dialog.lines = PackedStringArray(["Hello", "Happy", "Unknown"])
	dialog.line_expressions = PackedStringArray(["sparkle", "happy", "missing"])
	add_child(dialog)
	assert(dialog.get_node("%Portrait").texture == npc.portrait_expressions["sparkle"])
	dialog._advance_dialog()
	assert(dialog.get_node("%Portrait").texture == npc.portrait_expressions["happy"])
	dialog._advance_dialog()
	assert(dialog.get_node("%Portrait").texture == npc.portrait_expressions["neutral"])
	dialog._advance_dialog()
	assert(dialog._closed)
	print("PORTRAIT REGRESSION COMPLETE")
	get_tree().quit()
