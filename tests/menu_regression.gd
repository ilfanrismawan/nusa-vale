extends Node

var failures := 0
var settings: SettingsMenu
var ui: CanvasLayer

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	# SaveManager memuat slot secara deferred. Selesaikan startup sebelum
	# fixture dibuat, terutama setelah tes tidur menyimpan ke direktori audit.
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	DiscoveryManager.reset()
	var data := GameState.p1()
	data.reset_to_starter()
	# Pedang kayu awal ada di tas (Phase 4B-1); kosongkan supaya hitungan crafting tetap jelas.
	data.remove_item("sword_wood", 1)
	settings = load("res://scenes/ui/settings_menu.tscn").instantiate()
	settings.name = "SettingsMenu"
	add_child(settings)
	var display_config := ConfigFile.new()
	display_config.set_value("display", "window_mode", 0)
	display_config.set_value("display", "res_x", 1366)
	display_config.set_value("display", "res_y", 768)
	display_config.save(SettingsMenu.CONFIG_PATH)
	settings.load_settings()
	check(settings.RESOLUTIONS[settings.resolution_option.selected] == Vector2i(1366, 768), "saved resolution survives settings load instead of old dropdown overriding it")
	ui = load("res://scenes/ui/ui_inventory.tscn").instantiate()
	ui.name = "UIInventory"
	check(ui.get_node("%SlotGrid").get_child_count() == 12, "Bag slots exist in the scene before any UI script runs")
	for page_name in ["StatusPage", "EquipmentPage", "CraftingPage", "CollectionPage", "SettingsPage", "SkillTreePage", "RelationshipPage"]:
		var page := ui.get_node("Dimmer/BookRoot/" + page_name) as Control
		check(page != null and not page.scene_file_path.is_empty(), "Book page is an editable scene instance: " + page_name)
	add_child(ui)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	get_viewport().push_input(esc, true)
	await get_tree().process_frame
	check(ui.visible and not settings.visible and get_tree().paused, "Esc opens inventory, not settings, and pauses solo")
	check(ui._top_tabs.size() == 9 and not ui.has_method("_on_save_pressed"), "Top tabs include skills, NPC and controls pages without a direct save action")
	await click_icon(ui._menu_buttons["NPC"])
	check(is_instance_valid(ui._relationship_ui), "NPC tab opens from an actual mouse click")
	ui._relationship_ui.close_menu()
	await get_tree().process_frame
	await click_icon(ui._menu_buttons["Crafting"])
	check(ui._crafting_panel.visible and not ui._equipment_panel.visible, "Crafting is a separate inventory page")
	var recipe_tile := recipe_button("sword_wood")
	await click_control(recipe_tile, recipe_tile.get_global_rect().get_center())
	check(ui._crafting_panel._craft_button.disabled, "Craft action is disabled when materials are missing")
	data.add_item("wood", 8)
	check(not ui._crafting_panel._craft_button.disabled, "Craft action refreshes when materials enter the bag")
	ui._crafting_panel._quantity.value = 2
	check(ui._crafting_panel._craft_button.disabled, "Craft quantity validates total material requirements")
	ui._crafting_panel._quantity.value = 1
	await capture("menu_crafting")
	recipe_tile = recipe_button("bow_wood")
	await click_control(recipe_tile, recipe_tile.get_global_rect().get_center())
	check(ui._crafting_panel._selected.recipe_id == "bow_wood", "Recipe grid click changes the selected recipe and detail")
	recipe_tile = recipe_button("sword_wood")
	await click_control(recipe_tile, recipe_tile.get_global_rect().get_center())
	var craft_button: Button = ui._crafting_panel._craft_button
	await click_control(craft_button, craft_button.get_global_rect().get_center())
	check(data.get_item_count("wood") == 0 and data.get_item_count("sword_wood") == 1, "Craft button consumes materials and places output in the owning bag")
	check(SaveManager.save_game(), "Crafted output saves through existing game slots")
	data.remove_item("sword_wood", 1)
	check(SaveManager.load_game() and data.has_item("sword_wood"), "Crafted output survives game save/load")
	var ammo_filter: TextureButton = ui._crafting_panel._filters[2]
	await click_control(ammo_filter, ammo_filter.get_global_rect().get_center())
	check(ui._crafting_panel._recipe_buttons.size() >= 1 and recipe_button("arrow_wood") != null, "Ammo filter includes wooden ammunition alongside other tiers")
	recipe_tile = recipe_button("arrow_wood")
	await click_control(recipe_tile, recipe_tile.get_global_rect().get_center())
	data.add_item("wood", 4)
	data.add_item("stone", 2)
	ui._crafting_panel._quantity.value = 2
	check(not ui._crafting_panel._craft_button.disabled and ui._crafting_panel._title.text.contains("Hasil x20"), "Batch UI shows total ammunition output")
	await click_control(craft_button, craft_button.get_global_rect().get_center())
	check(data.get_item_count("arrow_wood") == 20, "Batch crafting from the menu produces the displayed quantity")
	var building_filter: TextureButton = ui._crafting_panel._filters[3]
	await click_control(building_filter, building_filter.get_global_rect().get_center())
	recipe_tile = recipe_button("furnace")
	await click_control(recipe_tile, recipe_tile.get_global_rect().get_center())
	check(ui._crafting_panel._recipe_buttons.size() >= 13 and ui._crafting_panel._selected.recipe_id == "furnace", "Building filter offers structures, farm buildings, machines and all chest tiers")
	data.bag_level = 1
	ui._crafting_panel._quantity.value = 1
	data.add_item("stone", 25)
	data.add_item("copper_ore", 10)
	await capture("menu_building_recipes")
	await click_control(craft_button, craft_button.get_global_rect().get_center())
	check(data.get_item_count("furnace") == 1 and data.get_item_count("copper_ore") == 0, "Basic furnace crafting consumes materials and creates a placeable item")
	data.reset_to_starter()
	await click_icon(ui._menu_buttons["Equipment"])
	check(ui._equipment_panel.visible and not ui._collection_panel.visible, "Equipment icon opens a separate page")
	check(ui._equipment_panel._portrait.texture != null and ui._equipment_panel._preview_key == data.appearance.get_key(), "Equipment portrait uses the owning player's appearance")
	check(data.equipment_stats() == Vector2i(0, 3) and data.has_item("sword_wood"), "New players start with wooden armor equipped and the wooden sword in the bag")
	check(not ui._equipment_panel._remove_buttons.has("weapon") and not data.equipment.has("weapon"), "Weapons are held from the hotbar, not equipped")
	var remove: Button = ui._equipment_panel._remove_buttons["armor"]
	await click_control(remove, remove.get_global_rect().get_center())
	check(data.equipment["armor"] == null and data.has_item("armor_wood"), "Unequip button returns armor to bag")
	var equip: Button = ui._equipment_panel._entries[0]
	await click_control(equip, equip.get_global_rect().get_center())
	check(data.equipment["armor"] != null and not data.has_item("armor_wood"), "Equip button moves armor out of bag without duplication")
	await capture("menu_equipment")
	var other := PlayerData.new(1)
	other.reset_to_starter()
	check(other.unequip("armor") and data.equipment["armor"] != null, "Co-op equipment belongs to each player")
	var saved_other := other.to_dict()
	other.reset_to_starter()
	other.load_dict(saved_other)
	check(other.equipment["armor"] == null and other.has_item("armor_wood"), "Co-op equipment round-trips independently")
	other.add_item_silent("helmet_wood", 1)
	for slot in other.bag_size:
		if other.inventory[slot] != null and other.inventory[slot]["item"].item_id == "helmet_wood":
			other.equip_from_slot(slot)
			break
	for slot in other.bag_size:
		if other.inventory[slot] == null:
			other.inventory[slot] = {"item": GameState._resolve_item("stone"), "count": 1}
	check(not other.unequip("helmet") and other.equipment["helmet"] != null, "Full bag cannot lose equipped gear")
	var armor_slot := -1
	for slot in other.bag_size:
		if other.inventory[slot]["item"].item_id == "armor_wood":
			armor_slot = slot
	check(other.equip_from_slot(armor_slot), "Equipment can be equipped with a full bag")
	other.inventory[armor_slot] = {"item": GameState._resolve_item("armor_wood"), "count": 1}
	check(other.equip_from_slot(armor_slot) and other.inventory[armor_slot]["item"].item_id == "armor_wood", "Replacing gear swaps into its source slot")
	check(not other.equip_from_slot(0), "Farm tools cannot enter equipment slots")
	other.load_equipment({"weapon": "armor_wood", "armor": "stone"})
	check(not other.equipment.has("weapon") and other.equipment["armor"] == null, "Invalid equipment save entries are rejected")
	other.load_equipment({})
	check(other.equipment_stats() == Vector2i.ZERO, "Older saves default to empty equipment slots")
	check(SaveManager.save_game(), "Equipment saves using normal save slots")
	data.equipment = {"armor": null}
	check(SaveManager.load_game() and data.equipment_stats() == Vector2i(0, 3), "P1 equipped items survive save and load")
	await click_icon(ui._menu_buttons["Status"])
	check(ui._status_panel.visible, "Status icon opens character page")
	await click_icon(ui.tab_book)
	for ribbon in [ui.ribbon_red, ui.ribbon_blue, ui.ribbon_green, ui.ribbon_orange, ui.ribbon_tan, ui.ribbon_fish, ui.ribbon_forage]:
		await click_icon(ribbon)
		check(ui.tab_book.texture_normal == ui.TEX_TAB_ACTIVE, "Category filter keeps Bag page active")
	check(ui.current_category == ItemData.Category.FORAGE, "Forest filter is on the right ribbon")
	await capture("menu_bag")
	var item := GameState._resolve_item("common_mushroom")
	check(item != null, "Forage catalog fixture exists")
	if item != null:
		data.add_item(item, 1)
		data.remove_item(item.item_id, 1)
		check(DiscoveryManager.has_discovered("item_" + item.item_id), "Discovery survives removal from inventory")
	await click_icon(ui.tab_collection)
	check(ui._collection_panel.visible and not ui._status_panel.visible, "Collection is a separate page")
	if item != null:
		check(ui._collection_panel.is_known(item), "Forage collection uses persisted discovery")
	var fish := GameState._resolve_item("fish_carp")
	DiscoveryManager.discover("fish_" + fish.item_id)
	check(ui._collection_panel.is_known(fish), "Collection supports legacy fish discovery IDs")
	check(SaveManager.save_game(), "Collection test saves through existing save format")
	DiscoveryManager.reset()
	check(SaveManager.load_game(), "Collection test reloads saved progress")
	check(ui._collection_panel.is_known(fish) and ui._collection_panel.is_known(item), "Fish and forage discoveries survive save/load")
	ui._collection_panel._set_category(ItemData.Category.FORAGE)
	await get_tree().process_frame
	await capture("menu_collection")
	await click_icon(ui.tab_book)
	await click_control(ui._btn_sort, ui._btn_sort.get_global_rect().get_center())
	check(ui._selected_slot_index == -1, "Sort is a button inside Bag")
	await click_icon(ui.tab_gear)
	var settings_page: PanelContainer = ui._settings_panel
	check(settings_page.visible and not settings.visible, "Settings opens as a book page without a separate overlay")
	settings_page.get_node("%Section").select(1)
	settings_page._select_section(1)
	settings_page.get_node("%Music").value = 0.35
	settings_page.get_node("%Sfx").value = 0.65
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))), 0.35), "Music slider controls Music bus")
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))), 0.65), "SFX slider controls SFX bus independently")
	var config := ConfigFile.new()
	config.load(SettingsMenu.CONFIG_PATH)
	check(is_equal_approx(config.get_value("audio", "music_volume", 0.0), 0.35) and is_equal_approx(config.get_value("audio", "sfx_volume", 0.0), 0.65), "Audio channels persist separately")
	await capture("menu_settings")
	check(settings_page.get_node("%Bindings").get_child_count() > 0, "Book settings exposes editable keyboard and gamepad bindings")
	var binding_button := settings_page.get_node("%Bindings").get_child(0).get_node("Buttons/Keyboard") as Button
	var binding_before := binding_button.text
	binding_button.pressed.emit()
	check(not settings_page._capture.is_empty(), "Book binding button begins key capture while standalone settings stays hidden")
	var cancel_binding := InputEventKey.new()
	cancel_binding.physical_keycode = KEY_ESCAPE
	cancel_binding.pressed = true
	check(settings_page.capture_input(cancel_binding) and settings_page._capture.is_empty() and binding_button.text == binding_before, "Esc cancels binding capture and restores the button without closing inventory")

	await capture("menu_controls")
	await capture("menu_game")
	var save_button := settings_page.get_node("%Save") as Button
	settings_page.get_node("%Section").select(2)
	settings_page._select_section(2)
	await get_tree().process_frame
	await click_control(save_button, save_button.get_global_rect().get_center())
	check(is_instance_valid(settings._slot_menu), "Single save route opens the three-slot chooser")
	settings._slot_menu.queue_free()
	await get_tree().process_frame
	settings._slot_menu = null
	settings._confirm_exit(false)
	check(settings._exit_dialog.visible and not settings._exit_to_desktop, "Menu exit asks about unsaved progress")
	settings._exit_dialog.hide()
	settings._confirm_exit(true)
	check(settings._exit_dialog.visible and settings._exit_to_desktop, "Desktop exit also requires in-game confirmation")
	settings._exit_dialog.hide()
	await click_icon(ui.tab_book)
	check(not settings_page.visible and get_tree().paused, "Switching from settings returns to paused bag page")
	ui._close()
	Coop.active = true
	settings._open()
	check(not get_tree().paused, "Settings does not pause other players during co-op")
	settings._close()
	data.index = 1
	ui._open()
	ui._on_gear_pressed()
	check(not settings.visible and ui.tab_gear.tooltip_text.contains("P1"), "P2 cannot open global settings and sees P1-only hint")
	ui._close()
	data.index = 0
	Coop.active = false
	settings.set_save_buttons_visible(false)
	check(not settings._save_row.visible and not settings.get_node("%BtnMainMenu").visible, "Main-menu settings hides gameplay save and return-to-menu actions")
	# Pertahankan runner saat berpindah ke menu utama.
	get_tree().current_scene = null
	settings._exit_to_desktop = false
	settings._perform_exit()
	await get_tree().process_frame
	await get_tree().process_frame
	check(get_tree().current_scene != null and get_tree().current_scene.scene_file_path == "res://scenes/ui/main_menu.tscn", "Confirmed menu exit returns to the main-menu scene")
	check(not Coop.active and not DayCycle.is_running and not get_tree().paused, "Leaving gameplay clears co-op, day cycle, and pause state")
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))), 0.35), "Audio channels reload in main-menu settings")
	print("MENU REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)

func recipe_button(id: String) -> Button:
	for button: Button in ui._crafting_panel._recipe_buttons:
		var recipe: CraftingRecipe = button.get_meta("recipe")
		if recipe.recipe_id == id:
			ui._crafting_panel.get_node("%RecipePager").reveal(button.get_index())
			return button
	return null

func click_icon(button: TextureButton) -> void:
	var point: Vector2 = button.get_node("Icon").get_global_rect().get_center()
	await click_control(button, point)

func click_control(control: Control, point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	check(get_viewport().gui_get_hovered_control() == control, "Mouse input reaches " + control.name)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = point
		event.global_position = point
		get_viewport().push_input(event, true)
		await get_tree().process_frame

func capture(name_text: String) -> void:
	# Let rebuilt recipe grids finish layout even when screenshots are disabled.
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://scratch/" + name_text + ".png")
