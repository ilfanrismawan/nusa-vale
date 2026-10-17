class_name CookingManager
extends RefCounted

const DB_PATH := "res://resources/cooking/data/recipe_database.tres"

static var _recipes: Dictionary = {}

static func _ensure_loaded() -> void:
	if not _recipes.is_empty():
		return
	var db := load(DB_PATH) as RecipeDatabase
	if db == null:
		push_error("RecipeDatabase tidak ditemukan: %s" % DB_PATH)
		return
	for recipe in db.recipes:
		if recipe != null:
			_recipes[recipe.id] = recipe

static func get_recipe(id: String) -> RecipeData:
	_ensure_loaded()
	return _recipes.get(id)

static func all_recipes() -> Array:
	_ensure_loaded()
	return _recipes.values()

static func knows(data: PlayerData, id: String) -> bool:
	var recipe := get_recipe(id)
	return data != null and recipe != null and (recipe.book_price == 0 or id in data.learned_recipes)

static func learn(data: PlayerData, id: String) -> Dictionary:
	var recipe := get_recipe(id)

	if data == null or recipe == null or not recipe.is_valid_recipe() or knows(data, id):
		return {"ok": false, "message": "Resep sudah dipelajari atau tidak tersedia."}

	if not GameState.spend_money(recipe.book_price):
		return {"ok": false, "message": "Uang tidak cukup untuk buku resep."}
	data.learned_recipes.append(id)
	return {"ok": true, "message": "Resep %s dipelajari." % recipe.display_name}

static func cook(data: PlayerData, id: String, available_equipment: Array[CookingEquipmentData] = []) -> Dictionary:
	if data == null or not knows(data, id):
		return {"ok": false, "message": "Pelajari resep terlebih dahulu."}

	var recipe := get_recipe(id)
	var ingredients = recipe.ingredients
	if not recipe.is_valid_recipe():
		return {"ok": false, "message": "Data resep belum lengkap. Periksa resource resep."}
	var missing := recipe.missing_equipment(available_equipment)
	if not missing.is_empty():
		return {"ok": false, "message": "Peralatan belum tersedia: %s." % ", ".join(missing)}

	for ingredient in ingredients:
		if not data.has_item(ingredient, int(ingredients[ingredient])):
			return {"ok": false, "message": "Bahan masakan belum cukup."}

	# Stage the transaction before touching the player's bag, including slots
	# released by consuming ingredients. A full bag never loses ingredients.
	var staged := PlayerData.new(-1)
	staged.bag_level = data.bag_level
	staged.load_inventory(data.serialize_inventory())

	for ingredient in ingredients:
		var remaining := int(ingredients[ingredient])

		for slot in staged.bag_size:
			if remaining == 0:
				break

			if staged.inventory[slot] == null or staged.inventory[slot].item.item_id != ingredient:
				continue

			var amount := mini(remaining, int(staged.inventory[slot].count))
			staged.inventory[slot].count -= amount
			remaining -= amount

			if staged.inventory[slot].count == 0:
				staged.inventory[slot] = null

	if staged._store(recipe.result_item(), recipe.output_count) != 0:
		return {"ok": false, "message": "Tas penuh. Sediakan ruang untuk masakan."}

	data.load_inventory(staged.serialize_inventory())
	data._changed()
	return {"ok": true, "message": "%s selesai dimasak." % recipe.display_name}

static func eat(player: Player, slot: int) -> Dictionary:
	var data := player.data
	if slot < 0 or slot >= data.bag_size or data.inventory[slot] == null:
		return {"ok": false, "message": "Tidak ada makanan."}
	var item: ItemData = data.inventory[slot].item
	if item.category != ItemData.Category.FOOD:
		return {"ok": false, "message": "Item ini bukan makanan."}
	var effects: Array[FoodEffectData] = []
	for effect in item.food_effects:
		if effect == null or not effect.is_valid_effect():
			return {"ok": false, "message": "Data efek makanan belum valid."}
		effects.append(effect)
	if effects.is_empty() and item.speed_buff_seconds > 0.0:
		var legacy := FoodEffectData.new()
		legacy.id = &"legacy_food_speed"
		legacy.display_name = "Kecepatan makanan"
		legacy.duration_seconds = item.speed_buff_seconds
		legacy.movement_multiplier = item.speed_buff_multiplier
		effects.append(legacy)
	if data.stamina >= data.max_stamina and effects.is_empty() and (data.hp >= data.max_hp or item.hp_restore_amount() <= 0):
		return {"ok": false, "message": "Stamina masih penuh."}
	data.remove_item_at(slot, 1)
	data.restore_stamina(item.stamina_restore)
	data.restore_hp(item.hp_restore_amount())
	for effect in effects:
		data.apply_food_effect(effect)
	if item.food_effects.is_empty() and item.speed_buff_seconds > 0:
		player.food_speed_remaining = maxf(player.food_speed_remaining, item.speed_buff_seconds)
		player.food_speed_multiplier = item.speed_buff_multiplier
	return {"ok": true, "message": "%s dimakan · %s" % [item.display_name, item.food_summary()]}
