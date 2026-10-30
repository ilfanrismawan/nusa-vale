class_name RanchHusbandry
extends RefCounted
## JSON-only extension of the original chicken save format.
const SPECIES := {
	"chicken": {"name": "Ayam", "price": 800, "interval": 1, "product": "chicken_egg", "tool": "", "home": "chicken_coop"},
	"duck": {"name": "Bebek", "price": 1400, "interval": 2, "product": "duck_egg", "tool": "", "home": "chicken_coop"},
	"cow": {"name": "Sapi", "price": 2500, "interval": 1, "product": "cow_milk", "tool": "milk_pail", "home": "barn"},
	"goat": {"name": "Kambing", "price": 3200, "interval": 2, "product": "goat_milk", "tool": "milk_pail", "home": "barn"},
	"sheep": {"name": "Domba", "price": 3000, "interval": 3, "product": "wool", "tool": "shears", "home": "barn"},
	"buffalo": {"name": "Kerbau", "price": 4000, "interval": 2, "product": "buffalo_milk", "tool": "milk_pail", "home": "barn"},
	## Tanpa alat di Barn = hasil siap diambil tangan dari hewannya. "large": false = tanpa ukuran besar
	## (kualitas perak/emas tetap dari kasih sayang).
	"pig": {"name": "Babi", "price": 6000, "interval": 3, "product": "truffle", "tool": "", "home": "barn", "large": false},
	"ostrich": {"name": "Burung Unta", "price": 4500, "interval": 3, "product": "ostrich_egg", "tool": "", "home": "chicken_coop", "large": false},
	## interval 0 = tidak menghasilkan komoditas harian (GDD 4.10.5).
	"capybara": {"name": "Kapibara", "price": 2000, "interval": 0, "product": "", "tool": "", "home": "barn"},
	"horse": {"name": "Kuda", "price": 5000, "interval": 0, "product": "", "tool": "", "home": "barn"},
}
const MAX_PRODUCTS := 999
## Lama hamil dalam hari terawat (GDD 4.10.9). Spesies tanpa entri tidak bisa dibiakkan.
const BREED_DAYS := {"cow": 6, "goat": 5, "sheep": 5, "buffalo": 7, "capybara": 4, "pig": 5}
## Lama inkubasi telur (hari) dan spesies yang menetas.
const HATCH := {"chicken_egg": {"species": "chicken", "days": 3}, "duck_egg": {"species": "duck", "days": 5}, "ostrich_egg": {"species": "ostrich", "days": 7}}
## Hari sampai anak hewan dewasa; anak tidak berproduksi dan tidak bisa ditunggangi/dibiakkan.
const GROW_DAYS := {"chicken_coop": 3, "barn": 5}
const BREED_AFFECTION := 80
const FEATHER_DAYS := 4
const FEATHER_AFFECTION := 60
const HORSE_LIMIT := 1
## Warna kuda yang dijual Eep -> file Horse/<n>.png di PNG/14.x Horse. Kuda save lama ("white") = bay.
const HORSE_COATS := {"bay": "1", "flaxen": "2", "cream": "3", "chestnut": "4", "pearl": "5"}
const BASIC_VARIANTS := ["white", "brown"]
const ANIMAL_DEFAULTS := {"species": "chicken", "brush_day": 0, "bad_days": 0, "sick": false, "progress": 0, "ready": "", "baby_days": 0, "pregnant": 0, "feather": 0}

static func migrate(state: Dictionary) -> Dictionary:
	for key in {"tier": 0, "dirt": 0, "hay": 0, "door": false, "products": {}}:
		if not state.has(key):
			state[key] = {"tier": 0, "dirt": 0, "hay": 0, "door": false, "products": {}}[key]
	if not state.get("incubator") is Dictionary:
		state.incubator = {"installed": false, "egg": "", "days": 0}
	for animal in state.chickens:
		for key in ANIMAL_DEFAULTS:
			if not animal.has(key):
				animal[key] = ANIMAL_DEFAULTS[key]
	return state

static func capacity(state: Dictionary) -> int:
	return 4 + int(state.get("tier", 0)) * 4

static func animal_by_id(state: Dictionary, id: int) -> Dictionary:
	for animal in state.chickens:
		if int(animal.id) == id:
			return animal
	return {}

