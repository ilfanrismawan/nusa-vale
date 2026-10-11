class_name CharacterSpriteBuilder
extends RefCounted

## Menyusun SpriteFrames karakter dari layer terpisah
## (assets/farm_rpg/Character/PNG/<animasi>/Skins, Eyes, Clothers, Hair's, Acc, Weapons).
##
## Cara kerja: SpriteFrames asli Player (sheet pre-made Josh) dipakai sebagai template.
## Untuk tiap sheet Josh yang punya resep CharacterSheet, layer ditumpuk ke Image baru
## dengan tata letak yang sama, lalu setiap AtlasTexture diarahkan ke Image itu.
## Nama animasi, kecepatan, loop, durasi frame, dan hit_frame tidak berubah.

const LAYER_ORDER: Array[CharacterPart.Layer] = [
	CharacterPart.Layer.SKIN,
	CharacterPart.Layer.EYES,
	CharacterPart.Layer.OUTFIT,
	CharacterPart.Layer.HAIR,
	CharacterPart.Layer.FACE,
	CharacterPart.Layer.HEAD,
]

static var _template: SpriteFrames
static var _image_cache: Dictionary = {}
static var _dir_cache: Dictionary = {}
static var _warned: Dictionary = {}
static var _clothing_cache: Dictionary = {}
static var _hair_cache: Dictionary = {}

## Hasil: {"frames": SpriteFrames, "textures": {source_sheet: ImageTexture}}.
## `tool_tiers`: {ToolData.ToolType: ToolData.ToolTier}. Tipe yang tidak ada = WOOD.
## `only_animations`: kosong = semua animasi; isi untuk preview cepat (mis. idle, walk).
static func build(
		catalog: CharacterCatalog,
		appearance: CharacterAppearance,
		tool_tiers: Dictionary = {},
		only_animations: PackedStringArray = []
) -> Dictionary:
	var template := get_template(catalog)
	var frames := SpriteFrames.new()
	var textures := {}
	if template == null:
		return {"frames": frames, "textures": textures}

	var sheets := {}
	for sheet in catalog.sheets:
		if sheet != null:
			sheets[sheet.source_sheet] = sheet

	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")

	for anim in template.get_animation_names():
		if not only_animations.is_empty() and not only_animations.has(String(anim)):
			continue
		frames.add_animation(anim)
		frames.set_animation_speed(anim, template.get_animation_speed(anim))
		frames.set_animation_loop(anim, template.get_animation_loop(anim))
		for i in template.get_frame_count(anim):
			var texture := template.get_frame_texture(anim, i)
			var duration := template.get_frame_duration(anim, i)
			frames.add_frame(anim, _swap_atlas(texture, sheets, textures, catalog, appearance, tool_tiers), duration)

	return {"frames": frames, "textures": textures}

## Menyusun satu sheet. `size` = ukuran sheet Josh yang digantikan.
static func compose_sheet(
		sheet: CharacterSheet,
		catalog: CharacterCatalog,
		appearance: CharacterAppearance,
		tool_tier: int,
		size: Vector2i
) -> Image:
	var out := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for path in _layer_paths(sheet, catalog, appearance, tool_tier):
		var layer := _load_image(path)
		if layer != null:
			var hair := catalog.find_part(appearance.hair)
			if (path.contains("/Hair's/") or path.contains("/Hair/")) and hair != null and hair.hair_style == "korean_curtain":
				var hair_key := "%s|%d" % [path, sheet.directions]
				if not _hair_cache.has(hair_key):
					_hair_cache[hair_key] = CharacterHairStyler.curtain(layer, sheet.directions)
				layer = _hair_cache[hair_key]
			if path.contains("/Clothers/"):
				var outfit := catalog.find_part(appearance.outfit)
				var style := outfit.clothing_style if outfit != null else ""
				var key := "%s|%s|%s" % [path, style, appearance.pants]
				if not _clothing_cache.has(key):
					var reference_path := _resolve_file(sheet.part_folder, "Clothers/Track Jacket/Black.png")
					var reference := _load_image(reference_path) if not reference_path.is_empty() else layer
					_clothing_cache[key] = CharacterClothingStyler.apply(layer, style, appearance.pants == "pants_baggy_jeans", reference)
				layer = _clothing_cache[key]
			_blit_layer(out, layer, sheet)
	return out

