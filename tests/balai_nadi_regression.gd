extends Node

## Titik berdiri pemain di depan Bale Agung pada balai.tscn.
const BALE_STAND := Vector2(616, 432)

const ID := "balai_nadi_restoration"
var failures := 0
var completions := 0
var contributions := 0
var reentrant_accepted := 0

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	check(get_viewport().gui_get_hovered_control() == button, "Contribution button receives real pointer input")
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame

func capture(filename: String) -> void:
	if OS.get_cmdline_user_args().has("--capture-balai"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://scratch/" + filename)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		push_error("Balai tests require isolated nusa-save-audit-* APPDATA and NUSA_SAVE_AUDIT=1.")
		get_tree().quit(2)
		return
	await get_tree().process_frame
	DayCycle.is_running = false
	GameState.new_game()
	var manager := GameState.balai_nadi
	var donor := GameState.p1()
	manager.project_completed.connect(func(_id): completions += 1)
	manager.contribution_added.connect(func(_id, _item, _amount): contributions += 1)
	check(manager.contributed(ID, "wood") == 0 and not manager.completed(ID) and not WorldState.has_flag("balai_nadi_restored"), "New Game initializes zero contributions and abandoned state")
	check(manager.contribute(donor, ID, "wood") == 0, "Zero resources accepted without deduction")
	donor.add_item("wood", 35)
	var reenter := func(): reentrant_accepted += manager.contribute(donor, ID, "wood")
	GameState.inventory_changed.connect(reenter)
	check(manager.contribute(donor, ID, "wood") == 35 and donor.get_item_count("wood") == 0 and manager.contributed(ID, "wood") == 35 and not manager.completed(ID), "Partial contribution deducts exactly 35 wood")
	GameState.inventory_changed.disconnect(reenter)
	check(reentrant_accepted == 0, "Inventory signal cannot cause a duplicate transaction")
	check(manager.contribute(donor, ID, "wood") == 0 and contributions == 1, "Repeated contribution is a no-op")
	check(SaveManager.load_game() and manager.contributed(ID, "wood") == 35 and donor.get_item_count("wood") == 0, "Partial progress and inventory survive actual disk reload")
	var old_save := SaveManager._build_save_data()
	old_save.version = 7
	old_save.erase("balai_nadi")
	old_save.player.money = 678
	old_save.world_state.bridge_repaired = true
	var legacy_file := FileAccess.open(SaveManager.slot_path(3), FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(old_save))
	legacy_file.close()
	SaveManager.select_slot(3)
	check(SaveManager.load_game(), "Pre-feature version 7 JSON loads from an actual save slot")
	check(GameState.money == 678 and WorldState.has_flag("bridge_repaired") and manager.contributed(ID, "wood") == 0, "Pre-feature save preserves player/world data and defaults Balai progress")
	check(SaveManager._is_valid_save(old_save), "Version 7 save without Balai section remains valid")
	SaveManager.select_slot(1)
	check(SaveManager.delete_slot(3), "Legacy test slot is cleaned up for following save regressions")
	check(SaveManager.load_game() and manager.contributed(ID, "wood") == 35, "Reload restores saved partial contribution after legacy load")
	donor.add_item("wood", 90)
	donor.add_item("stone", 70)
	# Force the existing atomic-save path to fail, without touching real saves.
	DirAccess.make_dir_absolute(SaveManager.BACKUP_PATH + ".tmp")
	check(manager.contribute(donor, ID, "stone") == 0 and donor.get_item_count("stone") == 70 and manager.contributed(ID, "stone") == 0, "Save failure rolls back accepted inventory and progress")
	DirAccess.remove_absolute(SaveManager.BACKUP_PATH + ".tmp")
	check(manager.contribute(donor, ID, "wood") == 65 and donor.get_item_count("wood") == 25 and manager.contributed(ID, "wood") == 100, "Excess inventory is clamped to remaining wood")
	check(manager.contribute(donor, ID, "stone", -1) == 0 and manager.contribute(donor, "unknown", "stone") == 0 and manager.contribute(donor, ID, "fiber") == 0, "Invalid requests and items are rejected")
	check(manager.contribute(donor, ID, "stone", 20) == 20 and manager.contributed(ID, "stone") == 20, "Explicit smaller quantity is accepted")
	GameState.money = 500
	check(manager.contribute(donor, ID, "money") == 500 and GameState.money == 0, "Restoration requires shared funding")
	check(manager.contribute(donor, ID, "stone") == 30 and donor.get_item_count("stone") == 20 and manager.completed(ID) and WorldState.has_flag("balai_nadi_restored") and completions == 1, "Completion sets flag and emits exactly one restoration event")
	check(manager.contribute(donor, ID, "wood") == 0 and manager.contribute(donor, ID, "stone") == 0, "Completed project refuses further resources")
	check(SaveManager.load_game() and manager.completed(ID) and WorldState.has_flag("balai_nadi_restored") and completions == 1 and donor.get_item_count("stone") == 20, "Completed disk reload preserves state without duplicate rewards/events")
	var scene := load("res://scenes/world/balai_nadi/balai.tscn").instantiate() as Node2D
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().physics_frame
	await get_tree().physics_frame
	var player := scene.get_node("Player/CharacterBody2D") as Player
	var visual := scene.get_node("BaleAgung")
	var art := visual.get_node("Polygon2D/Art") as Sprite2D
	check(art.texture == visual.restored_texture, "Restored Bale Agung art is visible after loading completion")
	await capture("balai-restored.png")
	GameState.new_game()
	check(not manager.completed(ID) and not WorldState.has_flag("balai_nadi_restored") and art.texture == visual.ruined_texture, "New Game resets progress, flag and live visuals")
	var table := scene.get_node("BaleAgung/BalaiInteractionArea")
	player.global_position = BALE_STAND
	player.facing_direction = Vector2.UP
	await get_tree().physics_frame
	check(player._find_interactable() == table, "Existing physics interaction finds the Bale Agung contribution area")
	player.data.add_item("wood", 35)
	player._try_interact()
	await get_tree().process_frame
	var menu: BalaiNadiUI = table._menus.get(0)
	check(is_instance_valid(menu) and get_tree().paused, "Table interaction opens modal and pauses solo gameplay")
	table.interact()
	check(table._menus.get(0) == menu, "Repeated interaction keeps one UI instance")
	menu._select_requirement("stone")
	check(menu.get_node("%Donate").disabled, "Missing materials cannot be donated")
	menu._select_requirement("wood")
	check(not menu.get_node("%Donate").disabled, "Donation action reflects the selected material inventory")
	await capture("balai-ui.png")
	# Tunggu animasi kartu selesai; selama tween masuk tombol belum menerima klik.
	await get_tree().create_timer(1.0, true).timeout
	await click(menu.get_node("%Donate"))
	check(manager.contributed(ID, "wood") == 35 and menu.get_node("%Donate").disabled and menu._rows.wood.label.text.contains("35 / 100"), "Contribution UI immediately updates progress and button state")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	# Esc kembali satu tingkat: kartu -> lingkaran -> tutup.
	for step in 2:
		get_viewport().push_input(escape, true)
		await get_tree().process_frame
	check(not get_tree().paused and not is_instance_valid(menu), "Closing UI resumes gameplay and removes modal")
	Coop.active = true
	table.interact()
	menu = table._menus.get(0)
	check(is_instance_valid(menu) and not get_tree().paused and player.is_input_locked() and player.get_input_vector() == Vector2.ZERO, "Co-op modal locks only its player without pausing the world")
	menu.close_menu()
	await get_tree().process_frame
	check(not player.is_input_locked() and not get_tree().paused, "Closing co-op modal releases player input")
	Coop.stop()
	manager.load_save({"projects": {ID: {"contributions": {"wood": -50, "stone": {}}, "completed": false}}})
	check(manager.contributed(ID, "wood") == 0 and manager.contributed(ID, "stone") == 0, "Malformed and negative project amounts initialize safely")
	manager.load_save({"projects": {ID: {"contributions": {"wood": 999, "stone": 999, "money": 999}}}})
	check(manager.completed(ID) and completions == 1, "Load clamps amounts and reconciles completion without emitting reward")
	# P2 can donate while the ambient active inventory belongs to P1.
	GameState.new_game()
	var p2 := GameState.ensure_player(1)
	p2.add_item("wood", 7)
	check(manager.contribute(p2, ID, "wood") == 7 and p2.get_item_count("wood") == 0 and donor.get_item_count("wood") == 0 and GameState.current == donor, "Explicit co-op donor is deducted without changing active player")
	check(SaveManager.load_game() and manager.contributed(ID, "wood") == 7 and p2.get_item_count("wood") == 0, "Co-op donation saves shared progress and correct player's inventory")
	player.global_position = scene.get_node("ReturnTown").global_position - Player.FEET_OFFSET
	await get_tree().physics_frame
	await get_tree().create_timer(1.2, true).timeout
	check(get_tree().current_scene.scene_file_path.ends_with("town.tscn") and not Transition.on_transition, "South exit returns to town and finishes fade")
	scene = get_tree().current_scene
	player = scene.get_node("Player/CharacterBody2D")
	check(player.global_position.distance_to(Vector2(331, 52)) < 1, "Exit restores configured town spawn")
	player.global_position = scene.get_node("BalaiNadiAccess").global_position
	await get_tree().physics_frame
	await get_tree().create_timer(1.2, true).timeout
	check(get_tree().current_scene.scene_file_path.ends_with("balai_nadi/balai.tscn") and not Transition.on_transition, "Town access returns to Balai Nadi and finishes fade")
	check(manager.contributed(ID, "wood") == 7, "Scene transitions retain contribution progress")
	print("BALAI NADI REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
