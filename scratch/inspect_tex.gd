extends SceneTree

func _init() -> void:
	var files: Array[String] = [
		"res://assets/farm_rpg/tileset/ext/Big old Tree.png",
		"res://assets/farm_rpg/tileset/ext/Tree Deep Forest.png",
		"res://assets/farm_rpg/tileset/ext/Fantasy Mushroom.png",
		"res://assets/farm_rpg/tileset/ext/bushes.png",
		"res://assets/farm_rpg/objects/exterior/Road.png",
		"res://assets/farm_rpg/tileset/ext/Tileset Grass Cliff Tileset Spring.png",
		"res://assets/farm_rpg/tileset/ext/ALL props seasons.png",
		"res://assets/farm_rpg/tileset/ext/Tileset Grass Water Spring.png"
	]
	for p in files:
		if ResourceLoader.exists(p):
			var tex: Texture2D = load(p)
			if tex:
				print(p.get_file(), " -> size: ", tex.get_size())
	quit()
