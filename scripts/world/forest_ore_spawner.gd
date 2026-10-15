class_name ForestOreSpawner
extends ForageSpawner
## Renewable starter metal. Small iron deposits require Copper, never Iron itself.

@export var entrance_position := Vector2(741, 539)
var _reachable: Dictionary = {}
var _spawn_cells: Array[Vector2i] = []

func _sync(animate_existing: bool) -> void:
	_reachable = _starter_routes()
	_spawn_cells.clear()
	for cell in _reachable:
		if _cell_allowed(cell):
			_spawn_cells.append(cell)
	super(animate_existing)

func _random_cell() -> Vector2i:
	return _spawn_cells[randi() % _spawn_cells.size()] if not _spawn_cells.is_empty() else Vector2i(-1, -1)

func _cell_allowed(cell: Vector2i) -> bool:
	# An open patch off narrow passages; rocks must not seal the route to the next tier.
	for offset in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if not _reachable.has(cell + offset):
			return false
	return true

func _starter_routes() -> Dictionary:
	if not is_instance_valid(_ground):
		return {}
	var world := _ground.get_parent()
	var excluded: Array[RID] = []
	for group in [&"choppable", &"mineable", &"player"]:
		for node in get_tree().get_nodes_in_group(group):
			if not node is CollisionObject2D or node.get_world_2d() != get_world_2d():
				continue
			if node is Player or (node is Choppable and node.required_tool_tier() == ToolData.ToolTier.WOOD):
				excluded.append(node.get_rid())
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 4.2
	query.shape = shape
	query.exclude = excluded
	query.collision_mask = 1
	query.collide_with_areas = false
	var start := _ground.local_to_map(_ground.to_local(entrance_position + Player.FEET_OFFSET))
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
	var result := {start: true}
	var index := 0
	var bridges := world.get_node_or_null("Bridges")
	while index < queue.size():
		var cell := queue[index]
		index += 1
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + direction
			if seen.has(next):
				continue
			seen[next] = true
			var center := _ground.to_global(_ground.map_to_local(next))
			var surface := _ground.get_cell_source_id(next) >= 0
			if not surface and bridges != null:
				for bridge in bridges.get_children():
					if bridge is Sprite2D and bridge.get_rect().has_point(bridge.to_local(center)):
						surface = true
						break
			if not surface:
				continue
			query.transform = Transform2D(0, center - Player.FEET_OFFSET)
			if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
				continue
			result[next] = true
			queue.append(next)
	return result

func _area_key() -> String:
	return location_id + "#ore"

func _clear_on_season() -> bool:
	return false

func _pick_id() -> String:
	# Replenish the least abundant metal, avoiding a cap full of unmineable iron.
	var copper := 0
	var iron := 0
	for value in ForageManager.get_items(_area_key()).values():
		if value == "copper":
			copper += 1
		elif value == "iron_small":
			iron += 1
	return "copper" if copper <= iron else "iron_small"

func _make_node(id: String, cell: Vector2i) -> Node2D:
	var path: String
	match id:
		"copper": path = "res://scenes/objects/RockCopper.tscn"
		"iron_small": path = "res://scenes/objects/small_iron_rock.tscn"
		_: return null
	var rock := load(path).instantiate() as Choppable
	rock.persistent = false
	rock.name = "ForestOre_%d_%d" % [cell.x, cell.y]
	rock.tree_exiting.connect(_on_removed.bind(rock, cell))
	return rock

func _on_removed(rock: Choppable, cell: Vector2i) -> void:
	if rock.is_destroyed:
		ForageManager.remove_item(_area_key(), cell)
		_nodes.erase(ForageManager.key_of(cell))

func _on_spawned(_count: int) -> void:
	if DiscoveryManager.discover("forest_ore_tip"):
		Notify.say("Endapan bijih muncul kembali di hutan. Tembaga bisa ditambang dengan Beliung Kayu; endapan besi kecil membutuhkan Tembaga.")
