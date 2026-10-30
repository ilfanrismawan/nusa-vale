class_name HarvestEffect
extends ActionEffect

## Jangkauan tebasan sabit ke rumput liar (px dari tengah sel target), + per tier.
const WEED_RADIUS := 12.0
const WEED_RADIUS_PER_TIER := 4.0
## Jarak titik tebasan di depan badan pemain (px).
const WEED_SWING_REACH := 12.0
## Kaki pemain (titik badan pemain = kaki).
const FEET_OFFSET := Player.FEET_OFFSET

func apply(player: Player, cell: Vector2i) -> void:
	var tool := active_tool(player)
	var cost := cost_for(player)
	if player.data.stamina < cost:
		return
	var worked := false
	if tool != null:
		Juice.play(&"swish", Juice.cell_center(player, cell))
		worked = _cut_weeds(player, cell, Juice.cell_center(player, cell), tool)
	for target in cells_for(player, cell):
		if not FarmManager.can_harvest(target):
			continue
		var crop_tex := Juice.crop_texture(target)
		if FarmManager.harvest(target):
			worked = true
			var pos := Juice.cell_center(player, target)
			Juice.play(&"harvest", pos)
			Juice.leap(crop_tex, pos + Vector2(0, -4))
	if worked:
		player.data.spend_stamina(cost)
	elif tool == null:
		_pick_forage(player, cell, Juice.cell_center(player, cell))


## Sabit menebas semua rumput liar di sekitar sel target dan di depan badan pemain.
## Titik di depan badan dan kaki perlu karena badan pemain (8 px di atas kaki) yang menabrak
## rumput: dari atas, kiri, atau kanan, sel target dari kaki bisa meleset satu petak.
func _cut_weeds(player: Player, cell: Vector2i, pos: Vector2, tool: ToolData) -> bool:
	var hit := false
	var radius := WEED_RADIUS + WEED_RADIUS_PER_TIER * float(tool.tier)
	var dir := player.facing_direction.normalized()
	var swing_body := player.global_position + dir * WEED_SWING_REACH
	var swing_feet := player.global_position + FEET_OFFSET + dir * WEED_SWING_REACH * 0.5
	for node in player.get_tree().get_nodes_in_group(&"weed"):
		if not is_instance_valid(node) or not node.has_method("take_hit"):
			continue
		if (node as Node2D).get_world_2d() != player.get_world_2d():
			continue
		var shape := (node as Node).get_node_or_null("CollisionShape2D") as Node2D
		var weed_pos: Vector2 = shape.global_position if shape else (node as Node2D).global_position
		if player.world_to_cell(weed_pos) == cell \
				or weed_pos.distance_to(pos) <= radius \
				or weed_pos.distance_to(swing_body) <= radius \
				or weed_pos.distance_to(swing_feet) <= radius:
			node.take_hit(tool.damage)
			hit = true
	return hit


## Tangan kosong di sel tanpa tanaman: pungut barang forage di sel itu (seperti Stardew).
func _pick_forage(player: Player, cell: Vector2i, pos: Vector2) -> void:
	for node in player.get_tree().get_nodes_in_group(&"forageable"):
		if not is_instance_valid(node) or not node.has_method("interact"):
			continue
		var ground: Vector2 = node.ground_position() if node.has_method("ground_position") else (node as Node2D).global_position
		if player.world_to_cell(ground) == cell or ground.distance_to(pos) <= 8.0:
			node.interact()
			return
