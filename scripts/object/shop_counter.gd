class_name ShopCounter
extends Area2D

const DEFAULT_SHOP := "res://resources/shop/general_store.tres"

## Data toko yang dibuka counter ini. Kosong = toko umum.
@export var shop_data: ShopData
## Scene UI toko (root ShopUI, mis. scenes/ui/warteg_ui.tscn). Kosong = ShopUI standar.
@export var menu_scene: PackedScene
## id ServiceHours; di luar jam buka counter hanya menampilkan pesan tutup. Kosong = selalu buka.
@export var service := ""
## npc_id penjaga (mis. "joko"); bila diisi counter hanya buka saat penjaga bertugas di dekatnya.
@export var keeper := ""
## Jarak maksimal penjaga dari counter agar dianggap sedang berjaga.
const KEEPER_RANGE := 64.0

## Pemain di dekat counter (co-op bisa lebih dari satu).
var _players: Array[Player] = []
var _shop: ShopUI

func _ready() -> void:
	set_meta("player_interaction", true)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is Player and not _players.has(body):
		_players.append(body)
		
func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_players.erase(body)

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_shop):
		return
	var player := PlayerInput.find_presser(event, _players, [&"ui_accept", &"interact"])
	if player == null:
		return
	interact(player)
	get_viewport().set_input_as_handled()

func interact(player: Player = null) -> void:
	if player == null:
		player = RoomDoor.player()
	if player == null or player.is_input_locked() or is_instance_valid(_shop):
		return
	if service != "" and not ServiceHours.is_open(service):
		Notify.say(ServiceHours.closed_message(service))
		return
	if keeper != "":
		var npc = _keeper_npc()
		if npc == null or not npc.has_method("_service_available") or not npc._service_available() \
				or npc.global_position.distance_to(global_position) > KEEPER_RANGE:
			Notify.say("%s sedang tidak berjaga. Datang lagi saat dia di sini." % (npc.npc_name if npc != null else "Penjaganya"))
			return
	_shop = menu_scene.instantiate() as ShopUI if menu_scene != null else ShopUI.new()
	_shop.player = player
	if shop_data != null:
		_shop.shop_data = shop_data
	elif _shop.shop_data == null:
		_shop.shop_data = load(DEFAULT_SHOP) as ShopData
	Coop.ui_parent(player).add_child(_shop)


## Actor penjaga di NPCActors peta yang memuat counter ini.
func _keeper_npc() -> Node2D:
	var node := get_parent()
	while node != null:
		var actors := node.get_node_or_null("NPCActors")
		if actors != null:
			for actor in actors.get_children():
				if actor is VillageNPC and (actor as VillageNPC).npc_id == keeper:
					return actor
			return null
		node = node.get_parent()
	return null
