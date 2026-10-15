extends Node
## Shared farm structures. JSON-only records include chest contents and furnace jobs.
signal changed
const PreservesJarRecipe = preload("res://scripts/resources/preserves_jar_recipe.gd")
const DehydratorRecipe = preload("res://scripts/resources/dehydrator_recipe.gd")
const IDS := ["furnace", "wooden_chest", "wooden_fence", "crafting_workbench", "stone_fence", "wooden_gate", "copper_chest", "iron_chest", "gold_chest", "chicken_coop", "preserves_jar", "barn", "dehydrator", "silo", "pasture_grass", "mayonnaise_maker", "cheese_press", "loom"]
const CONSTRUCTION := {
	"chicken_coop": {"money": 2000, "materials": {"wood": 100, "stone": 50}},
	"barn": {"money": 3000, "materials": {"wood": 200, "stone": 100}},
	"silo": {"money": 1200, "materials": {"wood": 50, "stone": 100}},
}
const RANCHES := ["chicken_coop", "barn"]
const ARTISANS := {
	"mayonnaise_maker": {"chicken_egg": "mayonnaise", "duck_egg": "duck_mayonnaise"},
	"cheese_press": {"cow_milk": "cheese", "goat_milk": "goat_cheese"},
	"loom": {"wool": "cloth"},
}
const ARTISAN_SECONDS := 20.0
const CHESTS := ["wooden_chest", "copper_chest", "iron_chest", "gold_chest"]
var records: Array[Dictionary] = []
var _next_uid := 1
var _views: Array[WeakRef] = []
var _menus: Dictionary = {}
var solo_ranch_uid := 0
var _ranch_returns: Dictionary = {}
var _recipes: Array[FurnaceRecipe] = []
var _preserves_recipes: Array[PreservesJarRecipe] = []
var _dehydrator_recipes: Array[DehydratorRecipe] = []

func _ready() -> void:
	DayCycle.day_passed.connect(_advance_chickens)
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
	if not RanchHusbandry.SPECIES.has(species) or not variant in ChickenHusbandry.VARIANTS:
		return _result(false, "Jenis hewan tidak tersedia.")
	var info: Dictionary = RanchHusbandry.SPECIES[species]
	if record.get("item") != info.home:
		return _result(false, "Hewan ini memerlukan kandang yang sesuai.")
	var state := coop_state(record)
	if state.chickens.size() >= RanchHusbandry.capacity(state):
		return _result(false, "Kandang penuh. Tingkatkan kandang terlebih dahulu.")
	if not GameState.spend_money(int(info.price)):
		return _result(false, "Uang tidak cukup: %d G." % int(info.price))
	var animal_name := requested_name.replace("\n", " ").replace("\r", " ").strip_edges().left(16)
	if animal_name.is_empty():
		animal_name = "%s %d" % [info.name, int(state.next_id)]
	state.chickens.append({"id": int(state.next_id), "name": animal_name, "variant": variant, "species": species, "fed_day": 0, "pet_day": 0, "affection": 0, "brush_day": 0, "bad_days": 0, "sick": false, "progress": 0, "ready": ""})
	state.next_id = int(state.next_id) + 1
	_sync_all()
	return _result(true, "%s tiba! Beri pakan, elus, dan jaga kebersihan kandang." % animal_name)

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
			node = load("res://scripts/world/placed_structure.gd").new()
			node.name = name
			node.uid = record.uid
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

func place(player: Player, slot: int, cell: Vector2i) -> Dictionary:
	if records.size() >= 512:
		return _result(false, "Batas bangunan farm tercapai (512).")
	if not is_instance_valid(player) or slot < 0 or slot >= player.data.bag_size:
		return _result(false, "Slot tidak valid.")
	var entry: Variant = player.data.inventory[slot]
	if entry == null or not entry["item"].item_id in IDS:
		return _result(false, "Pilih bangunan dari hotbar.")
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
	for actor in get_tree().get_nodes_in_group(&"ranch_animal"):
		if actor.visible and actor.get_world_2d() == player.get_world_2d() and actor.global_position.distance_to(player.global_position + Player.FEET_OFFSET) < 22:
			actor.interact_with(player)
			return true
	var selected := closest_structure(player)
	if selected.is_empty():
		return false
	if selected.item in RANCHES:
		enter_ranch(player, int(selected.uid))
		return true
	var menu = load("res://scripts/ui/chicken_coop_menu.gd" if selected.item in RANCHES else "res://scripts/ui/structure_menu.gd").new()
	menu.player = player
	menu.uid = selected.uid
	_menus[player.data.index] = menu
	Coop.ui_parent(player).add_child(menu)
	return true

func closest_structure(player: Player) -> Dictionary:
	var feet := player.global_position + Player.FEET_OFFSET
	var nearest := 33.0
	var selected := {}
	for record in records:
		var item := GameState._resolve_item(record.item)
		var center := player.base_layer_ground.to_global(player.base_layer_ground.map_to_local(Vector2i(int(record.cell[0]), int(record.cell[1])))) + Vector2(item.placement_size - Vector2i.ONE) * 8
		var distance := feet.distance_to(center)
		if record.item in CONSTRUCTION:
			center = player.base_layer_ground.to_global(player.base_layer_ground.map_to_local(Vector2i(int(record.cell[0]), int(record.cell[1])) + Vector2i(item.placement_size.x / 2, item.placement_size.y)))
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
	if not record.storage.is_empty() or not record.job.is_empty() or not record.ready.is_empty():
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
		record.ready = {}
	else:
		record.ready.count = left
	if left < count:
		data._changed()
	changed.emit()
	return _result(left < count, "Hasil diambil." if left < count else "Tas penuh. Hasil tetap di mesin.")

func artisan_output(machine: String, input: String) -> String:
	if not ARTISANS.has(machine):
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
	if not DayCycle.is_running:
		return
	for record in records:
		if record.job.is_empty():
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
		elif record.item in ARTISANS:
			var output := artisan_output(str(record.item), str(record.job.input))
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
			if not entry is Dictionary or not entry.get("item", "") in IDS:
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
			# Ready output wins over a stale simultaneous job after loading.
			if not record.ready.is_empty():
				record.job = {}
			records.append(record)
	_sync_all()

func _result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}

func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))
