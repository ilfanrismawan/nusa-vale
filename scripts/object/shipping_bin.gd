class_name ShippingBin
extends Area2D


@export var sell_prices: Dictionary = {
	"strawberry": 20,
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
	var total_earned := 0
	for item_id in sell_prices.keys():
		var count = GameState.get_item_count(item_id)
		if count > 0:
			var price = sell_prices[item_id] * count
			GameState.remove_item(item_id, count)
			total_earned += price
	
	if total_earned > 0:
		GameState.add_money(total_earned)
		print("Terjual! Mendapatkan %d gold. Total uang: %d" % [total_earned, GameState.money])
	else:
		print("Tidak ada barang yang bisa dijual di tas!")
