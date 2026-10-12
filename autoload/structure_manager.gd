extends Node
## Shared farm structures. JSON-only records include chest contents and furnace jobs.
signal changed
const IDS := ["furnace", "wooden_chest", "wooden_fence", "crafting_workbench", "stone_fence", "wooden_gate", "copper_chest", "iron_chest", "gold_chest"]
const CHESTS := ["wooden_chest", "copper_chest", "iron_chest", "gold_chest"]
var records: Array[Dictionary] = []
var _next_uid := 1
var _views: Array[WeakRef] = []
var _menus: Dictionary = {}
var _recipes: Array[FurnaceRecipe] = []

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
	_next_uid += 1
	records.append(record)
	player.data.remove_item_at(slot, 1)
	_sync_all()
	player.bind_context()
	Juice.play_sound(&"item_drop")
	player.play_item_gesture()
	return _result(true, "%s dipasang. Interaksi untuk menggunakannya." % item.display_name)

func interact_near(player: Player) -> bool:
	if player.world_root().get_meta("structure_area", "") != "farm" or player.base_layer_ground == null:
		return false
	var feet := player.global_position + Player.FEET_OFFSET
	var nearest := 33.0
	var selected := {}
	for record in records:
		var item := GameState._resolve_item(record.item)
		var center := player.base_layer_ground.to_global(player.base_layer_ground.map_to_local(Vector2i(int(record.cell[0]), int(record.cell[1])))) + Vector2(item.placement_size - Vector2i.ONE) * 8
		var distance := feet.distance_to(center)
		if distance < nearest and (center - feet).dot(player.facing_direction) >= -1:
			selected = record
			nearest = distance
	if selected.is_empty():
		return false
	var menu = load("res://scripts/ui/structure_menu.gd").new()
	menu.player = player
	menu.uid = selected.uid
	_menus[player.data.index] = menu
	player.get_parent().add_child(menu)
	return true

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
			if file.ends_with(".tres"):
				var recipe: Resource = load("res://resources/furnace/" + file)
				if recipe is FurnaceRecipe:
					_recipes.append(recipe)
	return _recipes

func smelt(data: PlayerData, uid: int, recipe: FurnaceRecipe) -> Dictionary:
	var record := record_for(uid)
	if record.is_empty() or record.item != "furnace" or not furnace_recipes().has(recipe):
		return _result(false, "Furnace atau resep tidak tersedia.")
	if not record.job.is_empty() or not record.ready.is_empty():
		return _result(false, "Tunggu proses selesai dan ambil hasilnya.")
	if not data.remove_item(recipe.input_item_id, recipe.input_amount):
		return _result(false, "Bijih tidak cukup.")
	record.job = {"recipe": recipe.recipe_id, "seconds": recipe.process_time}
	changed.emit()
	return _result(true, "Peleburan dimulai.")

func collect(data: PlayerData, uid: int) -> Dictionary:
	var record := record_for(uid)
	if record.is_empty() or record.ready.is_empty():
		return _result(false, "Belum ada hasil.")
	var item := GameState._resolve_item(record.ready.id)
	var count: int = record.ready.count
	var left := data.add_item(item, count)
	if left == 0:
		record.ready = {}
	else:
		record.ready.count = left
	changed.emit()
	return _result(left < count, "Hasil diambil." if left < count else "Tas penuh. Hasil tetap di furnace.")

func _process(delta: float) -> void:
	if not DayCycle.is_running:
		return
	for record in records:
		if record.job.is_empty():
			continue
		record.job.seconds -= delta
		if record.job.seconds > 0:
			continue
		for recipe in furnace_recipes():
			if recipe.recipe_id == record.job.recipe:
				record.ready = {"id": recipe.output_item_id, "count": recipe.output_amount}
				break
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
			var record := {"uid": _next_uid, "item": entry.item, "cell": cell.duplicate(), "storage": [], "open": entry.get("open") == true, "job": {}, "ready": {}}
			_next_uid += 1
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
			records.append(record)
	_sync_all()

func _result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}

func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))
