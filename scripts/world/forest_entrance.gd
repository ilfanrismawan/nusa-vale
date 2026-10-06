extends Area2D

const FOREST_SCENE_PATH := "res://scenes/world/forest.tscn"
const FOREST_SPAWN_POS := Vector2(256, 420)

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if Transition.on_transition:
		return
	if not (body is Player or body.is_in_group("player")):
		return
	
	if DiscoveryManager.discover("forest"):
		Notify.say("Memasuki Hutan.")
	
	GameState.next_spawn_position = FOREST_SPAWN_POS
	GameState.has_spawn_point = true
	Transition.scene_transition.call_deferred(FOREST_SCENE_PATH)
