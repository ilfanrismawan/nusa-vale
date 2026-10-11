class_name SeasonalTileSwapper
extends Node
## Menukar tekstur TileSetAtlasSource di semua TileMapLayer di bawah parent
## sesuai musim aktif. Letakkan sebagai anak root scene dunia.
## Set di resources/seasons/ dipakai otomatis; `texture_sets` untuk tambahan per scene.

@export var texture_sets: Array[SeasonalTextureSet] = []

func _ready() -> void:
	DayCycle.season_changed.connect(_apply)
	SaveManager.game_loaded.connect(_on_game_loaded)
	_apply(DayCycle.get_season())

func _on_game_loaded() -> void:
	_apply(DayCycle.get_season())

func _apply(season: int) -> void:
	var seen: Dictionary = {}
	for layer in _find_layers(get_parent()):
		var ts := layer.tile_set
		if ts == null or seen.has(ts):
			continue
		seen[ts] = true
		for i in ts.get_source_count():
			var src := ts.get_source(ts.get_source_id(i)) as TileSetAtlasSource
			if src == null:
				continue
			var tex_set := SeasonalTextureSet.find_for(src.texture, texture_sets)
			if tex_set:
				src.texture = tex_set.get_for(season)

func _find_layers(root: Node) -> Array[TileMapLayer]:
	var out: Array[TileMapLayer] = []
	for c in root.get_children():
		if c is TileMapLayer:
			out.append(c)
		out.append_array(_find_layers(c))
	return out
