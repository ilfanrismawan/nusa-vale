extends Area2D

## Pintu Menara Penyihir di Hutan Dalam. Tersegel bagi karakter yang belum menamatkan kursus
## Dasar Sihir Tongkat (Fakultas Sihir, Universitas). Syarat per karakter: di co-op, pemain yang
## sudah lulus bisa masuk walau temannya belum.

@export_file("*.tscn") var target_scene := "res://scenes/world/interior/witch_tower.tscn"
@export var spawn_position := Vector2(240, 256)
## Kemampuan yang membuka segel (Abilities.MAGIC).
@export var required_ability: StringName = &"magic"


func _ready() -> void:
	add_to_group("scene_door")


func interact(actor: Player = null) -> void:
	if actor == null:
		actor = RoomDoor.player()
	if actor == null or actor.is_input_locked() or Transition.on_transition:
		return
	if not Abilities.has(actor.data, required_ability):
		Notify.say("Pintu menara tersegel cahaya ungu. Sebuah ukiran berbunyi: \"Hanya yang telah menguasai %s boleh masuk.\" Ambil kursusnya di Fakultas Sihir, Universitas." % Abilities.title(required_ability))
		return
	RoomDoor.travel(actor, target_scene, spawn_position)
