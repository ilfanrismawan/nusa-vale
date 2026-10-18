class_name HouseLevelData
extends Resource

## Satu tingkat upgrade rumah yang dibangun Wira, tukang kayu (GDD 4.12).
## File resources/house/house_level_<n>.tres; n = tingkat sesudah upgrade (1 = upgrade pertama).

@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export_range(0, 9999999) var price: int = 1000
@export var materials: Dictionary[String, int] = {}
## Jumlah pergantian hari sampai selesai (0 = langsung jadi).
@export_range(0, 28) var build_days: int = 2
## Flag WorldState yang menyala saat tingkat ini selesai.
@export var grants_flags: PackedStringArray = []
## Tambahan stamina maksimum untuk semua pemain selama rumah di tingkat ini atau lebih.
@export_range(0, 200) var stamina_bonus: int = 0
@export_multiline var completed_message: String
