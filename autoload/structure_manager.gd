extends Node
## Shared farm structures. JSON-only records include chest contents and furnace jobs.
signal changed
const FURNITURE := ["wooden_chair", "wooden_bench"]
const PreservesJarRecipe = preload("res://scripts/resources/preserves_jar_recipe.gd")
const DehydratorRecipe = preload("res://scripts/resources/dehydrator_recipe.gd")
const IDS := ["furnace", "wooden_chest", "wooden_fence", "crafting_workbench", "stone_fence", "wooden_gate", "copper_chest", "iron_chest", "gold_chest", "platinum_chest", "crimson_chest", "frost_chest", "shadow_chest", "chicken_coop", "preserves_jar", "barn", "dehydrator", "silo", "pasture_grass", "mayonnaise_maker", "cheese_press", "loom", "wooden_chair", "wooden_bench", "fairy_chest", "obsidian_chest", "beehive", "sawmill", "alchemy_table", "anvil", "scarecrow", "birdhouse", "street_lamp", "hay_bale", "wooden_bucket", "village_barrel", "mailbox_decor", "stone_statue", "snowman", "feed_trough", "bonfire", "candle", "stacked_barrels", "notice_board", "garden_well", "water_fountain", "garden_swing", "seesaw", "signpost", "picnic_blanket", "twin_lamp", "clothesline", "dog_house", "cow_weathervane", "chicken_weathervane", "hanging_lantern", "xmas_tree", "sandbox", "wooden_broom", "keg", "oil_maker", "fish_smoker", "lightning_rod", "single_bed_wood", "double_bed_wood", "single_bed_blue", "bunk_bed", "baby_crib", "classic_chair", "stool_wood", "armchair_cozy", "sofa_living", "sofa_large", "study_desk", "dining_table_wood", "round_table", "nightstand", "wardrobe_classic", "bookshelf_tall", "kitchen_cabinet", "dresser_mirror", "dresser_drawers", "fireplace_stone", "fireplace_brick", "candle_stand", "floor_lamp", "cat_tree_tall", "cat_bed", "cat_bowl", "grandfather_clock", "indoor_plant_large", "indoor_plant_small", "painting_wall", "gramophone", "wall_mirror", "carpet_rug", "wall_shelf", "umbrella_stand", "school_blackboard", "school_desk", "grand_bookshelf", "lab_alchemy_desk", "weapon_rack", "temple_bell"]
## Dekorasi pasang (GDD 4.13). frames = jumlah frame animasi di atlas ikon, night_frame = frame saat malam, light = menyala saat malam.
const DECOR := {
	"scarecrow": {}, "birdhouse": {}, "street_lamp": {"frames": 2, "night_frame": 1, "light": true}, "hay_bale": {}, "wooden_bucket": {},
	"village_barrel": {}, "mailbox_decor": {}, "stone_statue": {}, "snowman": {}, "feed_trough": {},
	"bonfire": {"frames": 6, "light": true}, "candle": {"frames": 4, "light": true}, "stacked_barrels": {}, "notice_board": {},
	"garden_well": {}, "water_fountain": {}, "garden_swing": {}, "seesaw": {}, "signpost": {}, "picnic_blanket": {},
	"twin_lamp": {"frames": 2, "night_frame": 1, "light": true}, "clothesline": {}, "dog_house": {}, "cow_weathervane": {},
	"chicken_weathervane": {}, "hanging_lantern": {"light": true}, "xmas_tree": {}, "sandbox": {}, "wooden_broom": {},
	"single_bed_wood": {}, "double_bed_wood": {}, "single_bed_blue": {}, "bunk_bed": {}, "baby_crib": {},
	"classic_chair": {}, "stool_wood": {}, "armchair_cozy": {}, "sofa_living": {}, "sofa_large": {},
	"study_desk": {}, "dining_table_wood": {}, "round_table": {}, "nightstand": {},
	"wardrobe_classic": {}, "bookshelf_tall": {}, "kitchen_cabinet": {}, "dresser_mirror": {}, "dresser_drawers": {},
	"fireplace_stone": {"light": true}, "fireplace_brick": {"light": true}, "candle_stand": {"light": true}, "floor_lamp": {"light": true},
	"cat_tree_tall": {}, "cat_bed": {}, "cat_bowl": {},
	"grandfather_clock": {}, "indoor_plant_large": {}, "indoor_plant_small": {}, "painting_wall": {},
	"gramophone": {}, "wall_mirror": {}, "carpet_rug": {}, "wall_shelf": {}, "umbrella_stand": {},
	"school_blackboard": {}, "school_desk": {}, "grand_bookshelf": {}, "lab_alchemy_desk": {}, "weapon_rack": {}, "temple_bell": {},
}
## Mesin crafting baru (GDD 4.13): sprite dirapatkan ke bawah tapak seperti dekorasi.
const WORKSHOPS := {"beehive": {"frames": 7}, "sawmill": {}, "alchemy_table": {}, "anvil": {}, "keg": {}, "oil_maker": {}, "fish_smoker": {}, "lightning_rod": {}}
## Meja yang meracik langsung dari katalog crafting sendiri.
const STATION_CATALOGS := {"alchemy_table": "res://resources/crafting/alchemy.tres", "anvil": "res://resources/crafting/anvil.tres"}
const BEEHIVE_DAYS := 3
const CONSTRUCTION := {
	"chicken_coop": {"money": 2000, "materials": {"wood": 100, "stone": 50}},
	"barn": {"money": 3000, "materials": {"wood": 200, "stone": 100}},
	"silo": {"money": 1200, "materials": {"wood": 50, "stone": 100}},
}
const RANCHES := ["chicken_coop", "barn"]
const ARTISANS := {
	"mayonnaise_maker": {"chicken_egg": "mayonnaise", "duck_egg": "duck_mayonnaise"},
	"cheese_press": {"cow_milk": "cheese", "goat_milk": "goat_cheese", "buffalo_milk": "buffalo_cheese"},
	"loom": {"wool": "cloth"},
	"keg": {
		"wheat": "beer", "grape": "wine", "apple": "wine", "cherry": "wine",
		"peach": "wine", "orange": "wine", "strawberry": "wine", "blueberry": "wine",
		"honey": "mead", "banana": "juice", "mango": "juice", "melon": "juice",
		"watermelon": "juice", "pineapple": "juice", "tomato": "juice", "carrot": "juice"
	},
	"oil_maker": {
		"corn": "oil", "sunflower": "oil", "truffle": "truffle_oil", "garlic": "garlic_oil"
	},
	"fish_smoker": {
		"smoked_fish": "smoked_fish"
	},
}
const PROCESSING_MACHINES := [
	"keg",
	"oil_maker",
	"fish_smoker",
	"mayonnaise_maker",
	"cheese_press",
	"loom",
	"preserves_jar",
	"dehydrator",
	"furnace",
	"sawmill",
	"beehive",
	"lightning_rod"
]

static func is_processing_machine(item_id: String) -> bool:
	return item_id in PROCESSING_MACHINES or ARTISANS.has(item_id)

const ARTISAN_SECONDS := 20.0
const CHESTS := ["wooden_chest", "copper_chest", "iron_chest", "gold_chest", "platinum_chest", "crimson_chest", "frost_chest", "shadow_chest", "fairy_chest", "obsidian_chest"]
var records: Array[Dictionary] = []
var _next_uid := 1
var _views: Array[WeakRef] = []
var _menus: Dictionary = {}
var solo_ranch_uid := 0
var _ranch_returns: Dictionary = {}
var _recipes: Array[FurnaceRecipe] = []
var _preserves_recipes: Array[PreservesJarRecipe] = []
var _dehydrator_recipes: Array[DehydratorRecipe] = []
var _sawmill_recipes: Array[FurnaceRecipe] = []
## Kuda yang sedang ditunggangi: "uid:id" -> Player. Tidak disimpan; tidur/muat ulang menurunkan penunggang.
var _riders: Dictionary = {}
## Tempat kuda ditinggal di dunia (gaya Stardew): {"scene", "pos", "flip"}. Kosong = di depan Barn.
## Tidak disimpan; setiap pagi kuda kembali ke depan Barn.
var horse_spot: Dictionary = {}
var _horse_scan := 0.0

func _ready() -> void:
	DayCycle.day_passed.connect(func(_day: int):
		dismount_all()
		horse_spot = {})
	DayCycle.day_passed.connect(_advance_chickens)
	DayCycle.day_passed.connect(_advance_beehives)
	DayCycle.day_passed.connect(func(_day: int): if GameState.weather.is_storm(): _advance_lightning_rods())
	DayCycle.time_tick.connect(_ranch_time)
	GameState.weather.changed.connect(func(): _ranch_time(DayCycle.hour, DayCycle.minute))

func _advance_chickens(day: int) -> void:
	var updated := false
	var earliest := day
	for record in records:
		if record.item in RANCHES:
			earliest = mini(earliest, int(coop_state(record).last_day))
	# Process skipped days chronologically so shared silos cannot create free feed.
	for next_day in range(earliest + 1, day + 1):
		for record in records:
			if record.item in RANCHES and int(coop_state(record).last_day) < next_day:
				var state := coop_state(record)
				RanchHusbandry.advance(state, next_day)
				if int(state.tier) == 2:
					_feed_from_silos(state, next_day)
				updated = true
	for record in records:
		if record.item == "pasture_grass":
			updated = true
	if updated:
		_sync_all()

## Sarang lebah: job = {"day": hari siap}. Musim Dingin menunda panen sehari demi sehari.
func _advance_beehives(day: int) -> void:
	var updated := false
	for record in records:
		if record.item != "beehive" or not record.ready.is_empty():
			continue
		if record.job.is_empty():
			record.job = {"day": day + BEEHIVE_DAYS}
		elif int(record.job.get("day", 0)) <= day:
			if DayCycle.get_current_season() == "winter":
				record.job = {"day": day + 1}
			else:
				record.job = {}
				record.ready = {"id": "honey", "count": 1, "extra": {"id": "beeswax", "count": 1}}
		updated = true
	if updated:
		_sync_all()

func station_catalog(machine: String) -> CraftingCatalog:
	return load(STATION_CATALOGS[machine]) as CraftingCatalog if STATION_CATALOGS.has(machine) else null

func _feed_from_silos(state: Dictionary, day: int) -> void:
	for animal in state.chickens:
		if int(animal.fed_day) == day:
			continue
		for silo in records:
			if silo.item == "silo" and int(silo.get("hay", 0)) > 0:
				silo.hay = int(silo.hay) - 1
				animal.fed_day = day
				break

