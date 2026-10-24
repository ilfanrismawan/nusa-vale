class_name BrokenBridge
extends Node2D

const BRIDGE_FLAG := "bridge_repaired"

const REQUIRED_WOOD: int = 100
const REQUIRED_STONE: int = 50

const WARNING_COOLDOWN: float = 2.0
const UNLOCK_FEEDBACK: ActionFeedback = preload("res://resources/feedback/bridge_unlock.tres")

@export var water_layer: PassableTileLayer
@export var walkaway: Rect2 = Rect2(-62, -16, 124, 23)

@onready var broken_sprite: Sprite2D = $Visual/BrokenSprite
@onready var repaired_sprite: Sprite2D = $Visual/RepairedSprite
@onready var blocker: StaticBody2D = $Blocker
@onready var interaction_area: Area2D = $InteractionArea
@onready var blocker_collision: CollisionShape2D = $Blocker/CollisionShape2D
@onready var warning_area: Area2D = $BlockerWarningArea
@onready var warning_collisioon: CollisionShape2D = $BlockerWarningArea/CollisionShape2D

var _warning_ready: bool = true
var _repair_in_progress: bool = false

func _ready() -> void:
	_open_water_under_walkaway()
	_apply_world_state()
	WorldState.flag_changed.connect(_on_world_flag_changed)	
	warning_area.body_entered.connect(_on_warning_body_entered)
	
func _on_world_flag_changed(flag_id: String, value: bool) -> void:
	if flag_id == BRIDGE_FLAG:
		_apply_world_state()
	
		
func _apply_world_state() -> void:
	var repaired := WorldState.has_flag(BRIDGE_FLAG)
	
	broken_sprite.visible = not repaired
	repaired_sprite.visible = repaired
	
	blocker_collision.set_deferred("disabled", repaired)

func _open_water_under_walkaway() -> void:
	if water_layer == null:
		return
	var top_left: Vector2i = water_layer.local_to_map(water_layer.to_local(to_global(walkaway.position)))
	var bottom_right: Vector2i = water_layer.local_to_map(water_layer.to_local(to_global((walkaway.end - Vector2.ONE))))
	var cells: Array[Vector2i] = []
	for y in range(top_left.y, bottom_right.y + 1):
		for x in range(top_left.x, bottom_right.x + 1):
			cells.append(Vector2i(x, y))
	water_layer.set_cells_passable(cells, true)
			
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
	Notify.say("Tekan %s untuk memperbaiki." % InputPrompt.key_text(&"interact", null, InputLayout.FIELD, 1))
	
func interact() -> void:
	if WorldState.has_flag("bridge_repaired"):
		Notify.say("Jembatan sudah diperbaiki.")
		return
		
	if _repair_in_progress:
		return
	
	repair_bridge()

func repair_bridge() -> bool:
	if _repair_in_progress:
		return false
	
	if WorldState.has_flag(BRIDGE_FLAG):
		return false
	
	if not GameState.has_item("wood", REQUIRED_WOOD):
		Notify.say("Butuh %d Wood." % REQUIRED_WOOD)
		return false
	
	if not GameState.has_item("stone", REQUIRED_STONE):
		Notify.say("Butuh %d Stone." % REQUIRED_STONE)	
		return false
	
	_repair_in_progress = true
	
	if not GameState.remove_item("wood", REQUIRED_WOOD):
		_repair_in_progress = false
		return false
		
	if not GameState.remove_item("stone", REQUIRED_STONE):
		var remaining := GameState.add_item("wood", REQUIRED_WOOD)
		
		if remaining > 0:
			push_error("BrokenBridge: Gagal mengembalikan seluruh wood")
		
		_repair_in_progress = false
		return false
		
	_play_repair_transition()
	return true
	
func _play_repair_transition() -> void:
	await Transition.fade_action(_finish_repair)
	# Celebrate after the fade: particles and sound should not disappear behind black.
	_play_unlock_celebration()
	_repair_in_progress = false
	Notify.say("Jembatan berhasil diperbaiki!")
	
func _finish_repair() -> void:
	WorldState.set_flag(BRIDGE_FLAG, true)
	UnlockManager.unlock("forest")

func _play_unlock_celebration() -> void:
	Juice.play_upgrade_reward(1)
	Juice.shake(1.5, 0.22)
	Juice.float_text("Hutan terbuka!", to_global(Vector2(0, -34)), Color("ffe6a3"), 1.5)

	var base_scale := repaired_sprite.scale
	var base_modulate := repaired_sprite.modulate
	repaired_sprite.scale = base_scale * Vector2(1.04, 0.94)
	repaired_sprite.modulate = Color(1.5, 1.35, 1.05, base_modulate.a)
	var reveal := create_tween().set_parallel(true)
	reveal.tween_property(repaired_sprite, "scale", base_scale, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_property(repaired_sprite, "modulate", base_modulate, 0.65)

	# World-space bursts are visible to both players sharing this area.
	var sweep := create_tween()
	for x in [-48.0, -24.0, 0.0, 24.0, 48.0]:
		sweep.tween_callback(_unlock_sparkle.bind(Vector2(x, -6)))
		sweep.tween_interval(0.09)

func _unlock_sparkle(local_pos: Vector2) -> void:
	Juice.burst(to_global(local_pos), UNLOCK_FEEDBACK)
