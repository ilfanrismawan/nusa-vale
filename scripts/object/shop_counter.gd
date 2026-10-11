class_name ShopCounter
extends Area2D

const DEFAULT_SHOP := "res://resources/shop/general_store.tres"

## Data toko yang dibuka counter ini. Kosong = toko umum.
@export var shop_data: ShopData

## Pemain di dekat counter (co-op bisa lebih dari satu).
var _players: Array[Player] = []
var _shop: ShopUI

func _ready() -> void:
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
	var player := PlayerInput.find_presser(event, _players, [&"ui_accept"])
	if player == null:
		return
	_shop = ShopUI.new()
	_shop.player = player
	_shop.shop_data = shop_data if shop_data != null else load(DEFAULT_SHOP) as ShopData
	Coop.ui_parent(player).add_child(_shop)
	get_viewport().set_input_as_handled()
