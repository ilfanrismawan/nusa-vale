class_name RodData
extends ToolData
## Data khusus pancing per tier. Semua pengali bernilai 1.0 = tanpa efek.
## Kemampuan bersifat kumulatif: tier atas memakai nilai yang sudah termasuk bonus tier bawah.

@export_category("Lemparan")
## Jarak lempar minimum dan maksimum, dalam tile (16 px).
@export var min_cast_tiles: float = 1.0
@export var max_cast_tiles: float = 3.0
## Detik untuk mengisi power dari 0 ke 100% (lalu memantul turun).
@export var charge_time: float = 1.2
## Power di atas (1 - perfect_window) dihitung lemparan "Sempurna!".
@export_range(0.0, 0.5, 0.01) var perfect_window: float = 0.05

@export_category("Kemampuan")
## Pengali lama menunggu gigitan (0.75 = 25% lebih cepat).
@export var bite_time_mult: float = 1.0
## Pengali ukuran zona hijau di mini-game.
@export var zone_mult: float = 1.0
## Pengali turunnya progres saat ikan di luar zona.
@export var drain_mult: float = 1.0
## Pengali kecepatan gerak ikan di mini-game.
@export var fish_speed_mult: float = 1.0
## Pengali peluang ikan tier Langka ke atas.
@export var rare_weight_mult: float = 1.0
## Pengali peluang ikan Legendaris (ditumpuk dengan rare_weight_mult).
@export var legendary_weight_mult: float = 1.0
## Peluang mendapat 2 ikan sekaligus (0.1 = 10%).
@export_range(0.0, 1.0, 0.01) var double_catch_chance: float = 0.0

func ability_text() -> String:
	return "Lempar %.1f–%.1f petak | Stamina %d\nGigitan %.2fx waktu | Zona %.2fx\nDrain %.2fx | Gerak ikan %.2fx\nBobot langka %.2fx | Legendaris %.2fx\nTangkapan ganda %d%% | Perfect %d%%" % [min_cast_tiles, max_cast_tiles, stamina_cost, bite_time_mult, zone_mult, drain_mult, fish_speed_mult, rare_weight_mult, legendary_weight_mult, roundi(double_catch_chance * 100), roundi(perfect_window * 100)]
