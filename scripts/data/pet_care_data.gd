class_name PetCareData
extends Resource
## Aturan rawat peliharaan pemain 1 (GDD 4.10.12). File: resources/animals/pet_care.tres.
## Tampilan tiap pilihan kucing/anjing ada di resources/pets/<pet_id>.tres.

@export_range(1, 1000) var max_affection := 100
## Kasih sayang dari dielus sekali sehari.
@export_range(0, 100) var pet_gain := 5
## Kasih sayang dari diberi makan sekali sehari.
@export_range(0, 100) var feed_gain := 3
## Kategori item yang mau dimakan (ItemData.Category).
@export var food_categories: Array[ItemData.Category] = [ItemData.Category.FISH, ItemData.Category.FOOD]
## Jam main di depan rumah ladang (selain itu di dalam rumah).
@export_range(0, 23) var day_start := 6
@export_range(1, 24) var day_end := 20
@export_range(4.0, 120.0, 1.0) var wander_radius := 26.0
@export_range(4.0, 120.0, 1.0) var speed := 22.0
## Siulan: lama main di dekat pemain (detik), kecepatan lari, jarak berhenti dari pemain, jeda.
@export_range(1.0, 120.0, 0.5) var call_seconds := 12.0
@export_range(10.0, 200.0, 1.0) var call_speed := 64.0
@export_range(4.0, 48.0, 1.0) var call_gap := 12.0
@export_range(0, 10000, 100) var whistle_cooldown_ms := 1500
