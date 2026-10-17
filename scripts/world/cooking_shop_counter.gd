extends Area2D

@export var store: CookingShopData
@export var menu_scene: PackedScene = preload("res://scenes/ui/cooking_shop_ui.tscn")
var _menu: CanvasLayer

func _ready() -> void:
	set_meta("player_interaction", true)

func interact(player: Player) -> void:
	if player.is_input_locked() or is_instance_valid(_menu):
		return
	_menu = menu_scene.instantiate()
	_menu.player = player
	_menu.store = store
	Coop.ui_parent(player).add_child(_menu)
