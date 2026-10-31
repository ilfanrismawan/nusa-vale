class_name CaveManager
extends Node

## Progres Gua Tambang milik dunia (dibagi semua pemain co-op), dipegang GameState.cave.
## Lantai lift checkpoint tersimpan permanen; layout lantai diacak ulang tiap hari (GDD 9).

signal lift_unlocked(floor_number: int)

## load() (bukan preload) agar editor tidak memuat ~220 resource gua saat membuka project.
static var DATA: CaveData = load("res://resources/cave/cave_data.tres")

## Lantai tempat pemain berada / akan masuk (0 = lobi gua). Tidak disimpan.
var current_floor: int = 0
## Lantai lift tertinggi yang sudah dicapai (0 = belum ada).
var deepest_lift: int = 0
## Lantai terdalam yang pernah dicapai.
var deepest_floor: int = 0
## Lantai arena yang boss-nya sudah pernah dikalahkan (GDD 8.2-C, save v16).
var bosses_defeated: Array[int] = []

func reset() -> void:
	current_floor = 0
	deepest_lift = 0
	deepest_floor = 0
	bosses_defeated.clear()

## Catat kedatangan di lantai. True bila lift baru terbuka.
func reach(floor_number: int) -> bool:
	current_floor = floor_number
	deepest_floor = maxi(deepest_floor, floor_number)
	if not DATA.is_lift_floor(floor_number) or floor_number <= deepest_lift:
		return false
	deepest_lift = floor_number
	lift_unlocked.emit(floor_number)
	return true

## Tujuan lift: lobi (0) lalu tiap lantai checkpoint yang sudah terbuka.
func lift_floors() -> Array[int]:
	var floors: Array[int] = [0]
	var step := DATA.lift_interval
	for floor_number in range(step, deepest_lift + 1, step):
		floors.append(floor_number)
	return floors

## Seed layout: sama sepanjang satu hari untuk lantai yang sama, berganti esok harinya.
func floor_seed(floor_number: int, day: int = DayCycle.current_day) -> int:
	return hash("cave:%d:%d" % [day, floor_number])

func is_boss_defeated(floor_number: int) -> bool:
	return bosses_defeated.has(floor_number)

## Catat boss lantai ini kalah. True bila baru pertama kali (hadiah pertama diberikan).
func mark_boss_defeated(floor_number: int) -> bool:
	if bosses_defeated.has(floor_number):
		return false
	bosses_defeated.append(floor_number)
	bosses_defeated.sort()
	return true

func to_save() -> Dictionary:
	return {"deepest_lift": deepest_lift, "deepest_floor": deepest_floor, "bosses": bosses_defeated.duplicate()}

static func valid_save(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	for key in ["deepest_lift", "deepest_floor"]:
		if data.has(key) and not (data[key] is int or data[key] is float):
			return false
	if data.has("bosses"):
		if not data["bosses"] is Array:
			return false
		for value in data["bosses"]:
			if not (value is int or value is float):
				return false
	return true

func load_save(data: Variant) -> void:
	reset()
	if not data is Dictionary:
		return
	var step := DATA.lift_interval
	deepest_floor = clampi(int(data.get("deepest_floor", 0)), 0, DATA.max_floor)
	deepest_lift = clampi(int(data.get("deepest_lift", 0)), 0, DATA.max_floor)
	deepest_lift -= deepest_lift % step
	# Save v15 ke bawah belum punya daftar boss: semua boss belum kalah.
	for value in data.get("bosses", []):
		var floor_number := int(value)
		if floor_number > 0 and not bosses_defeated.has(floor_number):
			bosses_defeated.append(floor_number)
	bosses_defeated.sort()
