extends Node

var _log := PackedStringArray()

func say(text: String) -> void:
	print(text)
	_log.append(text)
	var f := FileAccess.open("res://tests/balai_interact_probe.log", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_log))

func shot(file_name: String) -> void:
	await get_tree().create_timer(0.6, true, false, true).timeout
	RenderingServer.force_draw()
	var image := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://scratch")
	image.save_png("res://scratch/%s.png" % file_name)
	say("PROBE shot %s %s" % [file_name, image.get_size()])

## Probe: buka Balai Nadi dari meja interior dan Bale Agung exterior seperti pemain menekan interact,
## lalu ambil tangkapan layar tiap tingkat UI lingkaran kaca.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	say("PROBE START")
	GameState.new_game()
	for path in ["res://scenes/world/balai_nadi/balai.tscn"]:
		var scene: Node = load(path).instantiate()
		get_tree().root.add_child(scene)
		for i in 4:
			await get_tree().physics_frame
		var player: Player = null
		for node in get_tree().get_nodes_in_group("player"):
			if node is Player and scene.is_ancestor_of(node):
				player = node
		say("PROBE %s player=%s" % [path, player])
		if player != null:
			var target_pos := Vector2(616, 432)
			player.global_position = target_pos
			player.facing_direction = Vector2.UP
			for i in 30:
				player.velocity = Vector2.UP * 60
				player.move_and_slide()
				await get_tree().physics_frame
			var ok := player._try_interact()
			say("PROBE try_interact=%s" % ok)
			for i in 6:
				await get_tree().process_frame
			var menus := get_tree().root.find_children("*", "CanvasLayer", true, false).filter(func(n): return n is BalaiNadiUI)
			say("PROBE menus=%d" % menus.size())
			for m in menus:
				say("PROBE petals_before=%d projects=%d" % [m.get_node("%Petals").get_child_count(), m._filtered_projects().size()])
				if path.contains("interior"):
					await shot("balai_ui_0_locked")
				GameState.balai_nadi.load_save({"projects": {"balai_nadi_restoration": {"contributions": {}, "completed": true}, "spring_crops_bundle": {"contributions": {"parsnip": 1, "potato": 1}, "completed": false}}})
				m._refresh()
				say("PROBE petals_after=%d projects=%d" % [m.get_node("%Petals").get_child_count(), m._filtered_projects().size()])
				if path.contains("interior"):
					m._set_selection(1)
					await shot("balai_ui_1_wings")
					m._select_wing("alam")
					await shot("balai_ui_2_bundles")
					player.data.add_item_silent("parsnip", 3)
					player.data.add_item_silent("cauliflower", 1)
					m._select_project_id("spring_crops_bundle")
					m._select_requirement("cauliflower")
					await shot("balai_ui_3_card")
					say("PROBE card items=%d donate_disabled=%s" % [m._rows.size(), m.get_node("%Donate").disabled])
				GameState.balai_nadi.reset()
				m.close_menu()
		scene.queue_free()
		await get_tree().process_frame
	say("PROBE DONE")
	await get_tree().create_timer(3.0).timeout
	get_tree().quit()
