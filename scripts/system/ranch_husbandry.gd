class_name RanchHusbandry
extends RefCounted
## JSON-only extension of the original chicken save format.
const SPECIES := {
	"chicken": {"name": "Ayam", "price": 800, "interval": 1, "product": "chicken_egg", "tool": "", "home": "chicken_coop"},
	"duck": {"name": "Bebek", "price": 1400, "interval": 2, "product": "duck_egg", "tool": "", "home": "chicken_coop"},
	"cow": {"name": "Sapi", "price": 2500, "interval": 1, "product": "cow_milk", "tool": "milk_pail", "home": "barn"},
	"goat": {"name": "Kambing", "price": 3200, "interval": 2, "product": "goat_milk", "tool": "milk_pail", "home": "barn"},
	"sheep": {"name": "Domba", "price": 3000, "interval": 3, "product": "wool", "tool": "shears", "home": "barn"},
}
const MAX_PRODUCTS := 999

static func migrate(state: Dictionary) -> Dictionary:
	for key in {"tier": 0, "dirt": 0, "hay": 0, "door": false, "products": {}}:
		if not state.has(key):
			state[key] = {"tier": 0, "dirt": 0, "hay": 0, "door": false, "products": {}}[key]
	for animal in state.chickens:
		for key in {"species": "chicken", "brush_day": 0, "bad_days": 0, "sick": false, "progress": 0, "ready": ""}:
			if not animal.has(key):
				animal[key] = {"species": "chicken", "brush_day": 0, "bad_days": 0, "sick": false, "progress": 0, "ready": ""}[key]
	return state

static func capacity(state: Dictionary) -> int:
	return 4 + int(state.get("tier", 0)) * 4

static func animal_by_id(state: Dictionary, id: int) -> Dictionary:
	for animal in state.chickens:
		if int(animal.id) == id:
			return animal
	return {}

static func species(animal: Dictionary) -> String:
	return str(animal.get("species", "chicken"))

static func product(animal: Dictionary, comfortable: bool) -> String:
	var base: String = SPECIES[species(animal)].product
	var affection := int(animal.affection)
	var suffix := ""
	if comfortable and affection >= 40:
		suffix = "_gold" if affection >= 80 else "_silver"
	if comfortable and affection >= 60:
		base += "_large"
	return base + suffix

static func product_count(state: Dictionary) -> int:
	var count := int(state.eggs)
	for amount in state.get("products", {}).values():
		count += int(amount)
	return count

static func advance(state: Dictionary, day: int) -> void:
	migrate(state)
	if day <= int(state.last_day):
		return
	for previous in range(int(state.last_day), day):
		for animal in state.chickens:
			var fed := int(animal.fed_day) == previous
			var dirty := int(state.dirt) >= 3
			var was_sick: bool = animal.sick
			animal.bad_days = int(animal.bad_days) + 1 if not fed or dirty else 0
			if int(animal.bad_days) >= 2:
				animal.sick = true
			elif fed and int(state.dirt) == 0:
				animal.sick = false
			animal.affection = clampi(int(animal.affection) + (2 if fed else -3), 0, 100)
			if not fed or was_sick or animal.sick or not str(animal.ready).is_empty():
				continue
			animal.progress = int(animal.progress) + 1
			var info: Dictionary = SPECIES[species(animal)]
			if int(animal.progress) < int(info.interval):
				continue
			var output := product(animal, not dirty)
			if str(info.tool).is_empty():
				if product_count(state) >= MAX_PRODUCTS:
					animal.progress = mini(int(animal.progress), int(info.interval))
					continue
				if output == "chicken_egg":
					state.eggs = int(state.eggs) + 1
				else:
					state.products[output] = int(state.products.get(output, 0)) + 1
			else:
				animal.ready = output
			animal.progress = 0
		if not state.chickens.is_empty():
			state.dirt = mini(3, int(state.dirt) + 1)
		state.door = false
		state.last_day = previous + 1
		# Deluxe refills only from actual stored portions, once for each new day.
		if int(state.tier) == 2:
			feed_from_hay(state, previous + 1)

static func feed_from_hay(state: Dictionary, day: int) -> int:
	var fed := 0
	for animal in state.chickens:
		if int(state.hay) <= 0:
			break
		if int(animal.fed_day) == day:
			continue
		state.hay = int(state.hay) - 1
		animal.fed_day = day
		fed += 1
	return fed

static func condition(state: Dictionary, animal: Dictionary, day: int) -> String:
	if animal.get("sick", false):
		return "Kurang sehat: beri pakan dan bersihkan kandang"
	if int(state.dirt) >= 3:
		return "Kurang nyaman: kandang kotor"
	return "Nyaman" if int(animal.fed_day) == day else "Lapar: perlu 1 pakan"

static func valid(state: Variant, home: String = "chicken_coop") -> bool:
	if not state is Dictionary:
		return false
	if state.is_empty():
		return true
	if not state.get("chickens") is Array or not state.get("products", {}) is Dictionary:
		return false
	for required in ["last_day", "next_id", "eggs"]:
		if not state.has(required):
			return false
	for key in ["last_day", "next_id", "eggs", "tier", "dirt", "hay"]:
		var n: Variant = state.get(key, 0)
		if not integer(n) or n < 0:
			return false
	if state.last_day < 1 or state.last_day > 1000000 or state.next_id != state.chickens.size() + 1 or state.get("tier", 0) > 2 or state.get("dirt", 0) > 3 or state.get("hay", 0) > 240 or state.eggs > MAX_PRODUCTS or state.chickens.size() > capacity(state):
		return false
	if not state.get("door", false) is bool:
		return false
	if home == "barn" and (state.eggs != 0 or not state.get("products", {}).is_empty()):
		return false
	var seen := {}
	for animal in state.chickens:
		if not animal is Dictionary or not animal.get("name") is String or animal.name.strip_edges().is_empty() or animal.name.length() > 16 or not animal.get("variant") in ["white", "brown"]:
			return false
		var kind := species(animal)
		if not SPECIES.has(kind) or SPECIES[kind].home != home:
			return false
		for required in ["id", "fed_day", "pet_day", "affection"]:
			if not animal.has(required):
				return false
		for key in ["id", "fed_day", "pet_day", "brush_day", "affection", "bad_days", "progress"]:
			var n: Variant = animal.get(key, 0)
			if not integer(n) or n < 0 or n > 1000000:
				return false
		if animal.id < 1 or animal.id >= state.next_id or seen.has(int(animal.id)) or animal.affection > 100 or animal.fed_day > state.last_day or animal.pet_day > state.last_day or animal.get("brush_day", 0) > state.last_day or animal.get("progress", 0) > SPECIES[kind].interval or not animal.get("sick", false) is bool:
			return false
		if not animal.get("ready", "") is String:
			return false
		if animal.get("ready", "") != "" and (str(SPECIES[kind].tool).is_empty() or not valid_product(str(animal.ready), str(SPECIES[kind].product))):
			return false
		seen[int(animal.id)] = true
	for id in state.get("products", {}):
		if not id is String or not (valid_product(id, "chicken_egg") or valid_product(id, "duck_egg")) or home != "chicken_coop" or not integer(state.products[id]) or state.products[id] <= 0:
			return false
	return product_count(state) <= MAX_PRODUCTS

static func integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))

static func valid_product(id: String, base: String) -> bool:
	for size in ["", "_large"]:
		for quality in ["", "_silver", "_gold"]:
			if id == base + size + quality:
				return true
	return false
