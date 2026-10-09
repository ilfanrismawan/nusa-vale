class_name FishingBlocker
extends Area2D

const BLOCKER_LAYER_BIT := 1 << 8

func _ready() -> void:
	collision_layer = BLOCKER_LAYER_BIT
	collision_mask = 0
	monitoring = false
