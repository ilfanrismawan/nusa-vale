extends Node

const SAVE_PATH := "user://nusa_vale_save.json"


func _ready() -> void:
	load_game()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	var farm: Array = []
	for cell: Vector2i in FarmManager.farm_data:
		var d: Dictionary = FarmManager.farm_data[cell]
		farm.append({
			"cell": [cell.x, cell.y],
			"state": d["state"],
			"crop": d["crop"].resource_path if d["crop"] != null else "",
			"stage": d["stage"],
			"days_in_stage": d["days_in_stage"],
			"watered": d["watered"],
			"stamina": GameState.stamina,
		})
	
	var inv: Array = []
	for i in range(GameState.inventory.size()):
		var slot = GameState.inventory[i]
		if slot != null and slot.get("item") != null:
			inv.append({"slot": i, "id": slot["item"].item_id, "count": slot["count"]})
	var data := {
		"version": 1,
		"day": DayCycle.current_day,
		"hour": DayCycle.hour,
		"minute": DayCycle.minute,
		"money": GameState.money,
		"inventory": inv,
		"farm": farm,		
		"chopped_trees": GameState.chopped_trees,
		"mined_rocks": GameState.mined_rocks,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Gagal menyimpan: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data))
	print("Game tersimpan (hari %d)" % DayCycle.current_day)
	
func load_game() -> void:	
	if not has_save():
		return
		
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("File save rusak, dilewati.")
		return
	
	DayCycle.current_day = int(parsed.get("day", 1))
	DayCycle.hour = int(parsed.get("hour", 6))
	DayCycle.minute = int(parsed.get("minute", 0))
	GameState.money = int(parsed.get("money", 100))
	GameState.stamina = int(parsed.get("stamina", GameState.MAX_STAMINA))
	GameState.stamina_changed.emit(GameState.stamina, GameState.MAX_STAMINA)
	
	for i in GameState.INVENTORY_SIZE:
		GameState.inventory[i] = null
	
	for entry in parsed.get("inventory", []):
		var item_id: String = str(entry.get("id", ""))
		var count: int = int(entry.get("count", 1))
		var slot_idx: int = int(entry.get("slot", -1))
		if slot_idx >= 0 and slot_idx < GameState.INVENTORY_SIZE:
			var item: ItemData = GameState._resolve_item(item_id)
			if item != null:
				GameState.inventory[slot_idx] = {"item": item, "count": count}
		else:
			GameState.add_item(item_id, count)
	
	# Pastikan starter tools selalu ada jika save file lama belum menyimpannya
	GameState.ensure_starter_tools()
	GameState.inventory_changed.emit()
	
	FarmManager.farm_data.clear()
	
	for entry in parsed.get("farm", []):
		var cell := Vector2i(int(entry["cell"][0]), int(entry["cell"][1]))
		var crop: CropData = null
		if str(entry["crop"]) != "":
			crop = load(str(entry["crop"]))
		FarmManager.farm_data[cell] = {
			"state": str(entry["state"]),
			"crop": crop,
			"stage": int(entry["stage"]),
			"days_in_stage": int(entry["days_in_stage"]),
			"watered": bool(entry["watered"]),
		}
		
	GameState.chopped_trees.clear()
	for p in parsed.get("chopped_trees", []):
		GameState.chopped_trees.append(str(p))
	GameState.mined_rocks.clear()
	for p in parsed.get("mined_rocks", []):
		GameState.mined_rocks.append(str(p))
	print("Game dimuat: hari %d" % DayCycle.current_day)
