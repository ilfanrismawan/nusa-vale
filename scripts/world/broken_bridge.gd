class_name BrokenBridge
extends Node2D

const BRIDGE_FLAG := "bridge_repaired"

const REQUIRED_WOOD: int = 20
const REQUIRED_STONE: int = 10

const WARNING_COOLDOWN: float = 2.0

@onready var broken_sprite: Sprite2D = $Visual/BrokenSprite
@onready var repaired_sprite: Sprite2D = $Visual/RepairedSprite
@onready var blocker: StaticBody2D = $Blocker
@onready var interaction_area: Area2D = $InteractionArea
@onready var blocker_collision: CollisionShape2D = $Blocker/CollisionShape2D
@onready var warning_area: Area2D = $BlockerWarningArea
@onready var warning_collisioon: CollisionShape2D = $BlockerWarningArea/CollisionShape2D

var _warning_ready: bool = true

func _ready() -> void:
	_apply_world_state()
	WorldState.flag_changed.connect(_on_world_flag_changed)	
	warning_area.body_entered.connect(_on_warning_body_entered)
func _on_world_flag_changed(flag_id: String, value: bool) -> void:
	if flag_id == BRIDGE_FLAG:
		_apply_world_state()
	
		
func _apply_world_state() -> void:
	var repaired := WorldState.has_flag(BRIDGE_FLAG)
	
	broken_sprite.visible = not repaired
	repaired_sprite.visible = not repaired == false
	
	blocker_collision.set_deferred("disabled", repaired)


func _on_warning_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if WorldState.has_flag(BRIDGE_FLAG):
		return
	if not _warning_ready:
		return
	
	_show_requirements()
	
	_warning_ready = false
	await get_tree().create_timer(WARNING_COOLDOWN).timeout
	_warning_ready = true

func _show_requirements() -> void:
	var wood := GameState.get_item_count("wood")	
	var stone := GameState.get_item_count("stone")
	Notify.say("Jembatan rusak! Butuh %d Wood (%d/%d) dan %d Stone (%d/%d)." %[ 
		REQUIRED_WOOD, wood, REQUIRED_WOOD,
		REQUIRED_STONE, stone, REQUIRED_STONE,
	])
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
	UnlockManager.unlock("forest")
	
	Notify.say("Jembatan berhasil diperbaiki!")
		
	return true