func graze_animal(uid: int, animal_id: int, pasture_uid: int) -> Dictionary:
	var record := record_for(uid)
	var pasture := record_for(pasture_uid)
	if not record.get("item") in RANCHES or pasture.get("item") != "pasture_grass" or not grazing_weather():
		return _result(false, "Rumput tidak tersedia.")
	var state := coop_state(record)
	var home_cell := Vector2i(int(record.cell[0]), int(record.cell[1]))
	var grass_cell := Vector2i(int(pasture.cell[0]), int(pasture.cell[1]))
	if home_cell.distance_to(grass_cell) > 10:
		return _result(false, "Rumput terlalu jauh dari kandang.")
	var animal := RanchHusbandry.animal_by_id(state, animal_id)
	if animal.is_empty() or not state.door or DayCycle.hour >= 18 or DayCycle.hour < 6 or int(animal.fed_day) == DayCycle.current_day or int(pasture.get("regrow_day", 0)) > DayCycle.current_day:
		return _result(false, "Hewan sudah makan atau rumput belum tumbuh.")
	animal.fed_day = DayCycle.current_day
	pasture.regrow_day = DayCycle.current_day + 2
	_sync_all()
	return _result(true, "%s kenyang setelah merumput." % animal.name)

func coop_state(record: Dictionary) -> Dictionary:
	if not record.has("livestock") or record.livestock.is_empty():
		record.livestock = ChickenHusbandry.empty(DayCycle.current_day)
	return RanchHusbandry.migrate(record.livestock)

func buy_animal(uid: int, species: String, requested_name: String = "", variant: String = "white") -> Dictionary:
	var record := record_for(uid)
	if not RanchHusbandry.SPECIES.has(species) or not variant in RanchHusbandry.variants_for(species):
		return _result(false, "Jenis hewan tidak tersedia.")
	var info: Dictionary = RanchHusbandry.SPECIES[species]
	if record.get("item") != info.home:
		return _result(false, "Hewan ini memerlukan kandang yang sesuai.")
	var state := coop_state(record)
	if state.chickens.size() >= RanchHusbandry.capacity(state):
		return _result(false, "Kandang penuh. Tingkatkan kandang terlebih dahulu.")
	if species == "horse" and count_species("horse") >= RanchHusbandry.HORSE_LIMIT:
		return _result(false, "Kamu sudah punya kuda. Satu kuda cukup untuk satu peternakan.")
	if not GameState.spend_money(int(info.price)):
		return _result(false, "Uang tidak cukup: %d G." % int(info.price))
	var animal_name := requested_name.replace("\n", " ").replace("\r", " ").strip_edges().left(16)
	if animal_name.is_empty():
		animal_name = "%s %d" % [info.name, int(state.next_id)]
	var animal: Dictionary = RanchHusbandry.ANIMAL_DEFAULTS.duplicate()
	animal.merge({"id": int(state.next_id), "name": animal_name, "variant": variant, "species": species, "fed_day": 0, "pet_day": 0, "affection": 0}, true)
	state.chickens.append(animal)
	state.next_id = int(state.next_id) + 1
	_sync_all()
	return _result(true, "%s tiba! Beri pakan, elus, dan jaga kebersihan kandang." % animal_name)

func count_species(kind: String) -> int:
	var count := 0
	for record in records:
		if record.item in RANCHES:
			for animal in coop_state(record).chickens:
				count += 1 if RanchHusbandry.species(animal) == kind else 0
	return count

func rename_animal(uid: int, id: int, requested_name: String) -> Dictionary:
	var record := record_for(uid)
	if not record.get("item") in RANCHES:
		return _result(false, "Kandang tidak tersedia.")
	var animal := RanchHusbandry.animal_by_id(coop_state(record), id)
	var animal_name := requested_name.replace("\n", " ").replace("\r", " ").strip_edges().left(16)
	if animal.is_empty() or animal_name.is_empty():
		return _result(false, "Tulis nama terlebih dahulu.")
	animal.name = animal_name
	_sync_all()
	return _result(true, "Namanya sekarang %s." % animal_name)

## Pembiakan Barn (GDD 4.10.9): gratis, satu kehamilan per kandang, anak lahir setelah BREED_DAYS hari terawat.
func breed_animal(uid: int, id: int) -> Dictionary:
	var record := record_for(uid)
	if record.get("item") != "barn":
		return _result(false, "Pembiakan hanya di Kandang Ternak.")
	var state := coop_state(record)
	var animal := RanchHusbandry.animal_by_id(state, id)
	if animal.is_empty():
		return _result(false, "Hewan tidak tersedia.")
	var reason := RanchHusbandry.can_breed(state, animal)
	if not reason.is_empty():
		return _result(false, reason)
	animal.pregnant = int(RanchHusbandry.BREED_DAYS[RanchHusbandry.species(animal)])
	_sync_all()
	Juice.play_sound(&"pickup")
	return _result(true, "%s sedang hamil. Anak lahir setelah %d hari terawat." % [animal.name, int(animal.pregnant)])

## Inkubator dipasang sekali di Kandang Unggas memakai item "incubator" dari tas.
func install_incubator(data: PlayerData, uid: int) -> Dictionary:
	var record := record_for(uid)
	if data == null or record.get("item") != "chicken_coop":
		return _result(false, "Inkubator hanya untuk Kandang Unggas.")
	var state := coop_state(record)
	if state.incubator.installed:
		return _result(false, "Inkubator sudah terpasang.")
	if not data.remove_item("incubator", 1):
		return _result(false, "Rakit Inkubator terlebih dahulu.")
	state.incubator.installed = true
	_sync_all()
	return _result(true, "Inkubator terpasang. Masukkan telur ayam atau bebek.")

func incubate_egg(data: PlayerData, uid: int, egg_id: String) -> Dictionary:
	var record := record_for(uid)
	if data == null or record.get("item") != "chicken_coop":
		return _result(false, "Kandang tidak tersedia.")
	var state := coop_state(record)
	var base := RanchHusbandry.base_egg(egg_id)
	if not state.incubator.installed:
		return _result(false, "Pasang Inkubator terlebih dahulu.")
	if not str(state.incubator.egg).is_empty():
		return _result(false, "Inkubator masih berisi telur.")
	if base.is_empty() or not data.remove_item(egg_id, 1):
		return _result(false, "Bawa telur ayam atau bebek di tas.")
	state.incubator.egg = egg_id
	state.incubator.days = int(RanchHusbandry.HATCH[base].days)
	_sync_all()
	return _result(true, "Telur dierami. Menetas dalam %d hari bila kandang punya tempat." % int(state.incubator.days))

func incubator_eggs(data: PlayerData) -> Array[String]:
	var result: Array[String] = []
	for slot in data.bag_size:
		if data.inventory[slot] != null:
			var id: String = data.inventory[slot].item.item_id
			if not RanchHusbandry.base_egg(id).is_empty() and not id in result:
				result.append(id)
	return result

## Kuda tunggangan (GDD 4.10.10), gaya Stardew/Harvest Moon: interaksi pada kuda di dunia langsung menaikinya.
## Kuda lapar diberi 1 jerami dari tas pemain; elusan harian ikut terhitung saat naik.
## Kecepatan dipakai MoveState lewat Player.mount_speed_multiplier().
func mount_horse(player: Player, uid: int, id: int) -> Dictionary:
	var record := record_for(uid)
	var animal := RanchHusbandry.animal_by_id(coop_state(record), id) if record.get("item") in RANCHES else {}
	if player == null or animal.is_empty() or RanchHusbandry.species(animal) != "horse":
		return _result(false, "Kuda tidak tersedia.")
	if not RanchHusbandry.is_adult(animal):
		return _result(false, "%s masih terlalu kecil untuk ditunggangi." % animal.name)
	if animal.sick:
		return _result(false, "%s kurang sehat. Beri pakan dan bersihkan kandang dulu." % animal.name)
	if player.is_riding():
		return _result(false, "Turun dari kendaraan dulu.")
	var key := "%d:%d" % [uid, id]
	if is_instance_valid(_riders.get(key)):
		return _result(false, "%s sedang ditunggangi pemain lain." % animal.name)
	if player.has_meta("riding_horse") or (player.has_meta("carried_animal") and is_instance_valid(player.get_meta("carried_animal"))):
		return _result(false, "Tanganmu sedang sibuk.")
	var note := ""
	if int(animal.fed_day) != DayCycle.current_day:
		if not player.data.remove_item("hay", 1):
			return _result(false, "%s lapar. Bawa 1 jerami untuk memberinya makan." % animal.name)
		animal.fed_day = DayCycle.current_day
		note = " Diberi 1 jerami."
	if int(animal.pet_day) != DayCycle.current_day:
		animal.pet_day = DayCycle.current_day
		animal.affection = mini(100, int(animal.affection) + 3)
	_riders[key] = player
	player.set_meta("riding_horse", {"uid": uid, "id": id, "affection": int(animal.affection), "coat": RanchHusbandry.horse_coat(animal)})
	# Pemain berpindah ke punggung kuda yang berdiri di dunia.
	var actor := _horse_actor(player.world_root())
	if actor != null:
		player.global_position = actor.global_position - Player.FEET_OFFSET
		actor.queue_free()
	var mount: Node2D = load("res://scripts/world/horse_mount.gd").new()
	mount.name = "HorseMount"
	player.add_child(mount)
	_sync_all()
	return _result(true, "Menunggangi %s.%s Tekan interaksi untuk turun." % [animal.name, note])

func dismount(player: Player, silent: bool = false) -> void:
	if not is_instance_valid(player) or not player.has_meta("riding_horse"):
		return
	var info: Dictionary = player.get_meta("riding_horse")
	player.remove_meta("riding_horse")
	_riders.erase("%d:%d" % [int(info.uid), int(info.id)])
	var mount := player.get_node_or_null("HorseMount")
	if mount != null:
		if not str(mount.last_scene).is_empty():
			horse_spot = {"scene": str(mount.last_scene), "pos": mount.last_position, "flip": player.facing_direction.x < 0}
		if not silent:
			mount.play_dismount()
			# Pemain turun ke samping kuda bila ada ruang.
			var side := Vector2(14, 0) if player.facing_direction.x >= 0 else Vector2(-14, 0)
			if not player.test_move(player.global_transform, side):
				player.global_position += side
		mount.queue_free()
	_sync_all()
	_sync_horse_actors()

func dismount_all() -> void:
	for player in _riders.values():
		dismount(player, true)
	_riders.clear()

func is_ridden(uid: int, id: int) -> bool:
	return is_instance_valid(_riders.get("%d:%d" % [uid, id]))

## Kuda dewasa pertama milik peternakan: {"uid", "id"} atau kosong.
func find_horse() -> Dictionary:
	for record in records:
		if record.item == "barn":
			for animal in coop_state(record).chickens:
				if RanchHusbandry.species(animal) == "horse" and RanchHusbandry.is_adult(animal):
					return {"uid": int(record.uid), "id": int(animal.id)}
	return {}

