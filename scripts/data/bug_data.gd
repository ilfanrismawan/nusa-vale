extends Resource
## Satu jenis serangga (GDD 7, 4A-3). File: resources/bugs/<item_id>.tres, dimuat BugSpawner.
## Tangkap dengan jaring serangga; hasilnya ItemData `item` (dijual, umpan, Bundel Serangga Balai Nadi).

## Item yang masuk ke tas saat tertangkap. Ikonnya juga jadi sprite serangga di dunia.
@export var item: ItemData
## Musim munculnya ("spring", "summer", "fall", "winter"). Kosong = sepanjang tahun.
@export var seasons: PackedStringArray = []
## Area munculnya, cocok dengan BugSpawner.location_id ("farm", "forest", "town", "mountain", "cave").
@export var locations: PackedStringArray = []
## Waktu muncul: siang 06.00-18.00, malam 18.00-06.00.
@export_enum("any", "day", "night") var time: String = "any"
## Bobot acak relatif; 1.0 = biasa, 0.2 = langka.
@export_range(0.01, 10.0, 0.01) var weight: float = 1.0
## true = terbang mengitari titik asal; false = merayap pelan di tanah.
@export var flying: bool = true
## Kecepatan gerak (px/detik). Serangga cepat lebih sulit didekati dengan jaring kecil.
@export_range(4.0, 120.0, 1.0) var speed: float = 22.0
## Jarak (px) pemain yang membuatnya kabur. 0 = tidak pernah kabur.
@export_range(0.0, 64.0, 1.0) var flee_radius: float = 20.0
## Berpendar di malam hari (kunang-kunang).
@export var glows: bool = false


static func is_night(hour: int) -> bool:
	return hour >= 18 or hour < 6


func is_available(location_id: String, season: String, hour: int) -> bool:
	if item == null or not locations.has(location_id):
		return false
	if not seasons.is_empty() and not seasons.has(season):
		return false
	match time:
		"day":
			return not is_night(hour)
		"night":
			return is_night(hour)
	return true
