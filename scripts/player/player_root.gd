## Root node for the Player scene.
## Syncs its own position to the CharacterBody2D child every frame
## so that Y-sorting in the parent (Farm) works correctly.
extends Node2D

@onready var body: CharacterBody2D = $CharacterBody2D

func _ready() -> void:
	# Start the body at the origin so all movement is relative to this root.
	# The root's position in the world is set by whoever instantiates the scene.
	pass

func _physics_process(_delta: float) -> void:
	# Copy the CharacterBody2D's local movement back to this root node,
	# then reset the body's local position to zero.
	# This keeps the root's position in sync for Y-sorting.
	if body:
		var body_local_pos := body.position
		if body_local_pos != Vector2.ZERO:
			global_position += body_local_pos
			body.position = Vector2.ZERO
