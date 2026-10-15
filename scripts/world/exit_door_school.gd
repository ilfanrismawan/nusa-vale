extends Area2D

## Pintu keluar sekolah. Pola sama dengan exit_door_house.gd, tapi posisi
## muncul di luar bisa diatur dari Inspector.

@export_file("*.tscn") var target_scene: String = "res://scenes/world/farm.tscn"
## Posisi pemain di scene tujuan (di depan pintu sekolah).
## Sementara diarahkan ke depan rumah sampai pintu sekolah dipasang di peta.
@export var spawn_position: Vector2 = Vector2(1136, 285)

func _ready() -> void:
	# Shared by school entrances, room exits, and town boundaries.
	# Only destinations inside buildings require an explicit interaction.
	if not "/interior/" in target_scene and not target_scene.ends_with("/interior.tscn"):
		body_entered.connect(_on_body_entered)
	else:
		add_to_group("scene_door")

func interact(actor: Player = null) -> void:
	_on_body_entered(actor if actor != null else RoomDoor.player())

func _on_body_entered(body: Node2D) -> void:
	if Transition.on_transition:
		return
	if body is Player:
		var destination: Vector2 = RoomDoor.town_returns.get(body.data.index, spawn_position) if target_scene == "res://scenes/world/town.tscn" else spawn_position
		RoomDoor.travel(body, target_scene, destination)
