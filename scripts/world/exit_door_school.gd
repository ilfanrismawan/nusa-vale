extends Area2D

## Pintu keluar sekolah. Pola sama dengan exit_door_house.gd, tapi posisi
## muncul di luar bisa diatur dari Inspector.

@export_file("*.tscn") var target_scene: String = "res://scenes/world/Farm.tscn"
## Posisi pemain di scene tujuan (di depan pintu sekolah).
## Sementara diarahkan ke depan rumah sampai pintu sekolah dipasang di peta.
@export var spawn_position: Vector2 = Vector2(1136, 285)

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if Transition.on_transition:
		return
	if body is Player or body.is_in_group("player"):
		GameState.next_spawn_position = spawn_position
		GameState.has_spawn_point = true
		Transition.scene_transition.call_deferred(target_scene)
