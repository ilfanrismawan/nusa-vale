extends ActionEffect
## Memasang tapper (GDD 7): hadap ke pohon besar lalu pakai item Tapper.

## Jarak maksimum (px) akar pohon dari sel yang dibidik / titik di depan pemain.
const TREE_REACH := 18.0

func apply(player: Player, cell: Vector2i) -> void:
	var tree := find_tree(player, cell)
	if tree == null:
		Notify.say("Hadap ke pohon besar untuk memasang tapper.")
		return
	player.bind_context()
	if GameState.gathering.place(tree, player.data):
		Juice.play(&"plant", tree.global_position)


static func find_tree(player: Player, cell: Vector2i) -> Node2D:
	var target := Juice.cell_center(player, cell)
	var front := player.global_position + Vector2(0, 8) + player.facing_direction.normalized() * 14.0
	var best: Node2D = null
	var best_dist := TREE_REACH
	for node in player.get_tree().get_nodes_in_group(&"choppable"):
		if not node is Node2D or (node as Node2D).get_world_2d() != player.get_world_2d() or node.is_queued_for_deletion():
			continue
		var root := (node as Node2D).global_position
		var dist := minf(root.distance_to(target), root.distance_to(front))
		if dist < best_dist:
			best_dist = dist
			best = node
	return best
