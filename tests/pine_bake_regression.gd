extends Node2D
## Pinus: mask poligon editor dipanggang ke tekstur, clip_children mati, hasil sama dengan aslinya.

var failures := 0
var _log: PackedStringArray = []

func check(ok: bool, label: String) -> void:
	_log.append(("PASS: " if ok else "FAIL: ") + label)
	print(_log[-1])
	if not ok:
		failures += 1

func _ready() -> void:
	DayCycle.is_running = false
	var packed := load("res://scenes/objects/pine_tree.tscn") as PackedScene
	var source := (packed.instantiate() as Node)
	var original: SpriteFrames = (source.get_node("TrunkMask/AnimatedSprite2D") as AnimatedSprite2D).sprite_frames
	var tree := packed.instantiate() as Choppable
	tree.persistent = false
	add_child(tree)
	var trunk_mask := tree.get_node("TrunkMask") as Polygon2D
	var canopy_mask := tree.get_node("CanopyMask") as Polygon2D
	check(trunk_mask.clip_children == CanvasItem.CLIP_CHILDREN_DISABLED and canopy_mask.clip_children == CanvasItem.CLIP_CHILDREN_DISABLED, "clip_children dimatikan saat jalan")
	check(trunk_mask.self_modulate.a == 0.0, "poligon mask tidak terlihat")
	var trunk: SpriteFrames = tree.animated_sprite.sprite_frames
	var canopy: SpriteFrames = tree._canopy.sprite_frames
	check(trunk != original and canopy != original and trunk != canopy, "trunk dan kanopi memakai frame hasil panggang")
	var total_px := 0
	var mismatch := 0
	var trunk_px := 0
	var canopy_px := 0
	for anim in original.get_animation_names():
		check(trunk.get_frame_count(anim) == original.get_frame_count(anim), "jumlah frame %s sama" % anim)
		for i in original.get_frame_count(anim):
			var src_tex := original.get_frame_texture(anim, i) as AtlasTexture
			var src := src_tex.atlas.get_image()
			src.convert(Image.FORMAT_RGBA8)
			src = src.get_region(Rect2i(src_tex.region))
			var a := trunk.get_frame_texture(anim, i).get_image()
			var b := canopy.get_frame_texture(anim, i).get_image()
			a.convert(Image.FORMAT_RGBA8)
			b.convert(Image.FORMAT_RGBA8)
			for y in src.get_height():
				for x in src.get_width():
					var s := src.get_pixel(x, y)
					if s.a <= 0.0:
						continue
					total_px += 1
					var pa := a.get_pixel(x, y)
					var pb := b.get_pixel(x, y)
					if pa.a > 0.0:
						trunk_px += 1
					if pb.a > 0.0:
						canopy_px += 1
					var got := pa if pa.a > 0.0 else pb
					if (pa.a > 0.0) == (pb.a > 0.0) or not got.is_equal_approx(s):
						mismatch += 1
	check(total_px > 0 and mismatch == 0, "trunk + kanopi = gambar asli, tiap piksel tepat satu lapis (%d piksel, %d beda)" % [total_px, mismatch])
	check(trunk_px > 0 and canopy_px > trunk_px, "kanopi lebih besar dari batang (%d vs %d)" % [canopy_px, trunk_px])
	var second := packed.instantiate() as Choppable
	second.persistent = false
	add_child(second)
	check(second.animated_sprite.sprite_frames == trunk, "pinus lain memakai cache yang sama")
	tree.take_hit(1, ToolData.ToolTier.IRON)
	await get_tree().process_frame
	await get_tree().process_frame
	check(tree._canopy.animation == tree.animated_sprite.animation and tree._canopy.frame == tree.animated_sprite.frame, "kanopi ikut animasi tebang")
	source.free()
	_log.append("PINE BAKE COMPLETE: failures=%d" % failures)
	var f := FileAccess.open("res://tests/pine_bake_regression.log", FileAccess.WRITE)
	f.store_string("\n".join(_log))
	f.close()
	await get_tree().create_timer(3.0).timeout
	get_tree().quit(1 if failures else 0)
