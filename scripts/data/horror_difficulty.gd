class_name HorrorDifficulty
extends Resource

## Kesulitan Gaib (GDD 4.1, Progres Horor), dipilih per save. File: resources/horror/difficulty/*.tres.
## Mengatur seberapa kejam angka horor; hantu yang muncul tetap ditentukan Tingkat Gaib.

@export var id: StringName = &"normal"
@export var display_name: String = "Normal"
@export_multiline var description: String = ""
## Hanya Suasana: kabut, ambience, dan kejadian ganjil tetap ada; tanpa makhluk dan tanpa denda.
@export var ambience_only: bool = false

@export_range(0.0, 3.0, 0.05) var fear_rise_scale: float = 1.0
## Dikali peluang muncul makhluk dari Tingkat Gaib.
@export_range(0.0, 3.0, 0.01) var stalker_chance_scale: float = 1.0
## Dikali energi yang hilang saat disentuh makhluk.
@export_range(0.0, 3.0, 0.05) var penalty_scale: float = 1.0
@export var jumpscare_can_faint: bool = false
## Dikali radius aman cahaya.
@export_range(0.2, 3.0, 0.01) var safe_radius_scale: float = 1.0
## Dikali hadiah material malam (Tahap 3).
@export_range(0.0, 3.0, 0.05) var reward_scale: float = 1.0
## Dikali besaran pencurian Tuyul (Tahap 4). 0 = tidak mencuri.
@export_range(0.0, 3.0, 0.05) var theft_scale: float = 1.0
