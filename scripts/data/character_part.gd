class_name CharacterPart
extends Resource

## Satu pilihan tampilan (kulit, mata, rambut, baju, aksesori).
## `asset` adalah path relatif terhadap folder animasi di
## assets/farm_rpg/Character/PNG/<animasi>/ dan boleh berisi placeholder:
##   {color}      -> warna layer ini (mis. "black" -> "Black")
##   {skin}       -> nomor kulit yang dipilih (1-4)
##   {hair_color} -> warna rambut yang dipilih

## Urutan gambar dari bawah ke atas. Tambah nilai baru hanya di akhir.
enum Layer { SKIN, EYES, OUTFIT, HAIR, FACE, HEAD, PANTS }

@export var id: String = ""
@export var display_name: String = ""
@export var layer: Layer = Layer.SKIN
@export var asset: String = ""
## Warna yang tersedia (snake_case). Kosong = layer ini tidak punya pilihan warna.
@export var colors: PackedStringArray = []
## Desain kode mengikuti mask tiap pose pakaian, bukan gambar statis.
@export var clothing_style: String = ""
@export var hair_style: String = ""
## Artwork sumber desain; runtime memakai adaptasi mask 32px.
@export_file("*.png") var design_source: String = ""

func has_colors() -> bool:
	return not colors.is_empty()

## Path file untuk satu folder animasi, placeholder sudah diganti.
func resolve_asset(values: Dictionary) -> String:
	var path := asset
	for key in values:
		path = path.replace("{%s}" % key, str(values[key]))
	return path