func _horse_holder(world: Node) -> Node:
	var holder := world.get_node_or_null("YSort")
	return holder if holder != null else world

func _horse_actor(world: Node) -> Node2D:
	if world == null:
		return null
	var actor := _horse_holder(world).get_node_or_null("HorseActor") as Node2D
	return actor if is_instance_valid(actor) and not actor.is_queued_for_deletion() else null

## Menampilkan kuda di area tempat ia ditinggal (atau di depan Barn) untuk setiap dunia yang dibuka pemain.
func _sync_horse_actors() -> void:
	var horse := find_horse()
	var seen := {}
	for node in get_tree().get_nodes_in_group(Combat.PLAYER_GROUP):
		if not node is Player:
			continue
		var world: Node = node.world_root()
		if world == null or seen.has(world):
			continue
		seen[world] = true
		var actor := _horse_actor(world)
		var wanted := not horse.is_empty() and not is_ridden(int(horse.uid), int(horse.id))
		if wanted:
			wanted = world.get_meta("structure_area", "") == "farm" if horse_spot.is_empty() else str(world.scene_file_path) == str(horse_spot.scene)
		if not wanted:
			if actor != null:
				actor.queue_free()
			continue
		if actor != null:
			continue
		var position := Vector2.ZERO
		if horse_spot.is_empty():
			var barn := structure_node(world, int(horse.uid))
			if barn == null:
				continue
			var size := GameState._resolve_item("barn").placement_size
			position = barn.global_position + Vector2(-size.x * 8 - 12, size.y * 8 + 10)
		else:
			position = horse_spot.pos
		actor = load("res://scripts/world/horse_actor.gd").new()
		actor.name = "HorseActor"
		actor.uid = int(horse.uid)
		actor.animal_id = int(horse.id)
		actor.flip = bool(horse_spot.get("flip", false))
		_horse_holder(world).add_child(actor)
		actor.global_position = position

## Cheat debug: bangun kandang gratis di tanah kosong terdekat dari pemain (harus di ladang).
func debug_build(player: Player, item_id: String) -> String:
	if not is_instance_valid(player) or player.world_root().get_meta("structure_area", "") != "farm" or player.base_layer_ground == null:
		return "Pergi ke ladang (Farm) dulu, lalu jalankan cheat ini."
	var ground := player.base_layer_ground
	var origin := ground.local_to_map(ground.to_local(player.global_position + Player.FEET_OFFSET))
	var size := GameState._resolve_item(item_id).placement_size
	for radius in range(2, 25):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var cell := origin + Vector2i(dx, dy) - Vector2i(size.x / 2, size.y)
				if not check_construction(player, item_id, cell).ok:
					continue
				var record := {"uid": _next_uid, "item": item_id, "cell": [cell.x, cell.y], "storage": [], "open": false, "job": {}, "ready": {}}
				if item_id in RANCHES:
					record.livestock = ChickenHusbandry.empty(DayCycle.current_day)
				_next_uid += 1
				records.append(record)
				_sync_all()
				placement_feedback(player, record)
				return "%s dibangun gratis di dekatmu." % GameState._resolve_item(item_id).display_name
	return "Tidak ada tanah kosong yang cukup luas di sekitarmu. Pindah ke area lapang."

## Cheat debug: kuda dewasa gratis di Barn pertama, kenyang dan 4 hati, langsung berdiri di samping pemain.
func debug_spawn_horse(player: Player) -> String:
	var horse := find_horse()
	if horse.is_empty():
		var barn := {}
		for record in records:
			if record.item == "barn":
				barn = record
				break
		if barn.is_empty():
			return "Bangun Kandang Ternak (Barn) dulu; kuda tinggal di sana."
		var state := coop_state(barn)
		if state.chickens.size() >= RanchHusbandry.capacity(state):
			return "Barn penuh."
		var animal: Dictionary = RanchHusbandry.ANIMAL_DEFAULTS.duplicate()
		animal.merge({"id": int(state.next_id), "name": "Kilat", "variant": "bay", "species": "horse", "fed_day": DayCycle.current_day, "pet_day": 0, "affection": 80}, true)
		state.chickens.append(animal)
		state.next_id = int(state.next_id) + 1
		horse = {"uid": int(barn.uid), "id": int(animal.id)}
	var data := RanchHusbandry.animal_by_id(coop_state(record_for(int(horse.uid))), int(horse.id))
	data.fed_day = DayCycle.current_day
	data.sick = false
	if player != null and is_instance_valid(player):
		dismount(player, true)
		var actor := _horse_actor(player.world_root())
		if actor != null:
			actor.queue_free()
		horse_spot = {"scene": str(player.world_root().scene_file_path), "pos": player.global_position + Player.FEET_OFFSET + Vector2(18, 0), "flip": true}
		if player.world_root().has_meta("ranch_uid") or str(player.world_root().scene_file_path).contains("/interior/"):
			horse_spot = {}
	_sync_all()
	_sync_horse_actors.call_deferred()
	return "Kuda %s siap di dekatmu. Dekati lalu tekan interaksi untuk naik." % data.name

func brush_animal(data: PlayerData, uid: int, id: int) -> Dictionary:
	var record := record_for(uid)
	if data == null or not record.get("item") in RANCHES:
		return _result(false, "Kandang tidak tersedia.")
	var animal := RanchHusbandry.animal_by_id(coop_state(record), id)
	if animal.is_empty() or RanchHusbandry.species(animal) in ["chicken", "duck"]:
		return _result(false, "Unggas cukup dielus.")
	if int(animal.brush_day) == DayCycle.current_day:
		return _result(false, "Sudah disikat hari ini.")
	if not data.has_item("animal_brush", 1):
		return _result(false, "Beli Sikat Ternak di toko terlebih dahulu.")
	animal.brush_day = DayCycle.current_day
	animal.affection = mini(100, int(animal.affection) + 1)
	_sync_all()
	Juice.play_sound(&"pickup")
	return _result(true, "%s senang disikat!" % animal.name)

func clean_ranch(data: PlayerData, uid: int) -> Dictionary:
	var record := record_for(uid)
	if data == null or not record.get("item") in RANCHES:
		return _result(false, "Kandang tidak tersedia.")
	var state := coop_state(record)
	if int(state.dirt) == 0:
		return _result(false, "Kandang sudah bersih.")
	if not data.spend_stamina(1):
		return _result(false, "Perlu 1 stamina untuk membersihkan.")
	state.dirt = int(state.dirt) - 1
	_sync_all()
	Juice.play_sound(&"cut")
	return _result(true, "Satu titik kotor dibersihkan. Sisa: %d." % int(state.dirt))

func harvest_animal(data: PlayerData, uid: int, id: int) -> Dictionary:
	var record := record_for(uid)
	if data == null or not record.get("item") in RANCHES:
		return _result(false, "Kandang tidak tersedia.")
	var animal := RanchHusbandry.animal_by_id(coop_state(record), id)
	if animal.is_empty() or str(animal.ready).is_empty():
		return _result(false, "Belum siap dipanen. Penuhi pakan dan tunggu hari terawat.")
	var tool: String = RanchHusbandry.SPECIES[RanchHusbandry.species(animal)].tool
	if not data.has_item(tool, 1):
		return _result(false, "Perlu %s di tas. Tersedia di toko." % GameState._resolve_item(tool).display_name)
	if data.stamina < 1:
		return _result(false, "Perlu 1 stamina untuk panen.")
	var output := str(animal.ready)
	# _store avoids an inventory signal until the shared ready state is committed.
	if data._store(GameState._resolve_item(output), 1) != 0:
		return _result(false, "Tas penuh. Hasil tetap siap di hewan.")
	animal.ready = ""
	data.spend_stamina(1)
	data._changed()
	_sync_all()
	Juice.play_sound(&"harvest")
	return _result(true, "%s dipanen dari %s." % [GameState._resolve_item(output).display_name, animal.name])

func store_hay(data: PlayerData, uid: int, amount: int = 10) -> Dictionary:
	var record := record_for(uid)
	if data == null or not (record.get("item") in RANCHES or record.get("item") == "silo"):
		return _result(false, "Penyimpanan pakan tidak tersedia.")
	var state := coop_state(record) if record.item in RANCHES else record
	var count := mini(mini(maxi(amount, 0), data.get_item_count("hay")), 240 - int(state.get("hay", 0)))
	if count <= 0:
		return _result(false, "Jerami di tas habis atau penyimpanan penuh (240).")
	if not data.remove_item("hay", count):
		return _result(false, "Jerami tidak cukup.")
	state.hay = int(state.get("hay", 0)) + count
	_sync_all()
	return _result(true, "%d jerami disimpan." % count)

func take_hay(data: PlayerData, uid: int, amount: int = 10) -> Dictionary:
	var record := record_for(uid)
	if data == null or not (record.get("item") in RANCHES or record.get("item") == "silo"):
		return _result(false, "Penyimpanan tidak tersedia.")
	var state := coop_state(record) if record.item in RANCHES else record
	var count := mini(maxi(amount, 0), int(state.get("hay", 0)))
	var moved := count - data._store(GameState._resolve_item("hay"), count)
	if moved <= 0:
		return _result(false, "Tas penuh atau stok jerami kosong.")
	state.hay = int(state.get("hay", 0)) - moved
	data._changed()
	_sync_all()
	return _result(true, "%d jerami diambil." % moved)

func harvest_hay() -> bool:
	for record in records:
		if record.item == "silo" and int(record.get("hay", 0)) < 240:
			record.hay = int(record.get("hay", 0)) + 1
			_sync_all()
			return true
	return false

func feed_stored(uid: int) -> Dictionary:
	var record := record_for(uid)
	if not record.get("item") in RANCHES:
		return _result(false, "Kandang tidak tersedia.")
	var count := RanchHusbandry.feed_from_hay(coop_state(record), DayCycle.current_day)
	_sync_all()
	return _result(count > 0, "%d hewan makan dari cadangan kandang." % count)

func upgrade_ranch(data: PlayerData, uid: int) -> Dictionary:
	var record := record_for(uid)
	if data == null or not record.get("item") in RANCHES:
		return _result(false, "Kandang tidak tersedia.")
	var state := coop_state(record)
	if int(state.tier) >= 2:
		return _result(false, "Kandang sudah Deluxe.")
	var cost := 4000 if int(state.tier) == 0 else 8000
	var wood := 150 if int(state.tier) == 0 else 250
	var stone := 100 if int(state.tier) == 0 else 150
	if GameState.money < cost or not data.has_item("wood", wood) or not data.has_item("stone", stone):
		return _result(false, "Perlu %d G, %d kayu, %d batu." % [cost, wood, stone])
	data.remove_item("wood", wood)
	data.remove_item("stone", stone)
	GameState.spend_money(cost)
	state.tier = int(state.tier) + 1
	_sync_all()
	return _result(true, "Kapasitas menjadi %d.%s" % [RanchHusbandry.capacity(state), " Auto-feeder aktif esok pagi." if int(state.tier) == 2 else ""])

