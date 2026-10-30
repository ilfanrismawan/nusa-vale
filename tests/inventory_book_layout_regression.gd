extends Node
var failures := 0
func check(value: bool, message: String) -> void:
	if value: print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	var inv = load("res://scenes/ui/ui_inventory.tscn").instantiate()
	add_child(inv)
	inv._open()
	if "--crafting-only" in OS.get_cmdline_user_args():
		inv._show_crafting()
		await get_tree().process_frame
		await get_tree().process_frame
		check_area(inv._crafting_panel.get_node("Pages/Left"), "crafting left page")
		check_area(inv._crafting_panel.get_node("Pages/Right"), "crafting right page")
		await check_crafting(inv)
		inv._close()
		inv.queue_free()
		print("CRAFTING TABS COMPLETE: failures=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return
	for control: Control in inv.find_children("*", "Control", true, false):
		check_text_style(control, "inventory including hidden controls")
	if "--npc-details-only" in OS.get_cmdline_user_args():
		inv._show_relationships()
		inv._relationship_ui._open_npc("zarathia")
		for section in 4:
			inv._relationship_ui._select_section(section)
			await get_tree().process_frame
			check_area(inv._relationship_ui.get_node("%DetailsLeft"), "NPC profile/journal %d" % section)
			check_area(inv._relationship_ui.get_node("Design/Right"), "NPC gift panel %d" % section)
		inv._relationship_ui._select_section(2)
		for category in 5:
			inv._relationship_ui._select_category(category)
			await get_tree().process_frame
			check_area(inv._relationship_ui.get_node("Design/Right"), "NPC gift category %d" % category)
		inv._relationship_ui._select_section(3)
		var gift_info: Control = inv._relationship_ui.get_node("%GiftInfo")
		var long_gift_note := "Catatan hadiah panjang untuk memeriksa font piksel enam belas. ".repeat(24)
		gift_info.text = long_gift_note
		await get_tree().process_frame
		await get_tree().process_frame
		check(gift_info._pages.size() > 1, "16px gift detail paginates long descriptions")
		check_area(inv._relationship_ui.get_node("Design/Right"), "long 16px gift detail")
		check("".join(gift_info._pages).replace(" ", "").replace("\n", "") == long_gift_note.replace(" ", ""), "16px gift pagination preserves all text")
		inv._close()
		inv.queue_free()
		print("NPC DETAIL LAYOUT COMPLETE: failures=%d" % failures)
		get_tree().quit(1 if failures else 0)
		return
	var top_tabs: Control = inv.get_node("%TopTabsContainer")
	check(top_tabs.position == Vector2(44, -40), "compact tabs match reference book inset and top margin")
	check(inv._top_tabs.size() == 9 and top_tabs.find_children("*", "Label", true, false).is_empty(), "all nine top tabs are icon-only")
	for index in inv._top_tabs.size():
		var tab: TextureButton = inv._top_tabs[index]
		check(tab.position.x == index * 38 and tab.size.x == 38, "tab %d touches its neighbours without spacing" % index)
		check(is_equal_approx(tab.position.y + tab.size.y, 42.0), "tab %d stays attached to book edge" % index)
		var icon_rect: Rect2 = tab.get_node("Icon").get_rect()
		check(not tab.tooltip_text.is_empty() and icon_rect.size == Vector2(24, 24) and is_equal_approx(icon_rect.get_center().x, tab.size.x / 2.0) and Rect2(Vector2.ZERO, tab.size).encloses(icon_rect), "tab %d has centred icon padding and accessible name" % index)
		tab.mouse_entered.emit()
		check(is_equal_approx(tab.position.y + tab.size.y, 42.0), "hover keeps tab %d attached" % index)
		tab.mouse_exited.emit()
	inv._show_bag_page()
	if DisplayServer.get_name() != "headless":
		await get_tree().process_frame
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png("res://scratch/inventory_top_tabs_preview.png")
	# Native dropdown internals have no scene owner; page content must have no scrollers.
	check(inv.book_root.find_children("*", "ScrollContainer", true, true).is_empty(), "inventory contains no scroll containers")
	for method: String in ["_show_bag_page", "_show_status", "_show_equipment", "_show_crafting", "_show_skills", "_show_relationships", "_show_collection", "_on_gear_pressed", "_show_controls"]:
		inv.call(method)
		await get_tree().process_frame
		await get_tree().process_frame
		var areas: Array[Control] = []
		if method == "_show_bag_page":
			areas.assign([inv.book_root.get_node("LeftPage"), inv.book_root.get_node("RightPage")])
		else:
			var pages: Dictionary = {"_show_status": inv._status_panel, "_show_equipment": inv._equipment_panel, "_show_crafting": inv._crafting_panel, "_show_skills": inv._skill_tree, "_show_relationships": inv._relationship_ui, "_show_collection": inv._collection_panel, "_on_gear_pressed": inv._settings_panel, "_show_controls": inv._controls_panel}
			var page: Control = pages[method]
			var design: Node = page.get_node("Design" if page.has_node("Design") else "Pages")
			areas.assign([design.get_child(0), design.get_child(1)])
		var count := 0
		for area: Control in areas:
			var bounds := area.get_global_rect().grow(0.2)
			for control: Node in area.find_children("*", "Control", true, false):
				if control.is_visible_in_tree():
					check_text_style(control, method)
					if not bounds.encloses(control.get_global_rect()):
						check(false, "%s outside paper: %s %s vs %s" % [method, area.get_path_to(control), control.get_global_rect(), bounds])
					count += 1
		print("CHECKED: %s (%d visible controls)" % [method, count])
	inv._show_controls()
	check(inv._controls_panel.visible and not inv._settings_panel.visible, "controls opens as a dedicated tab")
	var controls: PanelContainer = inv._controls_panel
	check(controls.get_node("%Bindings").get_child_count() > 0, "controls lists configurable actions")
	var binding_button: Button = controls.get_node("%Bindings").get_child(0).get_node("Buttons/Keyboard")
	controls._begin_capture(PlayerInput.rows()[0]["id"], "kb", binding_button)
	var cancel := InputEventKey.new()
	cancel.physical_keycode = KEY_ESCAPE
	cancel.pressed = true
	check(controls.capture_input(cancel) and controls._capture.is_empty(), "Escape cancels rebinding")
	controls._begin_capture(PlayerInput.rows()[0]["id"], "kb", binding_button)
	inv._show_bag_page()
	check(controls._capture.is_empty(), "leaving controls cancels rebinding")
	# Check secondary sections as well as the initial view of every tab.
	inv._on_gear_pressed()
	for index in 5:
		inv._settings_panel._select_section(index)
		await get_tree().process_frame
		check_area(inv._settings_panel.get_node("Pages/Left"), "settings section %d" % index)
		check_area(inv._settings_panel.get_node("Pages/Right"), "settings right section %d" % index)
	inv._show_relationships()
	inv._relationship_ui._open_npc("zarathia")
	for index in 4:
		inv._relationship_ui._select_section(index)
		await get_tree().process_frame
		check_area(inv._relationship_ui.get_node("%DetailsLeft"), "NPC left section %d" % index)
		check_area(inv._relationship_ui.get_node("Design/Right"), "NPC section %d" % index)
	inv._relationship_ui._select_section(2)
	for index in 5:
		inv._relationship_ui._select_category(index)
		await get_tree().process_frame
		check_area(inv._relationship_ui.get_node("Design/Right"), "gift category %d" % index)
	inv._show_collection()
	var detail = inv._collection_panel.get_node("%Detail")
	var source := "Kalimat panjang untuk memeriksa isi halaman buku. ".repeat(12)
	detail.text = source
	await get_tree().process_frame
	check(detail._pages.size() > 1, "long notes create text pages")
	var reconstructed := "".join(detail._pages).replace(" ", "").replace("\n", "")
	check(reconstructed == source.replace(" ", ""), "text pagination preserves every character")
	detail._change(1)
	check(detail._page == 1 and detail.get_node("Body").text == detail._pages[1], "text next reaches second page")
	inv._show_crafting()
	await check_crafting(inv)
	inv._close()
	inv.queue_free()
	print("INVENTORY BOOK LAYOUT COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)

func check_area(area: Control, context: String) -> void:
	var bounds := area.get_global_rect().grow(0.2)
	for node: Node in area.find_children("*", "Control", true, false):
		if node.is_visible_in_tree():
			check_text_style(node, context)
		if node.is_visible_in_tree() and not bounds.encloses(node.get_global_rect()):
			check(false, "%s outside paper: %s %s vs %s" % [context, area.get_path_to(node), node.get_global_rect(), bounds])

func check_text_style(control: Control, context: String) -> void:
	if not (control is Label or control is Button or control is LineEdit):
		return
	var font := control.get_theme_font("font")
	var pixel_size := control.get_theme_font_size("font_size")
	if control is Label and control.label_settings != null:
		if control.label_settings.font != null:
			font = control.label_settings.font
		pixel_size = control.label_settings.font_size
	while font is FontVariation:
		font = font.base_font
	check(font != null and font.resource_path == "res://assets/fonts/m5x7.ttf", "%s %s uses m5x7" % [context, control.name])
	check(pixel_size == 16, "%s %s uses font size 16" % [context, control.name])

func check_crafting(inv) -> void:
	var crafting = inv._crafting_panel
	check(crafting._filters.size() == crafting.GROUPS.size(), "crafting has one icon tab per category")
	for index in crafting._filters.size():
		var tab: TextureButton = crafting._filters[index]
		check(tab.get_node("Icon").texture != null and not tab.tooltip_text.is_empty(), "crafting filter %d has an icon and accessible name" % index)
		check(tab.get_global_rect().end.x <= crafting.get_node("Pages/Left").get_global_rect().position.x, "crafting filter %d stays on the outer left edge" % index)
		if index > 0:
			check(crafting._filters[index - 1].get_rect().end.y <= tab.position.y, "crafting filter tabs stack without overlap")
		tab.pressed.emit()
		check(crafting._group == crafting.GROUPS[index] and tab.button_pressed, "crafting filter %d selects its category" % index)
		for recipe_button in crafting._recipe_buttons:
			check(index == 0 or recipe_button.get_meta("recipe").group == crafting.GROUPS[index], "crafting filters only show matching recipes")
	crafting._select_group("Semua")
	if DisplayServer.get_name() != "headless":
		await get_tree().process_frame
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png("res://scratch/crafting_vertical_tabs_preview.png")
	var pager = inv._crafting_panel.get_node("%RecipePager")
	var total: int = inv._crafting_panel._recipe_buttons.size()
	pager.reveal(total - 1)
	check(inv._crafting_panel._recipe_buttons[-1].visible, "last recipe reachable without scroll")
	check(not inv._crafting_panel._recipe_buttons[0].visible and pager.get_node("Next").disabled, "last recipe group excludes first group")
	pager.reveal(0)
	check(inv._crafting_panel._recipe_buttons[0].visible, "recipe pager returns to first group")
