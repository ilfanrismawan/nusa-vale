class_name FishData
extends Resource

@export var item: ItemData
@export var locations: PackedStringArray = []
## Musim ikan bisa dipancing: "spring" / "summer" / "fall" / "winter"
## (sama dengan DayCycle.get_current_season()). Kosong = sepanjang tahun (GDD 5).
@export var seasons: PackedStringArray = []
@export_range(0, 24) var min_hour: int = 0
@export_range(0, 24) var max_hour: int = 24
@export var weight_mult: float = 1.0
@export_range(-0.1, 0.1, 0.01) var difficulty_offset: float = 0.0


func get_difficulty() -> float:
	return FishTiers.difficulty_of(self)

func get_weight() -> float:
	return FishTiers.weight_of(self)

func is_in_season(season: String) -> bool:
	return seasons.is_empty() or season.is_empty() or seasons.has(season)

## season kosong = abaikan musim (dipakai tes/debug lama).
func is_available(location_id: String, hour: int, season: String = "") -> bool:
	if not locations.has(location_id):
		return false
	if not is_in_season(season):
		return false
	if min_hour <= max_hour:
		return hour >= min_hour and hour < max_hour
	return hour >= min_hour or hour < max_hour
