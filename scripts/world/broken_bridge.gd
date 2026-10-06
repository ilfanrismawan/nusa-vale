class_name BrokenBridge
extends Node2D

const BRIDGE_FLAG := "bridge_repaired"
const FOREST_FLAG := "forest_unlocked"

const REQUIRED_WOOD: int = 20
const REQUIRED_STONE: int = 10

@onready var broken_sprite: Sprite2D = $Visual/BrokenSprite
@onready var repaired_sprite: Sprite2D = $Visual/RepairedSprite
@onready var blocker: StaticBody2D = $Blocker
@onready var interaction_area: Area2D = $InteractionArea
@onready var blocker_collision: CollisionShape2D = $Blocker/CollisionShape2D


func _ready() -> void:
	_apply_world_state()
	WorldState.flag_changed.connect(_on_world_flag_changed)	
		
func _on_world_flag_changed(flag_id: String, value: bool) -> void:
	if flag_id == BRIDGE_FLAG:
		_apply_world_state()
		
func _apply_world_state() -> void:
	var repaired := WorldState.has_flag(BRIDGE_FLAG)
	
	broken_sprite.visible = not repaired
	repaired_sprite.visible = repaired
	
	blocker_collision.set_deferred("disabled", repaired)

	
func interact() -> void:
	if WorldState.has_flag("bridge_repaired"):
		Notify.say("Jembatan sudah diperbaiki.")
		return
	
	repair_bridge()

func repair_bridge() -> bool:
	if WorldState.has_flag(BRIDGE_FLAG):
		return false
	
	if not GameState.has_item("wood", REQUIRED_WOOD):
		Notify.say("Butuh %d Wood." % REQUIRED_WOOD)
		return false
	
	if not GameState.has_item("stone", REQUIRED_STONE):
		Notify.say("Butuh %d Stone." % REQUIRED_STONE)	
		return false
	
	GameState.remove_item("wood", REQUIRED_WOOD)
	GameState.remove_item("stone", REQUIRED_STONE)
	
	WorldState.set_flag(BRIDGE_FLAG, true)
	WorldState.set_flag(FOREST_FLAG, true)
	
	Notify.say("Jembatan berhasil diperbaiki!")
		
	return true
