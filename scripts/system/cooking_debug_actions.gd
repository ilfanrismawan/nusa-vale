extends RefCounted

static func enabled(config: Resource) -> bool:
	return OS.is_debug_build() and not Engine.is_editor_hint() and config != null and config.enabled and config.catalog != null

static func prepare_ingredients(data: PlayerData, recipe: RecipeData, batches: int, config: Resource) -> Dictionary:
	if not enabled(config) or data == null or recipe == null or not recipe.is_valid_recipe() or batches < 1:
		return {"ok": false, "message": "Debug tidak aktif atau resep/jumlah tidak valid."}
	var staged := PlayerData.new(-1)
	staged.bag_level = data.bag_level
	staged.load_inventory(data.serialize_inventory())
	for id in recipe.ingredients:
		var needed := maxi(0, recipe.ingredients[id] * batches - staged.get_item_count(id))
		if needed > 0 and staged._store(GameState._resolve_item(id), needed) > 0:
			return {"ok": false, "message": "Tas penuh. Tidak ada bahan yang ditambahkan. Gunakan tombol tas maksimal."}
	data.load_inventory(staged.serialize_inventory())
	data._changed()
	return {"ok": true, "message": "Bahan siap untuk %d kali memasak %s." % [batches, recipe.display_name]}

static func unlock_recipe(data: PlayerData, recipe: RecipeData, config: Resource) -> Dictionary:
	if not enabled(config) or data == null or recipe == null or not recipe.is_valid_recipe():
		return {"ok": false, "message": "Debug tidak aktif atau resep tidak valid."}
	if not data.learned_recipes.has(recipe.id):
		data.learned_recipes.append(recipe.id)
	return {"ok": true, "message": "Resep %s dibuka tanpa biaya." % recipe.display_name}

static func unlock_all(data: PlayerData, config: Resource) -> Dictionary:
	if not enabled(config) or data == null or config.catalog.recipes == null:
		return {"ok": false, "message": "Debug tidak aktif atau katalog belum tersedia."}
	for recipe in config.catalog.recipes.recipes:
		if recipe != null and recipe.is_valid_recipe() and not data.learned_recipes.has(recipe.id):
			data.learned_recipes.append(recipe.id)
	return {"ok": true, "message": "Semua resep katalog dibuka untuk pemain ini."}

static func give_output(data: PlayerData, recipe: RecipeData, config: Resource) -> Dictionary:
	if not enabled(config) or data == null or recipe == null or not recipe.is_valid_recipe():
		return {"ok": false, "message": "Debug tidak aktif atau resep tidak valid."}
	var staged := PlayerData.new(-1)
	staged.bag_level = data.bag_level
	staged.load_inventory(data.serialize_inventory())
	if staged._store(recipe.result_item(), recipe.output_count) > 0:
		return {"ok": false, "message": "Tas penuh. Tidak ada hasil masakan yang ditambahkan."}
	data.load_inventory(staged.serialize_inventory())
	data._changed()
	return {"ok": true, "message": "Hasil resep ditambahkan langsung untuk tes makan."}

static func expand_bag(data: PlayerData, config: Resource) -> Dictionary:
	if not enabled(config) or data == null:
		return {"ok": false, "message": "Debug tidak aktif."}
	data.bag_level = PlayerData.BAG_SIZES.size() - 1
	GameState.bag_upgraded.emit(data.bag_size)
	data._changed()
	return {"ok": true, "message": "Tas pemain ini diperbesar ke %d slot." % data.bag_size}

static func set_stamina(data: PlayerData, percent: float, config: Resource) -> Dictionary:
	if not enabled(config) or data == null or not is_finite(percent):
		return {"ok": false, "message": "Debug tidak aktif atau stamina tidak valid."}
	data.stamina = roundi(data.max_stamina * clampf(percent, 0.0, 100.0) / 100.0)
	return {"ok": true, "message": "Stamina diatur menjadi %d/%d." % [data.stamina, data.max_stamina]}

static func clear_effects(player: Player, config: Resource) -> Dictionary:
	if not enabled(config) or not is_instance_valid(player):
		return {"ok": false, "message": "Debug tidak aktif atau pemain tidak tersedia."}
	player.data.clear_food_effects()
	player.food_speed_remaining = 0.0
	player.food_speed_multiplier = 1.0
	return {"ok": true, "message": "Seluruh buff/debuff makanan pemain ini dihapus."}

static func grant_gold(config: Resource) -> Dictionary:
	if not enabled(config) or config.gold_amount < 0:
		return {"ok": false, "message": "Debug tidak aktif atau jumlah uang tidak valid."}
	GameState.add_money(config.gold_amount)
	return {"ok": true, "message": "+%d G ke uang bersama." % config.gold_amount}
