extends VillageNPC
var _shops: Dictionary = {}

func interact(player: Player = null) -> void:
	if player == null:
		player = RoomDoor.player()
	if player == null or is_instance_valid(_shops.get(player.data.index)):
		return
	_face_player(player)
	var shop = load("res://scripts/ui/livestock_shop_ui.gd").new()
	shop.player = player
	shop.portrait = portrait
	_shops[player.data.index] = shop
	Coop.ui_parent(player).add_child(shop)

func _physics_process(delta: float) -> void:
	for shop in _shops.values():
		if is_instance_valid(shop):
			velocity = Vector2.ZERO
			return
	super._physics_process(delta)
