class_name VillageNPC
extends StaticBody2D

## Komponen dasar untuk NPC Warga Desa di Nusa Vale.
## Mendukung animasi hadap pemain (idle 4 arah), deteksi area interaksi,
## dan pembukaan kotak dialog dengan potret (NPCDialogUI).

@export var npc_id: String = ""
@export var npc_name: String = "Warga Desa"
@export var role_title: String = ""
@export var portrait: Texture2D
@export var dialog_lines: PackedStringArray = [
	"Halo! Selamat menikmati harimu di Nusa Vale."
]

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var interaction_area: Area2D = get_node_or_null("InteractionArea")

var _players: Array[Player] = []
var _dialog_ui: NPCDialogUI

func _ready() -> void:
	if interaction_area != null:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)
	
	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation("idle_down"):
		sprite.play("idle_down")

func _on_body_entered(body: Node2D) -> void:
	if body is Player and not _players.has(body):
		_players.append(body)

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_players.erase(body)

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_dialog_ui):
		return
	var player := PlayerInput.find_presser(event, _players)
	if player != null:
		get_viewport().set_input_as_handled()
		interact(player)

## Dipanggil langsung via Player._try_interact() atau proximity input
func interact(player: Player = null) -> void:
	if is_instance_valid(_dialog_ui):
		return
	if player == null:
		player = Coop.current_player() if Coop.active else get_tree().get_first_node_in_group("player")

	_face_player(player)

	if dialog_lines.is_empty():
		return

	_dialog_ui = NPCDialogUI.new()
	_dialog_ui.player = player
	_dialog_ui.npc_name = npc_name
	_dialog_ui.role_title = role_title
	_dialog_ui.portrait_texture = portrait
	_dialog_ui.lines = dialog_lines
	
	_dialog_ui.finished.connect(_on_dialog_finished)
	Coop.ui_parent(player).add_child(_dialog_ui)

func _on_dialog_finished() -> void:
	_dialog_ui = null

func _face_player(player: Player) -> void:
	if sprite == null or not is_instance_valid(player):
		return
	if not (player is CharacterBody2D):
		return

	var dir: Vector2 = player.global_position - global_position
	if abs(dir.x) > abs(dir.y):
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("idle_side"):
			sprite.play("idle_side")
		sprite.flip_h = dir.x < 0
	else:
		sprite.flip_h = false
		if sprite.sprite_frames != null:
			if dir.y > 0 and sprite.sprite_frames.has_animation("idle_down"):
				sprite.play("idle_down")
			elif dir.y <= 0 and sprite.sprite_frames.has_animation("idle_up"):
				sprite.play("idle_up")
