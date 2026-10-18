class_name CaveBand
extends Resource

## Rentang lantai gua dengan tabel bijih dan musuhnya sendiri (GDD 9).

@export_range(1, 999) var first_floor: int = 1
@export_range(1, 999) var last_floor: int = 20
## item_id dari CaveData.ores. Batu biasa ("stone") boleh ikut di sini.
@export var ore_ids: PackedStringArray = []
## Bobot acak, sejajar dengan ore_ids.
@export var ore_weights: PackedFloat32Array = []
@export_range(0, 80) var rock_min: int = 18
@export_range(0, 80) var rock_max: int = 26
@export var enemies: Array[EnemyData] = []
@export_range(0, 20) var enemy_min: int = 2
@export_range(0, 20) var enemy_max: int = 4

func contains(floor_number: int) -> bool:
	return floor_number >= first_floor and floor_number <= last_floor

## Pilih item_id bijih memakai RNG lantai (urutan tetap untuk seed yang sama).
func pick_ore(rng: RandomNumberGenerator) -> String:
	if ore_ids.is_empty():
		return "stone"
	var total := 0.0
	for i in ore_ids.size():
		total += _weight(i)
	var roll := rng.randf() * total
	for i in ore_ids.size():
		roll -= _weight(i)
		if roll <= 0.0:
			return ore_ids[i]
	return ore_ids[ore_ids.size() - 1]

func _weight(index: int) -> float:
	return maxf(ore_weights[index], 0.0) if index < ore_weights.size() else 1.0
