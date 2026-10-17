extends Node

var failures := 0

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func _ready() -> void:
	var catalog: CharacterCatalog = load("res://resources/character/character_catalog.tres")
	var look := catalog.sanitize(CharacterAppearance.new())
	var frames: SpriteFrames = CharacterSpriteBuilder.build(catalog, look)["frames"]
	var template := CharacterSpriteBuilder.get_template(catalog)
	for animation in frames.get_animation_names():
		for i in frames.get_frame_count(animation):
			var texture := frames.get_frame_texture(animation, i) as AtlasTexture
			check(texture != null and texture.atlas is ImageTexture, "composed character atlas for %s/%d" % [animation, i])
	for anim in template.get_animation_names():
		check(frames.get_frame_count(anim) == template.get_frame_count(anim), "existing frame count " + anim)
		check(frames.get_animation_speed(anim) == template.get_animation_speed(anim), "existing speed " + anim)
		check(frames.get_animation_loop(anim) == template.get_animation_loop(anim), "existing loop " + anim)
	var montage := Image.create_empty(512, 512, false, Image.FORMAT_RGBA8)
	montage.fill(Color(0.18, 0.23, 0.22))
	var index := 0
	for sheet in catalog.sheets:
		if sheet.animation_name.is_empty():
			continue
		var suffixes: Array[String] = ["down", "up", "right", "left"]
		for row in sheet.directions:
			var anim := String(sheet.animation_name) + ("_" + suffixes[row] if sheet.directions > 1 else "")
			check(frames.has_animation(anim), "registered " + anim)
			check(frames.get_animation_loop(anim) == sheet.animation_loop, "loop " + anim)
			for frame in frames.get_frame_count(anim):
				var atlas := frames.get_frame_texture(anim, frame) as AtlasTexture
				var image := atlas.atlas.get_image().get_region(Rect2i(atlas.region))
				check(image.get_used_rect().has_area(), "visible frame %s/%d" % [anim, frame])
		var first := String(sheet.animation_name) + ("_down" if sheet.directions > 1 else "")
		var texture := frames.get_frame_texture(first, 0) as AtlasTexture
		var tile := texture.atlas.get_image().get_region(Rect2i(texture.region))
		@warning_ignore("integer_division")
		var position := Vector2i((index % 8) * 64, (index / 8) * 64)
		montage.blend_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), position + (Vector2i(64, 64) - tile.get_size()) / 2)
		index += 1
	montage.resize(1024, 1024, Image.INTERPOLATE_NEAREST)
	montage.save_png("user://character-animation-preview.png")
	var host := Node2D.new()
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.sprite_frames = frames
	host.add_child(sprite)
	var controller := AnimationController.new()
	host.add_child(controller)
	add_child(host)
	controller.set_direction(Vector2.LEFT)
	controller.play(&"sword")
	check(sprite.animation == &"sword_left" and not sprite.flip_h, "native left pose")
	controller.play(&"walk")
	check(sprite.animation == &"walk_right" and sprite.flip_h, "legacy mirrored left")
	controller.set_visual_override(&"sleep")
	controller.play(&"idle")
	check(sprite.animation == &"sleep", "sleep override survives locomotion")
	controller.set_visual_override(&"")
	check(sprite.animation == &"idle_right" and sprite.flip_h, "wake restores facing")
	var hit_frames := [0]
	controller.frame_changed.connect(func(_frame: int):
		if String(sprite.animation).begins_with("item_drop_"):
			hit_frames[0] += 1)
	check(controller.play_item_gesture(&"item_drop") and sprite.animation == &"item_drop_left", "item drop uses the character's native directional pose")
	await get_tree().create_timer(1.0).timeout
	check(not controller.item_gesture_playing and sprite.animation == &"idle_right" and hit_frames[0] == 0, "item gesture restores locomotion without emitting tool hit frames")
	controller.set_direction(Vector2.UP)
	check(controller.play_item_gesture(&"pick_up") and sprite.animation == &"pick_up_up", "pickup gesture follows character facing")
	await get_tree().create_timer(1.0).timeout
	check(not controller.item_gesture_playing and sprite.animation == &"idle_up", "pickup gesture ends automatically")
	controller.set_carrying_item(true)
	for direction in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
		controller.set_direction(direction)
		for action in [&"idle", &"walk", &"run"]:
			controller.play(action)
			check(String(sprite.animation).begins_with("carry_" + String(action) + "_"), "carrying locomotion uses native directional sheet")
	controller.set_carrying_item(false)
	check(sprite.animation == &"run_right", "stopping carry restores ordinary locomotion")
	look.outfit = "outfit_sports_tracktop"
	look.pants = "pants_baggy_jeans"
	look.hair = "hair_korean_curtain"
	var custom: SpriteFrames = CharacterSpriteBuilder.build(catalog, catalog.sanitize(look), {}, ["horse_idle_left", "pick_up_down"])["frames"]
	check(custom.has_animation(&"horse_idle_left") and custom.has_animation(&"pick_up_down"), "custom clothes and hair support new poses")
	check(custom.get_animation_names().size() == 2, "filtered preview builds only selected animations")
	var harvest: ActionData = load("res://resources/action_data/hand_harvest.tres")
	check(harvest.animation_name == &"pick_up" and harvest.hit_frame < frames.get_frame_count(&"pick_up_down"), "hand harvest uses valid pickup hit frame")
	var creator := load("res://scenes/ui/character_creator_ui.tscn").instantiate() as CharacterCreatorUI
	creator.pause_game = false
	add_child(creator)
	for i in creator._preview_actions.size():
		creator._change_action(i)
		for direction in range(4):
			creator._turn(1)
			check(creator._preview.sprite_frames.has_animation(creator._preview.animation), "creator preview selects valid animation")
	creator.queue_free()
	print("CHARACTER ANIMATION REGRESSION: %d extra actions, %d animations, failures=%d" % [index, frames.get_animation_names().size(), failures])
	print("PREVIEW: " + OS.get_user_data_dir().path_join("character-animation-preview.png"))
	get_tree().quit(1 if failures else 0)
