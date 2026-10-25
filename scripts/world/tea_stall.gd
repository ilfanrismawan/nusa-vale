extends StaticBody2D

## Kedai teh & kue Zarathia (Town). Meja meneruskan interaksi ke Zarathia selama
## jadwalnya `tea_stall`; di luar jam itu menampilkan pesan tutup.
## Geser kedai di editor: titik jadwal NPCPoints/<keeper_point> ikut ke KeeperSpot.

@export var npc_id := "zarathia"
@export var open_activity := "tea_stall"
@export var keeper_point := "zarathia_tea_stall"
@export_multiline var closed_message := "Kedai Teh Zarathia sedang tutup. Buka 09.00–12.30 dan 13.30–16.30 saat cuaca cerah."

@onready var keeper_spot: Marker2D = $KeeperSpot
var _presenter: Node

func _ready() -> void:
	set_meta("player_interaction", true)
	var world := _world()
	if world == null:
		return
	_presenter = world.get_node_or_null("NPCMapPresenter")
	# Berjalan sebelum NPCMapPresenter._ready (urutan pohon), jadi Zarathia langsung menuju meja.
	var marker := world.get_node_or_null(NodePath("NPCPoints/" + keeper_point)) as Node2D
	if marker != null:
		marker.global_position = keeper_spot.global_position

func _world() -> Node:
	var node := get_parent()
	while node != null and node.get_node_or_null("NPCPoints") == null:
		node = node.get_parent()
	return node

func _keeper() -> VillageNPC:
	if _presenter == null or not "actors" in _presenter:
		return null
	return _presenter.actors.get(npc_id) as VillageNPC

func _physics_process(_delta: float) -> void:
	# NPCActors memakai z_index 1 (selalu di atas bangunan). Saat berjaga, Zarathia
	# diturunkan ke lapis 0 agar ikut y-sort: badannya tertutup meja, pemain di depan tetap terlihat.
	var keeper := _keeper()
	if keeper == null:
		return
	var at_stall := keeper.global_position.distance_to(keeper_spot.global_position) < 20.0
	keeper.z_index = -1 if at_stall else 0

func interact(player: Player = null) -> void:
	var keeper := _keeper()
	if keeper != null and keeper.visible and not keeper._is_walking and keeper._current_activity == open_activity:
		keeper.interact(player)
		return
	Notify.say(closed_message)
