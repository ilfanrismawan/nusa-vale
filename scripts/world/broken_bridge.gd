class_name BrokenBridge
extends StaticBody2D

@export var wood_required: int = 20
@export var stone_required: int = 10

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	if WorldState.has_flag("bridge_repaired"):
		_repaired()


func repair() -> bool:
	
	if WorldState.has_flag("bridge_repaired"):
		return false
	
	if not GameState.has_item(
		"wood",
		wood_required
	):
		Notify.say("Butuh Wood x%d." % wood_required)
		return false
	
	if not GameState.has_item(
		"stone",
		stone_required
	):
		Notify.say("Butuh Stone x%d." %stone_required)
		
	GameState.remove_item(
		"wood",
		wood_required
	)
	
	GameState.remove_item(
		"stone",
		stone_required
	)
	
	WorldState.set_flag(
		"bridge_repaired",
		true
	)
	_repaired()
	
	Notify.say("Jembatan berhasil diperbaiki.")
	
	return true
	
func _repaired() -> void:
	collision_shape.set_deferred("disabled", true)
	
	if sprite:
		sprite.visible = false