## Varian yang boleh dibeli untuk jenis hewan ini.
static func variants_for(kind: String) -> Array:
	return HORSE_COATS.keys() if kind == "horse" else BASIC_VARIANTS

## Nomor file warna kuda ("1".."5") dari varian hewan.
static func horse_coat(animal: Dictionary) -> String:
	return str(HORSE_COATS.get(str(animal.get("variant", "")), "1"))

static func species(animal: Dictionary) -> String:
	return str(animal.get("species", "chicken"))

static func product(animal: Dictionary, comfortable: bool) -> String:
	var info: Dictionary = SPECIES[species(animal)]
	var base: String = info.product
	var affection := int(animal.affection)
	var suffix := ""
	if comfortable and affection >= 40:
		suffix = "_gold" if affection >= 80 else "_silver"
	if comfortable and affection >= 60 and info.get("large", true):
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
		var friendly := _capybara_comfort(state, previous)
		var births: Array[Dictionary] = []
		for animal in state.chickens:
			var fed := int(animal.fed_day) == previous
			var dirty := int(state.dirt) >= 3
			var was_sick: bool = animal.sick
			animal.bad_days = int(animal.bad_days) + 1 if not fed or dirty else 0
			if int(animal.bad_days) >= 2:
				animal.sick = true
			elif fed and int(state.dirt) == 0:
				animal.sick = false
			var bonus := 1 if friendly and fed and species(animal) != "capybara" else 0
			animal.affection = clampi(int(animal.affection) + (2 + bonus if fed else -3), 0, 100)
			if int(animal.baby_days) > 0:
				animal.baby_days = int(animal.baby_days) - 1
				continue
			if int(animal.pregnant) > 0 and fed and not animal.sick:
				animal.pregnant = int(animal.pregnant) - 1
				if int(animal.pregnant) == 0:
					births.append(animal)
			var info: Dictionary = SPECIES[species(animal)]
			if not fed or was_sick or animal.sick or int(info.interval) == 0:
				continue
			if species(animal) == "duck" and not dirty and int(animal.affection) >= FEATHER_AFFECTION:
				animal.feather = int(animal.feather) + 1
				if int(animal.feather) >= FEATHER_DAYS and product_count(state) < MAX_PRODUCTS:
					animal.feather = 0
					state.products["duck_feather"] = int(state.products.get("duck_feather", 0)) + 1
				animal.feather = mini(int(animal.feather), FEATHER_DAYS)
			if not str(animal.ready).is_empty():
				continue
			animal.progress = int(animal.progress) + 1
			if int(animal.progress) < int(info.interval):
				continue
			var output := product(animal, not dirty)
			if str(info.tool).is_empty() and info.home == "chicken_coop":
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
		for parent in births:
			# Kandang penuh menunda kelahiran sampai ada tempat, tanpa kehilangan anak.
			if not add_baby(state, species(parent), "Anak " + str(parent.name), str(parent.variant)):
				parent.pregnant = 1
		_advance_incubator(state)
		if not state.chickens.is_empty():
			state.dirt = mini(3, int(state.dirt) + 1)
		state.door = false
		state.last_day = previous + 1
		# Deluxe refills only from actual stored portions, once for each new day.
		if int(state.tier) == 2:
			feed_from_hay(state, previous + 1)

## Kapibara Nyaman (makan, sehat) membuat hewan lain sekandang +1 kasih sayang saat makan; tidak menumpuk.
static func _capybara_comfort(state: Dictionary, previous: int) -> bool:
	for animal in state.chickens:
		if species(animal) == "capybara" and int(animal.fed_day) == previous and not animal.sick and int(state.dirt) < 3:
			return true
	return false

static func _advance_incubator(state: Dictionary) -> void:
	var incubator: Dictionary = state.incubator
	if str(incubator.egg).is_empty():
		return
	incubator.days = maxi(0, int(incubator.days) - 1)
	if int(incubator.days) > 0:
		return
	var kind: String = HATCH[base_egg(str(incubator.egg))].species
	var label := "Anak " + str(SPECIES[kind].name)
	if add_baby(state, kind, label, "brown" if kind == "chicken" and int(state.next_id) % 2 == 0 else "white"):
		incubator.egg = ""

