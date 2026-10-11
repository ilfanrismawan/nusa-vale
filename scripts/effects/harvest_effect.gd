class_name HarvestEffect
extends ActionEffect

## Jangkauan tebasan sabit ke rumput liar (px dari tengah sel target), + per tier.
const WEED_RADIUS := 12.0
const WEED_RADIUS_PER_TIER := 4.0

func apply(
	player: Player,
	cell: Vector2i
) -> void:
	var action: ActionData = player.tool_controller.current_tool
	var with_tool := action != null and action.tool_data != null
	var pos := Juice.cell_center(player, cell)
	if with_tool:
		Juice.play(&"swish", pos)
	var data: Dictionary = FarmManager.get_cell_data(cell)
	if data.is_empty() or data.get("crop") == null:
		if with_tool:
			_cut_weeds(player, cell, pos, action.tool_data)
		return
	# Ambil gambar tanaman sebelum tile-nya dihapus oleh harvest().
	var crop_tex := Juice.crop_texture(cell)
	if not FarmManager.harvest(cell):
		Notify.say("Belum ada tanaman matang")
		return
	Juice.play(&"harvest", pos)
	Juice.leap(crop_tex, pos + Vector2(0, -4))


## Sabit menebas semua rumput liar di sekitar sel target.
func _cut_weeds(player: Player, cell: Vector2i, pos: Vector2, tool: ToolData) -> void:
	var radius := WEED_RADIUS + WEED_RADIUS_PER_TIER * float(tool.tier) + 8.0 * float(maxi(tool.area_size - 1, 0))
	for node in player.get_tree().get_nodes_in_group(&"weed"):
		if not is_instance_valid(node) or not node.has_method("take_hit"):
			continue
		var weed_pos: Vector2 = (node as Node2D).global_position
		if player.world_to_cell(weed_pos) == cell or weed_pos.distance_to(pos) <= radius:
			node.take_hit(tool.damage)
