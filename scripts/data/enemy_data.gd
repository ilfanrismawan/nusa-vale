class_name EnemyData
extends Resource

## Data satu jenis musuh. File: resources/enemies/<id>.tres.
## Phase 4B-1 hanya memakai musuh sebagai target (diam di tempat, melukai bila disentuh);
## gerak dan AI menyusul di Phase 4B-2.

@export var id: StringName
@export var display_name: String = ""

@export_group("Gambar")
## Folder berisi Idle.png, Damage.png, Dead.png (res://assets/farm_rpg/Enemy/..., huruf E besar).
@export_dir var sprite_folder: String = ""
## Ukuran satu frame di sheet. Baris pertama sheet = menghadap ke bawah.
@export var frame_size: Vector2i = Vector2i(32, 32)
@export_range(1.0, 24.0) var animation_fps: float = 8.0
## Geser gambar supaya kaki musuh berada di titik asal node.
@export var sprite_offset: Vector2 = Vector2(0, -8)

@export_group("Statistik")
@export_range(1, 9999) var max_hp: int = 20
## Serangan musuh; pemain menerima max(1, attack - total DEF).
@export_range(0, 999) var attack: int = 5
@export_range(0, 999) var defense: int = 0
## true = melukai pemain yang menyentuhnya.
@export var contact_damage: bool = true
@export_range(2.0, 32.0) var body_radius: float = 6.0
## 0 = terdorong penuh, 1 = tidak bergeser saat kena.
@export_range(0.0, 1.0, 0.05) var knockback_resist: float = 0.0

@export_group("Suara")
## Preset Juice (resources/feedback/<key>.tres) saat musuh terkena dan saat mati.
@export var hit_feedback: StringName = &"creature_hit"
@export var death_feedback: StringName = &"enemy_death"

@export_group("Hadiah")
## item_id yang jatuh saat mati. Kosong = tidak ada.
@export var drop_item_id: String = ""
@export_range(0.0, 1.0, 0.05) var drop_chance: float = 0.5
@export_range(1, 10) var drop_min: int = 1
@export_range(1, 10) var drop_max: int = 1
