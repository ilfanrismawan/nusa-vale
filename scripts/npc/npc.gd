extends CharacterBody2D

@export var npc_id: String = "kirana"
@export var npc_name: String = "Kirana"
@export var move_speed: float = 45.0
@export var npc_sprite_frames: SpriteFrames

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var dialogue_label: Label = $DialogueLabel

var nearby_player: Node2D = null
var current_activity: String = "idle"

var _dialog_ui: NPCDialogUI

func _ready() -> void:
	set_meta("player_interaction", true)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	platform_floor_layers = 0
	platform_wall_layers = 0
	
	if npc_sprite_frames != null:
		sprite.sprite_frames = npc_sprite_frames
		
	dialogue_label.hide()
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	agent.path_desired_distance = 4.0
	agent.target_desired_distance = 4.0
	
func go_to(target: Vector2, activity: String) -> void:
	current_activity = activity
	agent.target_position = target

func interact(player: Player = null) -> void:
	if is_instance_valid(_dialog_ui) or player == null:
		return
	
	velocity = Vector2.ZERO
	
	_dialog_ui = NPCDialogUI.new()
	_dialog_ui.player = player
	_dialog_ui.npc_name = npc_name
	_dialog_ui.lines = PackedStringArray([
		"Halo! Senang bertem denganmu!"
	])
	_dialog_ui.finished.connect(_on_dialog_finished)
	Coop.ui_parent(player).add_child(_dialog_ui)

func _on_dialog_finished() -> void:
	_dialog_ui = null
		
func _physics_process(_delta: float) -> void:
	if is_instance_valid(_dialog_ui):
		velocity = Vector2.ZERO
		play_idle()
		return
		
	if NavigationServer2D.map_get_iteration_id(agent.get_navigation_map()) == 0:
		return
	
	if agent.is_navigation_finished():
		velocity = Vector2.ZERO
		play_idle()
	else:
		var next_point = agent.get_next_path_position()
		var direction = global_position.direction_to(next_point)
		velocity = direction * move_speed
		play_walk(direction)
	
	move_and_slide()

func play_walk(direction: Vector2) -> void:
	if abs(direction.x) > abs (direction.y):
		if direction.x > 0:
			sprite.flip_h = false
			sprite.play("walk_right")
		else:
			sprite.flip_h = true
			sprite.play("walk_right")
	elif direction.y > 0:
		sprite.play("walk_down")
	else:
		sprite.play("walk_up")

func play_idle() -> void:
	sprite.play("idle_down")

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(nearby_player):
		return
		
	if not nearby_player is Player:
		return		
		
	var player := nearby_player as Player
	if player.is_input_locked():
		return
	
	if player.input.is_event(event, &"interact"):
		get_viewport().set_input_as_handled()
		interact(player)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		nearby_player = body

func _on_body_exited(body: Node2D) -> void:
	if body == nearby_player:
		nearby_player = null
		dialogue_label.hide()	
