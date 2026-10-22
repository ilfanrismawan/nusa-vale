class_name CaveOre
extends Resource

## Satu jenis batu tambang atau kristal permata di gua (GDD 9). Tiap jenis punya file
## sendiri di resources/cave/ores/ dan dipakai CaveData; batu dibangun dari rock.tscn.

@export var item_id: String = "stone"
enum SpawnKind { ROCK, ORE, GEM }
## Kategori zona dungeon; Is Gem yang aktif tetap diperlakukan sebagai GEM.
@export var spawn_kind: SpawnKind = SpawnKind.ORE
## Scene batu khusus (mis. small_rock.tscn untuk batu biasa). Kosong = rock.tscn dengan
## gambar dari `sprite`.
@export var scene: PackedScene
## Gambar batu di gua. Kosong = kolom `sprite_column` di `stone with minerals.png`.
@export var sprite: Texture2D
## Gambar kilat saat dipukul. Kosong = memakai `sprite`.
@export var hit_sprite: Texture2D
@export_range(0.3, 2.0, 0.05) var sprite_scale: float = 1.0
## Cadangan lama: kolom 16 px di `stone with minerals.png` (0 Tembaga, 1 Besi, 2 Emas,
## 3 Platinum, 4 ungu, 5 merah, 6 hijau, 7 biru, 8 gelap, 9 merah muda).
@export_range(0, 9) var sprite_column: int = 0
## Beliung minimal (tier ToolData) untuk menambangnya.
@export var minimum_tool_tier: ToolData.ToolTier = ToolData.ToolTier.WOOD
@export_range(1, 20) var health: int = 3
@export_range(1, 10) var drop_min: int = 1
@export_range(1, 10) var drop_max: int = 2
## Barang tambahan yang kadang ikut jatuh (mis. tanah liat dari batu biasa).
@export var bonus_item_ids: PackedStringArray = []
## Peluang tiap barang tambahan (0-1), sejajar dengan bonus_item_ids.
@export var bonus_chances: PackedFloat32Array = []
## Kristal permata atau mineral (bukan bijih logam).
@export var is_gem: bool = false
