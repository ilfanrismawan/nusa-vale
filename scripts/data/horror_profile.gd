class_name HorrorProfile
extends Resource

## Satu Tingkat Gaib (GDD 4.1, Progres Horor). File: resources/horror/profiles/tier_*.tres.
## Tingkat tercapai bila SALAH SATU syarat terpenuhi (0 / kosong = syarat itu tidak dipakai).
## Tingkat 1 tanpa syarat = selalu aktif sejak awal.

@export_range(1, 4) var tier: int = 1
@export var display_name: String = "Bisikan"

@export_group("Syarat")
## Lantai terdalam Gua Tambang yang pernah dicapai.
@export var unlock_cave_floor: int = 0
## Hari permainan (1 tahun = 112 hari; musim ke-3 tahun 1 = hari 57).
@export var unlock_day: int = 0
## Id unlock area (UnlockManager), mis. "deep_forest".
@export var unlock_area: String = ""
## Pesan pagi saat tingkat ini pertama kali tercapai. Kosong = tanpa pesan.
@export_multiline var notify_reached: String = ""

@export_group("Penunggu")
## Makhluk yang boleh muncul sendiri di tingkat ini (scene dengan script NightStalker).
@export var stalkers: Array[PackedScene] = []
## Peluang tiap undian (dikali Kesulitan Gaib).
@export_range(0.0, 1.0, 0.01) var stalker_chance: float = 0.35
## Tiap selang ini (detik nyata) diundi.
@export var stalker_check_interval: float = 15.0
## Jeda setelah makhluk pergi / menyentuh sebelum boleh muncul lagi (detik nyata).
@export var stalker_cooldown: float = 150.0
## Makhluk sekaligus per pemain (tingkat 3+: 2, aturan bisa bertentangan).
@export_range(1, 4) var max_stalkers: int = 1

@export_group("Kejadian Ganjil")
@export var event_interval_min: float = 18.0
@export var event_interval_max: float = 38.0

@export_group("Rasa Takut")
## Pengali kenaikan rasa takut di gelap (dikali lagi oleh Kesulitan Gaib).
@export_range(0.1, 3.0, 0.05) var fear_rise_scale: float = 1.0
## Rasa takut berdampak gameplay (stamina, lari, pandangan berkunang; angka di NightHorror).
@export var fear_effects: bool = false


## true bila progres sekarang memenuhi salah satu syarat tingkat ini.
func is_reached(deepest_floor: int, day: int, is_area_unlocked: Callable) -> bool:
	if unlock_cave_floor <= 0 and unlock_day <= 0 and unlock_area.is_empty():
		return true
	if unlock_cave_floor > 0 and deepest_floor >= unlock_cave_floor:
		return true
	if unlock_day > 0 and day >= unlock_day:
		return true
	return not unlock_area.is_empty() and bool(is_area_unlocked.call(unlock_area))
