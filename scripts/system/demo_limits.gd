extends RefCounted
## Batas versi demo. Aktif hanya di build yang diexport dengan fitur kustom "demo"
## (preset "Windows Demo" di export_presets.cfg). Build penuh dan editor tidak terpengaruh.
## Save demo memakai format yang sama, jadi bisa dilanjutkan di versi penuh.

const FEATURE := "demo"
## Hari terakhir yang bisa dimainkan (akhir musim Semi tahun pertama).
const LAST_DAY := 28
## Lantai gua terdalam yang bisa dicapai.
const MAX_CAVE_FLOOR := 10
const END_SCREEN := "res://scenes/ui/demo_end_screen.tscn"


static func is_demo() -> bool:
	return OS.has_feature(FEATURE)


## True jika hari ini sudah melewati batas demo.
static func is_day_over_limit(day: int) -> bool:
	return is_demo() and day > LAST_DAY


static func is_floor_locked(floor_number: int) -> bool:
	return is_demo() and floor_number > MAX_CAVE_FLOOR
