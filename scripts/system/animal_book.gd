class_name AnimalBook
extends RefCounted
## Data tab Hewan di buku tas (GDD 4.10): peliharaan pemain 1 lalu ternak per kandang di ladang.
## Hanya membaca; merawat tetap di hewannya atau menu kandang. Tugas hari ini memakai
## RanchHusbandry.status_needs() (sama dengan gelembung di atas kepala hewan).

const GROUP_PET := "Peliharaan"
const FOOD_NAMES := {ItemData.Category.FISH: "ikan", ItemData.Category.FOOD: "masakan"}

## [{group, home ("pet", "chicken_coop", "barn"), key, name, species, portrait, affection, max_affection, stage, needs, info, description,
##   todo, ready}] urut peliharaan, Kandang Unggas, lalu Barn (urutan bangun).
static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var pet := pet_entry()
	if not pet.is_empty():
		result.append(pet)
	var counts := {}
	for home in StructureManager.RANCHES:
		for record in StructureManager.records:
			if record.item != home or not record.get("livestock") is Dictionary or record.livestock.is_empty():
				continue
			counts[home] = int(counts.get(home, 0)) + 1
			var group := "%s %d" % [GameState._resolve_item(home).display_name, counts[home]]
			var state := RanchHusbandry.migrate(record.livestock)
			for animal in state.chickens:
				result.append(ranch_entry(group, int(record.uid), state, animal))
				result[-1].home = home
	return result

static func pet_entry() -> Dictionary:
	var data := GameState.p1()
	if data.pet_id.is_empty():
		return {}
	var option := PetActor.option(data.pet_id)
	var frames := PetActor.pet_frames(data.pet_id)
	var care := PetActor.CARE
	var day := DayCycle.current_day
	var foods: Array[String] = []
	for category in care.food_categories:
		foods.append(FOOD_NAMES.get(category, "makanan"))
	var food := " atau ".join(foods)
	var needs: Array = [{"kind": "feed", "done": data.pet_fed_day == day}, {"kind": "pet", "done": data.pet_day == day}]
	return _finish({
		"group": GROUP_PET, "home": "pet", "key": "pet", "name": data.pet_name,
		"species": str(option.get("display_name")) if option != null else "Peliharaan",
		"portrait": frames.get_frame_texture(&"sit", 0) if frames != null else null,
		"affection": data.pet_affection, "max_affection": care.max_affection,
		"stage": "Main di depan rumah ladang" if PetActor.is_daytime() else "Tidur di dalam rumah",
		"needs": needs,
		"info": [
			["Makanan", food.left(1).to_upper() + food.substr(1)],
			["Elus/makan", "+%d / +%d sehari" % [care.pet_gain, care.feed_gain]],
			["Panggil", "Siul"],
		],
		"description": str(option.get("description")) if option != null else "",
	})

static func ranch_entry(group: String, uid: int, state: Dictionary, animal: Dictionary) -> Dictionary:
	var kind := RanchHusbandry.species(animal)
	var data: AnimalSpeciesData = RanchHusbandry.species_data.get(kind)
	var adult := RanchHusbandry.is_adult(animal)
	var day := DayCycle.current_day
	var stage := RanchHusbandry.condition(state, animal, day)
	if not adult:
		stage = "Anak · dewasa %d hari lagi" % int(animal.baby_days)
	elif int(animal.pregnant) > 0:
		stage = "Hamil · lahir %d hari lagi" % int(animal.pregnant)
	var info: Array = []
	if data != null and data.interval > 0:
		var made := GameState._resolve_item(data.product)
		info.append(["Hasil", "%s tiap %d hari" % [made.display_name if made else data.product, data.interval]])
		if not data.tool.is_empty():
			info.append(["Alat", GameState._resolve_item(data.tool).display_name])
		if not adult:
			info.append(["Produksi", "Setelah dewasa"])
		elif not str(animal.get("ready", "")).is_empty():
			info.append(["Produksi", "Siap: " + GameState._resolve_item(str(animal.ready)).display_name])
		elif data.home == "chicken_coop":
			info.append(["Produksi", "Masuk stok kandang"])
		else:
			info.append(["Produksi", "%d/%d hari terawat" % [int(animal.progress), data.interval]])
	if data != null and data.breed_days > 0:
		info.append(["Biak", "Hamil %d hari, %d hati" % [data.breed_days, RanchHusbandry.BREED_AFFECTION / 20]])
	if data != null and data.hatch_days > 0:
		info.append(["Tetas", "Inkubator %d hari" % data.hatch_days])
	if kind == "horse":
		info.append(["Kuda", "Ditunggangi" if StructureManager.is_ridden(uid, int(animal.id)) else "Di depan Barn"])
	var frames := RanchVisual.frames(kind, str(animal.get("variant", "white")), false, "down", not adult)
	return _finish({
		"group": group, "key": "%d:%d" % [uid, int(animal.id)], "name": str(animal.name),
		"species": data.display_name if data != null else kind,
		"portrait": frames.get_frame_texture(&"default", 0) if frames != null else null,
		"affection": int(animal.affection), "max_affection": 100,
		"stage": stage, "needs": RanchHusbandry.status_needs(animal, day), "info": info,
		"description": data.description if data != null else "",
	})

## Tandai perlu dirawat (makan/elus/sikat/obat belum) dan hasil siap diambil.
static func _finish(entry: Dictionary) -> Dictionary:
	entry.todo = false
	entry.ready = false
	for need in entry.needs:
		if need.kind == "product":
			entry.ready = true
		elif not need.done:
			entry.todo = true
	return entry

## Saring entri: "all", "todo" (belum dirawat hari ini), "ready" (hasil siap diambil), atau
## tempat tinggal ("pet", "chicken_coop", "barn").
static func filtered(all: Array[Dictionary], filter: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in all:
		var keep: bool = filter == "all" or (filter == "todo" and entry.todo) or (filter == "ready" and entry.ready) or entry.get("home") == filter
		if keep:
			result.append(entry)
	return result
