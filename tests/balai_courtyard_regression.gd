extends Node

var failures := 0

func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ",message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _ready() -> void:
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	var packed: PackedScene = load("res://scenes/world/balai_nadi/exterior.tscn")
	var scene: Node2D = packed.instantiate()
	get_tree().root.add_child(scene)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var player := scene.get_node("Player/CharacterBody2D") as Player
	player.set_physics_process(false)
	check(scene.get_node("Terrain/Telaga") is TileMapLayer and scene.get_node("PelataranDanJembatan/PapanJati") is TileMapLayer, "Water and wooden deck are editable TileMapLayers")
	check(not player.test_move(player.global_transform, Vector2.DOWN * 255), "Spawn to south bridge is continuously walkable")
	var bridge_transform := player.global_transform
	bridge_transform.origin = Vector2(427,380)
	check(player.test_move(bridge_transform, Vector2.LEFT * 90), "Player cannot walk from bridge into lake")
	player.global_position = Vector2(427,270)
	player.facing_direction = Vector2.UP
	await get_tree().physics_frame
	check(player._find_interactable() == scene.get_node("Entrance"), "Existing interaction ray finds pavilion entrance")
	player.global_position = Vector2(427,249)
	await get_tree().physics_frame
	check(player._find_interactable() == scene.get_node("Entrance"), "Entrance also accepts existing close approach and interior return spawn")
	check(scene.get_node("ReturnWorld").target_scene == "res://scenes/world/town.tscn", "South exit returns to village")
	var camera := player.get_node("Camera2D") as Camera2D
	check(camera.limit_left == -320 and camera.limit_top == -128 and camera.limit_right == 1184 and camera.limit_bottom == 896, "Camera bounds include all exploration areas")
	check(scene.get_node("Terrain/TepianBerumput").modulate == Color.WHITE,"Shore retains the original Farm RPG palette")
	var shores: TileMapLayer = scene.get_node("Terrain/TepianBerumput")
	var masks: Dictionary = shores.get_meta("neighbor_masks")
	var concave_count := 0
	for cell: Vector2i in shores.get_used_cells():
		var coord := shores.get_cell_atlas_coords(cell)
		if (masks[cell] & 15) == 15 and (masks[cell] & 240) != 240:
			concave_count+=1
			check(coord in [Vector2i(5,1),Vector2i(6,1),Vector2i(6,2),Vector2i(5,2)],"Concave shore uses an inward corner at " + str(cell))
		elif masks[cell] == 255:
			if coord != Vector2i(9,2): check(false,"Interior shore cells must use the plain fill")
	var shore_image: Image = shores.tile_set.get_source(0).texture.get_image()
	var fill_clean := true
	for y in range(32,48):
		for x in range(144,160):
			var pixel: Color = shore_image.get_pixel(x,y)
			if pixel.a<0.99 or pixel.b>pixel.g or pixel.r>pixel.g: fill_clean=false
	check(fill_clean,"Grass fill contains no transparent, water, or cliff pixels")
	check(concave_count > 0,"Concave shore coverage is exercised")
	for art: Sprite2D in scene.get_node("Objek/Vegetasi").find_children("Art","Sprite2D",true,false):
		if art.scale != Vector2.ONE:
			check(false,"Vegetation must keep native pixel size")
	await check_exploration(scene,player)
	var visual := scene.get_node("RestorationVisual")
	check(visual.get_node("Unrestored").visible and not visual.get_node("Restored").visible, "Unrestored decoration matches progression")
	GameState.balai_nadi.load_save({"projects":{"balai_nadi_restoration":{"contributions":{"wood":100,"stone":50,"money":500},"completed":true}}})
	check(visual.get_node("Restored").visible and not visual.get_node("Unrestored").visible, "Restoration enables offerings and fantasy motes live")
	for path in ["bale_agung","sacred_props"]:
		var tex: Texture2D = load("res://assets/balai_nadi/v3/%s.png" % path)
		check(tex.get_image().detect_alpha() != Image.ALPHA_NONE,"Transparent new sprite imports: " + path)
	if OS.get_cmdline_user_args().has("--capture-courtyard"):
		player.global_position = Vector2(427,277)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://scratch/balai-courtyard-gameplay.png")
		for shot in [["west",Vector2(-40,424)],["waterfall",Vector2(864,96)]]:
			player.get_parent().global_position = shot[1]
			player.position = Vector2.ZERO
			await get_tree().physics_frame
			camera.force_update_scroll()
			camera.reset_smoothing()
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var world_corner := get_viewport().get_canvas_transform().affine_inverse() * Vector2.ZERO
			var world_view := Rect2(world_corner,Vector2(get_viewport().size)/camera.zoom)
			var world_bounds: Rect2 = scene.camera_bounds
			check(world_bounds.grow(1).encloses(world_view),"Camera exposes no empty area at " + shot[0])
			get_viewport().get_texture().get_image().save_png("res://scratch/balai-exploration-%s.png" % shot[0])
	scene.queue_free()
	await get_tree().process_frame
	if OS.get_cmdline_user_args().has("--capture-courtyard"):
		await capture(packed)
	var before: Dictionary = GameState.balai_nadi.to_save()
	var preview: Node = load("res://scenes/world/balai_nadi/courtyard_preview.tscn").instantiate()
	add_child(preview)
	await get_tree().process_frame
	preview.get_node("Container/Viewport/World").set("restored",false)
	check(GameState.balai_nadi.to_save() == before,"F6 preview toggle does not change restoration progression")
	preview.queue_free()
	print("BALAI COURTYARD COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)

func capture(packed: PackedScene) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1504,1024)
	vp.world_2d = World2D.new()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var display: Node2D = packed.instantiate()
	display.get_node("Player").free()
	display.set_script(null)
	display.position = Vector2(320,128)
	vp.add_child(display)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png("res://scratch/balai-courtyard-restored.png")
	GameState.balai_nadi.load_save({})
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png("res://scratch/balai-courtyard-unrestored.png")
	vp.queue_free()

func check_exploration(scene: Node2D, player: Player) -> void:
	var nav := AStarGrid2D.new()
	nav.region = scene.get_meta("cell_bounds")
	nav.cell_size = Vector2(16,16)
	nav.offset = Vector2(8,8)
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	nav.update()
	var allowed: Dictionary = {}
	for cell: Vector2i in scene.get_meta("walkable_cells"): allowed[cell]=true
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = player.get_node("CollisionShape2D").shape
	query.exclude = [player.get_rid()]
	query.collide_with_areas = false
	var space := scene.get_world_2d().direct_space_state
	for y in range(nav.region.position.y,nav.region.end.y):
		for x in range(nav.region.position.x,nav.region.end.x):
			var cell := Vector2i(x,y)
			var blocked := not allowed.has(cell)
			if not blocked:
				query.transform = Transform2D(0,Vector2(cell*16)+Vector2(8,8))
				blocked = not space.intersect_shape(query,1).is_empty()
			nav.set_point_solid(cell,blocked)
	var start := Vector2i(26,17)
	for marker: Marker2D in scene.get_node("JalurEksplorasi").get_children():
		var target := Vector2i(floor(marker.global_position/16.0))
		check(not nav.is_point_solid(target) and not nav.get_id_path(start,target).is_empty(),"Player can reach " + marker.name + " through actual collision geometry")
