class_name CaveBand
extends Resource

## Rentang lantai gua dengan tabel bijih dan musuhnya sendiri (GDD 9).

@export_range(1, 999) var first_floor: int = 1
@export_range(1, 999) var last_floor: int = 20
## Nama tingkat yang tampil di penanda lantai (mis. "Gua Tembaga").
@export var display_name: String = ""
## Ikon tingkat di penanda lantai.
@export var icon: Texture2D
## Warna bingkai penanda lantai dan warna nama tingkat.
@export var accent: Color = Color(0.9, 0.7, 0.3)
## Warna ubin lantai dan dinding di tingkat ini, supaya tiap tingkat terlihat beda.
@export var tint: Color = Color.WHITE
## item_id dari CaveData.ores. Batu biasa ("stone") boleh ikut di sini.
@export var ore_ids: PackedStringArray = []
## Bobot acak, sejajar dengan ore_ids.
@export var ore_weights: PackedFloat32Array = []
## Geoda yang bisa jatuh dari batu yang dihancurkan di tingkat ini (item_id GeodeData).
@export var geode_ids: PackedStringArray = []
## Peluang tiap geoda per batu (0-1), sejajar dengan geode_ids.
@export var geode_chances: PackedFloat32Array = []
@export_range(0, 80) var rock_min: int = 18
@export_range(0, 80) var rock_max: int = 26
@export var enemies: Array[EnemyData] = []
## Bobot sejajar Enemies; kosong = merata. Bobot 0 menonaktifkan jenis itu.
@export var enemy_weights: PackedFloat32Array = []
## Variasi dekorasi/rintangan buatan editor. Dipilih memakai seed lantai; kosong = tanpa template.
@export var floor_scenes: Array[PackedScene] = []
## Layout lantai utuh. Kosong memakai generator persegi lama. Floor Scenes adalah dekorasi legacy.
@export var dungeon_scenes: Array[PackedScene] = []
@export_range(0, 20) var enemy_min: int = 2
@export_range(0, 20) var enemy_max: int = 4

@export_group("Penempatan")
## Radius aman musuh dari marker Arrival (tile).
@export_range(1, 20) var enemy_safe_radius: float = 6.0
@export_range(0, 30) var pillar_min: int = 3
@export_range(0, 30) var pillar_max: int = 7
@export_range(1, 8) var pillar_max_length: int = 3
@export_range(1, 20) var pillar_safe_radius: float = 4.0
@export_range(0, 50) var decal_min: int = 4
@export_range(0, 50) var decal_max: int = 10

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

## Geoda yang jatuh dari satu batu, paling banyak satu.
func roll_geode(roll: float) -> String:
	for i in geode_ids.size():
		var chance := geode_chances[i] if i < geode_chances.size() else 0.0
		if roll < chance:
			return geode_ids[i]
		roll -= chance
	return ""

## Seleksi generik; identitas/statistik tier hanya berasal dari Resource.
func pick_enemy(rng: RandomNumberGenerator) -> EnemyData:
	var total := 0.0
	for i in enemies.size():
		if enemies[i] != null:
			total += maxf(enemy_weights[i], 0.0) if i < enemy_weights.size() else 1.0
	if total <= 0.0:
		return null
	var roll := rng.randf() * total
	var last: EnemyData
	for i in enemies.size():
		if enemies[i] == null:
			continue
		var weight := maxf(enemy_weights[i], 0.0) if i < enemy_weights.size() else 1.0
		if weight <= 0.0:
			continue
		last = enemies[i]
		roll -= weight
		if roll < 0.0:
			return last
	return last
