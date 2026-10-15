class_name ChickenVisual
extends RefCounted

const WHITE := preload("res://assets/farm_rpg/animals/chicken/white.png")
const BROWN := preload("res://assets/farm_rpg/animals/chicken/brown.png")
static var _cache: Dictionary = {}

static func frames(variant: String) -> SpriteFrames:
	if _cache.has(variant):
		return _cache[variant]
	var result := SpriteFrames.new()
	result.set_animation_speed(&"default", 2.5)
	for x in 2:
		var frame := AtlasTexture.new()
		frame.atlas = BROWN if variant == "brown" else WHITE
		frame.region = Rect2(x * 16, 0, 16, 16)
		result.add_frame(&"default", frame)
	_cache[variant] = result
	return result
