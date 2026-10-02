class_name ShopCounter
extends Area2D

var _player_in_range :=  false
var _shop: ShopUI

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_in_range = true
	
func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_in_range = false

func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed("ui_accept") and not is_instance_valid(_shop):
		_shop = ShopUI.new()
		get_tree().current_scene.add_child(_shop)
		get_viewport().set_input_as_handled()
		
