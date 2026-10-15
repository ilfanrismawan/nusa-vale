extends Node

var failures := 0

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: " + label)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	DayCycle.is_running = true
	PauseManager.set_requested(false)
	var hour := DayCycle.hour
	var minute := DayCycle.minute
	var timer := DayCycle._timer
	PauseManager.set_background(true)
	await get_tree().create_timer(0.1, true).timeout
	check(get_tree().paused and DayCycle.hour == hour and DayCycle.minute == minute and is_equal_approx(DayCycle._timer, timer), "focus loss pauses gameplay and time")
	PauseManager.set_requested(false)
	check(get_tree().paused, "menu close cannot undo background pause")
	PauseManager.set_requested(true)
	PauseManager.set_background(false)
	check(get_tree().paused, "regaining focus preserves open menu pause")
	PauseManager.set_requested(false)
	check(not get_tree().paused, "closing menu resumes after focus returns")
	DayCycle.is_running = false
	var seen := {}
	for name in Juice.TIER_TIMBRES:
		seen[name] = true
		check(Juice.impact_stream(name) != null, "tier sound loads: " + name)
	check(seen.size() == 10, "all ten tool tiers have distinct material samples")
	var footsteps := FootstepAudio.new()
	for entry in [["grass", "65ad56"], ["dirt", "ac7141"], ["snow", "dde7ee"], ["concrete", "686e70"]]:
		var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		image.fill(Color(entry[1]))
		var source := TileSetAtlasSource.new()
		source.texture = ImageTexture.create_from_image(image)
		source.create_tile(Vector2i.ZERO)
		check(footsteps._atlas_surface(source, Vector2i.ZERO, false) == entry[0], "mixed atlas identifies " + entry[0])
		if entry[0] == "dirt":
			check(footsteps._atlas_surface(source, Vector2i.ZERO, true) == "wood", "indoor warm floor uses wooden footsteps")
	for surface in ["carpet", "concrete", "grass", "snow", "wood"]:
		for variant in 5:
			check(Juice.impact_stream("footstep_%s_%03d" % [surface, variant]) != null, "surface sound loads: " + surface)
	GameState.new_game()
	var house := (load("res://scenes/world/interior/interior_house.tscn") as PackedScene).instantiate()
	add_child(house)
	await get_tree().process_frame
	var bed := house.get_node("Kasur") as Bed
	var player := house.get_node("Player/CharacterBody2D") as Player
	player.set_physics_process(false)
	var sprite := player.animation_controller.sprite
	var before := sprite.transform
	bed._place_on_pillow(player)
	var texture := sprite.sprite_frames.get_frame_texture("sleep", 0)
	var center := Vector2(texture.get_image().get_used_rect().get_center()) - texture.get_size() * 0.5
	check(sprite.to_global(center).distance_to(bed.to_global(bed.pillow_position)) < 0.1, "sleep head aligns with pillow independently of standing position")
	bed._restore_pose(player)
	check(sprite.transform.is_equal_approx(before) and not player.is_input_locked(), "waking restores pose and control")
	player.tool_controller.select_tool(3, false)
	player.hud_ui._update_water_meter()
	check(player.hud_ui.water_panel.visible and player.hud_ui.water_bar.value == player.data.watering_water, "selected watering can shows capacity bar")
	await get_tree().process_frame
	check(player.hud_ui.water_panel.get_global_rect().end.y <= get_viewport().get_visible_rect().size.y, "water capacity meter stays inside the viewport")
	player.data.watering_water = 0
	player.hud_ui._update_water_meter()
	check(player.hud_ui.water_bar.value == 0 and player.hud_ui.water_label.text.contains("Isi ulang"), "empty water meter shows refill hint")
	player.tool_controller.select_tool(0, false)
	player.hud_ui._update_water_meter()
	check(not player.hud_ui.water_panel.visible, "capacity meter hides for other tools")
	house.queue_free()
	await get_tree().process_frame
	print("FEEDBACK FOCUS COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
