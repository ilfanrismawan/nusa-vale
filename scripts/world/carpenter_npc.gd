extends VillageNPC

var _menu: CanvasLayer

func interact(player: Player = null) -> void:
	if is_instance_valid(_menu):
		return
	if player == null:
		player = Coop.current_player() if Coop.active else get_tree().get_first_node_in_group("player")
	if player == null:
		return
	_face_player(player)
	_menu = load("res://scenes/ui/carpenter_menu.tscn").instantiate()
	_menu.player = player
	_menu.vendor_name = npc_name
	_menu.vendor_portrait = portrait
	_menu.finished.connect(func(): _menu = null)
	Coop.ui_parent(player).add_child(_menu)
