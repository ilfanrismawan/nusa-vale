extends SceneTree

func _init() -> void:
	var out = FileAccess.open("res://scratch/asset_sizes.txt", FileAccess.WRITE)
	var list = [
		"res://assets/farm_rpg/tileset/ext/Big old Tree.png",
		"res://assets/farm_rpg/tileset/ext/Tree Deep Forest.png",
		"res://assets/farm_rpg/tileset/ext/Fantasy Mushroom.png",
		"res://assets/farm_rpg/tileset/ext/bushes.png",
		"res://assets/farm_rpg/objects/exterior/Road.png",
		"res://assets/farm_rpg/tileset/ext/ALL props seasons.png"
	]
	for p in list:
		var tex = load(p) as Texture2D
		if tex:
			out.store_line(p + " = " + str(tex.get_size()))
	out.close()
	quit()
