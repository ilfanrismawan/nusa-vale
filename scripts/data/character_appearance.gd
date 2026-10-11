class_name CharacterAppearance
extends Resource

## Tampilan karakter yang dipilih pemain. Disimpan di save lewat to_dict().
## Nilai part = CharacterPart.id, nilai warna = salah satu CharacterPart.colors.
## Default = tampilan Josh (sama persis dengan sheet pre-made lama).

@export var skin: String = "skin_3"
@export var eyes: String = "eyes_male"
@export var eye_color: String = "black"
@export var hair: String = "hair_josh"
@export var hair_color: String = "black"
@export var outfit: String = "outfit_farm"
@export var outfit_color: String = "blue"
## Kosong = tanpa aksesori.
@export var face: String = ""
@export var head: String = ""
@export var head_color: String = ""
## Kosong memakai celana bawaan baju (kompatibel dengan save lama).
@export var pants: String = ""

const FIELDS: Array[String] = [
	"skin", "eyes", "eye_color", "hair", "hair_color",
	"outfit", "outfit_color", "face", "head", "head_color", "pants",
]

func to_dict() -> Dictionary:
	var data := {}
	for field in FIELDS:
		data[field] = get(field)
	return data

## Key yang hilang atau bukan String memakai nilai default.
static func from_dict(data: Dictionary) -> CharacterAppearance:
	var result := CharacterAppearance.new()
	for field in FIELDS:
		var value: Variant = data.get(field)
		if value is String:
			result.set(field, value)
	return result

## Kunci unik untuk cache gambar hasil bake.
func get_key() -> String:
	var parts: PackedStringArray = []
	for field in FIELDS:
		parts.append(str(get(field)))
	return "|".join(parts)
