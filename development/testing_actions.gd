extends RefCounted
## Additional test actions live outside gameplay code.
static func recover(data: PlayerData) -> void:
	data.restore_hp()
	data.restore_stamina()
	data.clear_food_effects()
	for slot in data.inventory:
		if slot != null and slot.item is ToolData and slot.item.water_capacity > 0:
			data.watering_water = slot.item.water_capacity
	data._changed()

static func give_item(data: PlayerData, id: String, count: int) -> String:
	var item := GameState._resolve_item(id.strip_edges())
	if item == null:
		return "ID item tidak ditemukan."
	var remaining := data.add_item(item, clampi(count, 1, 999))
	return "%s: +%d (tidak muat: %d)" % [item.display_name, clampi(count, 1, 999) - remaining, remaining]
