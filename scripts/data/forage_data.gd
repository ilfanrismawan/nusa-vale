class_name ForageData
extends Resource
## Satu jenis barang liar yang bisa dipungut (foraging).
## File-nya di resources/forage_data/<item_id>.tres, dimuat otomatis oleh ForageManager.

@export var item: ItemData
## Musim munculnya: "spring", "summer", "fall", "winter". Kosong = semua musim.
@export var seasons: PackedStringArray = []
## Area tempat muncul, cocok dengan ForageSpawner.location_id (mis. "forest").
@export var locations: PackedStringArray = ["forest"]
## Bobot acak relatif; 1.0 = biasa, 0.2 = langka.
@export_range(0.01, 10.0, 0.01) var weight: float = 1.0


func is_available(location_id: String, season: String) -> bool:
	if item == null:
		return false
	if not locations.has(location_id):
		return false
	return seasons.is_empty() or seasons.has(season)
