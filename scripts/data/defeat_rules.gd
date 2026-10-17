class_name DefeatRules
extends Resource

## Yang terjadi saat HP pemain habis (GDD 4.2 dan 8.1). File: resources/combat/defeat_rules.tres.
## Urutan: tumbang, layar pindah ke Klinik Desa (denda dibayar di sana), lalu bangun di rumah.

@export_group("Klinik")
@export_file("*.tscn") var clinic_scene: String = "res://scenes/world/interior/town/clinic.tscn"
@export var clinic_position: Vector2 = Vector2(240, 200)
## Lama pemain terbaring di klinik sebelum dipulangkan (detik).
@export_range(0.5, 10.0, 0.1) var clinic_seconds: float = 2.5

@export_group("Bangun di rumah")
@export_file("*.tscn") var respawn_scene: String = "res://scenes/world/interior/interior_house.tscn"
@export var respawn_position: Vector2 = Vector2(317, 151)
## HP dan stamina setelah bangun, bagian dari nilai maksimum.
@export_range(0.1, 1.0, 0.05) var hp_after_respawn: float = 0.5
@export_range(0.1, 1.0, 0.05) var stamina_after_respawn: float = 0.5
## Solo: hari berganti dan pemain bangun jam wake_hour (GDD 4.2). Co-op: waktu tetap jalan
## untuk pemain lain, jadi hanya pemain yang tumbang yang dipulangkan.
@export var wake_next_morning: bool = true
@export_range(6, 12) var wake_hour: int = 8

@export_group("Denda")
## Persen uang bersama yang dipotong sebagai biaya perawatan.
@export_range(0, 100) var money_penalty_percent: int = 10
## Batas atas biaya perawatan (0 = tanpa batas).
@export_range(0, 100000) var money_penalty_max: int = 1000
## Jumlah tumpukan barang acak di tas yang berkurang. Alat, senjata, perlengkapan,
## bangunan, dan Biji Daya tidak pernah hilang.
@export_range(0, 10) var item_loss_stacks: int = 2
## Bagian tiap tumpukan terpilih yang hilang (dibulatkan ke atas).
@export_range(0.0, 1.0, 0.05) var item_loss_fraction: float = 0.5

@export_group("Waktu")
## Lama animasi tumbang sebelum layar pindah (detik).
@export_range(0.2, 5.0, 0.1) var collapse_seconds: float = 1.4
