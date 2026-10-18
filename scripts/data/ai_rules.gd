class_name AiRules
extends Resource

## Aturan umum AI musuh (GDD 8.2-B): suara, koordinasi token serang, dan pengepungan.
## File: resources/ai/ai_rules.tres (Perception.RULES). Angka per musuh ada di EnemyData.

@export_group("Suara")
## Berlari mengeluarkan suara langkah tiap interval, terdengar sejauh radius (piksel).
@export_range(0.0, 300.0) var run_noise_radius: float = 64.0
@export_range(0.05, 2.0, 0.05) var run_noise_interval: float = 0.4
## Beliung menghantam batu.
@export_range(0.0, 400.0) var mine_noise_radius: float = 112.0
## Senjata beradu: pukulan mengenai musuh, block, atau parry.
@export_range(0.0, 400.0) var clash_noise_radius: float = 96.0

@export_group("Persepsi")
## Jeda antar pemeriksaan penglihatan per musuh (detik). Lebih kecil = lebih peka, lebih berat.
@export_range(0.02, 0.5, 0.01) var perception_interval: float = 0.1

@export_group("Koordinasi")
## Jumlah musuh yang boleh menyerang satu pemain bersamaan (attack ticket).
@export_range(1, 8) var max_attackers: int = 2
## Setelah menyerang, musuh menunggu sekian detik sebelum boleh meminta token lagi
## (supaya kawannya bergantian).
@export_range(0.0, 5.0, 0.05) var ticket_rest: float = 0.8
## Musuh tanpa token mengepung di jarak attack_range + ini, di luar jangkauan pemain.
@export_range(0.0, 80.0) var flank_extra_distance: float = 22.0
## Musuh menjaga jarak satu sama lain saat mengepung.
@export_range(0.0, 64.0) var separation_radius: float = 18.0
## Kecepatan bergeser mengitari pemain (radian per detik).
@export_range(0.0, 6.0, 0.1) var circle_speed: float = 1.4

@export_group("Bantuan")
## Musuh yang mundur memanggil kawan dalam radius ini.
@export_range(0.0, 400.0) var help_radius: float = 112.0
