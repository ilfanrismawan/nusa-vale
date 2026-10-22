class_name RolePerk
extends Resource

## Satu perk di pohon keahlian role (GDD 13.2). File role ada di resources/skills/roles/.
## branch kosong = aktif otomatis saat level tercapai; "a"/"b" = cabang spesialisasi
## yang dipilih pemain di Lv5 dan Lv10 (layar rekap tidur).

@export_range(1, 10) var level: int = 1
## "", "a", atau "b".
@export var branch: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
## Efek angka: kunci stat -> nilai. Nilai perk aktif dijumlah (lihat daftar kunci di SkillSystem).
@export var effects: Dictionary[StringName, float] = {}
## true = sistem pendukungnya belum ada di game: tampil "Segera hadir" dan belum berefek.
@export var coming_soon: bool = false

@export_group("Skill Tree UI")
@export var ui_icon: Texture2D
@export var ui_position := Vector2(-1, -1)
