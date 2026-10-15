class_name CookingManager
extends RefCounted

const RECIPES := {
	"vegetable_soup": {"name": "Sup Sayur Bening", "ingredients": {"carrot": 1, "cabbage": 1}, "book": 0},
	"fried_egg": {"name": "Telur Goreng", "ingredients": {"chicken_egg": 1}, "book": 0},
	"grilled_catfish": {"name": "Ikan Bakar Lele", "ingredients": {"fish_lele": 1}, "book": 150},
	"fruit_salad": {"name": "Salad Buah", "ingredients": {"apple": 1, "strawberry": 1}, "book": 200},
	"mushroom_saute": {"name": "Tumis Jamur", "ingredients": {"common_mushroom": 2}, "book": 100},
}

static func knows(data: PlayerData, id: String) -> bool:
	return RECIPES.has(id) and (int(RECIPES[id].book) == 0 or id in data.learned_recipes)

static func learn(data: PlayerData, id: String) -> Dictionary:
	if data == null or not RECIPES.has(id) or knows(data, id):
		return {"ok": false, "message": "Resep sudah dipelajari atau tidak tersedia."}
	if not GameState.spend_money(int(RECIPES[id].book)):
		return {"ok": false, "message": "Uang tidak cukup untuk buku resep."}
	data.learned_recipes.append(id)
	return {"ok": true, "message": "Resep %s dipelajari." % RECIPES[id].name}

static func cook(data: PlayerData, id: String) -> Dictionary:
	if data == null or not knows(data, id):
		return {"ok": false, "message": "Pelajari resep terlebih dahulu."}
	var ingredients: Dictionary = RECIPES[id].ingredients
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
	if staged._store(GameState._resolve_item(id), 1) != 0:
		return {"ok": false, "message": "Tas penuh. Sediakan ruang untuk masakan."}
	data.load_inventory(staged.serialize_inventory())
	data._changed()
	return {"ok": true, "message": "%s selesai dimasak." % RECIPES[id].name}

static func eat(player: Player, slot: int) -> Dictionary:
	var data := player.data
	if slot < 0 or slot >= data.bag_size or data.inventory[slot] == null:
		return {"ok": false, "message": "Tidak ada makanan."}
	var item: ItemData = data.inventory[slot].item
	if item.category != ItemData.Category.FOOD:
		return {"ok": false, "message": "Item ini bukan makanan."}
	if data.stamina >= data.max_stamina and item.speed_buff_seconds <= 0:
		return {"ok": false, "message": "Stamina masih penuh."}
	data.remove_item_at(slot, 1)
	data.restore_stamina(item.stamina_restore)
	player.food_speed_remaining = maxf(player.food_speed_remaining, item.speed_buff_seconds)
	return {"ok": true, "message": "%s dimakan · +%d stamina." % [item.display_name, item.stamina_restore]}
