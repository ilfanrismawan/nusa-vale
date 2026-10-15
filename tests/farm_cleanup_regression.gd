extends Node

const Spawner = preload("res://scripts/world/farm_cleanup_spawner.gd")
var failures := 0

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func fixture() -> Node2D:
	var world := Node2D.new()
	world.name = "RenamedFarm"
	var holder := Node2D.new()
	holder.name = "YSort"
	holder.y_sort_enabled = true
	world.add_child(holder)
	return world

func _ready() -> void:
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	DayCycle.is_running = false
	GameState.new_game()
	var entries := Spawner.objects()
	var ids := {}
	var wood: Dictionary
	var rock: Dictionary
	for entry in entries:
		ids[entry.id] = true
		if entry.scene.ends_with("/wood.tscn"):
			wood = entry
		if entry.group == "mineable":
			rock = entry
	check(entries.size() == 586 and ids.size() == entries.size(), "586 placements have unique stable IDs")
	var world := fixture()
	var start := Time.get_ticks_usec()
	check(Spawner.populate(world) == 586, "new game restores every initial cleanup object")
	print("CLEANUP BENCH new_game: %.2f ms, objects=%d" % [(Time.get_ticks_usec() - start) / 1000.0, world.get_node("YSort").get_child_count()])
	check(Spawner.populate(world) == 0 and world.get_node("YSort").get_child_count() == 586, "population is idempotent")
	add_child(world)
	var wood_node := world.get_node("YSort/" + wood.name) as Choppable
	check(wood_node.position == wood.position and wood_node.persistence_id == wood.id and wood_node.is_in_group("choppable"), "spawn preserves position, stable ID and tool interaction")
	wood_node.drop_count = 0
	wood_node.take_hit(1)
	await get_tree().create_timer(0.8).timeout
	check(is_instance_valid(wood_node) and not GameState.chopped_trees.has(wood.id), "partial damage does not permanently clear an object")
	wood_node.take_hit(99)
	await get_tree().create_timer(1.0).timeout
	check(not is_instance_valid(wood_node) and GameState.chopped_trees.has(wood.id), "destroyed object is removed and records stable ID")
	check(SaveManager.save_game(), "cleanup progress saves")
	GameState.chopped_trees.clear()
	check(SaveManager.load_game() and GameState.chopped_trees.has(wood.id), "cleanup progress survives save round trip")
	world.queue_free()
	await get_tree().process_frame
	var reload := fixture()
	check(Spawner.populate(reload) == 585 and not reload.has_node("YSort/" + wood.name), "cleared object is never instantiated on reload")
	reload.free()
	GameState.chopped_trees.assign(["/root/Farm/YSort/" + wood.name])
	GameState.mined_rocks.assign(["/root/CoopRoot/Area_farm/Farm/YSort/" + rock.name])
	var legacy := fixture()
	check(Spawner.populate(legacy) == 584 and not legacy.has_node("YSort/" + wood.name) and not legacy.has_node("YSort/" + rock.name), "legacy solo and co-op paths preserve cleanup progress")
	legacy.free()
	GameState.chopped_trees.clear()
	GameState.mined_rocks.clear()
	for entry in entries:
		if entry.group == "mineable":
			GameState.mined_rocks.append(entry.id)
		else:
			GameState.chopped_trees.append(entry.id)
	var clean := fixture()
	start = Time.get_ticks_usec()
	check(Spawner.populate(clean) == 0 and clean.get_node("YSort").get_child_count() == 0, "fully cleared farm instantiates zero cleanup nodes")
	print("CLEANUP BENCH cleared: %.2f ms, objects=0" % ((Time.get_ticks_usec() - start) / 1000.0))
	add_child(clean)
	DayCycle.day_passed.emit(DayCycle.current_day + 1)
	await get_tree().process_frame
	check(clean.get_node("YSort").get_child_count() == 0, "new day does not respawn story cleanup objects")
	clean.queue_free()
	GameState.new_game()
	var reset := fixture()
	check(Spawner.populate(reset) == 586, "new game resets the abandoned farm")
	reset.free()
	print("FARM CLEANUP REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
