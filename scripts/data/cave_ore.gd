class_name CaveOre
extends Resource

## Satu jenis batu tambang di gua (GDD 9). Dipakai CaveData; batu dibangun dari rock.tscn.

@export var item_id: String = "stone"
## Scene batu khusus (mis. small_rock.tscn untuk batu biasa). Kosong = rock.tscn dengan
## gambar bijih dari `stone with minerals.png`.
@export var scene: PackedScene
## Kolom 16 px di `stone with minerals.png` (0 Tembaga, 1 Besi, 2 Emas, 3 Platinum, 4 ungu,
## 5 merah, 6 hijau, 7 biru, 8 gelap, 9 merah muda).
@export_range(0, 9) var sprite_column: int = 0
## Beliung minimal (tier ToolData) untuk menambangnya.
@export var minimum_tool_tier: ToolData.ToolTier = ToolData.ToolTier.WOOD
@export_range(1, 20) var health: int = 3
@export_range(1, 10) var drop_min: int = 1
@export_range(1, 10) var drop_max: int = 2
