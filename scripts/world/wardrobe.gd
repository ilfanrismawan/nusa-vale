class_name Wardrobe
extends StaticBody2D

## Lemari di rumah: membuka CharacterCreatorUI untuk mengganti penampilan.

@onready var interaction_area: Area2D = get_node_or_null("InteractionArea")

var _players: Array[Player] = []
var _ui: CharacterCreatorUI

func _ready() -> void:
	if interaction_area != null:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is Player and not _players.has(body):
		_players.append(body)

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_players.erase(body)

func _unhandled_input(event: InputEvent) -> void:
	var player := PlayerInput.find_presser(event, _players)
	if player != null:
		get_viewport().set_input_as_handled()
		interact(player)

## `player` kosong = pemain yang sedang beraksi (dipanggil dari Player._try_interact).
func interact(player: Player = null) -> void:
	if is_instance_valid(_ui):
		return
	if player == null:
		player = Coop.current_player()
	_ui = load("res://scenes/ui/character_creator_ui.tscn").instantiate() as CharacterCreatorUI
	_ui.player = player
	_ui.allow_cancel = true
	_ui.pause_game = true
	_ui.finished.connect(func(_appearance: CharacterAppearance): Notify.say("Penampilan diperbarui."))
	Coop.ui_parent(player).add_child(_ui)
