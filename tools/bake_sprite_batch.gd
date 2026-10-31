@tool
extends EditorScript
## Pilih node SpriteBatch2D (mis. Town/YSortEntities/ForestTrees), lalu
## File > Run (Ctrl+Shift+X) di Script Editor.
## - Bila node punya anak Sprite2D polos: anak itu dipadatkan ke data batch.
## - Bila tidak: seluruh instance dibongkar jadi anak Sprite2D agar bisa
##   digeser satu per satu; jalankan lagi setelah selesai untuk memadatkan.
## Sprite2D yang punya anak (mis. pohon ber-StaticBody2D) tidak disentuh.


func _run() -> void:
	var selected := EditorInterface.get_selection().get_selected_nodes()
	if selected.size() != 1 or not selected[0] is SpriteBatch2D:
		push_error("Pilih tepat satu node SpriteBatch2D.")
		return
	var batch: SpriteBatch2D = selected[0]
	var sprites: Array[Sprite2D] = []
	for child in batch.get_children():
		if child is Sprite2D and child.get_child_count() == 0 and child.texture != null:
			sprites.append(child)
	if sprites.is_empty():
		_unpack(batch)
	else:
		_pack(batch, sprites)


func _pack(batch: SpriteBatch2D, sprites: Array[Sprite2D]) -> void:
	var textures := batch.textures.duplicate()
	var offsets := batch.texture_offsets.duplicate()
	var colors := batch.colors.duplicate()
	var positions := batch.positions.duplicate()
	var texture_ids := batch.texture_ids.duplicate()
	var color_ids := batch.color_ids.duplicate()
	var flips := batch.flips.duplicate()
	for sprite in sprites:
		var texture_id := -1
		for i in textures.size():
			if textures[i] == sprite.texture and offsets[i] == sprite.offset:
				texture_id = i
		if texture_id < 0:
			textures.append(sprite.texture)
			offsets.append(sprite.offset)
			texture_id = textures.size() - 1
		var color_id := colors.find(sprite.modulate)
		if color_id < 0:
			colors.append(sprite.modulate)
			color_id = colors.size() - 1
		if texture_id > 255 or color_id > 255:
			push_error("SpriteBatch2D mendukung maksimal 256 tekstur dan 256 warna.")
			return
		positions.append(sprite.position)
		texture_ids.append(texture_id)
		color_ids.append(color_id)
		flips.append(1 if sprite.flip_h else 0)
	batch.textures = textures
	batch.texture_offsets = offsets
	batch.colors = colors
	batch.positions = positions
	batch.texture_ids = texture_ids
	batch.color_ids = color_ids
	batch.flips = flips
	for sprite in sprites:
		sprite.get_parent().remove_child(sprite)
		sprite.queue_free()
	print("SpriteBatch2D: %d sprite dipadatkan, total %d." % [sprites.size(), positions.size()])


func _unpack(batch: SpriteBatch2D) -> void:
	var owner := EditorInterface.get_edited_scene_root()
	for i in batch.positions.size():
		var sprite := Sprite2D.new()
		sprite.name = "Sprite%04d" % i
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = batch.positions[i]
		sprite.texture = batch.textures[batch.texture_ids[i]]
		sprite.offset = batch.texture_offsets[batch.texture_ids[i]]
		sprite.modulate = batch.colors[batch.color_ids[i]]
		sprite.flip_h = batch.flips[i] & 1
		batch.add_child(sprite)
		sprite.owner = owner
	print("SpriteBatch2D: %d instance dibongkar menjadi Sprite2D." % batch.positions.size())
	batch.positions = PackedVector2Array()
	batch.texture_ids = PackedByteArray()
	batch.color_ids = PackedByteArray()
	batch.flips = PackedByteArray()
