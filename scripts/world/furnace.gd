class_name Furnace
extends StaticBody2D

@export var copper_ore_required: int = 5
@export var copper_bar_output: int = 1

func smelt_copper() -> bool:
	if not GameState.has_item(
		"copper_ore",
		copper_ore_required
	):
		Notify.say("Copper Ore tidak cukup.")
		return false
	
	GameState.remove_item(
		"copper_ore",
		copper_ore_required
	)
	
	GameState.add_item(
		"copper_bar",
		copper_bar_output
	)
	
	Notify.say("Copper Bar berhasil dibuat.")
	
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		smelt_copper()
