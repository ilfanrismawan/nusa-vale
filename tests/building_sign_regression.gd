extends Node2D
var failures := 0

func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ") + message)
	if not value:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame in 4:
		await get_tree().process_frame

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	DayCycle.is_running = false
	var source := load("res://scenes/objects/building_sign.tscn") as PackedScene
	var sign = source.instantiate()
	sign.position = Vector2(220, 120)
	sign.get_node("%Caption").text = "Nama dari node"
	sign.get_node("%Caption").add_theme_font_size_override("font_size", 20)
	add_child(sign)
	await settle()
	check(sign.get_node("%Caption").text == "Nama dari node" and sign.get_node("%Caption").get_theme_font_size("font_size") == 20, "scene-authored caption and font survive ready")
	check(sign.get_node("%Frame") is Panel and sign.get_node("%Caption") is Label, "board artwork is composed of editable scene nodes")
	check(sign.board_rect().size.x >= sign.get_node("%Content").get_combined_minimum_size().x, "automatic board fits node text and padding")
	sign.caption = "Nama bangunan yang lebih panjang"
	sign.icon = load("res://icon.svg")
	sign.minimum_width = 140
	sign.wood_color = Color.RED
	await settle()
	check(sign.get_node("%Caption").text == sign.caption and sign.get_node("%Icon").visible, "existing caption and icon exports still work")
	check(sign.board_rect().size.x >= 140, "legacy minimum width is respected")
	for mode in 3:
		sign.mount = mode
		await settle()
		check(sign.get_node("%Posts").visible == (mode == 2) and sign.get_node("%Hanging").visible == (mode == 1), "mount visibility follows mode %d" % mode)
		if mode == 2:
			var board: Control = sign.get_node("%Board")
			var post: Control = sign.get_node("%LeftPost")
			check(is_equal_approx(board.position.y + post.position.y + post.size.y, sign.get_node("%Ground").position.y), "posts reach editable ground marker")
	var manual = source.instantiate()
	manual.auto_layout = false
	manual.get_node("%Board").position = Vector2(17, -35)
	manual.get_node("%Board").size = Vector2(170, 40)
	add_child(manual)
	await settle()
	check(manual.board_rect() == Rect2(17, -35, 170, 40), "manual node layout remains unchanged")
	check(manual.get_node("%Frame").get_theme_stylebox("panel").bg_color != Color.RED, "editing one sign does not recolor other instances")
	manual.hide()
	sign.hide()
	var names := ["school", "university", "blacksmith", "library", "warung", "shop"]
	for i in names.size():
		var preset = load("res://scenes/objects/signs/%s_sign.tscn" % names[i]).instantiate()
		preset.position = Vector2(150 + (i % 3) * 270, 110 + (i / 3) * 150)
		add_child(preset)
		await settle()
		check(preset.get_node("%Caption").text == preset.caption, "existing %s preset retains its caption" % names[i])
	var editable = load("res://scenes/objects/signs/shop_sign.tscn").instantiate()
	editable.use_preset_overrides = false
	editable.get_node("%Caption").text = "Edit lewat node"
	add_child(editable)
	await settle()
	check(editable.get_node("%Caption").text == "Edit lewat node", "node editing can override inherited legacy preset properties")
	editable.hide()
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png("res://scratch/building_sign_nodes_preview.png")
	print("BUILDING SIGN COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
