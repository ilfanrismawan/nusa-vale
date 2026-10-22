extends ActionEffect
## Jaring serangga (GDD 7): sekali ayun menangkap satu serangga terdekat di depan pemain.
## Jangkauan per tier ada di ToolData.BUG_NET_REACH (Kayu 20 px .. Emas 48 px).

## Titik tengah ayunan, px di depan badan pemain.
const SWING_OFFSET := 14.0

func apply(player: Player, _cell: Vector2i) -> void:
	var tool := active_tool(player)
	var cost := cost_for(player)
	if player.data.stamina < cost:
		return
	var tier := int(tool.tier) if tool != null else 0
	var reach: float = ToolData.BUG_NET_REACH[clampi(tier, 0, ToolData.BUG_NET_REACH.size() - 1)]
	var swing := player.global_position + player.facing_direction.normalized() * SWING_OFFSET
	Juice.play(&"swish", swing)
	player.data.spend_stamina(cost)
	var bug := nearest_bug(player, swing, reach)
	if bug != null:
		bug.catch(player)


## Serangga terdekat dari titik ayun (atau dari badan, untuk serangga yang hinggap di kaki pemain).
static func nearest_bug(player: Player, swing: Vector2, reach: float) -> Node2D:
	var best: Node2D = null
	var best_dist := reach
	for node in player.get_tree().get_nodes_in_group(&"bug"):
		if not node is Node2D or node.is_queued_for_deletion() or (node as Node2D).get_world_2d() != player.get_world_2d():
			continue
		var pos: Vector2 = node.catch_point()
		var dist := minf(pos.distance_to(swing), pos.distance_to(player.global_position) + 6.0)
		if dist <= best_dist:
			best_dist = dist
			best = node
	return best