## Menambah anak hewan bila kandang masih punya tempat. Nama dapat diganti di menu kandang.
static func add_baby(state: Dictionary, kind: String, label: String, variant: String) -> bool:
	if state.chickens.size() >= capacity(state):
		return false
	var animal := ANIMAL_DEFAULTS.duplicate()
	animal.merge({"id": int(state.next_id), "name": label.left(16), "variant": variant if variant in ["white", "brown"] else "white", "species": kind, "fed_day": 0, "pet_day": 0, "affection": 0, "baby_days": GROW_DAYS[SPECIES[kind].home]}, true)
	state.chickens.append(animal)
	state.next_id = int(state.next_id) + 1
	return true

static func base_egg(id: String) -> String:
	for base in HATCH:
		if valid_product(id, base):
			return base
	return ""

static func is_adult(animal: Dictionary) -> bool:
	return int(animal.get("baby_days", 0)) == 0

static func can_breed(state: Dictionary, animal: Dictionary) -> String:
	if not BREED_DAYS.has(species(animal)):
		return "Spesies ini tidak dibiakkan."
	if not is_adult(animal):
		return "Masih anak-anak."
	if int(animal.affection) < BREED_AFFECTION:
		return "Perlu 4 hati."
	if animal.sick or int(state.dirt) >= 3:
		return "Hewan harus Nyaman."
	for other in state.chickens:
		if int(other.get("pregnant", 0)) > 0:
			return "Sudah ada hewan hamil di kandang ini."
	if state.chickens.size() >= capacity(state):
		return "Kandang penuh."
	return ""

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
	var incubator: Variant = state.get("incubator", {"installed": false, "egg": "", "days": 0})
	if not incubator is Dictionary or not incubator.get("installed", false) is bool or not incubator.get("egg", "") is String or not integer(incubator.get("days", 0)):
		return false
	if incubator.get("installed", false) and home != "chicken_coop":
		return false
	if incubator.get("egg", "") != "" and (not incubator.get("installed", false) or base_egg(incubator.egg).is_empty() or incubator.days < 0 or incubator.days > HATCH[base_egg(incubator.egg)].days):
		return false
	var seen := {}
	for animal in state.chickens:
		if not animal is Dictionary or not animal.get("name") is String or animal.name.strip_edges().is_empty() or animal.name.length() > 16 or not (animal.get("variant") in BASIC_VARIANTS or (species(animal) == "horse" and HORSE_COATS.has(animal.get("variant")))):
			return false
		var kind := species(animal)
		if not SPECIES.has(kind) or SPECIES[kind].home != home:
			return false
		for required in ["id", "fed_day", "pet_day", "affection"]:
			if not animal.has(required):
				return false
		for key in ["id", "fed_day", "pet_day", "brush_day", "affection", "bad_days", "progress", "baby_days", "pregnant", "feather"]:
			var n: Variant = animal.get(key, 0)
			if not integer(n) or n < 0 or n > 1000000:
				return false
		if animal.id < 1 or animal.id >= state.next_id or seen.has(int(animal.id)) or animal.affection > 100 or animal.fed_day > state.last_day or animal.pet_day > state.last_day or animal.get("brush_day", 0) > state.last_day or animal.get("progress", 0) > SPECIES[kind].interval or not animal.get("sick", false) is bool:
			return false
		if not animal.get("ready", "") is String:
			return false
		if animal.get("baby_days", 0) > GROW_DAYS[home] or animal.get("pregnant", 0) > BREED_DAYS.get(kind, 0) or animal.get("feather", 0) > FEATHER_DAYS:
			return false
		if animal.get("ready", "") != "" and ((str(SPECIES[kind].tool).is_empty() and home == "chicken_coop") or not valid_product(str(animal.ready), str(SPECIES[kind].product))):
			return false
		seen[int(animal.id)] = true
	for id in state.get("products", {}):
		if not id is String or not (valid_product(id, "chicken_egg") or valid_product(id, "duck_egg") or valid_product(id, "ostrich_egg") or id == "duck_feather") or home != "chicken_coop" or not integer(state.products[id]) or state.products[id] <= 0:
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