func toggle_ranch_door(uid: int) -> Dictionary:
	var record := record_for(uid)
	if not record.get("item") in RANCHES:
		return _result(false, "Kandang tidak tersedia.")
	var state := coop_state(record)
	if state.door:
		state.door = false
	else:
		if not grazing_weather() or DayCycle.hour >= 18 or DayCycle.hour < 6:
			return _result(false, "Merumput hanya saat cerah, pukul 06–18, di luar musim dingin.")
		state.door = true
	_sync_all()
	return _result(true, "Pintu dibuka. Hewan mencari rumput pakan di sekitar kandang." if state.door else "Hewan kembali masuk dengan aman.")

func grazing_weather() -> bool:
	return GameState.weather.current == "sunny" and DayCycle.get_current_season() != "winter"

func _ranch_time(hour: int, _minute: int) -> void:
	if hour < 18 and hour >= 6 and grazing_weather():
		return
	var updated := false
	for record in records:
		if record.item in RANCHES and coop_state(record).door:
			record.livestock.door = false
			updated = true
	if updated:
		_sync_all()

func buy_chicken(uid: int, requested_name: String = "", variant: String = "white") -> Dictionary:
	return buy_animal(uid, "chicken", requested_name, variant)

func feed_chickens(data: PlayerData, uid: int, bird_id: int = -1) -> Dictionary:
	var record := record_for(uid)
	if data == null or not record.get("item") in RANCHES:
		return _result(false, "Kandang tidak tersedia.")
	var state := coop_state(record)
	var hungry: Array[Dictionary] = []
	for bird in state.chickens:
		if int(bird.fed_day) != DayCycle.current_day and (bird_id == -1 or int(bird.id) == bird_id):
			hungry.append(bird)
	if hungry.is_empty():
		return _result(false, "Ayam sudah makan hari ini, atau kandang masih kosong.")
	var feed_id := "animal_feed" if record.item == "chicken_coop" else "hay"
	var from_feed := mini(hungry.size(), data.get_item_count(feed_id))
	var from_hay := hungry.size() - from_feed
	if (feed_id == "hay" and from_hay > 0) or (feed_id != "hay" and data.get_item_count("hay") < from_hay):
		return _result(false, "Butuh %d pakan di tasmu. Unggas menerima pakan ayam atau jerami; ternak besar menerima jerami." % hungry.size())
	if from_feed > 0:
		data.remove_item(feed_id, from_feed)
	if from_hay > 0:
		data.remove_item("hay", from_hay)
	for bird in hungry:
		bird.fed_day = DayCycle.current_day
	_sync_all()
	Juice.play_sound(&"plant")
	return _result(true, "%d hewan diberi pakan. Produksi dievaluasi esok pagi." % hungry.size())

func pet_chicken(uid: int, bird_id: int) -> Dictionary:
	var record := record_for(uid)
	if not record.get("item") in RANCHES:
		return _result(false, "Kandang tidak tersedia.")
	for bird in coop_state(record).chickens:
		if int(bird.id) != bird_id:
			continue
		if int(bird.pet_day) == DayCycle.current_day:
			return _result(false, "%s sudah dielus hari ini." % bird.name)
		bird.pet_day = DayCycle.current_day
		bird.affection = mini(100, int(bird.affection) + 3)
		_sync_all()
		Juice.play_sound(&"pickup")
		return _result(true, "%s senang dielus!" % bird.name)
	return _result(false, "Ayam tidak tersedia.")

func collect_eggs(data: PlayerData, uid: int) -> Dictionary:
	var record := record_for(uid)
	if data == null or not record.get("item") in RANCHES:
		return _result(false, "Kandang tidak tersedia.")
	var state := coop_state(record)
	var total := RanchHusbandry.product_count(state)
	if total <= 0:
		return _result(false, "Belum ada telur. Beri pakan lalu tunggu hari produksi.")
	var left := data._store(GameState._resolve_item("chicken_egg"), int(state.eggs))
	state.eggs = left
	var collected := total - RanchHusbandry.product_count(state)
	for id in state.products.keys():
		var amount := int(state.products[id])
		left = data._store(GameState._resolve_item(id), amount)
		collected += amount - left
		if left == 0:
			state.products.erase(id)
		else:
			state.products[id] = left
	if collected > 0:
		data._changed()
		Juice.play_sound(&"harvest")
	_sync_all()
	return _result(collected > 0, "%d telur diambil; sisa tetap di kandang." % collected if collected > 0 else "Tas penuh. Telur tetap tersimpan di kandang.")

func attach(world: Node) -> void:
	if not is_instance_valid(world) or not world.is_inside_tree():
		return
	world.set_meta("structure_area", "farm")
	var holder := world.get_node_or_null("YSort")
	if holder == null:
		holder = world
	if holder.has_node("CraftedStructures"):
		return
	var view := Node2D.new()
	view.name = "CraftedStructures"
	view.y_sort_enabled = true
	view.set_meta("world", weakref(world))
	holder.add_child(view)
	_views.append(weakref(view))
	_sync_view(view)

func _sync_view(view: Node2D) -> void:
	var world: Node = view.get_meta("world").get_ref()
	var ground := world.get_node_or_null("BaseLayerGround") as TileMapLayer
	if ground == null:
		return
	var live := {}
	for record in records:
		var name := "Structure_%d" % record.uid
		live[name] = true
		var node := view.get_node_or_null(name)
		if node == null:
			if is_furniture(record.item):
				node = load("res://scenes/world/exterior/object/seat.tscn").instantiate()
				node.definition = GameState._resolve_item(record.item).seat_definition
				node.facing = int(record.get("facing", 1))
				node.placement_uid = record.uid
			else:
				node = load("res://scripts/world/placed_structure.gd").new()
				node.uid = record.uid
			node.name = name
			view.add_child(node)
		var item := GameState._resolve_item(record.item)
		var cell := Vector2i(int(record.cell[0]), int(record.cell[1]))
		node.global_position = ground.to_global(ground.map_to_local(cell)) + Vector2(item.placement_size - Vector2i.ONE) * 8
		node.refresh()
		if record.item in RANCHES:
			for animal in coop_state(record).chickens:
				var animal_name := "Animal_%d_%d" % [int(record.uid), int(animal.id)]
				live[animal_name] = true
				var actor := view.get_node_or_null(animal_name)
				if actor == null:
					actor = load("res://scripts/world/ranch_animal.gd").new()
					actor.name = animal_name
					actor.uid = int(record.uid)
					actor.animal_id = int(animal.id)
					actor.home = node.global_position + Vector2(0, item.placement_size.y * 8 + 8)
					view.add_child(actor)
				actor.refresh()
	for node in view.get_children():
		if not live.has(str(node.name)):
			view.remove_child(node)
			node.queue_free()

func _sync_all() -> void:
	for ref in _views:
		var view: Node2D = ref.get_ref()
		if is_instance_valid(view) and view.is_inside_tree():
			_sync_view(view)
	changed.emit()

func record_for(uid: int) -> Dictionary:
	for record in records:
		if record.uid == uid:
			return record
	return {}

func check_construction(player: Player, item_id: String, cell: Vector2i) -> Dictionary:
	if not is_instance_valid(player) or not CONSTRUCTION.has(item_id) or records.size() >= 512:
		return _result(false, "Bangunan tidak tersedia atau batas bangunan tercapai.")
	var world := player.world_root()
	var ground := player.base_layer_ground
	if world == null or world.get_meta("structure_area", "") != "farm" or ground == null:
		return _result(false, "Bangunan ditempatkan di ladang.")
	var item := GameState._resolve_item(item_id)
	var footprint := Rect2i(cell, item.placement_size)
	for existing in records:
		var other := GameState._resolve_item(existing.item)
		if footprint.intersects(Rect2i(Vector2i(int(existing.cell[0]), int(existing.cell[1])), other.placement_size)):
			return _result(false, "Lokasi sudah ditempati bangunan.")
	for x in item.placement_size.x:
		for y in item.placement_size.y:
			var target := cell + Vector2i(x, y)
			var tile := ground.get_cell_tile_data(target)
			if tile == null or not tile.get_custom_data("farmable"):
				return _result(false, "Pilih tanah kosong; air, jalan dan tebing tidak dapat dibangun.")
			if FarmManager.farm_data.has(target) and FarmManager.farm_data[target].get("area", "farm") != "greenhouse":
				return _result(false, "Lahan sudah digarap. Bersihkan dengan sekop dahulu.")
			var shape := RectangleShape2D.new()
			shape.size = Vector2(14, 14)
			var query := PhysicsShapeQueryParameters2D.new()
			query.shape = shape
			query.transform = Transform2D(0, ground.to_global(ground.map_to_local(target)))
			query.exclude = [player.get_rid()]
			query.collide_with_areas = true
			query.collide_with_bodies = true
			query.collision_mask = 0xFFFFFFFF
			if not player.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
				return _result(false, "Lokasi terhalang pohon, batu, objek atau pemain lain.")
	var entrance := cell + Vector2i(item.placement_size.x / 2, item.placement_size.y)
	var doorway := ground.get_cell_tile_data(entrance)
	if doorway == null or not doorway.get_custom_data("farmable") or occupies(entrance):
		return _result(false, "Sisakan tanah kosong yang bisa dilewati di depan pintu.")
	var door_shape := RectangleShape2D.new()
	door_shape.size = Vector2(14, 14)
	var door_query := PhysicsShapeQueryParameters2D.new()
	door_query.shape = door_shape
	door_query.transform = Transform2D(0, ground.to_global(ground.map_to_local(entrance)))
	door_query.exclude = [player.get_rid()]
	door_query.collide_with_areas = true
	if not player.get_world_2d().direct_space_state.intersect_shape(door_query, 1).is_empty():
		return _result(false, "Pintu bangunan harus memiliki jalan masuk yang bebas.")
	return _result(true, "Lokasi tersedia. Konfirmasi untuk membangun.")

