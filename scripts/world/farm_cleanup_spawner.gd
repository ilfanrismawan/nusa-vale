extends RefCounted
## Objek cerita farm: muncul sekali, tanpa spawn harian atau respawn.

const LAYOUT = preload("res://resources/world/farm_cleanup_layout.tres")
const ID_PREFIX := "farm:cleanup:"

static func objects() -> Array:
	return LAYOUT.get_meta(&"cleanup_objects")

static func removed_index(ids: Array[String]) -> Dictionary:
	var result := {}
	for id in ids:
		if id.begins_with(ID_PREFIX):
			result[id] = true
		else:
			# Save solo lama dan save co-op memakai path root yang berbeda.
			var marker := "/Farm/YSort/"
			var at := id.rfind(marker)
			if at >= 0:
				var name := id.substr(at + marker.length())
				if not name.contains("/"):
					result[ID_PREFIX + name] = true
	return result

static func populate(world: Node) -> int:
	var holder := world.get_node_or_null("YSort")
	if holder == null or holder.has_meta(&"cleanup_populated"):
		return 0
	var trees := removed_index(GameState.chopped_trees)
	var rocks := removed_index(GameState.mined_rocks)
	var scenes := {}
	var count := 0
	for entry in objects():
		var id: String = entry.id
		var removed: Dictionary = rocks if entry.group == "mineable" else trees
		if removed.has(id):
			continue # Tidak load scene dan tidak instantiate objek yang sudah bersih.
		var path: String = entry.scene
		if not scenes.has(path):
			scenes[path] = load(path) as PackedScene
		var packed: PackedScene = scenes[path]
		if packed == null:
			push_error("Farm cleanup scene missing: " + path)
			continue
		var node := packed.instantiate() as Choppable
		node.name = entry.name
		node.position = entry.position
		node.persistence_id = id
		holder.add_child(node)
		count += 1
	holder.set_meta(&"cleanup_populated", true)
	return count
