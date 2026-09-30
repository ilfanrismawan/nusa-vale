class_name State
extends Node

signal transitioned(next_state: State)

@export var animation_name: StringName

var player: Player
var animation_controller: AnimationController

func initialize(_player: Player,
				_animation_controller: AnimationController
				) -> void:
	player = _player
	animation_controller = _animation_controller

func enter() -> void:
	if animation_name.is_empty():
		push_error("%s: 'animation_name' belum diisi." % name)
		return
	animation_controller.play(animation_name)

func exit() -> void:
	pass

func physics_update(_delta: float) -> void:
	pass