func commit_construction(player: Player, item_id: String, cell: Vector2i, from_inventory: bool) -> Dictionary:
	var result := check_construction(player, item_id, cell)
	if not result.ok:
		return result
	var data := player.data
	if from_inventory:
		if not data.remove_item(item_id, 1):
			return _result(false, "Bangunan sudah tidak ada di tas.")
	else:
		var quote: Dictionary = CONSTRUCTION[item_id]
		if GameState.money < int(quote.money):
			return _result(false, "Uang untuk pembangunan tidak cukup.")
		for id in quote.materials:
			if not data.has_item(id, int(quote.materials[id])):
				return _result(false, "Bahan pembangunan di tasmu belum lengkap.")
		for id in quote.materials:
			data.remove_item(id, int(quote.materials[id]))
		GameState.spend_money(int(quote.money))
	var record := {"uid": _next_uid, "item": item_id, "cell": [cell.x, cell.y], "storage": [], "open": false, "job": {}, "ready": {}}
	if item_id in RANCHES:
		record.livestock = ChickenHusbandry.empty(DayCycle.current_day)
	_next_uid += 1
	records.append(record)
	_sync_all()
	placement_feedback(player, record)
	return _result(true, "%s dibangun!" % GameState._resolve_item(item_id).display_name)

func place(player: Player, slot: int, cell: Vector2i, facing: int = 1) -> Dictionary:
	if records.size() >= 512:
		return _result(false, "Batas bangunan farm tercapai (512).")
	if not is_instance_valid(player) or slot < 0 or slot >= player.data.bag_size:
		return _result(false, "Slot tidak valid.")
	var entry: Variant = player.data.inventory[slot]
	if entry == null or not (entry["item"].item_id in IDS or is_furniture(entry["item"].item_id)):
		return _result(false, "Pilih bangunan dari hotbar.")
	if is_furniture(entry["item"].item_id):
		return _place_furniture(player, slot, cell, facing)
	var world := player.world_root()
	if world.get_meta("structure_area", "") != "farm":
		return _result(false, "Bangunan hanya dapat dipasang di farm.")
	var ground := player.base_layer_ground
	if ground == null or (player.global_position + Player.FEET_OFFSET).distance_to(ground.to_global(ground.map_to_local(cell))) > 36:
		return _result(false, "Lokasi terlalu jauh.")
	var item: ItemData = entry["item"]
	var footprint := Rect2i(cell, item.placement_size)
	for existing in records:
		var existing_item := GameState._resolve_item(existing.item)
		if footprint.intersects(Rect2i(Vector2i(int(existing.cell[0]), int(existing.cell[1])), existing_item.placement_size)):
			return _result(false, "Lokasi sudah ditempati bangunan.")
	for x in item.placement_size.x:
		for y in item.placement_size.y:
			var target := cell + Vector2i(x, y)
			var tile := ground.get_cell_tile_data(target)
			if tile == null or not tile.get_custom_data("farmable") or FarmManager.farm_data.has(target):
				return _result(false, "Pilih tanah kosong, bukan air atau lahan yang dicangkul.")
			var shape := RectangleShape2D.new()
			shape.size = Vector2(14, 14)
			var query := PhysicsShapeQueryParameters2D.new()
			query.shape = shape
			query.transform = Transform2D(0, ground.to_global(ground.map_to_local(target)))
			query.collide_with_areas = true
			query.collide_with_bodies = true
			query.collision_mask = 0xFFFFFFFF
			if not player.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
				return _result(false, "Lokasi terhalang objek atau pemain.")
	var record := {"uid": _next_uid, "item": item.item_id, "cell": [cell.x, cell.y], "storage": [], "open": false, "job": {}, "ready": {}}
	if item.item_id in RANCHES:
		record.livestock = ChickenHusbandry.empty(DayCycle.current_day)
	if item.item_id == "beehive":
		record.job = {"day": DayCycle.current_day + BEEHIVE_DAYS}
	_next_uid += 1
	records.append(record)
	player.data.remove_item_at(slot, 1)
	_sync_all()
	player.bind_context()
	placement_feedback(player, record)
	player.play_item_gesture()
	return _result(true, "%s dipasang. Interaksi untuk menggunakannya." % item.display_name)

func placement_feedback(player: Player, record: Dictionary) -> void:
	var item := GameState._resolve_item(record.item)
	var cell := Vector2i(int(record.cell[0]), int(record.cell[1]))
	var center := player.base_layer_ground.to_global(player.base_layer_ground.map_to_local(cell)) + Vector2(item.placement_size - Vector2i.ONE) * 8
	player.bind_context()
	Juice.play(&"building_place", center)
	for x in [0, maxi(0, item.placement_size.x - 1)]:
		Juice.play(&"sparkle", player.base_layer_ground.to_global(player.base_layer_ground.map_to_local(cell + Vector2i(x, item.placement_size.y - 1))))

func interact_near(player: Player) -> bool:
	var world := player.world_root()
	if world != null and world.has_method("interact_ranch_near"):
		return world.interact_ranch_near(player)
	if player.world_root().get_meta("structure_area", "") != "farm" or player.base_layer_ground == null:
		return false
	for actor in get_tree().get_nodes_in_group(&"horse_actor"):
		if actor.get_world_2d() == player.get_world_2d() and actor.global_position.distance_to(player.global_position + Player.FEET_OFFSET) < 22:
			actor.interact(player)
			return true
	for actor in get_tree().get_nodes_in_group(&"ranch_animal"):
		if actor.visible and actor.get_world_2d() == player.get_world_2d() and actor.global_position.distance_to(player.global_position + Player.FEET_OFFSET) < 22:
			actor.interact_with(player)
			return true
	var selected := closest_structure(player)
	if selected.is_empty():
		return false
	if is_furniture(selected.item):
		var seat := furniture_node(player.world_root(), int(selected.uid))
		if seat != null:
			seat.interact(player)
			return true
		return false
	if selected.item in RANCHES:
		enter_ranch(player, int(selected.uid))
		return true
	if is_processing_machine(str(selected.item)):
		return interact_machine(player, int(selected.uid))
	var menu = load("res://scenes/ui/chest_ui.tscn").instantiate() if selected.item in CHESTS else load("res://scripts/ui/structure_menu.gd").new()
	menu.player = player
	menu.uid = selected.uid
	_menus[player.data.index] = menu
	Coop.ui_parent(player).add_child(menu)
	return true

func interact_with(player: Node, uid: int) -> bool:
	var record := record_for(uid)
	if record.is_empty():
		return false
	if is_furniture(record.item):
		var world = player.world_root() if player != null and player.has_method("world_root") else null
		var seat := furniture_node(world, uid)
		if seat != null:
			seat.interact(player)
			return true
		return false
	if record.item in RANCHES:
		enter_ranch(player, uid)
		return true
	if is_processing_machine(str(record.item)):
		return interact_machine(player, uid)
	var menu = load("res://scenes/ui/chest_ui.tscn").instantiate() if record.item in CHESTS else load("res://scripts/ui/structure_menu.gd").new()
	menu.player = player
	menu.uid = uid
	var p_data = player.get("data")
	var idx: int = p_data.index if p_data != null and "index" in p_data else 0
	_menus[idx] = menu
	Coop.ui_parent(player).add_child(menu)
	return true

func interact_machine(player: Node, uid: int) -> bool:
	var record := record_for(uid)
	if record.is_empty() or not is_processing_machine(str(record.item)):
		return false
	
	var data: PlayerData = player.get("data") if is_instance_valid(player) and player.get("data") is PlayerData else GameState.current
	var world = player.world_root() if is_instance_valid(player) and player.has_method("world_root") else null
	var placed := structure_node(world, uid) if world != null else null
	var machine_item := GameState._resolve_item(str(record.item))
	var machine_name := machine_item.display_name if machine_item != null else str(record.item)

	# 1. HAS READY PRODUCT -> COLLECT DIRECTLY (Stardew style!)
	if not record.ready.is_empty():
		var ready_id := str(record.ready.get("id", ""))
		var ready_count := int(record.ready.get("count", 1))
		var item := GameState._resolve_item(ready_id)
		var item_name := item.display_name if item != null else ready_id
		var res := collect(data, uid)
		if res.ok:
			if placed != null and placed.has_method("bounce_harvest"):
				placed.bounce_harvest()
			Juice.play_sound(&"harvest")
			Notify.say("Mengambil %s x%d!" % [item_name, ready_count])
			return true
		else:
			Notify.say(res.message)
			return true

	# 2. CURRENTLY PROCESSING -> WOBBLE / NOTIFY
	if not record.job.is_empty() and record.item != "beehive":
		if placed != null and placed.has_method("wobble_busy"):
			placed.wobble_busy()
		var secs := int(ceil(float(record.job.get("seconds", 0.0))))
		Notify.say("%s sedang memproses... (%d detik lagi)" % [machine_name, secs])
		return true

	# 3. BEEHIVE & LIGHTNING ROD PASSIVE LOGIC
	if record.item == "beehive":
		var days_left := maxi(0, int(record.job.get("day", DayCycle.current_day)) - DayCycle.current_day)
		Notify.say("Sarang lebah sedang memproduksi madu (%d hari lagi)." % days_left)
		return true
	if record.item == "lightning_rod":
		Notify.say("Penangkal petir siap menyerap kilat saat badai petir.")
		return true

	# 4. IDLE MACHINE -> CHECK HELD ITEM!
	var tool_ctrl = player.get("tool_controller") if is_instance_valid(player) else null
	var held: ItemData = tool_ctrl.get("current_item") if tool_ctrl != null and tool_ctrl.get("current_item") is ItemData else null

	# If holding Axe or Pickaxe on an empty machine -> PACK IT!
	var tool_data: ToolData = held.action_data.tool_data if held != null and held.action_data != null and held.action_data.tool_data != null else null
	if tool_data != null and (tool_data.tool_type == ToolData.ToolType.AXE or tool_data.tool_type == ToolData.ToolType.PICKAXE):
		var pack_res := pack(data, uid)
		if pack_res.ok:
			Juice.play_sound(&"hit")
			Notify.say("Mengemas kembali %s." % machine_name)
			return true

	# If empty hand -> notify what to do!
	if held == null:
		if placed != null and placed.has_method("wobble_reject"):
			placed.wobble_reject()
		Notify.say("%s siap digunakan. Pegang bahan di hotbar untuk mengolah." % machine_name)
		return true

	var held_id := held.item_id
	var job_started := false
	var product_name := ""

	# Check machine recipes:
	if record.item in ARTISANS:
		var out_id := artisan_output(str(record.item), held_id)
		if not out_id.is_empty():
			var res := process_animal_product(data, uid, held_id)
			if res.ok:
				job_started = true
				product_name = GameState._resolve_item(out_id).display_name if GameState._resolve_item(out_id) != null else out_id
	elif record.item == "preserves_jar":
		for recipe in preserves_jar_recipes():
			if recipe.input_item_id == held_id or held_id.begins_with(recipe.input_item_id):
				if data.get_item_count(held_id) >= recipe.input_amount:
					var res := preserve(data, uid, recipe)
					if res.ok:
						job_started = true
						product_name = GameState._resolve_item(recipe.output_item_id).display_name
						break
				else:
					Notify.say("Butuh %d %s untuk Preserves Jar." % [recipe.input_amount, held.display_name])
					return true
	elif record.item == "dehydrator":
		for recipe in dehydrator_recipes():
			if recipe.input_item_id == held_id or held_id.begins_with(recipe.input_item_id):
				if data.get_item_count(held_id) >= recipe.input_amount:
					var res := dehydrate(data, uid, recipe)
					if res.ok:
						job_started = true
						product_name = GameState._resolve_item(recipe.output_item_id).display_name
						break
				else:
					Notify.say("Butuh %d %s untuk Dehydrator." % [recipe.input_amount, held.display_name])
					return true
	elif record.item == "furnace":
		for recipe in furnace_recipes():
			if recipe.input_item_id == held_id:
				if data.get_item_count(held_id) >= recipe.input_amount:
					var res := smelt(data, uid, recipe)
					if res.ok:
						job_started = true
						product_name = GameState._resolve_item(recipe.output_item_id).display_name
						break
				else:
					Notify.say("Butuh %d %s untuk melebur di Furnace." % [recipe.input_amount, held.display_name])
					return true
	elif record.item == "sawmill":
		for recipe in sawmill_recipes():
			if recipe.input_item_id == held_id:
				if data.get_item_count(held_id) >= recipe.input_amount:
					var res := saw(data, uid, recipe)
					if res.ok:
						job_started = true
						product_name = GameState._resolve_item(recipe.output_item_id).display_name
						break
				else:
					Notify.say("Butuh %d %s untuk diproses di Sawmill." % [recipe.input_amount, held.display_name])
					return true

	if job_started:
		if placed != null and placed.has_method("bounce_insert"):
			placed.bounce_insert()
		Juice.sfx(load("res://assets/audio/sfx/machines/machine_start.wav"), -3.0, 0.08)
		Notify.say("Memasukkan %s ke %s..." % [held.display_name, machine_name])
		if is_instance_valid(player) and player.has_method("_sync_carried_item"):
			player._sync_carried_item()
		return true
	else:
		if placed != null and placed.has_method("wobble_reject"):
			placed.wobble_reject()
		Notify.say("%s tidak dapat diolah di %s." % [held.display_name, machine_name])
		return true

