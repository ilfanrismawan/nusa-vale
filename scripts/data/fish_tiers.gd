class_name FishTiers
extends RefCounted

const TIERS := [
	{"name": "Umum",       "difficulty": 0.15, "weight": 10.0, "price": 25,   "color": Color("c9c9c9")},
	{"name": "Tidak Umum", "difficulty": 0.35, "weight": 5.0,  "price": 70,   "color": Color("6fd16f")},
	{"name": "Langka",     "difficulty": 0.55, "weight": 2.0,  "price": 160,  "color": Color("5aa9ff")},
	{"name": "Epik",       "difficulty": 0.75, "weight": 0.8,  "price": 400,  "color": Color("b36bff")},
	{"name": "Legendaris", "difficulty": 0.92, "weight": 0.2,  "price": 1000, "color": Color("ffb938")},
]

static func get_tier(index: int) -> Dictionary:
	return TIERS[clampi(index, 0, TIERS.size() - 1)]
	
static func difficulty_of(fish: FishData) -> float:
	var t := get_tier(int(fish.item.rarity))
	return clampf(float(t["difficulty"]) + fish.difficulty_offset, 0.0, 1.0)
	
static func weight_of(fish: FishData) -> float:
	return float(get_tier(int(fish.item.rarity))["weight"]) * fish.weight_mult
