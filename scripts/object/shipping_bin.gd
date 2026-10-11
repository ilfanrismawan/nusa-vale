class_name ShippingBin
extends Area2D


var player_in_range: bool:
	get: return not _players.is_empty()
var _players: Array[Player] = []

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
	var player := PlayerInput.find_presser(event, _players, [&"ui_accept"])
	if player != null:
		get_viewport().set_input_as_handled()
		# Co-op: yang dijual isi tas pemain yang menekan; uangnya masuk ke uang bersama.
		GameState.use_player(player)
		sell_harvested_items()

func sell_harvested_items() -> void:
	var totals := {}
	var items := {}
	
	for slot in GameState.inventory:
		if slot == null:
			continue
			
		var item: ItemData = slot["item"]
		if item.sell_price <= 0:
			continue
		items[item.item_id] = item
		totals[item.item_id] = totals.get(item.item_id, 0) + slot["count"]
	
	var earned := 0
	for id in totals:
		GameState.remove_item(id, totals[id])
		earned += items[id].sell_price * totals[id]
		
	if earned > 0:
		GameState.add_money(earned)
		Notify.say("Terjual +%d G" % earned)
	else:
		Notify.say("Tidak ada yang bisa dijual")
