extends SceneTree

func _initialize() -> void:
	var sheet := Image.create(40, 16, false, Image.FORMAT_RGBA8)
	var region := Rect2i(2, 4, 8, 8)
	for y in range(7, 9):
		for x in range(5, 7):
			sheet.set_pixel(x, y, Color.RED)
			sheet.set_pixel(x + 16, y, Color.RED)
	for p in [Vector2i(21, 7), Vector2i(22, 7), Vector2i(21, 8), Vector2i(22, 8)]:
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if sheet.get_pixelv(p + d).a == 0:
				sheet.set_pixelv(p + d, Color.WHITE)
	# Unrelated lines included by the old expanded atlas region.
	for x in range(18, 26):
		sheet.set_pixel(x, 3, Color.WHITE)
	for y in range(4, 12):
		sheet.set_pixel(17, y, Color.WHITE)
	var icon := AtlasTexture.new()
	icon.atlas = ImageTexture.create_from_image(sheet)
	icon.region = Rect2(region)
	var actual := OutlineIcon.get_for(icon)
	var expected := OutlineIcon._generate(icon)
	var clean := actual.get_image()
	var reference := expected.get_image()
	var failures := 0
	if clean.get_size() != reference.get_size() or clean.get_data() != reference.get_data():
		push_error("FAIL: outline includes neighbouring atlas pixels")
		failures += 1
	if OutlineIcon.get_for(icon) != actual:
		push_error("FAIL: outline cache returns a different texture")
		failures += 1
	var preview := Image.create(80, 48, false, Image.FORMAT_RGBA8)
	preview.fill(Color("765a3a"))
	var row := 0
	for id in ["strawberry", "wood"]:
		var real_icon: Texture2D = load("res://resources/icons/icon_%s.tres" % id)
		var outlined := OutlineIcon.get_for(real_icon).get_image()
		var generated := OutlineIcon._generate(real_icon).get_image()
		if outlined.get_size() != generated.get_size():
			push_error("FAIL: unexpected outline size for " + id)
			failures += 1
		else:
			for y in outlined.get_height():
				for x in outlined.get_width():
					if (outlined.get_pixel(x, y).a > 0.5) != (generated.get_pixel(x, y).a > 0.5):
						push_error("FAIL: stray outline pixel in " + id)
						failures += 1
		preview.blend_rect(real_icon.get_image(), Rect2i(Vector2i.ZERO, real_icon.get_image().get_size()), Vector2i(8, row * 24 + 3))
		preview.blend_rect(outlined, Rect2i(Vector2i.ZERO, outlined.get_size()), Vector2i(44, row * 24 + 2))
		row += 1
	preview.resize(640, 384, Image.INTERPOLATE_NEAREST)
	preview.save_png("user://outline-icon-preview.png")
	print("PREVIEW: " + OS.get_user_data_dir().path_join("outline-icon-preview.png"))
	print("OUTLINE ICON REGRESSION COMPLETE: failures=%d" % failures)
	quit(1 if failures else 0)
