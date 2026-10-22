extends Choppable
## Pine layers and masks belong to the scene; never replace editor polygons.
##
## Performa: clip_children pada TrunkMask/CanopyMask membuat tiap pinus digambar lewat
## render target sendiri, jadi 150 pinus di farm memakan ~25 ms per frame. Saat game jalan,
## bentuk poligon dari editor "dipanggang" ke tekstur frame (sekali, di-cache untuk semua
## pinus), lalu clip dimatikan. Poligon di scene tetap jadi sumber bentuknya.

## Cache bersama: kunci (atlas, region, bentuk mask) -> ImageTexture yang sudah terpotong.
static var _baked_textures: Dictionary = {}
static var _atlas_images: Dictionary = {}
## Cache SpriteFrames hasil panggang per (sumber, bentuk mask, musim atlas).
static var _baked_frames: Dictionary = {}
static var _mask_images: Dictionary = {}

var _source_frames: SpriteFrames

func _setup_tree_layers() -> void:
	_canopy = get_node("CanopyMask/Canopy") as AnimatedSprite2D
	_source_frames = animated_sprite.sprite_frames
	_bake_masks()
	_sync_tree_layers()

func _sync_tree_layers() -> void:
	if _canopy == null or animated_sprite == null:
		return
	_canopy.animation = animated_sprite.animation
	_canopy.set_frame_and_progress(animated_sprite.frame, animated_sprite.frame_progress)

func _wobble() -> void:
	# Move the masks together, retaining each layer's authored transform.
	for layer_name in ["TrunkMask", "CanopyMask"]:
		var layer := get_node(layer_name) as Node2D
		var base := layer.position
		var tween := create_tween()
		tween.tween_property(layer, "position", base + Vector2(1, 0), 0.04)
		tween.tween_property(layer, "position", base + Vector2(-1, 0), 0.06)
		tween.tween_property(layer, "position", base, 0.04)


## Musim menukar atlas di SpriteFrames sumber, lalu frame hasil panggang dibuat ulang.
func _apply_season(season: int) -> void:
	if _source_frames == null:
		super(season)
		return
	for anim in _source_frames.get_animation_names():
		for i in _source_frames.get_frame_count(anim):
			var atlas_tex := _source_frames.get_frame_texture(anim, i) as AtlasTexture
			if atlas_tex == null:
				continue
			var tex_set := SeasonalTextureSet.find_for(atlas_tex.atlas)
			if tex_set:
				atlas_tex.atlas = tex_set.get_for(season)
	_bake_masks()


func _bake_masks() -> void:
	var trunk_mask := get_node_or_null("TrunkMask") as Polygon2D
	var canopy_mask := get_node_or_null("CanopyMask") as Polygon2D
	if trunk_mask == null or canopy_mask == null or _source_frames == null:
		return
	var trunk_frames := _baked_for(_source_frames, trunk_mask, animated_sprite)
	var canopy_frames := _baked_for(_source_frames, canopy_mask, _canopy)
	if trunk_frames == null or canopy_frames == null:
		return  # Format tidak dikenal: biarkan clip_children dari editor bekerja.
	var anim := animated_sprite.animation
	var frame := animated_sprite.frame
	var progress := animated_sprite.frame_progress
	var playing := animated_sprite.is_playing()
	animated_sprite.sprite_frames = trunk_frames
	_canopy.sprite_frames = canopy_frames
	animated_sprite.animation = anim
	animated_sprite.set_frame_and_progress(frame, progress)
	if playing:
		animated_sprite.play(anim)
	for mask in [trunk_mask, canopy_mask]:
		mask.clip_children = CanvasItem.CLIP_CHILDREN_DISABLED
		mask.self_modulate = Color(1, 1, 1, 0)
	_sync_tree_layers()


## SpriteFrames dengan setiap frame dipotong sesuai poligon mask (dalam ruang mask).
static func _baked_for(source: SpriteFrames, mask: Polygon2D, sprite: AnimatedSprite2D) -> SpriteFrames:
	var shape := mask.polygon.duplicate()
	for i in shape.size():
		shape[i] += mask.offset
	var to_mask: Transform2D = sprite.transform
	var key_parts := [source.get_instance_id(), var_to_str(shape), var_to_str(to_mask), var_to_str(sprite.offset), sprite.centered]
	for anim in source.get_animation_names():
		for i in source.get_frame_count(anim):
			var tex := source.get_frame_texture(anim, i) as AtlasTexture
			if tex == null or tex.atlas == null:
				return null
			key_parts.append(tex.atlas.get_instance_id())
	var key := str(key_parts).hash()
	if _baked_frames.has(key):
		return _baked_frames[key]
	var out := SpriteFrames.new()
	out.remove_animation(&"default")
	for anim in source.get_animation_names():
		out.add_animation(anim)
		out.set_animation_loop(anim, source.get_animation_loop(anim))
		out.set_animation_speed(anim, source.get_animation_speed(anim))
		for i in source.get_frame_count(anim):
			var tex := source.get_frame_texture(anim, i) as AtlasTexture
			var baked := _baked_texture(tex, shape, to_mask, sprite)
			if baked == null:
				return null
			out.add_frame(anim, baked, source.get_frame_duration(anim, i))
	_baked_frames[key] = out
	return out


static func _baked_texture(tex: AtlasTexture, shape: PackedVector2Array, to_mask: Transform2D, sprite: AnimatedSprite2D) -> Texture2D:
	var region := Rect2i(tex.region)
	var key := str([tex.atlas.get_instance_id(), region, var_to_str(shape), var_to_str(to_mask), var_to_str(sprite.offset), sprite.centered]).hash()
	if _baked_textures.has(key):
		return _baked_textures[key]
	var atlas_key := tex.atlas.get_instance_id()
	if not _atlas_images.has(atlas_key):
		var img := tex.atlas.get_image()
		if img == null:
			return null
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		_atlas_images[atlas_key] = img
	var atlas_img: Image = _atlas_images[atlas_key]
	var src := atlas_img.get_region(region)
	var mask := _mask_image(region.size, shape, to_mask, sprite)
	var out := Image.create_empty(region.size.x, region.size.y, false, Image.FORMAT_RGBA8)
	out.blit_rect_mask(src, mask, Rect2i(Vector2i.ZERO, region.size), Vector2i.ZERO)
	var baked := ImageTexture.create_from_image(out)
	_baked_textures[key] = baked
	return baked


## Gambar mask (alpha penuh di dalam poligon) seukuran frame; sama untuk semua frame.
static func _mask_image(size: Vector2i, shape: PackedVector2Array, to_mask: Transform2D, sprite: AnimatedSprite2D) -> Image:
	var key := str([size, var_to_str(shape), var_to_str(to_mask), var_to_str(sprite.offset), sprite.centered]).hash()
	if _mask_images.has(key):
		return _mask_images[key]
	var top_left := sprite.offset - Vector2(size) / 2.0 if sprite.centered else sprite.offset
	var mask := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			if Geometry2D.is_point_in_polygon(to_mask * (top_left + Vector2(x + 0.5, y + 0.5)), shape):
				mask.set_pixel(x, y, Color.WHITE)
	_mask_images[key] = mask
	return mask
