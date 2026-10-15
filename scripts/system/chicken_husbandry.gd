class_name ChickenHusbandry
extends RefCounted

## Shared coop data, independent of scene lifetime or a particular player's bag.
const CAPACITY := 4
const CHICKEN_PRICE := 800
const EGG_LIMIT := 999
const VARIANTS := ["white", "brown"]

static func empty(day: int) -> Dictionary:
	return {"chickens": [], "eggs": 0, "next_id": 1, "last_day": day}

static func integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))

static func valid(value: Variant) -> bool:
	return RanchHusbandry.valid(value)

static func advance(state: Dictionary, day: int) -> void:
	RanchHusbandry.advance(state, day)
