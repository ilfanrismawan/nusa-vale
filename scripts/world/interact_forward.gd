extends StaticBody2D

## Perabot yang meneruskan interaksi ke node lain, mis. meja konter -> penjaga di baliknya
## (pemain biasanya menekan tombol ke arah meja, bukan ke NPC).

@export var target: NodePath


func _ready() -> void:
	set_meta("player_interaction", true)


func interact(player: Player = null) -> void:
	var node := get_node_or_null(target)
	if node != null and node.has_method("interact"):
		node.interact(player)
