extends Node

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func settle() -> void:
	for frame in 6:
		await get_tree().process_frame

func capture(creator: CharacterCreatorUI, page: int, file_name: String) -> void:
	if OS.get_environment("NUSA_SETUP_SCREENSHOT") != "1" or DisplayServer.get_name() == "headless":
		return
	creator._show_page(page)
	await settle()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://scratch/" + file_name + ".png")

func bounded(creator: CharacterCreatorUI, control: Control) -> bool:
	return creator.get_viewport().get_visible_rect().grow(1).encloses(control.get_global_rect())

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	var creator := load("res://scenes/ui/character_creator_ui.tscn").instantiate() as CharacterCreatorUI
	creator.ask_name = true
	creator.pause_game = false
	add_child(creator)
	await settle()
	check(creator.find_children("*", "ScrollContainer", true, false).is_empty(), "character setup contains no scroll containers")
	check(creator.find_children("*", "OptionButton", true, false).is_empty(), "character and pet selection do not use dropdowns")
	check(creator.get_node("%Identity").visible and bounded(creator, creator._name_edit) and bounded(creator, creator._farm_edit) and bounded(creator, creator.get_node("%BirthdayButton")), "all profile inputs are accessible on one bounded page")
	var indices := {}
	creator._show_page(1)
	var pages := ceili(float(creator._eligible_options().size()) / creator.options_per_page)
	for page in pages:
		var visible_count := 0
		for index in creator._row_nodes:
			var row: Control = creator._row_nodes[index][0]
			if row.visible:
				indices[index] = true
				visible_count += 1
				check(bounded(creator, row), "appearance option remains inside viewport: " + str(index))
		check(visible_count <= creator.options_per_page, "appearance page never exceeds configured capacity")
		creator._change_option_page(1)
	check(indices.size() == creator._eligible_options().size(), "pagination exposes every available appearance option without scrolling")
	check(creator._pet_entries.size() >= 9, "catalog provides four dog and four cat variants plus no-pet choice")
	creator._show_page(2)
	var pet_indices := {}
	pages = ceili(float(creator._pet_entries.size()) / creator.pet_cards_per_page)
	for page in pages:
		for card in creator.get_node("%PetCards").get_children():
			pet_indices[card.get_meta("pet_index")] = true
			check(bounded(creator, card), "pet card remains inside viewport")
		check(creator.get_node("%PetCards").get_child_count() <= creator.pet_cards_per_page, "pet catalog fits each fixed-size page")
		creator._change_pet_page(1)
	check(pet_indices.size() == creator._pet_entries.size(), "pet page arrows expose all variants")
	var card: Button = creator.get_node("%PetCards").get_child(1)
	card.pressed.emit()
	check(creator._pet_id == "dog" and card.button_pressed and creator.get_node("%PetIcon").texture != null, "clicking a visual card highlights its pet and updates the preview")
	creator._name_edit.text = "Sari"
	creator._farm_edit.text = "Kebun Senja"
	creator._set_birthday(0, 12)
	creator._pet_name.text = "Piko"
	creator._validate_profile()
	check(not creator.get_node("%Confirm").disabled, "required identity and pet-name validation still work across tabs")
	await capture(creator, 0, "character-profile-no-scroll")
	await capture(creator, 1, "character-appearance-no-scroll")
	await capture(creator, 2, "character-pets-no-scroll")
	creator._confirm()
	await settle()
	check(GameState.p1().pet_id == "dog" and GameState.p1().pet_name == "Piko", "visual selection commits to the existing persistent pet fields")
	var view := SubViewport.new()
	view.size = Vector2i(640, 360)
	add_child(view)
	creator = load("res://scenes/ui/character_creator_ui.tscn").instantiate() as CharacterCreatorUI
	creator.ask_name = true
	creator.pause_game = false
	view.add_child(creator)
	await settle()
	for page in 3:
		creator._show_page(page)
		await settle()
		check(bounded(creator, creator.get_node("%Confirm")), "confirm action stays inside a small viewport")
		if page == 2:
			check(bounded(creator, creator._pet_name), "pet name fits a small viewport without scrolling")
	creator.queue_free()
	view.queue_free()
	await settle()
	print("CHARACTER SETUP NAVIGATION REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