## SpriteFrames asli dari scene template, dibaca lewat SceneState (tanpa instance).
static func get_template(catalog: CharacterCatalog) -> SpriteFrames:
	if _template != null:
		return _template
	var packed := load(catalog.template_scene) as PackedScene
	if packed == null:
		push_error("CharacterSpriteBuilder: template scene tidak ditemukan: %s" % catalog.template_scene)
		return null
	var state := packed.get_state()
	for i in state.get_node_count():
		if String(state.get_node_name(i)) != catalog.template_node:
			continue
		for p in state.get_node_property_count(i):
			if state.get_node_property_name(i, p) == &"sprite_frames":
				_template = state.get_node_property_value(i, p) as SpriteFrames
				return _template
	push_error("CharacterSpriteBuilder: node '%s' tanpa sprite_frames di %s" % [catalog.template_node, catalog.template_scene])
	return null

static func _swap_atlas(
		texture: Texture2D,
		sheets: Dictionary,
		textures: Dictionary,
		catalog: CharacterCatalog,
		appearance: CharacterAppearance,
		tool_tiers: Dictionary
) -> Texture2D:
	var atlas_tex := texture as AtlasTexture
	if atlas_tex == null or atlas_tex.atlas == null:
		return texture
	var source := atlas_tex.atlas.resource_path
	if not sheets.has(source):
		return texture

	if not textures.has(source):
		var sheet: CharacterSheet = sheets[source]
		var tier := int(tool_tiers.get(sheet.tool_type, 0))
		var image := compose_sheet(sheet, catalog, appearance, tier, Vector2i(atlas_tex.atlas.get_size()))
		textures[source] = ImageTexture.create_from_image(image)

	var result := AtlasTexture.new()
	result.atlas = textures[source]
	result.region = atlas_tex.region
	result.margin = atlas_tex.margin
	result.filter_clip = atlas_tex.filter_clip
	return result

static func _layer_paths(
		sheet: CharacterSheet,
		catalog: CharacterCatalog,
		appearance: CharacterAppearance,
		tool_tier: int
) -> PackedStringArray:
	var paths: PackedStringArray = []
	var skin_part := catalog.find_part(appearance.skin)
	var values := {
		"skin": skin_part.asset.get_file().get_basename() if skin_part != null else "1",
		"hair_color": appearance.hair_color.capitalize(),
	}
	var picks := {
		CharacterPart.Layer.SKIN: [appearance.skin, ""],
		CharacterPart.Layer.EYES: [appearance.eyes, appearance.eye_color],
		CharacterPart.Layer.OUTFIT: [appearance.outfit, appearance.outfit_color],
		CharacterPart.Layer.HAIR: [appearance.hair, appearance.hair_color],
		CharacterPart.Layer.FACE: [appearance.face, appearance.hair_color],
		CharacterPart.Layer.HEAD: [appearance.head, appearance.head_color],
	}
	for layer in LAYER_ORDER:
		var pick: Array = picks[layer]
		var part := catalog.find_part(pick[0])
		if part == null:
			continue
		var part_values := values.duplicate()
		part_values["color"] = String(pick[1]).capitalize()
		var path := _resolve_file(sheet.part_folder, part.resolve_asset(part_values))
		if not path.is_empty():
			paths.append(path)

	if sheet.tool_type >= 0 and not sheet.tool_asset.is_empty():
		var tier_number := clampi(tool_tier, 0, ToolData.ToolTier.size() - 1) + 1
		var tool_path := _resolve_file(sheet.part_folder, sheet.tool_asset.replace("{tier}", str(tier_number)))
		if not tool_path.is_empty():
			paths.append(tool_path)

	for extra in sheet.extra_layers:
		var extra_path := _resolve_file(sheet.part_folder, extra)
		if not extra_path.is_empty():
			paths.append(extra_path)
	return paths