func closest_structure(player: Player) -> Dictionary:
	if not is_instance_valid(player):
		return {}
	var world := player.world_root()
	var ground := player.base_layer_ground
	# Records menyimpan struktur farm; interior/transisi bisa tidak memiliki ground.
	if not is_instance_valid(world) or world.get_meta("structure_area", "") != "farm" or not is_instance_valid(ground):
		return {}
	var feet := player.global_position + Player.FEET_OFFSET
	var nearest := 33.0
	var selected := {}
	for record in records:
		var item := GameState._resolve_item(record.item)
		var center := ground.to_global(ground.map_to_local(Vector2i(int(record.cell[0]), int(record.cell[1])))) + Vector2(item.placement_size - Vector2i.ONE) * 8
		var distance := feet.distance_to(center)
		if record.item in CONSTRUCTION:
			center = ground.to_global(ground.map_to_local(Vector2i(int(record.cell[0]), int(record.cell[1])) + Vector2i(item.placement_size.x / 2, item.placement_size.y)))
			distance = feet.distance_to(center)
		if distance < nearest and (center - feet).dot(player.facing_direction) >= -1:
			selected = record
			nearest = distance
	return selected

func enter_ranch(player: Player, uid: int) -> Dictionary:
	var record := record_for(uid)
	if not is_instance_valid(player) or not record.get("item") in RANCHES or player.is_input_locked() or Transition.on_transition:
		return _result(false, "Kandang tidak tersedia atau perpindahan sedang berjalan.")
	var ground := player.base_layer_ground
	if ground == null or player.world_root().get_meta("structure_area", "") != "farm":
		return _result(false, "Masuk melalui pintu kandang di ladang.")
	var item := GameState._resolve_item(record.item)
	var cell := Vector2i(int(record.cell[0]), int(record.cell[1]))
	_ranch_returns[player.data.index] = ground.to_global(ground.map_to_local(cell + Vector2i(item.placement_size.x / 2, item.placement_size.y + 1))) - Player.FEET_OFFSET
	solo_ranch_uid = uid
	var path := "res://scenes/world/interior/%s_interior.tscn" % ("coop" if record.item == "chicken_coop" else "barn")
	if Coop.has_root():
		path += "#ranch=%d" % uid
	GameState.next_spawn_position = Vector2(427, 320)
	GameState.has_spawn_point = true
	Transition.scene_transition.call_deferred(path, player)
	return _result(true, "Masuk kandang.")

func leave_ranch(player: Player) -> void:
	GameState.next_spawn_position = _ranch_returns.get(player.data.index, Vector2(600, 300))
	GameState.has_spawn_point = true
	Transition.scene_transition.call_deferred("res://scenes/world/farm.tscn", player)

func open_ranch_menu(player: Player, uid: int) -> void:
	var record := record_for(uid)
	if not is_instance_valid(player) or not record.get("item") in RANCHES:
		return
	if has_menu(player.data.index):
		return
	var menu = load("res://scripts/ui/chicken_coop_menu.gd").new()
	menu.player = player
	menu.uid = uid
	_menus[player.data.index] = menu
	Coop.ui_parent(player).add_child(menu)

func has_menu(index: int) -> bool:
	var menu: Variant = _menus.get(index)
	return is_instance_valid(menu) and menu.visible

func occupies(cell: Vector2i) -> bool:
	for record in records:
		var item := GameState._resolve_item(record.item)
		if Rect2i(Vector2i(int(record.cell[0]), int(record.cell[1])), item.placement_size).has_point(cell):
			return true
	return false

func storage(record: Dictionary) -> PlayerData:
	var data := PlayerData.new(-1)
	data.configure_storage(chest_capacity(record))
	data.load_inventory(record.get("storage", []))
	return data

func chest_capacity(record: Dictionary) -> int:
	if not record.get("item", "") in CHESTS:
		return 0
	return GameState._resolve_item(record.item).storage_slots

func next_chest_recipe(uid: int) -> CraftingRecipe:
	var tier := CHESTS.find(record_for(uid).get("item", ""))
	if tier < 0 or tier >= CHESTS.size() - 1:
		return null
	for recipe in CraftingSystem.CATALOG.recipes:
		if recipe.output_item_id == CHESTS[tier + 1]:
			return recipe
	return null

## Upgrade in place: no output slot needed, no chest contents consumed.
func upgrade_chest(data: PlayerData, uid: int) -> Dictionary:
	var recipe := next_chest_recipe(uid)
	if recipe == null:
		return _result(false, "Peti sudah mencapai tier tertinggi atau tidak tersedia.")
	for id in recipe.ingredients:
		if not data.has_item(id, recipe.ingredients[id]):
			return _result(false, "Bahan upgrade kurang: %s." % GameState._resolve_item(id).display_name)
	var slots := data.inventory.duplicate(true)
	for id in recipe.ingredients:
		var remaining: int = recipe.ingredients[id]
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
	var record := record_for(uid)
	record.item = recipe.output_item_id
	data.inventory = slots
	_sync_all()
	data._changed()
	return _result(true, "Peti ditingkatkan: %s (%d slot)." % [GameState._resolve_item(record.item).display_name, chest_capacity(record)])

func transfer(data: PlayerData, uid: int, slot: int, deposit: bool) -> Dictionary:
	var record := record_for(uid)
	if record.is_empty() or not record.item in CHESTS:
		return _result(false, "Peti tidak tersedia.")
	var chest := storage(record)
	var source := data if deposit else chest
	var target := chest if deposit else data
	if slot < 0 or slot >= source.bag_size or source.inventory[slot] == null:
		return _result(false, "Slot kosong.")
	var item: ItemData = source.inventory[slot]["item"]
	var count: int = source.inventory[slot]["count"]
	var moved := count - target._store(item, count)
	if moved == 0:
		return _result(false, "Peti penuh." if deposit else "Tas penuh.")
	source.inventory[slot]["count"] -= moved
	if source.inventory[slot]["count"] == 0:
		source.inventory[slot] = null
	record.storage = chest.serialize_inventory()
	data._changed()
	changed.emit()
	return _result(true, "%s x%d %s." % [item.display_name, moved, "disimpan" if deposit else "diambil"])

func pack(data: PlayerData, uid: int) -> Dictionary:
	var record := record_for(uid)
	if record.is_empty():
		return _result(false, "Bangunan tidak tersedia.")
	for candidate in get_tree().get_nodes_in_group("player"):
		if candidate is Player and candidate.world_root() != null and candidate.world_root().get_meta("ranch_uid", 0) == uid:
			return _result(false, "Pemain masih berada di dalam kandang. Keluar dahulu sebelum mengemas.")
	if record.item in RANCHES:
		var state := coop_state(record)
		if not state.chickens.is_empty() or RanchHusbandry.product_count(state) > 0 or int(state.hay) > 0:
			return _result(false, "Kandang berisi ayam atau telur tidak dapat dikemas.")
	if record.item == "silo" and int(record.get("hay", 0)) > 0:
		return _result(false, "Silo berisi jerami tidak dapat dikemas.")
	if record.item == "pasture_grass" and int(record.get("regrow_day", 0)) > DayCycle.current_day:
		return _result(false, "Tunggu rumput tumbuh kembali sebelum dikemas.")
	if not record.storage.is_empty() or (not record.job.is_empty() and record.item != "beehive") or not record.ready.is_empty():
		return _result(false, "Kosongkan peti atau ambil hasil furnace terlebih dahulu.")
	if data.add_item(record.item, 1) > 0:
		return _result(false, "Tas penuh. Bangunan tetap terpasang.")
	records.erase(record)
	_sync_all()
	return _result(true, "Bangunan dikemas ke tas.")

func toggle_gate(uid: int) -> void:
	var record := record_for(uid)
	if record.get("item") == "wooden_gate":
		record.open = not record.open
		_sync_all()

func furnace_recipes() -> Array[FurnaceRecipe]:
	if _recipes.is_empty():
		for file in DirAccess.get_files_at("res://resources/furnace"):
			var resource_name := file.trim_suffix(".remap")
			if resource_name.ends_with(".tres"):
				var recipe: Resource = load("res://resources/furnace/" + resource_name)
				if recipe is FurnaceRecipe and not _recipes.has(recipe):
					_recipes.append(recipe)
	return _recipes

