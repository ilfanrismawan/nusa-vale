class_name WeedData
extends Resource
## Satu jenis rumput liar. Gambar dipilih per musim dari region di texture.
## File di resources/weed_data/*.tres dimuat otomatis oleh WeedSpawner.

@export var id: String = "weed"
@export var texture: Texture2D
## Region 16x16 per musim. Kosong = pakai regions_spring.
@export var regions_spring: Array[Rect2] = []
@export var regions_summer: Array[Rect2] = []
@export var regions_fall: Array[Rect2] = []
@export var regions_winter: Array[Rect2] = []
## Area tempat rumput ini tumbuh (location_id spawner).
@export var locations: PackedStringArray = ["farm", "forest"]
@export_range(0.0, 10.0, 0.05) var weight: float = 1.0
@export_category("Drop")
@export var drop_item: ItemData
@export_range(0.0, 1.0, 0.05) var drop_chance: float = 0.6
@export_range(1, 5) var drop_count: int = 1


func regions_for(season: String) -> Array[Rect2]:
	var list: Array[Rect2] = regions_spring
	match season:
		"summer":
			list = regions_summer
		"fall", "autumn":
			list = regions_fall
		"winter":
			list = regions_winter
	return list if not list.is_empty() else regions_spring
