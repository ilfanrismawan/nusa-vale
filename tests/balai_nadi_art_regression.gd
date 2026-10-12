extends Node

var failures := 0

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _ready() -> void:
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	var preview: Node = load("res://scenes/world/balai_nadi/art_preview.tscn").instantiate()
	add_child(preview)
	check(preview.get_node("Exterior").texture.get_size() == Vector2(1374, 1145), "Exterior PNG imported at original size")
	check(preview.get_node("Interior").texture.get_size() == Vector2(1448, 1086), "Interior PNG imported at original size")
	var exterior_size: Vector2 = preview.get_node("Exterior").texture.get_size()
	var interior_size: Vector2 = preview.get_node("Interior").texture.get_size()
	var before_state := GameState.balai_nadi.to_save()
	preview.set("restored", true)
	check(preview.get_node("Exterior").texture.get_size() == exterior_size and preview.get_node("Interior").texture.get_size() == interior_size, "Restoration variants preserve canvas sizes")
	check(preview.get_node("UI/State").text == "SETELAH RESTORASI", "Preview toggle updates selected state")
	check(GameState.balai_nadi.to_save() == before_state, "Preview does not mutate gameplay progression")
	for asset in ["exterior_ruined", "exterior_restored", "interior_ruined", "interior_restored", "props_atlas"]:
		var texture: Texture2D = load("res://assets/balai_nadi/v1/%s.png" % asset)
		var image := texture.get_image()
		check(image.detect_alpha() != Image.ALPHA_NONE and image.get_pixel(0, 0).a == 0.0, asset + " retains transparent PNG alpha")
	for prop in ["contribution_table", "bookshelf", "village_map", "banner", "lantern", "flowerpot"]:
		var texture: AtlasTexture = load("res://resources/balai_nadi/v1/%s.tres" % prop)
		check(texture != null and Rect2(Vector2.ZERO, texture.atlas.get_size()).encloses(texture.region) and texture.get_image().get_used_rect().has_area(), prop + " atlas region loads and contains visible pixels")
	if OS.get_cmdline_user_args().has("--capture-balai-art"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://scratch/balai-art-preview.png")
	print("BALAI ART REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
