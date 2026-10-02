class_name Choppable
extends Node2D

@export var health: int = 3
@export var drop_item_id: String = "wood"
@export var drop_count: int = 3

func _ready() -> void:
	add_to_group(&"choppable")


func take_hit(damage: int) -> void:
	health -= damage
	print("Hit! Sisa HPL %d" % health)
	if health <= 0:
		if not drop_item_id.is_empty():
			GameState.add_item(drop_item_id, drop_count)
			Notify.say("+%d Kayu" % drop_count)
		queue_free()
