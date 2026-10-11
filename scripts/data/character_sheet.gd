class_name CharacterSheet
extends Resource

## Resep untuk menyusun ulang satu sheet karakter dari layer terpisah.
## `source_sheet` adalah sheet pre-made (Josh) yang dipakai SpriteFrames Player.
## Builder membuat gambar baru dengan ukuran dan tata letak yang sama
## (baris: down, up, right), lalu mengganti atlas tiap frame. Nama animasi,
## kecepatan, durasi frame, dan hit_frame tetap dari SpriteFrames lama.

@export_file("*.png") var source_sheet: String = ""
## Folder animasi berlayer, mis. "res://assets/farm_rpg/Character/PNG/2. Walk".
@export_dir var part_folder: String = ""
## Ukuran satu frame di source_sheet (32, atau 64 untuk animasi memancing).
@export var frame_size: int = 32
## Jumlah arah di sheet layer (4 = down, up, right, left; 1 = satu arah saja).
@export var directions: int = 4

@export_group("Tool")
## Jenis alat yang terlihat di animasi ini (nilai ToolData.ToolType), -1 = tanpa alat.
@export var tool_type: int = -1
## Path relatif layer alat, {tier} = 1..10 (wood..obsidian).
@export var tool_asset: String = ""

@export_group("Extra")
## Layer tambahan yang selalu digambar paling atas (mis. "Weapons/Fish FX.png").
@export var extra_layers: PackedStringArray = []
