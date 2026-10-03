class_name ShippingBin
extends Area2D


@export var sell_prices: Dictionary = {
	"strawberry": 20,
	"carrot": 45,
	"wood": 5
}

var player_in_range: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_in_range = true

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_in_range = false

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and event.is_action_pressed("ui_accept"):
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