func smelt(data: PlayerData, uid: int, recipe: FurnaceRecipe) -> Dictionary:
	var record := record_for(uid)
	if data == null or record.is_empty() or record.item != "furnace" or not furnace_recipes().has(recipe):
		return _result(false, "Furnace atau resep tidak tersedia.")
	if not record.job.is_empty() or not record.ready.is_empty():
		return _result(false, "Tunggu proses selesai dan ambil hasilnya.")
	if not data.remove_item(recipe.input_item_id, recipe.input_amount):
		return _result(false, "Bijih tidak cukup.")
	record.job = {"recipe": recipe.recipe_id, "seconds": recipe.process_time}
	Juice.sfx(load("res://assets/audio/sfx/machines/machine_start.wav"), -6.0)
	changed.emit()
	return _result(true, "Peleburan dimulai.")

func sawmill_recipes() -> Array[FurnaceRecipe]:
	if _sawmill_recipes.is_empty():
		for file in DirAccess.get_files_at("res://resources/sawmill"):
			var resource_name := file.trim_suffix(".remap")
			if resource_name.ends_with(".tres"):
				var recipe: Resource = load("res://resources/sawmill/" + resource_name)
				if recipe is FurnaceRecipe and not _sawmill_recipes.has(recipe):
					_sawmill_recipes.append(recipe)
	return _sawmill_recipes

func saw(data: PlayerData, uid: int, recipe: FurnaceRecipe) -> Dictionary:
	var record := record_for(uid)
	if data == null or record.is_empty() or record.item != "sawmill" or not sawmill_recipes().has(recipe):
		return _result(false, "Penggergajian atau resep tidak tersedia.")
	if not record.job.is_empty() or not record.ready.is_empty():
		return _result(false, "Tunggu proses selesai dan ambil hasilnya.")
	if not data.remove_item(recipe.input_item_id, recipe.input_amount):
		return _result(false, "Kayu tidak cukup.")
	record.job = {"recipe": recipe.recipe_id, "seconds": recipe.process_time}
	Juice.sfx(load("res://assets/audio/sfx/machines/machine_start.wav"), -6.0)
	changed.emit()
	return _result(true, "Penggergajian dimulai.")

func preserves_jar_recipes() -> Array[PreservesJarRecipe]:
	if _preserves_recipes.is_empty():
		for file in DirAccess.get_files_at("res://resources/preserves_jar"):
			var resource_name := file.trim_suffix(".remap")
			if resource_name.ends_with(".tres"):
				var recipe: Resource = load("res://resources/preserves_jar/" + resource_name)
				if recipe is PreservesJarRecipe and not _preserves_recipes.has(recipe):
					_preserves_recipes.append(recipe)
	return _preserves_recipes

func preserve(data: PlayerData, uid: int, recipe: PreservesJarRecipe) -> Dictionary:
	var record := record_for(uid)
	if data == null or record.is_empty() or record.item != "preserves_jar" or not preserves_jar_recipes().has(recipe):
		return _result(false, "Preserves Jar atau resep tidak tersedia.")
	if not record.job.is_empty() or not record.ready.is_empty():
		return _result(false, "Tunggu proses selesai dan ambil hasilnya.")
	if not data.remove_item(recipe.input_item_id, recipe.input_amount):
		return _result(false, "Bahan hasil panen tidak cukup.")
	record.job = {"recipe": recipe.recipe_id, "seconds": recipe.process_time}
	Juice.sfx(load("res://assets/audio/sfx/machines/machine_start.wav"), -6.0)
	changed.emit()
	return _result(true, "Pengolahan dimulai.")

func dehydrator_recipes() -> Array[DehydratorRecipe]:
	if _dehydrator_recipes.is_empty():
		for file in DirAccess.get_files_at("res://resources/dehydrator"):
			var resource_name := file.trim_suffix(".remap")
			if resource_name.ends_with(".tres"):
				var recipe: Resource = load("res://resources/dehydrator/" + resource_name)
				if recipe is DehydratorRecipe and not _dehydrator_recipes.has(recipe):
					_dehydrator_recipes.append(recipe)
	return _dehydrator_recipes

func dehydrate(data: PlayerData, uid: int, recipe: DehydratorRecipe) -> Dictionary:
	var record := record_for(uid)
	if data == null or record.is_empty() or record.item != "dehydrator" or not dehydrator_recipes().has(recipe):
		return _result(false, "Dehydrator atau resep tidak tersedia.")
	if not record.job.is_empty() or not record.ready.is_empty():
		return _result(false, "Tunggu proses selesai dan ambil hasilnya.")
	if not data.remove_item(recipe.input_item_id, recipe.input_amount):
		return _result(false, "Bahan hasil panen tidak cukup.")
	record.job = {"recipe": recipe.recipe_id, "seconds": recipe.process_time}
	Juice.sfx(load("res://assets/audio/sfx/machines/machine_start.wav"), -6.0)
	changed.emit()
	return _result(true, "Proses dehidrasi dimulai.")

func collect(data: PlayerData, uid: int) -> Dictionary:
	var record := record_for(uid)
	if data == null or record.is_empty() or record.ready.is_empty():
		return _result(false, "Belum ada hasil.")
	var item := GameState._resolve_item(record.ready.id)
	var count: int = record.ready.count
	var left := data._store(item, count)
	if left == 0:
		var extra: Variant = record.ready.get("extra", {})
		record.ready = {}
		if extra is Dictionary and extra.get("id") is String and ResourceLoader.exists("res://resources/item_data/%s.tres" % extra.id):
			var extra_left := data._store(GameState._resolve_item(extra.id), int(extra.get("count", 1)))
			if extra_left > 0:
				record.ready = {"id": extra.id, "count": extra_left}
		if record.item == "beehive" and record.ready.is_empty():
			record.job = {"day": DayCycle.current_day + BEEHIVE_DAYS}
	else:
		record.ready.count = left
	if left < count:
		data._changed()
	changed.emit()
	return _result(left < count, "Hasil diambil." if left < count else "Tas penuh. Hasil tetap di mesin.")

func artisan_output(machine: String, input: String) -> String:
	if not ARTISANS.has(machine):
		return ""
	if machine == "fish_smoker":
		# Resolve input utuh: memotong akhiran dulu memicu error untuk item seperti sword_gold.
		var item := GameState._resolve_item(input)
		if item != null and item.category == ItemData.Category.FISH:
			var qual := ""
			if input.ends_with("_gold"): qual = "_gold"
			elif input.ends_with("_silver"): qual = "_silver"
			return "smoked_fish" + qual
		# Entri tabel fish_smoker hanya untuk validasi hasil di save; ikan asap bukan bahan.
		return ""
	for base in ARTISANS[machine]:
		if RanchHusbandry.valid_product(input, base):
			return str(ARTISANS[machine][base]) + input.trim_prefix(base)
	return ""

func artisan_options(data: PlayerData, machine: String) -> Array[String]:
	var result: Array[String] = []
	for slot in data.bag_size:
		if data.inventory[slot] == null:
			continue
		var id: String = data.inventory[slot].item.item_id
		if not artisan_output(machine, id).is_empty() and not id in result:
			result.append(id)
	return result

func process_animal_product(data: PlayerData, uid: int, input: String) -> Dictionary:
	var record := record_for(uid)
	var output := artisan_output(str(record.get("item", "")), input)
	if data == null or output.is_empty():
		return _result(false, "Bahan atau mesin tidak sesuai.")
	if not record.job.is_empty() or not record.ready.is_empty():
		return _result(false, "Tunggu proses selesai dan ambil hasilnya dahulu.")
	if not data.remove_item(input, 1):
		return _result(false, "Bahan tidak tersedia di tasmu.")
	record.job = {"input": input, "seconds": ARTISAN_SECONDS}
	_sync_all()
	Juice.sfx(load("res://assets/audio/sfx/machines/machine_start.wav"), -6.0)
	return _result(true, "Mengolah %s. Siap dalam 20 detik permainan aktif." % GameState._resolve_item(input).display_name)

func _process(delta: float) -> void:
	_horse_scan -= delta
	if _horse_scan <= 0.0:
		_horse_scan = 0.3
		_sync_horse_actors()
	if not DayCycle.is_running:
		return
	for record in records:
		if record.job.is_empty() or record.item == "beehive":
			continue
		record.job.seconds -= delta
		if record.job.seconds > 0:
			continue
		if record.item == "furnace":
			for recipe in furnace_recipes():
				if recipe.recipe_id == record.job.recipe:
					record.ready = {"id": recipe.output_item_id, "count": recipe.output_amount}
					break
		elif record.item == "preserves_jar":
			for recipe in preserves_jar_recipes():
				if recipe.recipe_id == record.job.recipe:
					record.ready = {"id": recipe.output_item_id, "count": recipe.output_amount}
					break
		elif record.item == "dehydrator":
			for recipe in dehydrator_recipes():
				if recipe.recipe_id == record.job.recipe:
					record.ready = {"id": recipe.output_item_id, "count": recipe.output_amount}
					break
		elif record.item == "sawmill":
			for recipe in sawmill_recipes():
				if recipe.recipe_id == record.job.recipe:
					record.ready = {"id": recipe.output_item_id, "count": recipe.output_amount}
					break
		elif record.item in ARTISANS:
			var in_id := str(record.job.get("input", ""))
			var output := artisan_output(str(record.item), in_id)
			if not output.is_empty():
				record.ready = {"id": output, "count": 1}
		record.job = {}
		changed.emit()

func to_save() -> Array:
	return records.duplicate(true)

func reset() -> void:
	records.clear()
	_next_uid = 1
	_sync_all()

