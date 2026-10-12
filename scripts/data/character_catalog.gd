class_name CharacterCatalog
extends Resource

## Daftar semua pilihan tampilan + resep sheet animasi.
## Satu file: res://resources/character/character_catalog.tres

@export var parts: Array[CharacterPart] = []
@export var sheets: Array[CharacterSheet] = []

## Scene yang memegang SpriteFrames asli (Josh). Dipakai sebagai template
## nama animasi, kecepatan, durasi, dan region frame.
@export_file("*.tscn") var template_scene: String = "res://scenes/player/Player.tscn"
@export var template_node: String = "AnimatedSprite2D"

func get_parts(layer: CharacterPart.Layer) -> Array[CharacterPart]:
	var result: Array[CharacterPart] = []
	for part in parts:
		if part != null and part.layer == layer:
			result.append(part)
	return result

func find_part(id: String) -> CharacterPart:
	if id.is_empty():
		return null
	for part in parts:
		if part != null and part.id == id:
			return part
	return null

## Mengembalikan salinan appearance dengan id/warna yang tidak dikenal
## diganti default (save lama atau katalog yang berubah tetap aman).
func sanitize(appearance: CharacterAppearance) -> CharacterAppearance:
	var fallback := CharacterAppearance.new()
	var result: CharacterAppearance = appearance.duplicate() if appearance != null else fallback.duplicate()
	result.skin = _valid_part(result.skin, CharacterPart.Layer.SKIN, fallback.skin, false)
	result.eyes = _valid_part(result.eyes, CharacterPart.Layer.EYES, fallback.eyes, false)
	result.hair = _valid_part(result.hair, CharacterPart.Layer.HAIR, fallback.hair, false)
	result.outfit = _valid_part(result.outfit, CharacterPart.Layer.OUTFIT, fallback.outfit, false)
	result.face = _valid_part(result.face, CharacterPart.Layer.FACE, "", true)
	result.head = _valid_part(result.head, CharacterPart.Layer.HEAD, "", true)
	result.pants = _valid_part(result.pants, CharacterPart.Layer.PANTS, "", true)
	result.eye_color = _valid_color(result.eyes, result.eye_color)
	result.hair_color = _valid_color(result.hair, result.hair_color)
	result.outfit_color = _valid_color(result.outfit, result.outfit_color)
	result.head_color = _valid_color(result.head, result.head_color)
	return result

func _valid_part(id: String, layer: CharacterPart.Layer, fallback: String, allow_empty: bool) -> String:
	if id.is_empty() and allow_empty:
		return ""
	var part := find_part(id)
	if part != null and part.layer == layer:
		return id
	return fallback

func _valid_color(part_id: String, color: String) -> String:
	var part := find_part(part_id)
	if part == null:
		return ""
	if not part.has_colors():
		# Pilihan warna boleh disembunyikan dari UI, tetapi asset masih
		# membutuhkan warna untuk placeholder di nama file.
		if part.asset.contains("{color}"):
			var available := _asset_colors(part)
			if color in available:
				return color
			var preferred := "blue" if part.layer == CharacterPart.Layer.OUTFIT else "black"
			if preferred in available:
				return preferred
			return available[0] if not available.is_empty() else preferred
		return ""
	if color in part.colors:
		return color
	return part.colors[0]

func _asset_colors(part: CharacterPart) -> PackedStringArray:
	for sheet in sheets:
		if sheet == null:
			continue
		var folder := sheet.part_folder.path_join(part.asset.get_base_dir())
		if not DirAccess.dir_exists_absolute(folder):
			continue
		var result: PackedStringArray = []
		for file in ResourceLoader.list_directory(folder):
			if file.get_extension().to_lower() == "png":
				result.append(file.get_basename().to_lower())
		if not result.is_empty():
			return result
	return []
