extends Node

var failures := 0
var player: Player
var farm: Node2D

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _record(item: String, cell: Vector2i) -> Dictionary:
	var uid := StructureManager._next_uid
	StructureManager._next_uid += 1
	var record := {"uid": uid, "item": item, "cell": [cell.x, cell.y], "storage": [], "open": false, "job": {}, "ready": {}}
	StructureManager.records.append(record)
	return record

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	FarmManager.farm_data.clear()
	farm = load("res://scenes/world/farm.tscn").instantiate()
	get_tree().root.add_child(farm)
	get_tree().current_scene = farm
	await get_tree().physics_frame
	await get_tree().physics_frame
	for node in farm.find_children("*", "CharacterBody2D", true, false):
		if node is Player:
			player = node
			break
	check(player != null, "Farm player is available")
	if player == null:
		get_tree().quit(1)
		return
	await check_chest_visuals()
	print("CHEST VISUAL REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)

func check_chest_visuals() -> void:
	var holder := Node2D.new()
	holder.set_meta("world", weakref(farm))
	farm.add_child(holder)
	var chest = load("res://scenes/objects/placed_structure.tscn").instantiate()
	var record := _record("wooden_chest", Vector2i.ZERO)
	chest.uid = record.uid
	holder.add_child(chest)
	chest.set_process(false)
	chest._quiet_until_ms = Time.get_ticks_msec() + 100000
	var previous_position := player.global_position
	var columns := {"wooden_chest": 232, "copper_chest": 40, "iron_chest": 8, "gold_chest": 104, "platinum_chest": 72, "crimson_chest": 168, "frost_chest": 136, "shadow_chest": 200}
	for id in columns:
		record.item = id
		var item: ItemData = GameState._resolve_item(id)
		player.global_position = chest.global_position + Vector2(500, 0) - Player.FEET_OFFSET
		chest._update_chest_lid()
		chest.refresh()
		check(not chest._chest_open and chest._sprite.texture == item.chest_closed_texture, id + " closes when player leaves")
		check(item.chest_closed_texture.region == Rect2(columns[id], 0, 16, 16), id + " closed sprite matches tier")
		player.global_position = chest.global_position - Player.FEET_OFFSET
		chest._update_chest_lid()
		check(chest._chest_open and chest._sprite.texture == item.chest_open_texture, id + " opens when player approaches")
		check(item.chest_open_texture.region == Rect2(columns[id], 16, 16, 16), id + " open sprite matches tier")
		chest.refresh()
		check(chest._sprite.texture == item.chest_open_texture, id + " refresh preserves open state after tier change")
		var original_distance := item.chest_open_distance
		item.chest_open_distance = 10.0
		player.global_position = chest.global_position + Vector2(11, 0) - Player.FEET_OFFSET
		chest._update_chest_lid()
		check(not chest._chest_open, id + " uses Inspector distance")
		item.chest_open_distance = original_distance
	# Exercise every upgrade and persist the highest occupied slot.
	record.item = "wooden_chest"
	record.storage = [{"slot": 23, "id": "stone", "count": 7}]
	var owner := PlayerData.new(0)
	for id in StructureManager.CHESTS.slice(1):
		var recipe := StructureManager.next_chest_recipe(record.uid)
		check(recipe != null and recipe.output_item_id == id, id + " has a registered upgrade recipe")
		owner.load_inventory([])
		for material in recipe.ingredients:
			owner.add_item_silent(material, recipe.ingredients[material])
		check(StructureManager.upgrade_chest(owner, record.uid).ok and record.item == id, id + " upgrades in place")
		var storage := StructureManager.storage(record)
		var capacity: int = GameState._resolve_item(id).storage_slots
		check(storage.bag_size == capacity and storage.get_item_count("stone") == 7, id + " expands capacity and retains contents")
		storage.inventory[capacity - 1] = {"item": GameState._resolve_item("wood"), "count": 9}
		record.storage = storage.serialize_inventory()
		check(StructureManager.storage(record).inventory[capacity - 1]["count"] == 9, id + " restores highest slot")
		check(StructureManager.transfer(owner, record.uid, capacity - 1, false).ok, id + " highest slot can be withdrawn")
	check(StructureManager.next_chest_recipe(record.uid) == null, "Shadow is the final chest tier")
	player.global_position = previous_position
	StructureManager.records.erase(record)
	holder.queue_free()
	await get_tree().process_frame