func load_save(saved: Variant) -> void:
	records.clear()
	_next_uid = 1
	if saved is Array:
		for entry in saved.slice(0, 512):
			if not entry is Dictionary or not entry.get("item", "") is String:
				continue
			if not (entry.item in IDS or is_furniture(entry.item)):
				continue
			var cell: Variant = entry.get("cell", [])
			if not cell is Array or cell.size() != 2 or not _integer(cell[0]) or not _integer(cell[1]) or absi(int(cell[0])) > 4096 or absi(int(cell[1])) > 4096:
				continue
			var item := GameState._resolve_item(entry.item)
			var footprint := Rect2i(Vector2i(int(cell[0]), int(cell[1])), item.placement_size)
			var overlap := false
			for record in records:
				var other := GameState._resolve_item(record.item)
				overlap = overlap or footprint.intersects(Rect2i(Vector2i(int(record.cell[0]), int(record.cell[1])), other.placement_size))
			if overlap:
				continue
			var saved_uid := _next_uid
			if _integer(entry.get("uid")) and entry.uid >= 1 and entry.uid <= 1000000:
				saved_uid = int(entry.uid)
			if not record_for(saved_uid).is_empty():
				continue
			var record := {"uid": saved_uid, "item": entry.item, "cell": [int(cell[0]), int(cell[1])], "storage": [], "open": entry.get("open") == true, "job": {}, "ready": {}}
			if is_furniture(entry.item):
				var direction: Variant = entry.get("facing", 1)
				if not _integer(direction) or int(direction) < 0 or int(direction) > 3:
					continue
				var definition: SeatDefinition = item.seat_definition
				if definition.pose_for(int(direction)) == null:
					continue
				record.facing = int(direction)
			if entry.item in RANCHES:
				var animals: Variant = entry.get("livestock", {})
				if not RanchHusbandry.valid(animals, str(entry.item)):
					continue
				record.livestock = animals.duplicate(true) if not animals.is_empty() else ChickenHusbandry.empty(DayCycle.current_day)
			if entry.item == "silo":
				if not RanchHusbandry.integer(entry.get("hay", 0)) or entry.get("hay", 0) < 0 or entry.get("hay", 0) > 240:
					continue
				record.hay = int(entry.get("hay", 0))
			if entry.item == "pasture_grass":
				if not RanchHusbandry.integer(entry.get("regrow_day", 0)) or entry.get("regrow_day", 0) < 0 or entry.get("regrow_day", 0) > 1000000:
					continue
				record.regrow_day = int(entry.get("regrow_day", 0))
			if entry.item in ARTISANS:
				var job: Variant = entry.get("job", {})
				if job is Dictionary and job.get("input") is String and not artisan_output(str(entry.item), job.input).is_empty() and (job.get("seconds") is float or job.get("seconds") is int) and is_finite(float(job.seconds)):
					record.job = {"input": job.input, "seconds": clampf(float(job.seconds), 0, ARTISAN_SECONDS)}
				var ready: Variant = entry.get("ready", {})
				if ready is Dictionary and ready.get("id") is String and ready.get("count") == 1:
					for base in ARTISANS[entry.item].values():
						if RanchHusbandry.valid_product(ready.id, base):
							record.ready = {"id": ready.id, "count": 1}
				if not record.ready.is_empty():
					record.job = {}
			_next_uid = maxi(_next_uid, saved_uid + 1)
			if entry.item in CHESTS and entry.get("storage", []) is Array:
				var valid: Array = []
				for slot in entry.get("storage", []):
					if slot is Dictionary and slot.get("id") is String and _integer(slot.get("slot")) and slot.slot >= 0 and slot.slot < chest_capacity(record) and _integer(slot.get("count")) and slot.count > 0 and ResourceLoader.exists("res://resources/item_data/%s.tres" % slot.id):
						valid.append(slot)
				record.storage = valid
				record.storage = storage(record).serialize_inventory()
			if entry.item == "furnace":
				var job: Variant = entry.get("job", {})
				var ready: Variant = entry.get("ready", {})
				for recipe in furnace_recipes():
					if job is Dictionary and job.get("recipe") == recipe.recipe_id and (job.get("seconds") is float or job.get("seconds") is int) and is_finite(float(job.seconds)):
						record.job = {"recipe": recipe.recipe_id, "seconds": clampf(float(job.seconds), 0, recipe.process_time)}
					if ready is Dictionary and ready.get("id") == recipe.output_item_id and _integer(ready.get("count")) and ready.count > 0:
						record.ready = {"id": ready.id, "count": mini(ready.count, recipe.output_amount)}
			if entry.item == "preserves_jar":
				var job: Variant = entry.get("job", {})
				var ready: Variant = entry.get("ready", {})
				for recipe in preserves_jar_recipes():
					if job is Dictionary and job.get("recipe") == recipe.recipe_id and (job.get("seconds") is float or job.get("seconds") is int) and is_finite(float(job.seconds)):
						record.job = {"recipe": recipe.recipe_id, "seconds": clampf(float(job.seconds), 0, recipe.process_time)}
					if ready is Dictionary and ready.get("id") == recipe.output_item_id and _integer(ready.get("count")) and ready.count > 0:
						record.ready = {"id": ready.id, "count": mini(ready.count, recipe.output_amount)}
			if entry.item == "dehydrator":
				var job: Variant = entry.get("job", {})
				var ready: Variant = entry.get("ready", {})
				for recipe in dehydrator_recipes():
					if job is Dictionary and job.get("recipe") == recipe.recipe_id and (job.get("seconds") is float or job.get("seconds") is int) and is_finite(float(job.seconds)):
						record.job = {"recipe": recipe.recipe_id, "seconds": clampf(float(job.seconds), 0, recipe.process_time)}
					if ready is Dictionary and ready.get("id") == recipe.output_item_id and _integer(ready.get("count")) and ready.count > 0:
						record.ready = {"id": ready.id, "count": mini(ready.count, recipe.output_amount)}
			if entry.item == "sawmill":
				var job: Variant = entry.get("job", {})
				var ready: Variant = entry.get("ready", {})
				for recipe in sawmill_recipes():
					if job is Dictionary and job.get("recipe") == recipe.recipe_id and (job.get("seconds") is float or job.get("seconds") is int) and is_finite(float(job.seconds)):
						record.job = {"recipe": recipe.recipe_id, "seconds": clampf(float(job.seconds), 0, recipe.process_time)}
					if ready is Dictionary and ready.get("id") == recipe.output_item_id and _integer(ready.get("count")) and ready.count > 0:
						record.ready = {"id": ready.id, "count": mini(ready.count, recipe.output_amount)}
			if entry.item == "beehive":
				var job: Variant = entry.get("job", {})
				var ready: Variant = entry.get("ready", {})
				if job is Dictionary and _integer(job.get("day")) and job.day >= 0 and job.day <= 1000000:
					record.job = {"day": int(job.day)}
				if ready is Dictionary and ready.get("id") in ["honey", "beeswax"] and _integer(ready.get("count")) and ready.count > 0:
					record.ready = {"id": ready.id, "count": mini(int(ready.count), 1)}
					var extra: Variant = ready.get("extra", {})
					if ready.id == "honey" and extra is Dictionary and extra.get("id") == "beeswax" and _integer(extra.get("count")) and extra.count > 0:
						record.ready.extra = {"id": "beeswax", "count": 1}
				if record.job.is_empty() and record.ready.is_empty():
					record.job = {"day": DayCycle.current_day + BEEHIVE_DAYS}
			# Ready output wins over a stale simultaneous job after loading.
			if not record.ready.is_empty():
				record.job = {}
			records.append(record)
	_sync_all()

func is_furniture(item_id: String) -> bool:
	if not item_id.is_valid_identifier() or not ResourceLoader.exists("res://resources/item_data/%s.tres" % item_id):
		return false
	var item := GameState._resolve_item(item_id)
	return item != null and item.placeable and item.seat_definition != null

func structure_node(world: Node, uid: int) -> Node2D:
	for ref in _views:
		var view: Node2D = ref.get_ref()
		if is_instance_valid(view) and (world == null or (view.has_meta("world") and view.get_meta("world").get_ref() == world)):
			return view.get_node_or_null("Structure_%d" % uid)
	return null

func furniture_node(world: Node, uid: int) -> Node2D:
	return structure_node(world, uid)

func check_furniture_placement(player: Player, item: ItemData, cell: Vector2i) -> Dictionary:
	if item == null or not is_furniture(item.item_id) or records.size() >= 512:
		return _result(false, "Furnitur tidak tersedia atau batas objek tercapai.")
	var world := player.world_root()
	var ground := player.base_layer_ground
	if world == null or world.get_meta("structure_area", "") != "farm" or ground == null:
		return _result(false, "Furnitur dapat dipasang di farm.")
	if (player.global_position + Player.FEET_OFFSET).distance_to(ground.to_global(ground.map_to_local(cell))) > 36:
		return _result(false, "Lokasi terlalu jauh.")
	var footprint := Rect2i(cell, item.placement_size)
	for record in records:
		var other := GameState._resolve_item(record.item)
		if footprint.intersects(Rect2i(Vector2i(int(record.cell[0]), int(record.cell[1])), other.placement_size)):
			return _result(false, "Lokasi sudah ditempati objek.")
	for x in item.placement_size.x:
		for y in item.placement_size.y:
			var target := cell + Vector2i(x, y)
			var tile := ground.get_cell_tile_data(target)
			if tile == null or not tile.get_custom_data("farmable") or FarmManager.farm_data.has(target):
				return _result(false, "Pilih tanah kosong, bukan air atau lahan yang dicangkul.")
			var shape := RectangleShape2D.new()
			shape.size = Vector2(14, 14)
			var query := PhysicsShapeQueryParameters2D.new()
			query.shape = shape
			query.transform = Transform2D(0, ground.to_global(ground.map_to_local(target)))
			query.collision_mask = 1
			if not player.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
				return _result(false, "Lokasi terhalang objek atau pemain.")
	return _result(true, "Klik kiri: pasang · R: putar")

func _place_furniture(player: Player, slot: int, cell: Vector2i, facing: int) -> Dictionary:
	var item: ItemData = player.data.inventory[slot]["item"]
	var definition: SeatDefinition = item.seat_definition
	if definition.pose_for(facing) == null:
		return _result(false, "Arah furnitur tidak tersedia.")
	var result := check_furniture_placement(player, item, cell)
	if not result.ok:
		return result
	if not player.data.remove_item_at(slot, 1):
		return _result(false, "Item tidak tersedia.")
	records.append({"uid": _next_uid, "item": item.item_id, "cell": [cell.x, cell.y], "facing": facing, "storage": [], "open": false, "job": {}, "ready": {}})
	_next_uid += 1
	_sync_all()
	placement_feedback(player, records[-1])
	if is_instance_valid(player.tool_controller.furniture_preview):
		player.tool_controller.furniture_preview.finish_placement()
	return _result(true, "%s dipasang. E/klik kanan: duduk · Shift + klik kanan: ambil." % item.display_name)

func pickup_furniture(player: Player, uid: int) -> Dictionary:
	var record := record_for(uid)
	if not is_furniture(str(record.get("item", ""))) or player.is_input_locked():
		return _result(false, "Furnitur tidak tersedia.")
	var seat := furniture_node(player.world_root(), uid)
	if seat == null or seat.get_world_2d() != player.get_world_2d() or player.global_position.distance_to(seat.global_position) > 48:
		return _result(false, "Dekati furnitur terlebih dahulu.")
	if is_instance_valid(seat.occupant):
		return _result(false, "Kursi sedang digunakan.")
	if player.data.add_item(str(record.item), 1) != 0:
		return _result(false, "Tas penuh.")
	records.erase(record)
	_sync_all()
	return _result(true, "Furnitur dikembalikan ke tas.")

func _result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}

func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))

func _advance_lightning_rods() -> void:
	var updated := false
	for record in records:
		if record.item == "lightning_rod" and record.ready.is_empty():
			record.ready = {"id": "battery_pack", "count": 1}
			updated = true
	if updated:
		_sync_all()
