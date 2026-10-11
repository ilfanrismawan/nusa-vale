class_name SeasonalTextureSet
extends Resource
## Satu tekstur dengan versi per musim. `spring` adalah tekstur yang dipakai di scene;
## musim lain harus berukuran dan ber-layout sama (lihat get_for).
## Semua file .tres di SETS_DIR otomatis dipakai oleh SeasonalTileSwapper dan pohon (Choppable).

const SETS_DIR := "res://resources/seasons/"

@export var spring: Texture2D
@export var summer: Texture2D
@export var fall: Texture2D
@export var winter: Texture2D

static var _registry: Array[SeasonalTextureSet] = []
static var _registry_loaded := false

## Tekstur untuk musim tertentu (0 = semi .. 3 = dingin).
## Jatuh balik ke spring jika musimnya kosong atau ukurannya beda dengan spring:
## atlas coords tile hanya cocok bila layout gambarnya sama persis.
func get_for(season: int) -> Texture2D:
	var tex: Texture2D = spring
	match season:
		1: tex = summer
		2: tex = fall
		3: tex = winter
	if tex == null or spring == null:
		return spring
	if tex.get_size() != spring.get_size():
		push_warning("SeasonalTextureSet: ukuran %s beda dengan spring, pakai spring" % tex.resource_path)
		return spring
	return tex

func has_texture(tex: Texture2D) -> bool:
	return tex != null and (tex == spring or tex == summer or tex == fall or tex == winter)

## Semua set di resources/seasons/ (dimuat sekali).
static func all_sets() -> Array[SeasonalTextureSet]:
	if not _registry_loaded:
		_registry_loaded = true
		for file in ResourceLoader.list_directory(SETS_DIR):
			if file.ends_with(".tres") or file.ends_with(".res"):
				var tex_set := load(SETS_DIR + file) as SeasonalTextureSet
				if tex_set:
					_registry.append(tex_set)
	return _registry

## Set yang memuat tekstur ini (dari daftar `extra` dulu, lalu registry).
static func find_for(tex: Texture2D, extra: Array[SeasonalTextureSet] = []) -> SeasonalTextureSet:
	if tex == null:
		return null
	for s in extra:
		if s and s.has_texture(tex):
			return s
	for s in all_sets():
		if s.has_texture(tex):
			return s
	return null
