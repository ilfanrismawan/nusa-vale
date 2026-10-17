extends Node2D

class QuietTreeSpawner extends TreeSpawner:
	func _sync(_animate: bool) -> void:
		pass

var failures := 0

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1

func _ready() -> void:
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	DayCycle.is_running = false
	var ground := TileMapLayer.new()
	ground.name = "BaseLayerGround"
	ground.tile_set = TileSet.new()
	var source := TileSetAtlasSource.new()
	var texture := GradientTexture2D.new()
	texture.width = 16
	texture.height = 16
	source.texture = texture
	source.texture_region_size = Vector2i(16, 16)
	source.create_tile(Vector2i.ZERO)
	ground.tile_set.add_source(source, 0)
	for x in 30:
		for y in 30:
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	add_child(ground)
	var holder := Node2D.new()
	holder.name = "YSortEntities"
	holder.y_sort_enabled = true
	add_child(holder)
	var spawner := QuietTreeSpawner.new()
	spawner.location_id = "spawn_regression"
	add_child(spawner)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var rock := load("res://scenes/objects/rock.tscn").instantiate() as Choppable
	rock.persistent = false
	rock.position = ground.map_to_local(Vector2i(10, 10))
	holder.add_child(rock)
	check(not spawner._is_free(Vector2i(10, 10)), "same-frame rock blocks tree spawn")
	check(not spawner._is_free(Vector2i(11, 10)), "adjacent rock reserves clearance")
	check(spawner._is_free(Vector2i(20, 20)), "open ground remains spawnable")
	var mature := load("res://scenes/objects/pine_tree.tscn").instantiate() as Choppable
	mature.persistent = false
	mature.position = ground.map_to_local(Vector2i(20, 20))
	holder.add_child(mature)
	check(not spawner._is_free(Vector2i(20, 18)), "new canopy refreshes occupancy beyond trunk clearance in same frame")
	mature.queue_free()
	check(spawner._is_free(Vector2i(20, 18)), "removed canopy does not leave stale occupied ground")
	var id := "pine|small|1"
	ForageManager.add_item(spawner._area_key(), Vector2i(10, 10), id)
	spawner._place(Vector2i(10, 10), id, false)
	check(not ForageManager.has_item_at(spawner._area_key(), Vector2i(10, 10)), "old overlapping save is relocated")
	check(ForageManager.get_items(spawner._area_key()).values() == [id], "relocation preserves resource identity and count")
	var tree := spawner._nodes.values()[0] as Choppable
	check(tree.global_position.distance_to(rock.global_position) >= 28.0, "restored tree clears rock")
	check(tree.animated_sprite.z_index == 0 and tree._canopy.z_index == 0, "generated tree layers share rock y-sort plane")
	for kind in ["pine", "birch", "maple", "mahogany", "deep_forest"]:
		var small := load("res://scenes/objects/small_%s_tree.tscn" % kind).instantiate() as Choppable
		var big := load("res://scenes/objects/%s_tree.tscn" % kind).instantiate() as Choppable
		check(small.scale.x < big.scale.x and small.required_tool_tier() < big.required_tool_tier(), kind + " size distinguishes tool requirement")
		if big.resource_size == Choppable.ResourceSize.LARGE:
			check(big.scale.x > 1.0, kind + " Iron-tier tree is larger than Copper-tier tree")
		if kind == "pine":
			check(big.get_node("TrunkMask").z_index == 0 and big.get_node("CanopyMask").z_index == 0, "authored pine masks share y-sort plane")
		small.free()
		big.free()
	var relocated_cell := ground.local_to_map(tree.position)
	tree.is_destroyed = true
	tree.queue_free()
	await get_tree().process_frame
	check(not ForageManager.has_item_at(spawner._area_key(), relocated_cell), "relocated removal callback clears correct saved cell")
	print("RESOURCE SPAWNER COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
