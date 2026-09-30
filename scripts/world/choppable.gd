class_name Choppable
extends Node2D

@export var health: int = 3

func _ready() -> void:
	add_to_group(&"choppable")


func take_hit(damage: int) -> void:
	health -= damage
	if health <= 0:
		queue_free()
