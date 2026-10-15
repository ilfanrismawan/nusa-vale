class_name RanchVisual
extends RefCounted

static var _cache: Dictionary = {}

static func frames(species: String, variant: String = "white", walking: bool = false, direction: String = "down") -> SpriteFrames:
	var key := species + variant + direction + ("_walk" if walking else "_idle")
	if _cache.has(key):
		return _cache[key]
	var texture: Texture2D = (ChickenVisual.BROWN if variant == "brown" else ChickenVisual.WHITE) if species == "chicken" else load("res://assets/farm_rpg/animals/%s.png" % species)
	var size := 16 if species in ["chicken", "duck"] else 32
	var result := SpriteFrames.new()
	result.set_animation_speed(&"default", 5 if walking else 2.5)
	var row := 0 if direction == "side" else (2 if direction == "up" else 1)
	if walking:
		row += 3
	for x in (4 if walking else 2):
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(x * size, row * size, size, size)
		frame.filter_clip = true
		result.add_frame(&"default", frame)
	_cache[key] = result
	return result
