extends Node

const SAVE_PATH := "user://nusa_vale_save.json"
const SAVE_VERSION := 2

func _ready() -> void:
	call_deferred("_load_on_startup")

func _load_on_startup() -> void:
	load_game()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,

		"day_cycle": {
			"day": DayCycle.current_day,
			"hour": DayCycle.hour,
			"minute": DayCycle.minute,
		},

		"player": {
			"money": GameState.money,
			"stamina": GameState.stamina,
		},

		"inventory": _serialize_inventory(),

		"farm": _serialize_farm(),

		"world_state": WorldState.flags.duplicate(true),

		"discoveries": DiscoveryManager.discoveries.duplicate(true),

		"resources": {
			"chopped_trees": GameState.chopped_trees.duplicate(),
			"mined_rocks": GameState.mined_rocks.duplicate(),
		},
	}


	var file := FileAccess.open(
		SAVE_PATH,
		FileAccess.WRITE
	)

	if file == null:
		push_error(
			"Gagal membuka save file: %s"
			% FileAccess.get_open_error()
		)
		return


	file.store_string(
		JSON.stringify(data, "\t")
	)

	file.close()


	print(
		"Game tersimpan | Hari %d"
		% DayCycle.current_day
	)
	
func load_game() -> void:	
	var file := FileAccess.open(
		SAVE_PATH,
		FileAccess.READ
	)

	if file == null:
		push_error(
			"Gagal membuka save file: %s"
			% FileAccess.get_open_error()
		)
		return


	var json_text := file.get_as_text()
	file.close()


	var parsed = JSON.parse_string(json_text)
	
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning(
			"Save file rusak atau format tidak valid."
		)
		return
	
	var version: int = int(
		parsed.get("version", 1)
	)
	
	_load_day_cycle(parsed)
	_load_player(parsed)
	_load_inventory(parsed)
	_load_farm(parsed)
	_load_world_state(parsed)
	_load_discoveries(parsed)
	_load_resources(parsed)
	
	print(
		"Loading save version: %d"
		% version
	)

func _load_day_cycle(data: Dictionary) -> void:
	var day_data: Dictionary = data.get(
		"day_cycle",
		{}
	)
	
	DayCycle.current_day = int(
		day_data.get("day", 1)
	)
	
	DayCycle.hour = int(
		day_data.get("hour", 6)
	)
	
	DayCycle.minute = int(
		day_data.get("minute", 0)
	)
	
func _load_player(data: Dictionary) -> void:
	var player_data: Dictionary = data.get(
		"player", 
		{}
	)
	
	GameState.money = int(
		player_data.get("money", 100)
	)
	
	GameState.stamina = int(
		player_data.get(
			"stamina",
			GameState.MAX_STAMINA
		)
	)
	
	GameState.stamina_changed.emit(
		GameState.stamina,
		GameState.MAX_STAMINA
	)
	
	GameState.money_changed.emit(
		GameState.money
	)
	
func _serialize_inventory() -> Array:
	var result: Array = []
	
	for i in range(GameState.inventory.size()):
		var slot = GameState.inventory[i]
		
		if slot == null:
			continue
		
		if slot.get("item") == null:
			continue
		
		var item: ItemData = slot["item"]
		
		result.append({
			"slot": i,
			"id": item.item_id,
			"count": int(slot["count"]),
		})
		
	return result

func _load_inventory(data: Dictionary) -> void:
	for i in range(GameState.INVENTORY_SIZE):
		GameState.inventory[i] = null
	
	var inventory_data: Array = data.get(
		"inventory",
		[]
	)	
	
	for entry in inventory_data:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		
		var item_id: String = str(entry.get("id", ""))
		var count: int = int(entry.get("count", 1))
		var slot_id: int = int(entry.get("slot", -1))
		
		if slot_id < 0:
			continue
		if slot_id >= GameState.INVENTORY_SIZE:
			continue
		if count <= 0:
			continue
			
		var item: ItemData = GameState._resolve_item(item_id)
		
		if item == null:
			push_warning("Item tidak ditemukan saat load: %s % item_id")
			continue
		
		GameState.inventory[slot_id] = {
			"item": item,
			"count": count,
		}
		
func _serialize_farm() -> Array:
	var farm_data: Array = []
	
	for cell: Vector2i in FarmManager.farm_data:
		var d: Dictionary = (
			FarmManager.farm_data[cell]
		)
		
		var crop: CropData = d.get("crop")
		
		farm_data.append({
			"cell": [cell.x, cell.y],
			"state": str(d.get("state", "")),
			"crop": (
				crop.resource_path
				if crop != null
				else ""
					),
			"stage": int(d.get("stage", 0)),
			"days_in_stage": int(
				d.get("days_in_stage", 0)
			),
			"watered": bool(d.get("watered", false)),
		})
		
	return farm_data
	
func _load_farm(data: Dictionary) -> void:
	FarmManager.farm_data.clear()
	
	var farm_data: Array = data.get(
		"farm",
		[]
	)
	
	for entry in farm_data:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		
		var cell_data: Array = entry.get(
			"cell",
			[]
		)
		
		if cell_data.size() < 2:
			continue
			
		var cell := Vector2i(
			int(cell_data[0]),
			int(cell_data[1])
		)
		
		var crop: CropData = null
		
		var crop_path: String = str(entry.get("crop", ""))
		
		if crop_path != "":
			if ResourceLoader.exists(crop_path):
				crop = load(crop_path) as CropData
			else:
				push_warning("Crop resource tidak ditemukan: %" % crop_path)
	
		FarmManager.farm_data[cell] = {
			"state": str(entry.get("state", "tilled")),
			"crop": crop,
			"stage": int(entry.get("stage", 0)),
			"days_in_stage": int(entry.get("days_in_stage", 0)),
			"watered": bool(entry.get("watered", false))
		}
		
func _load_world_state(data: Dictionary) -> void:
	WorldState.reset()
	
	var world_data: Dictionary = data.get(
		"world_state",
		{}
	)
	for flag_id in world_data:
		WorldState.flags[str(flag_id)] = bool(world_data[flag_id])
	
func _load_discoveries(data: Dictionary) -> void:
	DiscoveryManager.reset()
	
	var discovery_data: Dictionary = data.get(
		"discoveries",
		{}
	)
	
	for discovery_id in discovery_data:
		if bool(discovery_data[discovery_id]):
			DiscoveryManager.discover(
				str(discovery_id)
			)
			
func _load_resources(data: Dictionary) -> void:
	
	var resource_data: Dictionary = data.get(
		"resources",
		{}
	)
	
	GameState.chopped_trees.clear()
	
	for tree_id in resource_data.get(
		"chopped_trees",
		[]
	):
		GameState.chopped_trees.append(str(tree_id))
	
	GameState.mined_rocks.clear()
	
	for rock_id in resource_data.get(
		"mined_rocks", []
	):
		GameState.mined_rocks.append(str(rock_id))
