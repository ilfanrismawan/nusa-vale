class_name WaterEffect
extends ActionEffect

func _init() -> void:
	stamina_cost = 2

func try_refill(player: Player, cell: Vector2i, tool: ToolData) -> bool:
	if tool == null or FishingManager.find_spot_at(player, Juice.cell_center(player, cell)) == null:
		return false
	if player.data.watering_water >= tool.water_capacity:
		return true
	if not player.data.spend_stamina(maxi(tool.stamina_cost, 1)):
		return true
	player.data.watering_water = tool.water_capacity
	Notify.say("Air terisi penuh: %d/%d." % [tool.water_capacity, tool.water_capacity])
	Juice.play(&"water", Juice.cell_center(player, cell))
	return true

func apply(player: Player, cell: Vector2i) -> void:
	var tool := active_tool(player)
	if try_refill(player, cell, tool):
		return
	var cost := maxi(cost_for(player), 1)
	if player.data.stamina < cost:
		return
	if tool != null:
		player.data.watering_water = mini(player.data.watering_water, tool.water_capacity)
		if player.data.watering_water <= 0:
			Notify.say("Air habis! Gunakan penyiram di sungai/kolam untuk isi ulang.")
			return
	var worked := false
	for target in cells_for(player, cell):
		if tool != null and player.data.watering_water <= 0:
			break
		# Pouring on tilled soil still uses water/effort when already wet (rain included).
		if FarmManager.can_water(target):
			FarmManager.water(target)
			worked = true
			if tool != null:
				player.data.watering_water -= 1
			Juice.play(&"water", Juice.cell_center(player, target))
	if worked:
		player.data.spend_stamina(cost)
