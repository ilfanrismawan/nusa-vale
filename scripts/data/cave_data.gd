class_name CaveData
extends Resource

## Data Gua Tambang (GDD 9): jumlah lantai, lift, tabel lantai, dan pintu keluar.

## Lantai terdalam yang bisa dicapai sekarang. Lantai 20 = arena boss Raja Slime Emas.
@export_range(1, 999) var max_floor: int = 20
## Lift checkpoint tiap kelipatan lantai ini.
@export_range(1, 50) var lift_interval: int = 5
## Peluang tangga turun muncul dari satu batu yang dihancurkan.
@export_range(0.0, 1.0) var stairs_chance: float = 0.08
@export var ores: Array[CaveOre] = []
@export var bands: Array[CaveBand] = []
## Boss Guardian per lantai arena (BossData.floor_number), GDD 8.2-C.
@export var bosses: Array[BossData] = []
## Lantai berisi danau bawah tanah (spot pancing yang tidak membeku, GDD 5). 0 = tidak ada.
@export_range(0, 999) var lake_floor: int = 10
## Posisi (tile) dan ukuran danau di lantai itu.
@export var lake_cell: Vector2i = Vector2i(26, 14)
@export var lake_size: Vector2i = Vector2i(8, 6)
## Toko Combat di lobi gua.
@export var shop: ShopData
## Tujuan pintu keluar lobi gua (mulut gua di luar).
@export_file("*.tscn") var exit_scene: String = "res://scenes/world/mountain.tscn"
@export var exit_spawn: Vector2 = Vector2(328, 80)

func band_for(floor_number: int) -> CaveBand:
	for band in bands:
		if band != null and band.contains(floor_number):
			return band
	return bands[bands.size() - 1] if not bands.is_empty() else null

## Boss lantai ini, atau null bila bukan lantai arena.
func boss_for(floor_number: int) -> BossData:
	for entry in bosses:
		if entry != null and entry.floor_number == floor_number:
			return entry
	return null

func ore(item_id: String) -> CaveOre:
	for entry in ores:
		if entry != null and entry.item_id == item_id:
			return entry
	return null

func is_lift_floor(floor_number: int) -> bool:
	return floor_number > 0 and floor_number % lift_interval == 0
