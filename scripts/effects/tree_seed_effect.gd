extends ActionEffect
## Biji pohon (GDD 7): ditanam di tanah farm yang tidak dicangkul, tumbuh jadi pohon besar
## dalam seminggu, lalu bisa ditebang atau dipasangi tapper.

## Jenis pohon: "maple", "pine", "birch", "mahogany" (cocok dengan scenes/objects/<jenis>_tree.tscn).
@export var tree_kind: String = "maple"
@export var seed_item_id: String = "maple_seed"

func apply(player: Player, cell: Vector2i) -> void:
	var spawner: Node = null
	for node in player.get_tree().get_nodes_in_group(&"planted_trees"):
		if node is Node2D and (node as Node2D).get_world_2d() == player.get_world_2d():
			spawner = node
			break
	if spawner == null:
		Notify.say("Biji pohon hanya bisa ditanam di farm.")
		return
	player.bind_context()
	if not player.data.has_item(seed_item_id):
		return
	if spawner.plant(cell, tree_kind):
		player.data.remove_item(seed_item_id, 1)
		Juice.play(&"plant", Juice.cell_center(player, cell))