## Layer berbentuk satu baris frame persegi, `directions` arah berurutan
## (down, up, right, left). Baris ke-r di sheet tujuan = arah ke-r.
## Frame layer yang lebih kecil dari frame tujuan diletakkan di tengah
## (badan 32px di frame memancing 64px).
@warning_ignore_start("integer_division")
static func _blit_layer(out: Image, layer: Image, sheet: CharacterSheet) -> void:
	var layer_frame := layer.get_height()
	if layer_frame <= 0:
		return
	var count := layer.get_width() / layer_frame
	var per_direction := maxi(count / maxi(sheet.directions, 1), 1)
	var frame_size := sheet.frame_size
	var offset := Vector2i((frame_size - layer_frame) / 2, (frame_size - layer_frame) / 2)
	var rows := out.get_height() / frame_size
	var cols := out.get_width() / frame_size
	for row in rows:
		for col in mini(cols, per_direction):
			var index := row * per_direction + col
			if index >= count:
				continue
			var src := Rect2i(index * layer_frame, 0, layer_frame, layer_frame)
			out.blend_rect(layer, src, Vector2i(col * frame_size, row * frame_size) + offset)
@warning_ignore_restore("integer_division")

static func _load_image(path: String) -> Image:
	if _image_cache.has(path):
		return _image_cache[path]
	var texture := load(path) as Texture2D
	if texture == null:
		_warn_once(path, "CharacterSpriteBuilder: gagal memuat %s" % path)
		return null
	var image := texture.get_image()
	if image == null:
		return null
	if image.is_compressed():
		image.decompress()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	_image_cache[path] = image
	return image

## Mencari file layer. Toleran terhadap beda huruf besar/kecil ("Santa hat.png"),
## folder "Hair" vs "Hair's", dan animasi mata tertutup yang hanya punya satu warna.
static func _resolve_file(folder: String, relative: String) -> String:
	var direct := folder.path_join(relative)
	if ResourceLoader.exists(direct):
		return direct

	var current := folder
	var segments := relative.split("/")
	for i in segments.size():
		var is_last := i == segments.size() - 1
		var match_name := _match_entry(current, segments[i], not is_last)
		if match_name.is_empty():
			if is_last and relative.begins_with("Eyes/"):
				var any_eye := _first_png(current)
				if not any_eye.is_empty():
					return current.path_join(any_eye)
			# Folder layer utama tidak ada = animasi ini memang tanpa layer itu
			# (mis. Sleep tanpa Clothers). Hanya file yang hilang yang diperingatkan.
			if i > 0:
				_warn_once(direct, "CharacterSpriteBuilder: layer tidak ada, dilewati: %s" % direct)
			return ""
		current = current.path_join(match_name)
	return current

static func _match_entry(dir: String, wanted: String, is_dir: bool) -> String:
	var wanted_lower := wanted.to_lower()
	var aliases := [wanted_lower]
	if wanted_lower == "hair's":
		aliases.append("hair")
	elif wanted_lower == "hair":
		aliases.append("hair's")
	for entry in _list_dir(dir):
		var entry_is_dir := entry.ends_with("/")
		if entry_is_dir != is_dir:
			continue
		if entry.trim_suffix("/").to_lower() in aliases:
			return entry.trim_suffix("/")
	return ""

static func _first_png(dir: String) -> String:
	for entry in _list_dir(dir):
		if entry.get_extension().to_lower() == "png":
			return entry
	return ""

static func _list_dir(dir: String) -> PackedStringArray:
	if not _dir_cache.has(dir):
		_dir_cache[dir] = ResourceLoader.list_directory(dir) if DirAccess.dir_exists_absolute(dir) else PackedStringArray()
	return _dir_cache[dir]

static func _warn_once(key: String, message: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning(message)
