class_name BossData
extends EnemyData

## Boss Guardian gua (GDD 8.2-C): arena kabut, bar HP besar, fase, serangan bertelegraf,
## serangan tak bisa ditahan, anti-kiting, dan mode murka. Statistik dasar (HP, ATK, DEF, poise,
## gambar) memakai grup EnemyData biasa; angka jurus ada di bawah.
## File: resources/enemies/boss_<id>.tres, dipasang di CaveData.bosses.

@export_group("Boss")
## Nama besar di bar HP bawah layar.
@export var title: String = "Boss"
## Lantai gua tempat arena boss ini.
@export_range(1, 999) var floor_number: int = 20
## Gambar musuh biasa diperbesar sebesar ini.
@export_range(1.0, 5.0, 0.1) var sprite_scale: float = 2.5
## Jeda istirahat di antara jurus (dikali tempo fase).
@export_range(0.1, 5.0, 0.05) var rest_time: float = 1.1

@export_group("Fase")
## HP di bawah rasio ini = fase 2 / fase 3 (0 = tidak ada fase itu).
@export_range(0.0, 1.0, 0.05) var phase2_hp_ratio: float = 0.5
@export_range(0.0, 1.0, 0.05) var phase3_hp_ratio: float = 0.2
## Pengali waktu ancang-ancang dan jeda per fase (lebih kecil = lebih cepat). Indeks 0 = fase 1.
@export var phase_tempo: PackedFloat32Array = PackedFloat32Array([1.0, 0.8, 0.65])
## Pengali damage per fase.
@export var phase_attack: PackedFloat32Array = PackedFloat32Array([1.0, 1.15, 1.3])
## Jumlah hantaman beruntun per fase.
@export var phase_slam_combo: PackedInt32Array = PackedInt32Array([1, 2, 3])
## Lama raungan transisi fase (boss kebal).
@export_range(0.2, 4.0, 0.1) var roar_time: float = 1.4

@export_group("Hantaman (tak bisa ditahan)")
## Melompat lalu mendarat di posisi pemain. Retakan tanah muncul dulu sebagai tanda.
@export_range(0.1, 3.0, 0.05) var slam_windup: float = 0.8
@export_range(0.1, 2.0, 0.05) var slam_air_time: float = 0.55
@export_range(8.0, 80.0) var slam_radius: float = 30.0
@export_range(1, 999) var slam_damage: int = 22

@export_group("Terjangan (bisa di-parry)")
@export_range(0.1, 3.0, 0.05) var charge_windup: float = 0.55
@export_range(40.0, 400.0) var charge_speed: float = 190.0
@export_range(0.1, 1.5, 0.05) var charge_time: float = 0.45
@export_range(1, 999) var charge_damage: int = 16
## Terjangan dipilih bila pemain sedekat ini.
@export_range(16.0, 200.0) var charge_range: float = 80.0

@export_group("Semburan (bisa ditahan)")
@export_range(0.1, 3.0, 0.05) var spit_windup: float = 0.45
@export_range(40.0, 400.0) var spit_speed: float = 150.0
@export_range(1, 999) var spit_damage: int = 10
## Jumlah gumpalan per fase dan sudut sebarannya.
@export var phase_spit_count: PackedInt32Array = PackedInt32Array([3, 5, 7])
@export_range(0.0, 90.0) var spit_spread_deg: float = 18.0

@export_group("Anti-kiting")
## Pemain menjaga jarak lebih jauh dari ini selama kite_time = boss melompat menghantam
## (gap-closer) atau menyembur cepat.
@export_range(32.0, 400.0) var kite_distance: float = 110.0
@export_range(0.5, 10.0, 0.5) var kite_time: float = 2.5
## Kecepatan semburan anti-kiting dikali angka ini.
@export_range(1.0, 4.0, 0.1) var kite_spit_speed_scale: float = 1.8

@export_group("Pecah (fase 2+)")
## Anak slime yang dipanggil. Kosong = jurus ini dilewati.
@export var minion: EnemyData
@export_range(0, 8) var split_count: int = 3
## Maksimal anak hidup bersamaan.
@export_range(0, 12) var split_max: int = 4
@export_range(1.0, 60.0) var split_cooldown: float = 14.0

@export_group("Hujan Emas (fase 3, jurus pamungkas)")
@export_range(1, 16) var rain_count: int = 7
@export_range(8.0, 60.0) var rain_radius: float = 20.0
@export_range(1, 999) var rain_damage: int = 18
## Tanda retakan tiap gumpalan sebelum jatuh.
@export_range(0.2, 3.0, 0.05) var rain_delay: float = 0.9
@export_range(1.0, 60.0) var rain_cooldown: float = 12.0

@export_group("Murka (enrage)")
## Tidak di-stagger selama ini = murka sebentar. Stagger mereset hitungan dan memadamkan murka.
@export_range(5.0, 120.0) var enrage_time: float = 25.0
@export_range(1.0, 30.0) var enrage_duration: float = 8.0
@export_range(1.0, 3.0, 0.05) var enrage_attack_scale: float = 1.3
@export_range(0.3, 1.0, 0.05) var enrage_tempo: float = 0.7

@export_group("Hadiah pertama")
## Diberikan sekali saat boss pertama kali kalah (drop EnemyData biasa tetap jatuh).
@export_range(0, 100000) var reward_money: int = 2000
@export var reward_items: PackedStringArray = PackedStringArray()
@export var reward_counts: PackedInt32Array = PackedInt32Array()

func tempo_for(phase: int) -> float:
	return _pick_float(phase_tempo, phase, 1.0)

func attack_scale_for(phase: int) -> float:
	return _pick_float(phase_attack, phase, 1.0)

func slam_combo_for(phase: int) -> int:
	return maxi(1, _pick_int(phase_slam_combo, phase, 1))

func spit_count_for(phase: int) -> int:
	return maxi(1, _pick_int(phase_spit_count, phase, 3))

## Jumlah fase boss ini (1-3).
func phase_count() -> int:
	if phase2_hp_ratio <= 0.0:
		return 1
	return 3 if phase3_hp_ratio > 0.0 and phase3_hp_ratio < phase2_hp_ratio else 2

## Fase untuk sisa HP (rasio 0..1).
func phase_for_ratio(ratio: float) -> int:
	if phase_count() >= 3 and ratio <= phase3_hp_ratio:
		return 3
	if phase_count() >= 2 and ratio <= phase2_hp_ratio:
		return 2
	return 1

static func _pick_float(values: PackedFloat32Array, phase: int, fallback: float) -> float:
	if values.is_empty():
		return fallback
	return values[clampi(phase - 1, 0, values.size() - 1)]

static func _pick_int(values: PackedInt32Array, phase: int, fallback: int) -> int:
	if values.is_empty():
		return fallback
	return values[clampi(phase - 1, 0, values.size() - 1)]
