class_name CraftingSystem
extends RefCounted

const CATALOG: CraftingCatalog = preload("res://resources/crafting/catalog.tres")
const MAX_BATCHES := 99

## Build the complete result before consuming anything. No signals or discoveries in a preview.
static func preview(data: PlayerData, recipe: CraftingRecipe, batches: int = 1) -> Dictionary:
	if data == null or recipe == null or batches < 1 or batches > MAX_BATCHES:
		return _error("Jumlah pembuatan tidak valid.")
	if recipe.output_amount < 1 or recipe.output_amount > 99 or recipe.ingredients.is_empty():
		return _error("Resep tidak valid.")
	var output := _item(recipe.output_item_id)
	if output == null or output.max_stack < 1 or (not output.stackable and output.max_stack != 1):
		return _error("Hasil resep tidak tersedia.")
	for id in recipe.ingredients:
		var amount: Variant = recipe.ingredients[id]
		if not id is String or not amount is int or amount < 1 or amount > 999:
			return _error("Bahan resep tidak valid.")
		var material := _item(id)
		if material == null:
			return _error("Bahan resep tidak tersedia.")
		var required: int = amount * batches
		if data.get_item_count(id) < required:
			return _error("Bahan kurang: %s (%d / %d)." % [material.display_name, data.get_item_count(id), required])
	var slots: Array = data.inventory.duplicate(true)
	for id in recipe.ingredients:
		var remaining: int = recipe.ingredients[id] * batches
		for slot in range(data.bag_size - 1, -1, -1):
			if slots[slot] == null or slots[slot]["item"].item_id != id:
				continue
			var take: int = mini(remaining, slots[slot]["count"])
			slots[slot]["count"] -= take
			remaining -= take
			if slots[slot]["count"] == 0:
				slots[slot] = null
			if remaining == 0:
				break
	var remaining: int = recipe.output_amount * batches
	if output.stackable:
		for slot in data.bag_size:
			if slots[slot] == null or slots[slot]["item"].item_id != output.item_id:
				continue
			var put: int = mini(remaining, maxi(0, output.max_stack - int(slots[slot]["count"])))
			slots[slot]["count"] += put
			remaining -= put
	for slot in data.bag_size:
		if remaining == 0:
			break
		if slots[slot] != null:
			continue
		var put: int = mini(remaining, output.max_stack)
		slots[slot] = {"item": output, "count": put}
		remaining -= put
	if remaining > 0:
		return _error("Tas penuh. Sediakan ruang untuk hasil crafting.")
	return {"ok": true, "message": "Siap dibuat.", "inventory": slots, "output": output, "amount": recipe.output_amount * batches}

static func craft(data: PlayerData, recipe: CraftingRecipe, batches: int = 1) -> Dictionary:
	var result := preview(data, recipe, batches)
	if not result["ok"]:
		return result
	data.inventory = result["inventory"]
	var item: ItemData = result["output"]
	if item.category in [ItemData.Category.FISH, ItemData.Category.FORAGE, ItemData.Category.CROP, ItemData.Category.MATERIAL]:
		DiscoveryManager.discover("item_" + item.item_id)
	data._changed()
	result["message"] = "Dibuat: %s x%d." % [item.display_name, result["amount"]]
	return result

static func _error(message: String) -> Dictionary:
	return {"ok": false, "message": message}

static func _item(id: String) -> ItemData:
	if id.is_empty() or not ResourceLoader.exists("res://resources/item_data/%s.tres" % id):
		return null
	return GameState._resolve_item(id)
